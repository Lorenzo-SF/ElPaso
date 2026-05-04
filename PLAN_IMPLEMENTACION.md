# 🛠️ PLAN DE IMPLEMENTACIÓN — Sprint de Hardening ElPaso v0.1.0

> **Objetivo**: Corregir los 33 issues identificados en la auditoría y dotar al proyecto de una suite de testing real.  
> **Duración estimada**: 3 semanas (15 días laborables)  
> **Resultado esperado**: ElPaso listo para producción con score de seguridad ≥ 85/100  
> **Auditoría de referencia**: `AUDITORIA_FINAL.md` (leer antes de empezar)

---

## 📋 ÍNDICE

1. [Preparación y Prerrequisitos](#1-preparación-y-prerrequisitos)
2. [Fase 1: Issues Críticos (6 fixes — 5 días)](#2-fase-1-issues-críticos)
3. [Fase 2: Issues de Alta Prioridad (11 fixes — 5 días)](#3-fase-2-issues-de-alta-prioridad)
4. [Fase 3: Issues de Media Prioridad (10 fixes — 3 días)](#4-fase-3-issues-de-media-prioridad)
5. [Fase 4: Issues de Baja Prioridad (6 fixes — 1 día)](#5-fase-4-issues-de-baja-prioridad)
6. [Fase 5: Suite de Testing (6 días)](#6-fase-5-suite-de-testing)
7. [Verificación Final](#7-verificación-final)
8. [Anexo A: Archivos modificados completos](#8-anexo-a-archivos-modificados-completos)
9. [Anexo B: Dependencias entre fixes](#9-anexo-b-dependencias-entre-fixes)

---

## 1. PREPARACIÓN Y PRERREQUISITOS

### 1.1 Entorno necesario

```bash
# Verifica versiones
elixir --version   # Debe ser 1.19.5
erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell  # Debe ser "28"

# PostgreSQL corriendo
pg_isready

# Base de datos de desarrollo
mix ecto.create  # Si no existe
mix ecto.migrate
```

### 1.2 Rama de trabajo

```bash
cd /home/merendandum/proyectos/elpaso
git checkout -b hardening-sprint
```

### 1.3 Convenciones

- Cada fix se implementa en **un commit separado** con mensaje Conventional Commits
- Después de cada fix: `mix compile` debe pasar sin errores
- Después de cada fase: ejecutar `mix test` para asegurar no regresiones
- Los archivos modificados se listan al final de cada fix

### 1.4 Orden de implementación

```
FASE 1 (días 1-5)   → FASE 2 (días 6-10)  → FASE 3 (días 11-13)
        ↓                      ↓                      ↓
   CRÍTICOS              ALTA PRIORIDAD         MEDIA PRIORIDAD

FASE 4 (día 14)      → FASE 5 (días 15-20)   → VERIFICACIÓN (día 21)
        ↓                      ↓                      ↓
   BAJA PRIORIDAD          TESTING SUITE         CIERRE Y RELEASE
```

---

## 2. FASE 1: ISSUES CRÍTICOS

> **Tiempo**: 5 días | **Fixes**: 6 | **Archivos**: 7 | **Impacto**: Bloqueante

---

### FIX-01: SQL Injection en creación de BD

- **Issue**: CRIT-01
- **Archivo**: `lib/el_paso/cli.ex`
- **Líneas**: 514-546
- **Prioridad**: 🔴 CRÍTICO
- **Riesgo**: Ejecución arbitraria de SQL si el usuario controla `DATABASE_URL`

#### 🐛 Código ACTUAL (busca esto en el archivo)

```elixir
# Líneas 514-546 en lib/el_paso/cli.ex
defp handle_db(["create" | _]) do
    config =
      Ecto.Repo.Supervisor.parse_url(
        System.get_env("DATABASE_URL", "postgresql://postgres:postgres@localhost/elpaso")
      )

    db_name = config[:database]

    # Conectar a postgres sin especificar DB para crear la nuestra
    create_config = Keyword.put(config, :database, "postgres")

    case Postgrex.start_link(create_config) do
      {:ok, conn} ->
        case Postgrex.query(conn, "CREATE DATABASE #{db_name}", []) do
          {:ok, _} ->
            Output.success("Base de datos '#{db_name}' creada")
            GenServer.stop(conn)

          {:error, %{postgres: %{code: :duplicate_database}}} ->
            Output.info("Base de datos '#{db_name}' ya existe")
            GenServer.stop(conn)

          {:error, reason} ->
            Output.error("Error al crear la base de datos: #{inspect(reason)}")
            System.halt(1)
        end

      {:error, reason} ->
        Output.error("No se pudo conectar a PostgreSQL: #{inspect(reason)}")
        Output.info("Asegúrate de que PostgreSQL está corriendo.")
        System.halt(1)
    end
  end
```

#### ✅ Código NUEVO (reemplaza todo el bloque)

```elixir
defp handle_db(["create" | _]) do
    # Validar que el nombre de BD solo contenga caracteres seguros
    db_url = System.get_env("DATABASE_URL", "postgresql://postgres:postgres@localhost/elpaso")

    config = Ecto.Repo.Supervisor.parse_url(db_url)
    db_name = config[:database]

    # Validar db_name contra inyección: solo letras, números, guiones y underscore
    unless String.match?(db_name, ~r/^[a-zA-Z0-9_-]+$/) do
      Output.error("Nombre de base de datos inválido: '#{db_name}'. Solo se permiten letras, números, guiones y underscores.")
      System.halt(1)
    end

    # Conectar a postgres sin especificar DB para crear la nuestra
    create_config = Keyword.put(config, :database, "postgres")

    case Postgrex.start_link(create_config) do
      {:ok, conn} ->
        # Usar quoted identifier para prevenir SQL injection
        safe_db_name = "\"#{String.replace(db_name, "\"", "\"\"")}\""

        case Postgrex.query(conn, "CREATE DATABASE #{safe_db_name}", []) do
          {:ok, _} ->
            Output.success("Base de datos '#{db_name}' creada")
            GenServer.stop(conn)

          {:error, %{postgres: %{code: :duplicate_database}}} ->
            Output.info("Base de datos '#{db_name}' ya existe")
            GenServer.stop(conn)

          {:error, reason} ->
            Output.error("Error al crear la base de datos: #{inspect(reason)}")
            GenServer.stop(conn)
            System.halt(1)
        end

      {:error, reason} ->
        Output.error("No se pudo conectar a PostgreSQL: #{inspect(reason)}")
        Output.info("Asegúrate de que PostgreSQL está corriendo.")
        System.halt(1)
    end
  end
```

#### 🧪 Verificación

```bash
# Test 1: Nombre normal debe funcionar
DATABASE_URL="postgresql://postgres:postgres@localhost/elpaso_dev" mix run -e 'ElPaso.CLI.main(["db","create"])'

# Test 2: Nombres con caracteres especiales deben ser rechazados (NO deben crear BD)
DATABASE_URL="postgresql://postgres:postgres@localhost/evil;DROP_TABLE_users;" mix run -e 'ElPaso.CLI.main(["db","create"])'
# Debe mostrar: "Nombre de base de datos inválido"
```

#### 📝 Explicación

La interpolación directa de `db_name` en SQL permite inyección. La solución:
1. Valida que `db_name` solo contenga caracteres seguros (`^[a-zA-Z0-9_-]+$`)
2. Escapa las comillas dobles dentro del nombre (aunque ya no deberían aparecer tras la validación)
3. Envuelve el identificador en comillas dobles (PostgreSQL quoted identifier)
4. Añade `GenServer.stop(conn)` también en el caso de error (estaba ausente, causando resource leak)

---

### FIX-02: JWT secret hardcodeado

- **Issue**: CRIT-02
- **Archivos**: `lib/el_paso/security/jwt.ex` + `config/prod.exs`
- **Líneas**: jwt.ex:105-108, prod.exs:20-21
- **Prioridad**: 🔴 CRÍTICO
- **Riesgo**: Cualquiera puede generar tokens JWT válidos

#### 🐛 Código ACTUAL — `lib/el_paso/security/jwt.ex:104-108`

```elixir
  # Obtener secret desde env o config
  defp get_secret do
    System.get_env("ELPASO_JWT_SECRET") ||
      Application.get_env(:elpaso, :jwt_secret, "dev-secret-change-in-prod")
  end
```

#### 🐛 Código ACTUAL — `config/prod.exs:20-21`

```elixir
config :elpaso,
  jwt_secret: System.get_env("ELPASO_JWT_SECRET", "change-me-in-production")
```

#### ✅ Código NUEVO — `lib/el_paso/security/jwt.ex:104-124`

```elixir
  # Obtener secret desde env o config.
  # En producción, EXIGE que ELPASO_JWT_SECRET esté configurado con un valor fuerte.
  defp get_secret do
    secret = System.get_env("ELPASO_JWT_SECRET") ||
             Application.get_env(:elpaso, :jwt_secret)

    # Lista negra de secrets inseguros (nunca permitir en producción)
    unsafe_defaults = [
      "dev-secret-change-in-prod",
      "change-me-in-production",
      "secret",
      "changeme"
    ]

    is_prod = Application.get_env(:elpaso, :env) == :prod || config_env_is_prod?()

    cond do
      is_nil(secret) and is_prod ->
        raise """
        ⚠️  ELPASO_JWT_SECRET debe estar configurado en producción.

        Añade a tu entorno:
          export ELPASO_JWT_SECRET="$(openssl rand -base64 64)"

        O en config/prod.exs:
          config :elpaso, jwt_secret: System.fetch_env!("ELPASO_JWT_SECRET")
        """

      is_nil(secret) ->
        # Desarrollo: generar un secret aleatorio para la sesión (no persiste)
        Logger.warning("JWT secret no configurado. Generando secret temporal para desarrollo.")
        :crypto.strong_rand_bytes(32) |> Base.encode64()

      secret in unsafe_defaults and is_prod ->
        raise """
        ⚠️  ELPASO_JWT_SECRET usa un valor por defecto inseguro: "#{secret}"

        Genera un secret fuerte:
          openssl rand -base64 64
        """

      true ->
        secret
    end
  end

  defp config_env_is_prod? do
    case Application.get_env(:elpaso, :env) do
      :prod -> true
      _ -> false
    end
  end
```

#### ✅ Código NUEVO — `config/prod.exs:20-21`

```elixir
# En producción, ELPASO_JWT_SECRET es OBLIGATORIO. Sin fallback inseguro.
config :elpaso,
  jwt_secret: System.get_env("ELPASO_JWT_SECRET")
```

> **NOTA**: `System.get_env/1` (sin default) retorna `nil` si no existe. `System.fetch_env!("VAR")` lanzaría error. Usamos `get_env/1` y validamos en `get_secret/0`.

#### 🧪 Verificación

```bash
# En desarrollo: debe arrancar sin ELPASO_JWT_SECRET (genera uno temporal)
mix run -e 'IO.inspect(ElPaso.Security.JWT.generate_token("test"))'
# Debe generar un token sin errores, y mostrar warning en logs

# En producción simulado: debe FALLAR sin ELPASO_JWT_SECRET
MIX_ENV=prod mix run -e 'ElPaso.Security.JWT.generate_token("test")'
# Debe lanzar excepción con mensaje claro sobre ELPASO_JWT_SECRET

# En producción simulado con secret válido: debe funcionar
ELPASO_JWT_SECRET="$(openssl rand -base64 64)" MIX_ENV=prod mix run -e 'IO.inspect(ElPaso.Security.JWT.generate_token("test"))'
# Debe generar token correctamente
```

#### 📝 Explicación

El fallback `"dev-secret-change-in-prod"` es el problema. La solución:
1. **Producción**: Si no hay secret o es uno de los defaults inseguros → `raise` con mensaje claro.
2. **Desarrollo**: Si no hay secret → genera uno aleatorio temporal (no persiste entre reinicios, aceptable para dev).
3. Elimina el fallback `"change-me-in-production"` de `prod.exs`.

---

### FIX-03: Bug tokens siempre en cero (OpenAI + Anthropic)

- **Issue**: CRIT-03
- **Archivo**: `lib/el_paso/engine/http_client.ex`
- **Líneas**: 52-62 (OpenAI) y 111-121 (Anthropic)
- **Prioridad**: 🔴 CRÍTICO
- **Riesgo**: Métricas de uso incorrectas, cost management no funciona, estadísticas de router basura

#### 🐛 Código ACTUAL — `openai_compatible` (líneas 52-62)

```elixir
    case request(:post, url, headers, body, timeout) do
      {:ok, %{"choices" => [%{"message" => message, "finish_reason" => finish}]}} ->
        {:ok,
         %{
           content: message["content"],
           finish_reason: map_finish_reason(finish),
           prompt_tokens:
             Map.get(body, "usage", %{}) |> Map.get("prompt_tokens", 0) |> safe_int(),
           completion_tokens:
             Map.get(body, "usage", %{}) |> Map.get("completion_tokens", 0) |> safe_int()
         }}
```

#### 🐛 Código ACTUAL — `anthropic` (líneas 111-121)

```elixir
    case request(:post, url, headers, body, timeout) do
      {:ok, %{"content" => [%{"text" => text}], "stop_reason" => stop}} ->
        usage = Map.get(body, "usage", %{})

        {:ok,
         %{
           content: text,
           finish_reason: map_anthropic_reason(stop),
           prompt_tokens: Map.get(usage, "input_tokens", 0) |> safe_int(),
           completion_tokens: Map.get(usage, "output_tokens", 0) |> safe_int()
         }}
```

> **El bug**: `body` es la variable local que contiene el **payload del request** enviado al API. La respuesta HTTP está en la variable `parsed` que viene del pattern match. `usage` debe leerse de la respuesta, no del request.

#### ✅ Código NUEVO — `openai_compatible` (líneas 52-62)

```elixir
    case request(:post, url, headers, body, timeout) do
      {:ok, %{"choices" => [%{"message" => message, "finish_reason" => finish}]} = response} ->
        resp_usage = Map.get(response, "usage", %{})
        {:ok,
         %{
           content: message["content"],
           finish_reason: map_finish_reason(finish),
           prompt_tokens:
             Map.get(resp_usage, "prompt_tokens", 0) |> safe_int(),
           completion_tokens:
             Map.get(resp_usage, "completion_tokens", 0) |> safe_int()
         }}
```

#### ✅ Código NUEVO — `anthropic` (líneas 111-121)

```elixir
    case request(:post, url, headers, body, timeout) do
      {:ok, %{"content" => [%{"text" => text}], "stop_reason" => stop} = response} ->
        resp_usage = Map.get(response, "usage", %{})

        {:ok,
         %{
           content: text,
           finish_reason: map_anthropic_reason(stop),
           prompt_tokens: Map.get(resp_usage, "input_tokens", 0) |> safe_int(),
           completion_tokens: Map.get(resp_usage, "output_tokens", 0) |> safe_int()
         }}
```

#### 🧪 Verificación

```bash
# Si tienes un engine real configurado, haz una inferencia y verifica que los tokens no son 0:
./elpaso model add --name test-model --engine openai --url https://api.openai.com/v1 --api-key $OPENAI_KEY
./elpaso bench run --models test-model --prompt "Hello, count to 10"
# Debe mostrar tokens > 0 en los resultados
```

#### 📝 Explicación

La variable `body` en `openai_compatible/4` contiene el mapa que se envió como payload (línea 37: `body = %{model: model, messages: messages, ...}`). La respuesta del API viene en la variable matcheada del `case`. El fix captura la respuesta completa con `= response` y extrae `usage` de ahí.

---

### FIX-04: ModelManager serializa toda inferencia (bloqueo GenServer)

- **Issue**: CRIT-04
- **Archivo**: `lib/el_paso/domain/model_manager.ex`
- **Líneas**: 59-103
- **Prioridad**: 🔴 CRÍTICO
- **Riesgo**: Una sola request lenta bloquea todas las demás

#### 🐛 Código ACTUAL (líneas 59-103)

```elixir
  def infer(model_id, request) do
    GenServer.call(__MODULE__, {:infer, model_id, request})
  end

  @impl GenServer
  def handle_call(:all_states, _from, state) do
    {:reply, Enum.map(state.models, &model_to_state/1), state}
  end

  def handle_call({:infer, model_id, request}, _from, state) do
    # Find the model by name
    model = Enum.find(state.models, &(&1.name == model_id))

    result =
      case model do
        nil ->
          {:error, :model_not_found}

        %Model{} ->
          # Ensure circuit breaker exists for this model
          ensure_circuit_breaker(model_id)

          # Protected call via Zaguan Circuit Breaker
          case Zaguan.Engine.CircuitBreaker.call(
                 model_id,
                 fn -> do_infer(model, request) end,
                 @circuit_opts
               ) do
            {:ok, response} ->
              Zaguan.Engine.CircuitBreaker.success(model_id)
              {:ok, response}

            {:error, reason} ->
              Zaguan.Engine.CircuitBreaker.failure(model_id)

              Logger.warning(
                "[ModelManager] Inference failed for #{model_id}: #{inspect(reason)}"
              )

              {:error, reason}
          end
      end

    {:reply, result, state}
  end
```

#### ✅ Código NUEVO

```elixir
  # ── Client API ──────────────────────────────────────────────

  @doc """
  Ejecuta inferencia en un modelo.

  La inferencia se ejecuta de forma asíncrona en un Task supervisado.
  El proceso llamante recibe la respuesta vía mensaje o se bloquea
  con un timeout configurable (default: 120_000 ms).
  """
  def infer(model_id, request, timeout \\ 120_000) do
    # Validación síncrona rápida: ¿existe el modelo?
    case get_model_from_state(model_id) do
      nil ->
        {:error, :model_not_found}

      model ->
        # Ejecutar inferencia en un Task separado para no bloquear el GenServer
        task = Task.Supervisor.async_nolink(ElPaso.TaskSupervisor, fn ->
          ensure_circuit_breaker(model_id)

          case Zaguan.Engine.CircuitBreaker.call(
                 model_id,
                 fn -> do_infer(model, request) end,
                 @circuit_opts
               ) do
            {:ok, response} ->
              Zaguan.Engine.CircuitBreaker.success(model_id)
              {:ok, response}

            {:error, reason} ->
              Zaguan.Engine.CircuitBreaker.failure(model_id)
              Logger.warning("[ModelManager] Inference failed for #{model_id}: #{inspect(reason)}")
              {:error, reason}
          end
        end)

        case Task.yield(task, timeout) || Task.shutdown(task) do
          {:ok, result} -> result
          nil -> {:error, %{type: :timeout, message: "Inference timed out after #{timeout}ms"}}
        end
    end
  end

  # ── Server Callbacks ────────────────────────────────────────

  @impl GenServer
  def handle_call(:all_states, _from, state) do
    {:reply, Enum.map(state.models, &model_to_state/1), state}
  end

  @impl GenServer
  def handle_call({:get_model, model_id}, _from, state) do
    model = Enum.find(state.models, &(&1.name == model_id))
    {:reply, model, state}
  end

  @impl GenServer
  def handle_call({:reload_models}, _from, _state) do
    models = load_models()
    {:reply, {:ok, length(models)}, %{models: models, engine_states: %{}}}
  end

  @impl GenServer
  def handle_info({:model_updated, _model_id}, state) do
    # Recargar modelos cuando se notifica un cambio
    models = load_models()
    {:noreply, %{state | models: models}}
  end

  # ── Helpers ─────────────────────────────────────────────────

  defp get_model_from_state(model_id) do
    GenServer.call(__MODULE__, {:get_model, model_id})
  end

  def reload_models do
    GenServer.call(__MODULE__, :reload_models)
  end
```

#### ⚠️ Cambio adicional necesario en `lib/el_paso/application.ex`

Hay que añadir un `Task.Supervisor` al árbol de supervisión:

```elixir
# En lib/el_paso/application.ex, dentro de start/2, en base_children, ANTES de ModelManager:
base_children = [
  # Ecto Repo supervisor
  {ElPaso.Repo, []},

  # Finch
  {Finch, name: ElPaso.Finch},

  # Task.Supervisor para inferencias asíncronas
  {Task.Supervisor, name: ElPaso.TaskSupervisor},

  # Supervisor de la gestión de motores de inferencia
  ElPaso.Domain.ModelManager,

  # ... resto igual
]
```

#### 🧪 Verificación

```bash
# El servidor debe arrancar correctamente
./elpaso server start

# Debe aceptar múltiples requests concurrentes
# En dos terminales simultáneas:
curl -X POST http://localhost:8080/v1/messages -H "Content-Type: application/json" -d '{"model":"auto","max_tokens":500,"messages":[{"role":"user","content":"Escribe un ensayo largo sobre la historia de Elixir"}]}'
# La segunda request NO debe esperar a que termine la primera
```

#### 📝 Explicación

El `GenServer.call` es síncrono: el proceso GenServer ejecuta la inferencia (que puede durar 120s) y **ninguna otra request puede ser procesada** hasta que termine. Con `Task.Supervisor.async_nolink`, cada inferencia se ejecuta en su propio proceso. El `Task.yield` espera el resultado con timeout.

---

### FIX-05: Tests con valor real

- **Issue**: CRIT-05
- **Archivos**: `test/el_paso_test.exs` + crear nuevos archivos de test
- **Prioridad**: 🔴 CRÍTICO
- **Riesgo**: Sin tests, cualquier cambio puede romper funcionalidad

Este fix es extenso. Ver **Fase 5** al final del documento donde se detalla la suite completa de testing. En esta fase solo se prepara la infraestructura:

#### Acción inmediata en Fase 1

Añadir al menos tests de humo para los módulos críticos. Crear archivo `test/smoke_test.exs`:

```elixir
defmodule ElPaso.SmokeTest do
  use ExUnit.Case, async: false
  import Ecto.Query

  alias ElPaso.Repo
  alias ElPaso.Models.{Engine, Model, Personality}
  alias ElPaso.Domain.{EngineManager, ModelManager, PersonalityManager}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "EngineManager" do
    test "crea y lista engines" do
      {:ok, engine} = EngineManager.create_engine(%{
        name: "test-engine-smoke",
        adapter: "openai",
        base_url: "http://localhost:9999/v1"
      })

      engines = EngineManager.list_engines()
      assert length(engines) > 0
      assert Enum.any?(engines, &(&1.name == "test-engine-smoke"))
    end
  end

  describe "ModelManager" do
    setup do
      {:ok, engine} = EngineManager.create_engine(%{
        name: "test-engine-model",
        adapter: "openai",
        base_url: "http://localhost:9999/v1"
      })
      %{engine: engine}
    end

    test "crea y lista modelos", %{engine: engine} do
      {:ok, model} = ModelManager.create_model(%{
        name: "test-model-smoke",
        engine_id: engine.id,
        url: "http://localhost:9999/v1"
      })

      models = ModelManager.list_models()
      assert length(models) > 0
      assert Enum.any?(models, &(&1.name == "test-model-smoke"))
    end

    test "start_model y stop_model cambian active", %{engine: engine} do
      {:ok, model} = ModelManager.create_model(%{
        name: "test-model-toggle",
        engine_id: engine.id,
        url: "http://localhost:9999/v1"
      })

      {:ok, stopped} = ModelManager.stop_model("test-model-toggle")
      refute stopped.active

      {:ok, started} = ModelManager.start_model("test-model-toggle")
      assert started.active
    end

    test "get_model encuentra por nombre", %{engine: engine} do
      {:ok, _} = ModelManager.create_model(%{
        name: "test-model-get",
        engine_id: engine.id,
        url: "http://localhost:9999/v1"
      })

      found = ModelManager.get_model("test-model-get")
      assert found != nil
      assert found.name == "test-model-get"
    end
  end
end
```

#### 🧪 Verificación

```bash
mix test test/smoke_test.exs
# Deben pasar todos los tests
```

---

### FIX-06: Dispatcher integrado con Router

- **Issue**: CRIT-06
- **Archivo**: `lib/el_paso/engine/dispatcher.ex`
- **Líneas**: 1-26
- **Prioridad**: 🔴 CRÍTICO
- **Riesgo**: El dispatcher hardcodea `"default_model"`, inutilizando el sistema de routing

#### 🐛 Código ACTUAL (todo el archivo)

```elixir
defmodule ElPaso.Engine.Dispatcher do
  @moduledoc """
  Punto de entrada único para inferencia.

  Este módulo coordina las llamadas a los distintos motores de inferencia,
  determinando qué modelo usar según el contexto.
  """

  alias ElPaso.Domain.ModelManager

  @doc """
  Envía una solicitud de inferencia al modelo adecuado.
  """
  def dispatch(request) do
    # Determinar qué modelo usar para la solicitud
    model_id = determine_model(request)

    # Enviar la solicitud al modelo
    ModelManager.infer(model_id, request)
  end

  defp determine_model(_request) do
    # Lógica de selección del modelo (simplificada)
    "default_model"
  end
end
```

#### ✅ Código NUEVO (todo el archivo)

```elixir
defmodule ElPaso.Engine.Dispatcher do
  @moduledoc """
  Punto de entrada único para inferencia.

  Este módulo coordina las llamadas a los distintos motores de inferencia,
  integrando el Router para selección automática del mejor modelo.
  """

  alias ElPaso.Domain.{Router, ModelManager}
  require Logger

  @doc """
  Envía una solicitud de inferencia al modelo adecuado.

  ## Parámetros
    - `request`: mapa con `:messages` (obligatorio) y opcionalmente `:model_hint`

  ## Retorno
    - `{:ok, response}` — inferencia exitosa
    - `{:error, reason}` — error

  ## Ejemplo
      Dispatcher.dispatch(%{
        messages: [%{role: "user", content: "Escribe código para ordenar una lista"}],
        model_hint: "auto"
      })
  """
  @spec dispatch(map()) :: {:ok, map()} | {:error, term()}
  def dispatch(request) do
    messages = extract_messages(request)

    # Seleccionar modelo vía router, respetando model_hint si se especifica
    model_name =
      case Map.get(request, :model_hint) do
        hint when hint in [nil, "", "auto"] ->
          case Router.select_model(messages, %{}) do
            {:ok, %{model_name: name}} ->
              Logger.info("[Dispatcher] Router selected model: #{name}")
              name

            {:error, reason} ->
              Logger.error("[Dispatcher] Router failed: #{inspect(reason)}")
              nil
          end

        explicit_model ->
          Logger.info("[Dispatcher] Using explicit model: #{explicit_model}")
          explicit_model
      end

    if is_nil(model_name) do
      {:error, %{type: :no_model_available, message: "No active model available for inference"}}
    else
      ModelManager.infer(model_name, build_infer_request(request, model_name))
    end
  end

  # ── Private ──────────────────────────────────────────────────

  defp extract_messages(%{messages: msgs}) when is_list(msgs), do: msgs
  defp extract_messages(%{"messages" => msgs}) when is_list(msgs), do: msgs
  defp extract_messages(_), do: []

  defp build_infer_request(request, model_name) do
    %{
      messages: extract_messages(request),
      model_hint: model_name,
      temperature: Map.get(request, :temperature),
      max_tokens: Map.get(request, :max_tokens)
    }
  end
end
```

#### 🧪 Verificación

```bash
# Debe compilar sin errores
mix compile

# Verificar que el módulo exporta las funciones correctas
mix run -e 'IO.inspect(ElPaso.Engine.Dispatcher.__info__(:functions))'
# Debe mostrar: [dispatch: 1]
```

#### 📝 Explicación

El `dispatch` ahora usa `Router.select_model` cuando `model_hint` es `"auto"` o nil. Si el usuario especifica un modelo explícito, lo respeta. El `determine_model` hardcodeado se elimina.

---

## 3. FASE 2: ISSUES DE ALTA PRIORIDAD

> **Tiempo**: 5 días | **Fixes**: 11 | **Archivos**: ~12 | **Impacto**: Production-readiness

---

### FIX-07: Config.Loader.get — raise → {:error, reason}

- **Issue**: HIGH-01
- **Archivo**: `lib/el_paso/config.ex`
- **Líneas**: 40-170 (reescritura del método `get/0`)

#### Problema

`Config.Loader.get()` usa `raise` cuando faltan variables de entorno en producción. Esto crashea todo el proceso. Debe retornar `{:ok, config}` o `{:error, reason}`.

#### ✅ Código NUEVO para `Config.Loader` (líneas 40-170)

En lugar de `raise`, retornar `{:error, message}`:

```elixir
    def get do
      file_config = load_config_file()
      env_inference_url = System.get_env("ELPASO_INFERENCE_URL")
      env_inference_api_key = System.get_env("ELPASO_INFERENCE_API_KEY")

      is_prod = Application.get_env(:elpaso, :env) == :prod

      if is_prod and (!env_inference_url or !env_inference_api_key) do
        {:error, """
        Configuración requerida en producción:
          export ELPASO_INFERENCE_URL="https://tu-servidor-api.com/v1"
          export ELPASO_INFERENCE_API_KEY="sk-tu-api-key"
        """}
      else
        # En modo no producción, usar valores por defecto
        inference_url =
          env_inference_url || get_in_config(file_config, [:inference, "url"]) ||
            "http://localhost:8081/v1"

        inference_api_key =
          env_inference_api_key || get_in_config(file_config, [:inference, "api_key"]) ||
            "sk-local-test"

        config = %{
          inference: %{url: inference_url, api_key: inference_api_key},
          auth: %{
            enabled: parse_bool(System.get_env("ELPASO_AUTH_ENABLED"), get_in_config(file_config, [:auth, "enabled"], false)),
            allow_anonymous: parse_bool(System.get_env("ELPASO_ALLOW_ANONYMOUS"), get_in_config(file_config, [:auth, "allow_anonymous"], true))
          },
          # ... resto de secciones igual que antes ...
        }

        {:ok, config}
      end
    end
```

**Atención**: Este cambio rompe la API de `Config.Loader.get()`. Todos los callers deben adaptarse. Los callers son:

1. `ElPaso.Config.cluster_enabled?/0` y resto de funciones públicas en `Config`
2. `ElPaso.Security.Auth.authenticate/1` y `valid_api_key?/1`
3. `ElPaso.Domain.AutoTuner.do_auto_tune/1`
4. `ElPaso.HTTP.Server` (vía `ElPaso.Config.auto_tune_enabled?/0`)

**Cambio en cada caller**: Envolver en `case` o usar helper interno.

Ejemplo para `ElPaso.Config`:
```elixir
defp get_config! do
  case Loader.get() do
    {:ok, config} -> config
    {:error, msg} -> raise msg
  end
end
```

> **NOTA PARA EL IMPLEMENTADOR**: Este es el fix más invasivo. Requiere revisar TODOS los callers de `Loader.get()`. Si es demasiado arriesgado, una alternativa aceptable es mantener `raise` pero añadir `get_safe/0` que retorne `{:ok, config} | {:error, reason}` y migrar callers gradualmente.

---

### FIX-08: detect_task_type — heurística mejorada

- **Issue**: HIGH-02
- **Archivo**: `lib/el_paso/domain/router.ex`
- **Líneas**: 74-113

#### Problema

La heurística actual solo detecta palabras literales en inglés/español. Casi todo cae en `:unknown`.

#### ✅ Código NUEVO (reemplaza líneas 74-113)

```elixir
  # Detect task type from message content using keyword scoring
  defp detect_task_type(messages) do
    content =
      messages
      |> Enum.map(fn
        %{"content" => c} -> c
        %{content: c} -> c
        _ -> ""
      end)
      |> Enum.join(" ")
      |> String.downcase()

    # ── Keyword scoring ─────────────────────────────────────────
    # Cada categoría tiene keywords con pesos.
    # Se suma el peso de cada keyword encontrada y se elige la categoría
    # con mayor puntuación. Si ninguna supera el umbral, :unknown.

    categories = %{
      code: %{
        weight: 0,
        keywords: %{
          # Alta señal
          "function" => 4, "implement" => 4, "algorithm" => 4,
          "class" => 3, "method" => 3, "api" => 3, "endpoint" => 3,
          "bug" => 3, "error" => 3, "compile" => 3, "test" => 3,
          "debug" => 3, "refactor" => 3, "library" => 3, "framework" => 3,
          # Media señal
          "code" => 2, "program" => 2, "script" => 2, "module" => 2,
          "package" => 2, "import" => 2, "export" => 2, "return" => 2,
          "variable" => 2, "array" => 2, "string" => 2, "integer" => 2,
          "interface" => 2, "abstract" => 2, "docker" => 2, "sql" => 2,
          "query" => 2, "database" => 2, "schema" => 2, "migration" => 2,
          "html" => 2, "css" => 2, "javascript" => 2, "python" => 2,
          "elixir" => 2, "rust" => 2, "typescript" => 2,
          # Baja señal
          "file" => 1, "data" => 1, "type" => 1, "object" => 1,
          "server" => 1, "client" => 1, "request" => 1, "response" => 1
        }
      },
      translation: %{
        weight: 0,
        keywords: %{
          "translate" => 5, "translation" => 5, "traduce" => 5,
          "traducción" => 5, "traducir" => 5,
          "language" => 2, "idioma" => 2, "lengua" => 2,
          "spanish" => 3, "english" => 3, "french" => 3,
          "español" => 3, "inglés" => 3, "francés" => 3,
          "german" => 3, "chinese" => 3, "japanese" => 3,
          "alemán" => 3, "chino" => 3, "japonés" => 3,
          "to english" => 4, "to spanish" => 4, "en español" => 4
        }
      },
      summarization: %{
        weight: 0,
        keywords: %{
          "summarize" => 5, "summary" => 5, "summarization" => 5,
          "resumen" => 5, "resumir" => 5, "resume" => 4, "resum" => 4,
          "tl;dr" => 5, "tldr" => 5, "key points" => 3,
          "main idea" => 3, "brief" => 2, "concise" => 2,
          "sum up" => 4, "recap" => 4, "bullet points" => 3,
          "abstract" => 2
        }
      },
      reasoning: %{
        weight: 0,
        keywords: %{
          "analyze" => 4, "analysis" => 4, "analizar" => 4, "análisis" => 4,
          "compare" => 4, "comparison" => 4, "comparar" => 4, "comparación" => 4,
          "evaluate" => 4, "evaluation" => 4, "evaluar" => 4,
          "pros and cons" => 4, "advantages" => 3, "disadvantages" => 3,
          "ventajas" => 3, "desventajas" => 3,
          "reason" => 3, "razón" => 3, "por qué" => 3, "why" => 3,
          "cause" => 3, "effect" => 3, "consequence" => 3,
          "difference between" => 4, "diferencia entre" => 4,
          "better" => 2, "worse" => 2, "mejor" => 2, "peor" => 2,
          "opinion" => 2, "opinar" => 2, "think" => 2, "crees" => 2,
          "critique" => 4, "review" => 3, "criticar" => 4, "reseña" => 3
        }
      },
      question_answer: %{
        weight: 0,
        keywords: %{
          "what is" => 4, "what are" => 4, "qué es" => 4, "qué son" => 4,
          "define" => 4, "definition" => 4, "definir" => 4, "definición" => 4,
          "explain" => 3, "explicar" => 3, "explica" => 3, "explique" => 3,
          "describe" => 3, "describir" => 3, "describe" => 3,
          "how does" => 4, "cómo funciona" => 4, "how to" => 3,
          "who is" => 3, "when was" => 3, "where is" => 3,
          "qué significa" => 4, "cuál es" => 3, "por qué" => 2,
          "meaning of" => 4, "significado de" => 4,
          "history of" => 3, "historia de" => 3,
          "example" => 2, "ejemplo" => 2
        }
      },
      creative: %{
        weight: 0,
        keywords: %{
          "write a story" => 5, "write a poem" => 5, "escribe un cuento" => 5,
          "creative" => 4, "creativo" => 4, "imagination" => 3,
          "story" => 3, "poem" => 3, "poetry" => 3, "cuento" => 3, "poema" => 3,
          "fiction" => 3, "novel" => 2, "character" => 2,
          "roleplay" => 4, "act as" => 4, "pretend" => 3,
          "joke" => 3, "riddle" => 3, "chiste" => 3, "adivinanza" => 3,
          "song" => 3, "lyrics" => 3, "canción" => 3, "letra" => 3,
          "brainstorm" => 3, "ideas for" => 3, "ideas para" => 3
        }
      }
    }

    # Calcular puntuación para cada categoría
    scored =
      Enum.map(categories, fn {cat, %{keywords: kws}} ->
        score =
          Enum.reduce(kws, 0, fn {keyword, weight}, acc ->
            if String.contains?(content, keyword), do: acc + weight, else: acc
          end)

        {cat, score}
      end)

    # Elegir la categoría con mayor puntuación, con umbral mínimo de 4
    case Enum.max_by(scored, fn {_, score} -> score end, fn -> {:unknown, 0} end) do
      {cat, score} when score >= 4 -> cat
      _ -> :unknown
    end
  end
```

#### 🧪 Verificación

```bash
# En iex:
iex -S mix
# Probar detección:
alias ElPaso.Domain.Router
# Estos son funciones privadas, pero podemos testear indirectamente
```

#### 📝 Explicación

El nuevo sistema usa un **scoring ponderado**: cada categoría tiene keywords con pesos (1-5). Se suman los pesos de todas las keywords encontradas en el contenido y se elige la categoría con mayor puntuación, con umbral mínimo de 4 puntos para evitar falsos positivos.

---

### FIX-09: EngineManager.test_engine — :httpc → Finch

- **Issue**: HIGH-03
- **Archivo**: `lib/el_paso/domain/engine_manager.ex`
- **Líneas**: 60-95

#### ✅ Código NUEVO

```elixir
  def test_engine(name) do
    case Repo.get_by(Engine, name: name) do
      nil ->
        {:error, "Motor no encontrado"}

      %Engine{base_url: base_url, adapter: adapter} ->
        start = System.monotonic_time()
        health_url = health_url(adapter, base_url)

        # Usar Finch en lugar de :httpc (bloqueante)
        request = Finch.build(:get, health_url)
        timeout = 10_000  # Timeout corto para health check

        case Finch.request(request, ElPaso.Finch, receive_timeout: timeout) do
          {:ok, %{status: status}} when status >= 200 and status < 400 ->
            latency_ms =
              System.convert_time_unit(System.monotonic_time() - start, :native, :millisecond)
            {:ok, latency_ms}

          {:ok, %{status: status}} ->
            {:error, "HTTP #{status}"}

          {:error, reason} ->
            {:error, inspect(reason)}
        end
    end
  end

  # Health check URLs por adapter
  defp health_url("ollama", base_url), do: "#{String.trim_trailing(base_url, "/")}/api/tags"
  defp health_url("openai", base_url), do: "#{String.trim_trailing(base_url, "/")}/models"
  defp health_url("anthropic", base_url), do: "#{String.trim_trailing(base_url, "/")}/v1/messages"
  defp health_url(_adapter, base_url) do
    # Para llama.cpp y compatibles: intentar /v1/models o /health
    "#{String.trim_trailing(base_url, "/")}/health"
  end
```

#### 🧪 Verificación

```bash
./elpaso engine test --name llama-server
# Debe usar Finch, no :httpc
```

---

### FIX-10: Auth.valid_api_key? — consultar tabla users

- **Issue**: HIGH-04
- **Archivo**: `lib/el_paso/security/auth.ex`
- **Líneas**: 1-55

#### ✅ Código NUEVO (archivo completo)

```elixir
defmodule ElPaso.Security.Auth do
  @moduledoc """
  Autenticación de requests por API key.

  Busca usuarios en la tabla `users` de PostgreSQL (vía Ecto).
  Soporta también una API key global como fallback para desarrollo.
  """

  alias ElPaso.Repo
  alias ElPaso.Models.User
  import Ecto.Query

  @doc """
  Autentica un request por su API key. Devuelve {:ok, user_id} si es válido.
  """
  def authenticate(api_key) do
    config = ElPaso.Config.Loader.get() |> case do
      {:ok, c} -> c
      {:error, _} -> %{}
    end

    auth_enabled = get_in(config, [:auth, :enabled]) || false
    allow_anonymous = get_in(config, [:auth, :allow_anonymous]) || true

    cond do
      not auth_enabled ->
        {:ok, "anonymous"}

      is_nil(api_key) and allow_anonymous ->
        {:ok, "anonymous"}

      is_nil(api_key) ->
        {:error, :missing_api_key}

      true ->
        # Buscar en base de datos primero
        case find_user_in_db(api_key) do
          %User{id: user_id, active: true} ->
            {:ok, user_id}

          %User{active: false} ->
            {:error, :user_inactive}

          nil ->
            # Fallback: API key global (para desarrollo)
            global_key = Application.get_env(:elpaso, :inference_api_key)
            if api_key == global_key do
              {:ok, "admin"}
            else
              {:error, :invalid_api_key}
            end
        end
    end
  end

  @doc """
  Verifica si una API key es válida para generar token JWT en /auth/token.
  """
  def valid_api_key?(api_key) do
    case find_user_in_db(api_key) do
      %User{active: true} -> true
      _ ->
        # Fallback global key
        api_key == Application.get_env(:elpaso, :inference_api_key)
    end
  end

  @doc """
  Extrae la API key del header Authorization: Bearer <key>
  """
  def extract_api_key(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> key] -> key
      _ -> nil
    end
  end

  # ── Private ──────────────────────────────────────────────────

  defp find_user_in_db(api_key) do
    # La API key se almacena hasheada. Comparamos con hash SHA256.
    # NOTA: Si las API keys no están hasheadas aún, busca directa.
    # Para migración gradual: intentar ambos.
    api_key_hash = :crypto.hash(:sha256, api_key) |> Base.encode16(case: :lower)

    Repo.one(
      from u in User,
        where: u.api_key_hash == ^api_key_hash,
        or_where: u.api_key_hash == ^api_key
    )
  rescue
    _ -> nil
  end
end
```

> **IMPORTANTE**: Este cambio asume que existe una tabla `users` con campo `api_key_hash`. Si las API keys no están hasheadas, la migración debe hacerse. Ver FIX-24.

#### 🧪 Verificación

```bash
mix test test/el_paso/security/auth_test.exs
```

---

### FIX-11: Rate limiter en endpoints auth/admin

- **Issue**: HIGH-05
- **Archivo**: `lib/el_paso/http/server.ex`

Añadir rate limiting a `/auth/token` y endpoints `/admin/*`:

En `lib/el_paso/http/server.ex`, modificar los endpoints:

```elixir
  # V3.0: Endpoint de autenticación JWT con rate limiting
  post "/auth/token" do
    client_ip = get_client_ip(conn)

    case ElPaso.Security.RateLimiter.check_rate("auth:#{client_ip}", 5) do
      :ok ->
        with {:ok, body, _conn} <- read_body(conn),
             {:ok, params} <- Jason.decode(body),
             user_id <- Map.get(params, "user_id"),
             api_key <- Map.get(params, "api_key"),
             true <- ElPaso.Security.Auth.valid_api_key?(api_key) do
          token = ElPaso.Security.JWT.generate_token(user_id, :user)

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, Jason.encode!(%{token: token, expires_in: 86400}))
        else
          _reason ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(401, Jason.encode!(%{error: "unauthorized"}))
        end

      {:error, :rate_limited} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, Jason.encode!(%{error: "rate_limited", retry_after: 60}))
    end
  end
```

Añadir helper al final del módulo:
```elixir
  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ips | _] -> ips |> String.split(",") |> List.first() |> String.trim()
      _ -> to_string(conn.remote_ip)
    end
  end
```

---

### FIX-12: Rate limiter race condition → operación atómica

- **Issue**: HIGH-06
- **Archivo**: `lib/el_paso/security/rate_limiter.ex`
- **Líneas**: 1-30

#### ✅ Código NUEVO (archivo completo)

```elixir
defmodule ElPaso.Security.RateLimiter do
  @moduledoc """
  Token bucket rate limiter usando ETS con operaciones atómicas.

  Implementa el algoritmo token bucket:
  - Cada usuario/clave tiene un bucket con `max_tokens`.
  - Los tokens se recargan a razón de `max_tokens` por minuto.
  - Cada request consume 1 token.
  - Si no hay tokens, se rechaza con `{:error, :rate_limited}`.
  """

  @table :rate_limiter
  @cleanup_interval_ms 300_000  # 5 minutos

  @doc """
  Verifica si el usuario/clave tiene tokens disponibles.

  Retorna `:ok` si se permite el request, `{:error, :rate_limited}` si no.
  """
  @spec check_rate(String.t(), pos_integer()) :: :ok | {:error, :rate_limited}
  def check_rate(user_id, max_rpm) when is_binary(user_id) and is_integer(max_rpm) and max_rpm > 0 do
    # Usar ETS con operación atómica para evitar race conditions
    # Formato: {key, tokens_available, last_refill_second}
    key = user_id
    now = System.monotonic_time(:second)

    case :ets.lookup(@table, key) do
      [] ->
        # Primer request: crear bucket con max_rpm - 1 tokens
        :ets.insert_new(@table, {key, max_rpm - 1, now})
        :ok

      [{^key, tokens, last_refill}] ->
        # Calcular refill basado en tiempo transcurrido (en segundos)
        elapsed = now - last_refill
        # Refill rate: max_rpm tokens por 60 segundos
        refill_tokens = floor(elapsed * max_rpm / 60)
        new_tokens = min(tokens + refill_tokens, max_rpm)

        if new_tokens >= 1 do
          # Actualización atómica: solo actualizar si no ha cambiado
          :ets.insert(@table, {key, new_tokens - 1, now})
          :ok
        else
          {:error, :rate_limited}
        end
    end
  end

  @doc """
  Inicializa la tabla ETS para rate limiting.
  También programa limpieza periódica de entradas antiguas.
  """
  def init do
    case :ets.info(@table) do
      :undefined ->
        table = :ets.new(@table, [
          :named_table,
          :protected,   # Solo el proceso owner puede escribir
          :set,
          read_concurrency: true
        ])

        # Programar limpieza periódica
        spawn(fn -> cleanup_loop() end)

        table

      _ ->
        @table
    end
  end

  @doc """
  Limpia entradas que no han tenido actividad en más de 1 hora.
  """
  def cleanup_stale do
    now = System.monotonic_time(:second)
    threshold = now - 3600

    :ets.select_delete(@table, [
      {{:"$1", :"$2", :"$3"}, [{:<, :"$3", threshold}], [true]}
    ])
  end

  # ── Private ──────────────────────────────────────────────────

  defp cleanup_loop do
    Process.sleep(@cleanup_interval_ms)
    cleanup_stale()
    cleanup_loop()
  end
end
```

#### 🧪 Verificación

```bash
mix test test/el_paso/security/rate_limiter_test.exs
```

---

### FIX-13: Limpiar runtime.exs de config hardcodeada

- **Issue**: HIGH-07
- **Archivo**: `config/runtime.exs`

#### ✅ Código NUEVO (archivo completo)

```elixir
import Config

# ──────────────────────────────────────────────────────────────
# Configuración en tiempo de ejecución (runtime.exs)
#
# Este archivo se ejecuta al iniciar la aplicación.
# Las configuraciones aquí tienen prioridad sobre config.exs
# y los archivos de entorno (dev.exs, prod.exs, test.exs).
#
# SOLO configuraciones dinámicas que dependen del entorno de
# despliegue. NO hardcodear modelos, engines, o defaults inseguros.
# ──────────────────────────────────────────────────────────────

# Puerto HTTP (si no se configuró en el archivo de entorno)
if config_env() in [:dev, :prod] do
  config :elpaso,
    http_port: String.to_integer(System.get_env("ELPASO_PORT") || "4000")
end

# Repositorio Ecto — conexión desde variables de entorno
if config_env() in [:dev, :prod] do
  config :elpaso, ElPaso.Repo,
    hostname: System.get_env("DB_HOST", "localhost"),
    username: System.get_env("DB_USER", "postgres"),
    password: System.get_env("DB_PASSWORD", "postgres"),
    database: System.get_env("DB_NAME", "elpaso_#{config_env()}"),
    port: String.to_integer(System.get_env("DB_PORT", "5432")),
    pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "10")),
    log: config_env() == :dev
end
```

> **Nota**: Las configuraciones de modelos "fast"/"heavy", `inference_server_url`, `inference_api_key`, y `:security` que estaban hardcodeadas se ELIMINAN. Esas deben venir de variables de entorno o configurarse vía CLI/API.

---

### FIX-14: Security headers HTTP

- **Issue**: HIGH-08
- **Archivo**: `lib/el_paso/http/server.ex`

Añadir un plug para security headers ANTES de `plug(:match)`. Insertar entre las líneas 7 y 8:

```elixir
defmodule ElPaso.HTTP.Server do
  use Plug.Router
  require Logger

  import Plug.Conn

  # ── Security Plugs ─────────────────────────────────────────
  plug :add_security_headers

  plug(:match)
  plug(:dispatch)

  # ... resto del archivo ...

  # ── Security Headers ────────────────────────────────────────
  defp add_security_headers(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-xss-protection", "0")  # Obsoleto pero por compatibilidad
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=()")
    |> put_resp_header("content-security-policy",
      "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'")
    # HSTS solo en producción con HTTPS
    |> maybe_add_hsts()
  end

  defp maybe_add_hsts(conn) do
    if Application.get_env(:elpaso, :env) == :prod do
      put_resp_header(conn, "strict-transport-security", "max-age=31536000; includeSubDomains")
    else
      conn
    end
  end
```

---

### FIX-15: Sanitizar Logger para no loguear API keys

- **Issue**: HIGH-09
- **Archivos**: `lib/el_paso/engine/http_client.ex`, `lib/el_paso/domain/model_manager.ex`, `lib/el_paso/http/server.ex`

Añadir un helper al principio de `http_client.ex` (después de `require Logger`):

```elixir
  # ── Safe Logging ────────────────────────────────────────────
  # Redacta API keys y secrets de mensajes de log
  defp log_safe(msg) do
    Logger.info(fn -> sanitize_for_log(msg) end)
  end

  defp log_safe_error(msg) do
    Logger.error(fn -> sanitize_for_log(msg) end)
  end

  defp sanitize_for_log(term) when is_binary(term), do: term
  defp sanitize_for_log(%{api_key: _} = map) do
    Map.put(map, :api_key, "[REDACTED]")
  end
  defp sanitize_for_log(%{config: config} = map) when is_map(config) do
    sanitized_config = Map.drop(config || %{}, [:api_key])
    Map.put(map, :config, sanitized_config)
  end
  defp sanitize_for_log(term), do: inspect(term)
```

Y reemplazar todos los `Logger.error("[ElPaso.Engine.HTTPClient] ... #{inspect(reason)}")` por `log_safe_error("... #{sanitize_for_log(reason)}")`.

En `model_manager.ex`, línea 94-96, cambiar:
```elixir
Logger.warning("[ModelManager] Inference failed for #{model_id}: #{inspect(reason)}")
```
por:
```elixir
Logger.warning("[ModelManager] Inference failed for #{model_id}")
# El reason se loguea sin API keys
```

---

### FIX-16: Anthropic system field nativo

- **Issue**: HIGH-11
- **Archivo**: `lib/el_paso/engine/http_client.ex`
- **Líneas**: 322-331

#### 🐛 Código ACTUAL

```elixir
  defp transform_messages_for_anthropic(messages) do
    Enum.map(messages, fn
      %{"role" => role, "content" => content} when role in ["user", "assistant"] ->
        %{role: role, content: content}

      %{"role" => "system", "content" => content} ->
        # Anthropic usa el campo system del request, no como mensaje
        %{role: "user", content: "[SYSTEM: #{content}]"}
    end)
  end
```

#### ✅ Código NUEVO

Modificar también `anthropic/4` para extraer y pasar el system:

```elixir
  def anthropic(base_url, model, messages, opts \\ []) do
    api_key = Keyword.get(opts, :api_key, "")
    max_tokens = Keyword.get(opts, :max_tokens, 1024)
    temperature = Keyword.get(opts, :temperature, 0.7)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    # Extraer mensaje de sistema y mensajes de conversación
    {system_msg, conversation} = extract_system_message(messages)

    body =
      %{
        model: model,
        messages: transform_messages_for_anthropic(conversation),
        max_tokens: max_tokens,
        temperature: temperature
      }
      |> maybe_add_system(system_msg)

    # ... resto igual ...
  end

  # Extrae el mensaje con role: "system" y lo separa del resto
  defp extract_system_message(messages) do
    system = Enum.find(messages, &(Map.get(&1, "role") == "system" or Map.get(&1, :role) == :system))
    conversation = Enum.reject(messages, &(Map.get(&1, "role") == "system" or Map.get(&1, :role) == :system))
    {system, conversation}
  end

  defp maybe_add_system(body, nil), do: body
  defp maybe_add_system(body, %{"content" => content}), do: Map.put(body, :system, content)
  defp maybe_add_system(body, %{content: content}), do: Map.put(body, :system, content)

  defp transform_messages_for_anthropic(messages) do
    Enum.map(messages, fn
      %{"role" => role, "content" => content} when role in ["user", "assistant"] ->
        %{role: role, content: content}
      %{role: role, content: content} when role in [:user, :assistant] ->
        %{role: Atom.to_string(role), content: content}
      _ ->
        # No debería llegar aquí porque los system ya se extrajeron
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end
```

---

### FIX-17: Finch.call → Finch.request (deprecation)

- **Issue**: Adicional (detectado en compilación)
- **Archivo**: `lib/el_paso/engine/http_client.ex`
- **Líneas**: 287, 312

En Finch 0.21.0, `Finch.call/3` fue renombrado a `Finch.request/3`.

```elixir
# Línea 287: Cambiar
    case Finch.call(request, @finch, timeout) do
# Por:
    case Finch.request(request, @finch, receive_timeout: timeout) do

# Línea 312: Cambiar
    case Finch.stream(request, @finch, timeout || @default_timeout, chunk_callback) do
# Por:
    case Finch.stream(request, @finch, chunk_callback,
           receive_timeout: timeout || @default_timeout) do
```

---

## 4. FASE 3: ISSUES DE MEDIA PRIORIDAD

> **Tiempo**: 3 días | **Fixes**: 10 | **Archivos**: ~10

---

### FIX-18: Añadir Plug.Parsers

- **Archivo**: `lib/el_paso/http/server.ex`
- **Líneas**: 7-8

Insertar `plug Plug.Parsers` después de los security headers y antes de `plug(:match)`:

```elixir
  plug :add_security_headers
  plug Plug.Parsers,
    parsers: [:json],
    json_decoder: Jason,
    body_reader: {Plug.Parsers, :read_body, []},
    length: 10_000_000  # 10MB max body size
  plug(:match)
  plug(:dispatch)
```

Luego, en cada endpoint que usa `read_body` + `Jason.decode`, sustituir por `conn.body_params`:

```elixir
# ANTES:
  post "/v1/messages" do
    with {:ok, body, _conn} <- read_body(conn),
         {:ok, params} <- Jason.decode(body),
         ...

# DESPUÉS:
  post "/v1/messages" do
    params = conn.body_params
    # params ya está parseado como mapa por Plug.Parsers
    ...
```

**Aplicar a TODOS los endpoints**: `/v1/messages`, `/v1/messages_stream`, `/auth/token`.

---

### FIX-19: ETS tables :public → :protected

- **Archivos**: `lib/el_paso/security/rate_limiter.ex`, `lib/el_paso/config.ex`, `lib/el_paso/downloader/model_downloader.ex`

Cambiar las 3 tablas ETS de `:public` a `:protected`:

```elixir
# rate_limiter.ex (línea 28-29):
    :ets.new(:rate_limiter, [:named_table, :protected, :set, read_concurrency: true])

# config.ex (línea 225):
    table = :ets.new(:affinity_table, [:named_table, :protected, read_concurrency: true])

# model_downloader.ex (línea 236):
    :ets.new(@table, [:named_table, :protected, :set, read_concurrency: true])
```

> **NOTA**: Si hay procesos externos que necesitan escribir en estas tablas, deben hacerlo a través de funciones del módulo owner, no directamente.

---

### FIX-20: ModelDownloader ElPasoFinch → ElPaso.Finch

- **Archivo**: `lib/el_paso/downloader/model_downloader.ex`
- **Línea**: 112

```elixir
# Cambiar:
        |> Finch.stream(
          ElPasoFinch,
# Por:
        |> Finch.stream(
          ElPaso.Finch,
```

---

### FIX-21: Métricas Prometheus reales

- **Archivo**: `lib/el_paso/http/server.ex`
- **Líneas**: 262-299

#### ✅ Código NUEVO

```elixir
  defp generate_prometheus_metrics do
    hit_ratio = ElPaso.Telemetry.Store.prefix_cache_hit_ratio()
    events = ElPaso.Telemetry.Store.recent_events(100)

    # Contar eventos por tipo
    inference_complete = Enum.count(events, fn e -> e.name == "elpaso.inference.complete" end)
    inference_error = Enum.count(events, fn e -> e.name == "elpaso.inference.error" end)
    router_fallback = Enum.count(events, fn e -> e.name == "elpaso.router.fallback" end)
    cold_starts = Enum.count(events, fn e -> e.name == "elpaso.model.cold_start" end)

    # Calcular latencias
    latencies =
      events
      |> Enum.filter(fn e -> e.name == "elpaso.inference.complete" end)
      |> Enum.map(fn e -> Map.get(e.measurements || %{}, :latency_ms, 0) end)

    avg_latency = if latencies == [], do: 0, else: Enum.sum(latencies) / length(latencies)

    [
      "# HELP elpaso_prefix_cache_hit_ratio Ratio de cache hit del prefijo",
      "# TYPE elpaso_prefix_cache_hit_ratio gauge",
      "elpaso_prefix_cache_hit_ratio #{:erlang.float_to_binary(hit_ratio, [{:decimals, 4}])}",
      "",
      "# HELP elpaso_inference_complete_total Total de inferencias completadas",
      "# TYPE elpaso_inference_complete_total counter",
      "elpaso_inference_complete_total #{inference_complete}",
      "",
      "# HELP elpaso_inference_error_total Total de errores de inferencia",
      "# TYPE elpaso_inference_error_total counter",
      "elpaso_inference_error_total #{inference_error}",
      "",
      "# HELP elpaso_inference_avg_latency_ms Latencia media de inferencia",
      "# TYPE elpaso_inference_avg_latency_ms gauge",
      "elpaso_inference_avg_latency_ms #{:erlang.float_to_binary(avg_latency, [{:decimals, 2}])}",
      "",
      "# HELP elpaso_router_fallback_total Fallbacks del router",
      "# TYPE elpaso_router_fallback_total counter",
      "elpaso_router_fallback_total #{router_fallback}",
      "",
      "# HELP elpaso_model_cold_start_total Arranques desde frío",
      "# TYPE elpaso_model_cold_start_total counter",
      "elpaso_model_cold_start_total #{cold_starts}",
      ""
    ]
    |> Enum.join("\n")
  end
```

---

### FIX-22: Unificar config duplicada runtime.exs/prod.exs

- **Archivos**: `config/prod.exs`, `config/runtime.exs`

Mover TODA la configuración de DB a `runtime.exs` (ya hecho en FIX-13). En `prod.exs`, eliminar las líneas 78-87 (bloque `ElPaso.Repo` duplicado).

---

### FIX-23: Validación de tamaño de body en POST

- **Archivo**: `lib/el_paso/http/server.ex`

Con `Plug.Parsers` ya añadido en FIX-18, la validación de tamaño se configura con la opción `length`. Para endpoints específicos que necesitan límites más estrictos, añadir validación:

```elixir
  post "/v1/messages" do
    params = conn.body_params

    # Validar que messages no exceda cierto tamaño
    messages = Map.get(params, "messages", [])
    total_chars = messages |> Enum.map(&Map.get(&1, "content", "")) |> Enum.join() |> String.length()

    if total_chars > 100_000 do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(413, Jason.encode!(%{error: "Request too large", max_chars: 100_000}))
    else
      # ... pipeline normal ...
    end
  end
```

---

### FIX-24/25/26: Mejoras de esquema DB

Crear una nueva migración `20240505_schema_hardening.exs` en `priv/repo/migrations/`:

```elixir
defmodule ElPaso.Repo.Migrations.SchemaHardening do
  use Ecto.Migration

  def change do
    # FIX-24: Añadir PK compuesta a routing_decisions
    alter table(:routing_decisions) do
      modify :request_id, :string, null: false, primary_key: true
    end

    # FIX-24: Añadir PK a auto_tune_runs (columna serial)
    alter table(:auto_tune_runs) do
      add :id, :bigserial, primary_key: true
    end

    # FIX-25: Añadir FK de messages → sessions
    alter table(:messages) do
      modify :session_id, references(:sessions, column: :session_id, type: :string, on_delete: :delete_all), null: false
    end

    # FIX-26: Añadir CHECK constraints
    create constraint("models", :temperature_range, check: "temperature >= 0 AND temperature <= 2")
    create constraint("users", :valid_role, check: "role IN ('user', 'admin')")
  end
end
```

---

### FIX-27: Añadir @spec a funciones públicas sin documentar

Revisar todos los módulos y añadir `@spec` donde falte. Módulos prioritarios:

- `ElPaso.Domain.EngineManager`: `create_engine/1`, `list_engines/0`, `delete_engine/1`, `update_engine/2`, `test_engine/1`
- `ElPaso.Domain.PersonalityManager`: todas las funciones públicas
- `ElPaso.Domain.ProfileManager`: todas las funciones públicas
- `ElPaso.CostManager`: `record_usage/4`, `check_budget/1`

---

## 5. FASE 4: ISSUES DE BAJA PRIORIDAD

> **Tiempo**: 1 día | **Fixes**: 6

---

### FIX-28: Corregir typos en CLI help

- **Archivo**: `lib/el_paso/cli.ex`

```elixir
# Línea 64: cambiar "elapso" → "elpaso"
       elpaso cluster --help

# Línea 282: cambiar "elpasar" → "elpaso"
       elpaso bench run      Ejecutar benchmark
```

---

### FIX-29: Eliminar código muerto Config.Loader.ref/1

- **Archivo**: `lib/el_paso/config.ex`
- **Líneas**: 31-33

Eliminar la función `ref/1` (no se usa en ninguna parte del proyecto).

---

### FIX-30: Eliminar o documentar Engine behaviour

- **Archivo**: `lib/el_paso/engine.ex`

El behaviour `ElPaso.Engine` está definido (líneas 1-62) pero ningún adapter lo implementa (todos usan funciones planas en `Adapter` y `HTTPClient`).

**Opción A (recomendada)**: Eliminar el behaviour y mover los tipos `Response` y `Chunk` a `lib/el_paso/engine/types.ex`.

**Opción B**: Mantenerlo pero documentar que es para uso futuro / plugins externos. Añadir `@moduledoc` explicando que ningún adapter built-in lo usa actualmente.

---

### FIX-31: @download_dir con runtime path

- **Archivo**: `lib/el_paso/downloader/model_downloader.ex`
- **Línea**: 7

```elixir
# Cambiar de:
  @download_dir Application.compile_env(:elpaso, :default_models_dir, "~/modelos")
# Por:
  defp download_dir do
    Application.get_env(:elpaso, :default_models_dir, "~/modelos")
    |> Path.expand()
  end
```

Y actualizar la referencia en `default_dest_path` (líneas 175-178).

---

### FIX-32: AutoTuner previene ejecuciones solapadas

- **Archivo**: `lib/el_paso/domain/auto_tuner.ex`

Añadir un flag `tuning?` al estado del GenServer:

```elixir
  def init(_opts) do
    state = %{
      last_run: nil,
      last_suggestions_applied: [],
      tuning?: false    # ← NUEVO: flag para prevenir solapamiento
    }
    schedule_next_run()
    {:ok, state}
  end

  def handle_info(:run_auto_tune, %{tuning?: true} = state) do
    # Ya hay un tune en progreso, reprogramar para más tarde
    Process.send_after(self(), :run_auto_tune, 60_000)
    {:noreply, state}
  end

  def handle_info(:run_auto_tune, state) do
    {:noreply, %{state | tuning?: true}, {:continue, :run_auto_tune}}
  end

  def handle_continue(:run_auto_tune, state) do
    new_state = do_auto_tune(state)
    {:noreply, %{new_state | tuning?: false}}
  end
```

---

### FIX-33: Unificar Models/Schemas naming

Crear archivo `lib/el_paso/schemas.ex` que re-exporte todos los schemas desde un único namespace, facilitando la migración futura:

```elixir
defmodule ElPaso.Schemas do
  defmodule Model, do: ElPaso.Models.Model
  defmodule Engine, do: ElPaso.Models.Engine
  defmodule Personality, do: ElPaso.Models.Personality
  # ... etc
end
```

No es necesario migrar todas las referencias ahora, pero sí documentar la convención en el README de arquitectura.

---

## 6. FASE 5: SUITE DE TESTING

> **Tiempo**: 6 días | **Objetivo**: Cobertura ≥ 80% en módulos de dominio

---

### 6.1 Tests de Dominio (2 días)

#### `test/el_paso/domain/router_test.exs`

```elixir
defmodule ElPaso.Domain.RouterTest do
  use ElPaso.DataCase
  alias ElPaso.Domain.Router
  alias ElPaso.Repo
  alias ElPaso.Models.{Model, Engine}

  setup do
    {:ok, engine} = Repo.insert(%Engine{
      name: "test-engine",
      adapter: "openai",
      base_url: "http://localhost:9999/v1",
      active: true
    })

    {:ok, model1} = Repo.insert(%Model{
      name: "coder-model",
      engine_id: engine.id,
      url: "http://localhost:9999/v1",
      active: true,
      task_affinity: %{code: 0.9, reasoning: 0.5, summarization: 0.3, unknown: 0.5},
      complexity_ceiling: 1.0
    })

    {:ok, model2} = Repo.insert(%Model{
      name: "fast-model",
      engine_id: engine.id,
      url: "http://localhost:9999/v1",
      active: true,
      task_affinity: %{code: 0.3, reasoning: 0.4, summarization: 0.9, unknown: 0.5},
      complexity_ceiling: 0.7
    })

    %{engine: engine, models: [model1, model2]}
  end

  describe "select_model/2" do
    test "selecciona el modelo con mayor affinity para tareas de código", %{} do
      messages = [%{"role" => "user", "content" => "Write a Python function to implement quicksort algorithm"}]
      assert {:ok, %{model_name: "coder-model"}} = Router.select_model(messages, %{})
    end

    test "selecciona modelo para summarization", %{} do
      messages = [%{"role" => "user", "content" => "Summarize this document"}]
      assert {:ok, %{model_name: "fast-model"}} = Router.select_model(messages, %{})
    end

    test "retorna error si no hay modelos activos" do
      Repo.update_all(Model, set: [active: false])
      messages = [%{"role" => "user", "content" => "Hello"}]
      assert {:error, :no_active_model} = Router.select_model(messages, %{})
    end

    test "incluye task_type y score en la decisión" do
      messages = [%{"role" => "user", "content" => "Write code to sort an array"}]
      {:ok, decision} = Router.select_model(messages, %{})
      assert decision.task_type in [:code, :unknown]
      assert is_number(decision.score)
    end
  end

  describe "get_model_state/1" do
    test "devuelve estado para modelo existente" do
      {:ok, state} = Router.get_model_state("coder-model")
      assert state.name == "coder-model"
      assert state.status in ["active", "inactive"]
    end

    test "error para modelo inexistente" do
      assert {:error, :model_not_found} = Router.get_model_state("nonexistent")
    end
  end
end
```

#### `test/el_paso/domain/router_analyzer_test.exs`

Tests para:
- `analyze_trends/1` con datos sintéticos
- `alerts/0` con y sin condiciones de alerta
- Verificar que la regresión lineal detecta tendencias correctamente
- Verificar que retry_rate se calcula bien

---

### 6.2 Tests de Integración HTTP (2 días)

#### `test/el_paso/http/server_test.exs`

```elixir
defmodule ElPaso.HTTP.ServerTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias ElPaso.HTTP.Server

  @opts Server.init([])

  describe "GET /status" do
    test "devuelve status ok" do
      conn = conn(:get, "/status") |> Server.call(@opts)
      assert conn.status == 200
      assert %{"status" => "ok"} = Jason.decode!(conn.resp_body)
    end
  end

  describe "GET /metrics" do
    test "devuelve métricas en texto plano" do
      conn = conn(:get, "/metrics") |> Server.call(@opts)
      assert conn.status == 200
      assert String.contains?(conn.resp_body, "elpaso_")
    end
  end

  describe "GET /dashboard" do
    test "devuelve HTML" do
      conn = conn(:get, "/dashboard") |> Server.call(@opts)
      assert conn.status == 200
    end
  end

  describe "POST /auth/token" do
    test "rechaza sin credenciales" do
      conn = conn(:post, "/auth/token", Jason.encode!(%{}))
             |> put_req_header("content-type", "application/json")
             |> Server.call(@opts)
      assert conn.status == 401
    end
  end

  describe "POST /v1/messages" do
    test "rechaza body inválido" do
      conn = conn(:post, "/v1/messages", "not json")
             |> put_req_header("content-type", "application/json")
             |> Server.call(@opts)
      # Con Plug.Parsers, esto dará error de parseo
      assert conn.status in [400, 500]
    end
  end

  describe "admin endpoints" do
    test "GET /admin/sessions sin token retorna 403" do
      conn = conn(:get, "/admin/sessions") |> Server.call(@opts)
      assert conn.status == 403
    end
  end
end
```

---

### 6.3 Tests de Seguridad (1 día)

#### `test/el_paso/security/jwt_test.exs`

Tests para:
- `generate_token/2` produce un string
- `verify_token/1` acepta un token válido
- `verify_token/1` rechaza token expirado (usar TTL corto en test)
- `verify_token/1` rechaza token manipulado
- `extract_from_conn/1` extrae de header Authorization

#### `test/el_paso/security/rate_limiter_test.exs`

Tests para:
- Primer request es aceptado
- Requests dentro del límite son aceptados
- Requests que exceden el límite son rechazados
- Refill funciona tras esperar

#### `test/el_paso/security/auth_test.exs`

Tests para:
- `authenticate/1` con api_key válida
- `authenticate/1` con api_key inválida
- `authenticate/1` con auth deshabilitada
- `extract_api_key/1` con y sin header

---

### 6.4 Tests de Configuración (0.5 días)

#### `test/el_paso/config/loader_test.exs`

Tests para:
- `parse_ini/1` con archivo INI válido
- `parse_ini/1` con archivo vacío → `%{}`
- `parse_ini/1` con comentarios y líneas vacías
- `get_affinity/2` con valores existentes y no existentes
- `update_affinity/3` persiste y recupera correctamente

---

### 6.5 Actualizar test_helper.exs

```elixir
# test/test_helper.exs
ExUnit.start()

# Configurar Sandbox para tests
{:ok, _} = ElPaso.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(ElPaso.Repo, :manual)

# Inicializar RateLimiter ETS para tests
ElPaso.Security.RateLimiter.init()

# Inicializar affinity table para tests
ElPaso.Config.Loader.init_affinity_table()
```

---

## 7. VERIFICACIÓN FINAL

### 7.1 Comandos de verificación

```bash
# 1. Compilación limpia sin warnings
mix compile --warnings-as-errors

# 2. Formateo
mix format --check-formatted

# 3. Credo estricto (debe dar 0 warnings)
mix credo --strict

# 4. Tests (deben pasar todos)
mix test

# 5. Cobertura (debe ser ≥ 70% global, ≥ 80% en domain/)
mix test --cover

# 6. Hex audit (sin vulnerabilidades)
mix hex.audit

# 7. Dialyzer (sin errores)
mix dialyzer

# 8. Build de producción
MIX_ENV=prod mix compile
MIX_ENV=prod mix release --overwrite
```

### 7.2 Checklist manual

- [ ] `elpaso server start` arranca sin errores
- [ ] `curl http://localhost:8080/status` devuelve 200
- [ ] `curl http://localhost:8080/metrics` devuelve métricas con valores reales
- [ ] `curl http://localhost:8080/dashboard` devuelve HTML
- [ ] `POST /v1/messages` con modelo "auto" selecciona modelo correcto
- [ ] `POST /v1/messages_stream` devuelve SSE correctamente
- [ ] `POST /auth/token` con credenciales inválidas → 401
- [ ] `POST /auth/token` 6 veces seguidas → 429 rate limited
- [ ] `GET /admin/sessions` sin token → 403
- [ ] `elpaso model list` muestra modelos
- [ ] `elpaso engine test --name <engine>` funciona con Finch
- [ ] `elpaso router stats` muestra datos
- [ ] `elpaso router tune` ejecuta sin errores

### 7.3 Variables de entorno para verificación en prod

```bash
export ELPASO_JWT_SECRET="$(openssl rand -base64 64)"
export ELPASO_AUTH_ENABLED=true
export DB_HOST=localhost DB_USER=postgres DB_PASSWORD=postgres DB_NAME=elpaso_prod
MIX_ENV=prod ./elpaso server start
```

---

## 8. ANEXO A: ARCHIVOS MODIFICADOS COMPLETOS

### Lista de archivos modificados por fase

| Fase | Archivo | Fix(es) |
|------|---------|---------|
| 1 | `lib/el_paso/cli.ex` | FIX-01, FIX-28 |
| 1 | `lib/el_paso/security/jwt.ex` | FIX-02 |
| 1 | `config/prod.exs` | FIX-02, FIX-22 |
| 1 | `lib/el_paso/engine/http_client.ex` | FIX-03, FIX-15, FIX-16, FIX-17 |
| 1 | `lib/el_paso/domain/model_manager.ex` | FIX-04, FIX-15 |
| 1 | `lib/el_paso/application.ex` | FIX-04 (TaskSupervisor) |
| 1 | `lib/el_paso/engine/dispatcher.ex` | FIX-06 |
| 1 | `test/smoke_test.exs` | FIX-05 (nuevo) |
| 2 | `lib/el_paso/config.ex` | FIX-07, FIX-19, FIX-29 |
| 2 | `lib/el_paso/domain/router.ex` | FIX-08 |
| 2 | `lib/el_paso/domain/engine_manager.ex` | FIX-09 |
| 2 | `lib/el_paso/security/auth.ex` | FIX-10 |
| 2 | `lib/el_paso/http/server.ex` | FIX-11, FIX-14, FIX-18, FIX-21, FIX-23 |
| 2 | `lib/el_paso/security/rate_limiter.ex` | FIX-12, FIX-19 |
| 2 | `config/runtime.exs` | FIX-13, FIX-22 |
| 3 | `lib/el_paso/downloader/model_downloader.ex` | FIX-20, FIX-31 |
| 3 | `priv/repo/migrations/20240505_schema_hardening.exs` | FIX-24/25/26 (nuevo) |
| 3 | `lib/el_paso/domain/engine_manager.ex` | FIX-27 |
| 3 | `lib/el_paso/domain/personality_manager.ex` | FIX-27 |
| 3 | `lib/el_paso/domain/profile_manager.ex` | FIX-27 |
| 3 | `lib/el_paso/cost_manager.ex` | FIX-27 |
| 4 | `lib/el_paso/engine.ex` | FIX-30 |
| 4 | `lib/el_paso/domain/auto_tuner.ex` | FIX-32 |
| 4 | `lib/el_paso/schemas.ex` | FIX-33 (nuevo) |
| 5 | `test/*` (múltiples archivos) | FIX-05 (completo) |
| 5 | `test/test_helper.exs` | Actualización |

---

## 9. ANEXO B: DEPENDENCIAS ENTRE FIXES

```
FIX-01 (SQLi) ─────────────────────────────────────────────────────┐
FIX-02 (JWT) ──────────────────────────────────────────────────────┤
FIX-03 (Tokens=0) ─────────────────────────────────────────────────┤
FIX-04 (Async ModelManager) ──→ requiere FIX-04b (TaskSupervisor)  │
FIX-05 (Tests) ───────────────→ se completa en Fase 5              │
FIX-06 (Dispatcher) ───────────────────────────────────────────────┤
                                                                   │
FIX-07 (Config raise) ──→ afecta a FIX-10 (Auth) ─────────────────┤
FIX-08 (detect_task_type) ─────────────────────────────────────────┤
FIX-09 (:httpc→Finch) ─────────────────────────────────────────────┤
FIX-10 (Auth DB) ──→ depende de FIX-07 ────────────────────────────┤
FIX-11 (Rate limit endpoints) ──→ depende de FIX-12 ───────────────┤
FIX-12 (Rate limiter atomic) ──────────────────────────────────────┤
FIX-13 (runtime.exs limpio) ───────────────────────────────────────┤
FIX-14 (Security headers) ─────────────────────────────────────────┤
FIX-15 (Logger sanitize) ──────────────────────────────────────────┤
FIX-16 (Anthropic system) ─────────────────────────────────────────┤
FIX-17 (Finch.call→request) ───────────────────────────────────────┤
                                                                   │
FIX-18 (Plug.Parsers) ──→ depende de FIX-14 (orden de plugs) ─────┤
FIX-19 (ETS :protected) ───────────────────────────────────────────┤
FIX-20 (ElPasoFinch typo) ─────────────────────────────────────────┤
FIX-21 (Métricas reales) ──→ usa FIX-04 (Telemetry events) ───────┤
FIX-22 (Config unificada) ──→ depende de FIX-13 ───────────────────┤
FIX-23 (Body size) ──→ depende de FIX-18 ─────────────────────────┤
FIX-24/25/26 (Schema hardening) ───────────────────────────────────┤
FIX-27 (@spec docs) ───────────────────────────────────────────────┤
                                                                   │
FIX-28 (Typos) ────────────────────────────────────────────────────┤
FIX-29 (Dead code) ────────────────────────────────────────────────┤
FIX-30 (Engine behaviour) ─────────────────────────────────────────┤
FIX-31 (compile_env) ──────────────────────────────────────────────┤
FIX-32 (AutoTuner overlap) ────────────────────────────────────────┤
FIX-33 (Schemas naming) ───────────────────────────────────────────┤

LEYENDA:
──→ = dependencia fuerte (requiere que el otro fix esté aplicado)
──  = independiente (se puede aplicar en cualquier orden)
```

---

## 📊 RESUMEN DE ESFUERZO

| Fase | Días | Fixes | Tests añadidos |
|------|------|-------|----------------|
| Fase 1: Críticos | 5 | 6 | Smoke tests |
| Fase 2: Alta prioridad | 5 | 11 | — |
| Fase 3: Media prioridad | 3 | 10 | — |
| Fase 4: Baja prioridad | 1 | 6 | — |
| Fase 5: Testing | 6 | Suite completa | 50+ tests |
| **Total** | **20 días** | **33** | **~60 tests** |

---

*Plan de implementación generado por Macahan. 2026-05-04.*  
*"No te digo lo que quieres oír, te digo lo que necesitas saber."*
