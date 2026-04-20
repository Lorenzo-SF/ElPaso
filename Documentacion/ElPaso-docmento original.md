# CONSIDERACIONES ANTES DE EMPEZAR — LEER PRIMERO

## 1. Hardware y configuración de modelos

### Tu setup

- **Máquina**: MSI Stealth AI+ A16 — AMD HX370 (12 threads), 32 GB RAM, RTX 5080 16 GB VRAM
- **SO**: CachyOS (Linux)
- **Motor**: llama-server en `localhost:8081`, API key `sk-local`
- **Script de inicio**: `./llama.sh <modelo>` (un modelo a la vez, nunca simultáneos)

### Catálogo de modelos disponibles

| Alias      | Fichero GGUF                                 | Especialidad                      | Contexto | Cuant. |
| ---------- | -------------------------------------------- | --------------------------------- | -------- | ------ |
| `devstral` | Devstral-Small-2507-UD-Q3_K_XL.gguf          | DevOps, arquitectura, OTP         | 64k      | Q3     |
| `coder`    | Qwen3-Coder-30B-A3B-Instruct-UD-Q2_K_XL.gguf | Generación masiva de código       | 128k     | Q2     |
| `thinker`  | Qwen3-30B-A3B-Thinking-2507-UD-Q3_K_XL.gguf  | Razonamiento lógico y análisis    | 64k      | Q3     |
| `gemma`    | gemma-4-26B-A4B-it-UD-Q3_K_M.gguf            | General, HTML, documentación      | 128k     | Q3     |
| `glm`      | GLM-4.7-Flash-UD-Q2_K_XL.gguf                | Instrucciones estructuradas, JSON | 64k      | Q2     |

Todos corren full-GPU (`--n-gpu-layers 999`). `gemma` y `coder` usan `--cache-ram 12288`
para aprovechar la RAM cuando el contexto es largo (>32k tokens).

### Cuándo usar cada modelo en este proyecto

**devstral** → decisiones de diseño, arquitectura OTP, config system, módulos que
coordinan varios subsistemas (Application.start, ModelManager, Router, Wizard).
Es tu modelo principal para ElPaso porque entiende sistemas complejos y DevOps.

**coder** → generación masiva y repetitiva: adapters de engine, schemas Ecto,
migraciones, módulos HTTP, tests boilerplate, cualquier fichero con patrón claro.
Más rápido que devstral para código que no requiere razonar sobre la arquitectura.

**Thinker** → análisis estadístico, algoritmos de scoring, lógica de heurísticas
del router, cualquier cosa que requiera razonamiento matemático o análisis de datos.

**gemma** → dashboard HTML (V1.3), documentación, cualquier tarea con salida creativa
o narrativa. No para código Elixir complejo.

**glm** → tareas muy específicas de seguir instrucciones paso a paso, JSON structures,
scripts de automatización simples. Evitarlo para módulos OTP complejos.

Cada versión tiene su propio bloque "Modelos para esta versión" con la asignación concreta.

### Limitación de contexto: trabaja versión a versión

Este documento completo ocupa ~64.000 tokens. Ningún modelo cabe el documento entero.
La arquitectura de prompts por versión resuelve esto: cada bloque entre delimitadores
`═══ PROMPT Vx.y ═══` / `═══ FIN PROMPT Vx.y ═══` cabe en 32–64k tokens.

Flujo de trabajo obligatorio:

```
1. Extrae el prompt de la versión: sed -n '/PROMPT V1.0/,/FIN PROMPT V1.0/p' doc.md
2. Cárgalo en el modelo correcto junto con el código existente del repositorio
3. Implementa hasta que todos los criterios de completitud pasen
4. Commit con tag: git tag v1.0
5. Pasa a la siguiente versión
```

---

## 2. Zaguan — Integración en ElPaso

Zaguan (`hex.pm/packages/zaguan`) es un framework TUI/CLI para Elixir compatible con
OTP 28 / Elixir 1.19. Se integra en ElPaso para toda la interfaz de línea de comandos.

### Qué se integra y dónde

**`Zaguan.Drawer`** — toda salida visual de los comandos `mix elpaso *`:

```elixir
# En ElPaso.Config.Wizard — feedback de pasos del wizard
alias Zaguan.Drawer.Components.{Header, Table, Bar, Message}
Header.print("ElPaso Config Wizard", subtitle: "v1.0")
Message.print(:success, "Configuración guardada en ~/.config/elpaso/elpaso.conf")
Message.print(:error, "Puerto 8080 ya en uso")

# En ElPaso.CLI.Commands.RouterStats — salida de `mix elpaso router stats`
Table.print(
  headers: ["Modelo", "Calls", "Avg latencia", "p95", "Errores"],
  rows: stats_to_rows(report),
  headers_color: :cyan,
  table_border: :rounded
)

# En ElPaso.CLI.Commands.Bench — progreso de `mix elpaso bench`
Bar.print(current, total, label: "#{current}/#{total} requests", width: 40)

# En todos los comandos — mensajes de estado
Message.print(:success, "Modelo fast cargado (PID #{pid})")
Message.print(:warning, "Modelo heavy en estado :error, usando fallback")
```

**`Zaguan.UI`** — el wizard interactivo:

```elixir
# Menú de selección de tipo de motor
alias Zaguan.UI.Components.{Select, Input, Confirm}

# En ElPaso.Config.Wizard.step_engine_type/1
{:ok, engine_type} = Select.prompt("Tipo de motor:",
  options: ["llama_server", "vllm", "openai", "anthropic", "ollama"],
  default: "llama_server"
)

# En ElPaso.Config.Wizard.step_model_path/1
{:ok, path} = Input.prompt("Ruta al fichero GGUF:",
  placeholder: "~/modelos/modelo.gguf",
  validate: &File.exists?/1,
  error_msg: "Fichero no encontrado"
)

# En ElPaso.Config.Wizard.step_confirm/1
{:ok, confirmed} = Confirm.prompt("¿Guardar configuración?", default: true)
```

**`Zaguan.Engine`** — para la gestión del ciclo de vida de los motores de inferencia.

Tras leer el código fuente de Zaguan.Engine, el análisis previo era incorrecto.
`Zaguan.Engine` no es un wrapper sobre OTP: _es_ OTP bien empaquetado. Tiene su
propio `DynamicSupervisor` (`WorkerSupervisor`), `GenServer` (`Leader`, `Worker`),
circuit breaker con políticas configurables (`Policies`), monitor de estado
(`Monitor`) y sistema de eventos (`subscribe/0`). Es exactamente lo que ElPaso
necesita para arrancar motores en paralelo con tolerancia a fallos.

Uso concreto en ElPaso:

```elixir
# En ElPaso.Domain.ModelWorker — arrancar llama-server con política de reintentos
defmodule ElPaso.Domain.ModelWorker do
  alias Zaguan.Engine
  alias Zaguan.Engine.Policies

  # Política para motores locales: reintentar 3 veces con backoff exponencial
  @local_policy Policies.new(
    on_error: :retry,
    max_retries: 3,
    retry_delay: 2000,
    on_timeout: :stop,
    timeout: 60_000
  )

  # Arrancar el proceso del motor vía Zaguan.Engine.execute/2
  def start_engine_process(model_config, merged_args) do
    cmd = build_command(model_config.engine_binary, merged_args)

    # Zaguan.Engine.execute lanza el Worker bajo WorkerSupervisor
    # y aplica la política de reintentos automáticamente
    case Engine.execute(fn -> launch_and_monitor(cmd, model_config) end,
           policy: @local_policy,
           timeout: 60_000) do
      {:ok, result} -> {:ok, result}
      {:error, err} -> {:error, err.message}
    end
  end

  # Para operaciones paralelas (ej: health checks de todos los modelos)
  def check_all_health(model_ids) do
    tasks = Enum.map(model_ids, fn id ->
      fn -> {id, do_health_check(id)} end
    end)

    case Engine.run(tasks, workers: length(model_ids), timeout: 5_000) do
      {:ok, result} ->
        # Suscribirse a eventos para recibir resultados individuales
        Engine.subscribe()
        {:ok, result.data.batch_id}
      {:error, err} ->
        {:error, err}
    end
  end
end
```

El `Zaguan.Engine.Monitor` proporciona estadísticas de workers en tiempo real que
el `ElPaso.Domain.ModelManager` puede exponer via `mix elpaso models status`.

El circuit breaker de `Zaguan.Engine.Policies` reemplaza la lógica manual de
`consecutive_errors` y `max_restart_attempts` que el documento define para
`ModelWorker` — Zaguan ya lo tiene implementado con `Policies.strict/0`,
`Policies.tolerant/1` y `Policies.custom/1`.

**Cambio de diseño en V1.0**: el `ElPaso.Domain.ModelWorker` delega a
`Zaguan.Engine` para la ejecución de procesos externos con tolerancia a fallos.
El `DynamicSupervisor` propio de ElPaso supervisa los `ModelWorker` GenServers;
dentro de cada `ModelWorker`, `Zaguan.Engine` gestiona el proceso del motor.

### Dependencia en mix.exs

```elixir
{:zaguan, "~> 1.0"}
```

Se añade en V1.0. Está disponible en todos los módulos CLI desde el primer commit.

---

## 3. Gaps del documento — Lo que el agente debe crear sin instrucciones explícitas

### Gaps en V1.0

**A) mix.exs** — crear con estas dependencias:

```elixir
{:plug_cowboy, "~> 2.7"}, {:finch, "~> 0.19"}, {:jason, "~> 1.4"},
{:ecto_sql, "~> 3.11"}, {:postgrex, "~> 0.17"}, {:pgvector, "~> 0.2"},
{:nimble_options, "~> 1.1"}, {:telemetry, "~> 1.2"}, {:zaguan, "~> 1.0"},
{:jose, "~> 1.11"},          # inactivo hasta V3.0
{:libcluster, "~> 3.4"},     # inactivo hasta V2.1
{:ex_aws, "~> 2.5"}, {:ex_aws_s3, "~> 2.5"},  # inactivos hasta V3.0
{:ex_doc, "~> 0.31", only: :dev, runtime: false},
{:mox, "~> 1.1", only: :test}, {:bypass, "~> 2.1", only: :test}
```

**B) Application.start/2 + config/\*.exs** — árbol OTP definido en V1.0, más
`config/config.exs`, `config/dev.exs`, `config/test.exs`, `config/runtime.exs`.

**C) Schemas Ecto** (`lib/elpaso/context/schemas/`) — uno por tabla PostgreSQL:
`session.ex`, `message.ex` (con `field :embedding, Pgvector.Ecto.Vector`),
`conversation_summary.ex`, `routing_decision.ex`. Cada uno con `changeset/2`.

**D) `ElPaso.Context.SummarizationWorker`** — job asíncrono que genera resúmenes.
Implementado con código en la sección "Módulos adicionales obligatorios" de V1.0.

**E) `ElPaso.Engine.Dispatcher`** — punto de entrada único para inferencia.
Implementado con código en la sección "Módulos adicionales obligatorios" de V1.0.

**F) `ElPaso.Engine.ChatTemplate`** — formatea mensajes según template del modelo.
Implementado con código en la sección "Módulos adicionales obligatorios" de V1.0.

**G) `ElPaso.Domain.OutputCache`** — cache LRU+TTL en ETS.
Implementado con código en la sección "Módulos adicionales obligatorios" de V1.0.

**H) `ElPaso.Engine.Ollama`** — wrapper sobre OpenAI adapter con base_url diferente.
Implementado con código en la sección "Módulos adicionales obligatorios" de V1.0.

### Gaps en versiones posteriores

- **V1.1**: añadir paso de `embeddings` al wizard; `Storage.query_routing_decisions/1`
- **V1.2**: migración `20250101000005_add_user_id_to_sessions.exs`
- **V2.0**: `ElPaso.Engine.Registry` para plugins
- **V2.2**: migración tabla `auto_tune_runs`
- **V3.0**: schemas Ecto para `model_pricing` y `api_usage`

---

## 4. Instrucciones de trabajo

1. **Lee solo el prompt de la versión que implementas.** Extráelo con `sed` o
   cópialo manualmente. No cargues el documento entero en el modelo.

2. **Sigue el orden de prioridad** indicado en el Resumen ejecutivo de cada versión.

3. **Usa Zaguan para toda salida CLI** desde V1.0. No implementes colorización
   manual con códigos ANSI. Usa `Zaguan.Drawer.Printer` y `Zaguan.UI.Components`.

4. **Usa el modelo correcto para cada fase.** El bloque "Modelos para esta versión"
   al inicio de cada prompt especifica qué modelo hace qué.

5. **Commit tras cada módulo completo.** Referencia el criterio de completitud.

6. **Configuración del motor local**: endpoint `http://localhost:8081/v1`,
   API key `sk-local`. Los ejemplos del documento que usen `localhost:8080` deben
   ajustarse a `8081` para coincidir con tu script.

7. **Ante ambigüedad: implementa lo más simple que pase los criterios.**

═══════════════════════════════════════════════════════════════════════════════════
FIN DE CONSIDERACIONES
═══════════════════════════════════════════════════════════════════════════════════

# ElPaso

**Runtime**: Elixir 1.19.5-otp-28

ElPaso es un proxy de inferencia multi-modelo escrito en Elixir. Su objetivo es
proporcionar un único endpoint de acceso a múltiples modelos LLM, permitiendo al
usuario trabajar con ellos de forma transparente sin necesidad de gestionar cada
motor por separado.

El foco principal son los modelos locales: llama.cpp (via llama-server), vLLM,
Ollama y otros runtimes compatibles con la API de OpenAI. Sin renunciar a proveedores
externos como OpenAI o Anthropic cuando sean necesarios.

ElPaso decide qué modelo usar en cada momento, gestiona el ciclo de vida de los
procesos de motor, mantiene el contexto de conversación portable entre modelos, y
garantiza que el cambio entre ellos sea invisible para el usuario.

═══════════════════════════════════════════════════════════════════════════════════
FIN PROMPT V0
Siguiente: PROMPT V1.0
═══════════════════════════════════════════════════════════════════════════════════
═══════════════════════════════════════════════════════════════════════════════════
PROMPT V1.0 — SISTEMA FUNCIONAL LOCAL
Prerequisito: V0 entregado (proyecto Elixir 1.19.5-otp-28 creado desde cero).
Objetivo: sistema completamente funcional para uso local intensivo con un único
usuario. Los cuatro bloques implementados y operativos.
═══════════════════════════════════════════════════════════════════════════════════

# Prompt V1.0: Sistema Funcional Local

## Modelos para esta versión

| Fase                                                  | Modelo     | Comando               | Por qué                                                       |
| ----------------------------------------------------- | ---------- | --------------------- | ------------------------------------------------------------- |
| Arquitectura OTP, config system, ModelManager, Router | `devstral` | `./llama.sh devstral` | Diseña sistemas complejos, entiende supervisores y GenServers |
| Engine adapters, schemas Ecto, HTTP layer, tests      | `coder`    | `./llama.sh coder`    | Generación masiva de código estructurado repetitivo           |
| Wizard interactivo (Config.Wizard)                    | `devstral` | `./llama.sh devstral` | Razona sobre UX del CLI y decisiones de configuración         |
| Heurísticas del router (scoring, penalizaciones)      | `Thinker`  | `./llama.sh Thinker`  | Análisis lógico de las fórmulas de scoring                    |

**Flujo recomendado**: empieza con `devstral` para los bloques de arquitectura (Config,
ModelManager, estructura de Application). Cuando el esqueleto está en pie, cambia a
`coder` para generar los adapters de engine, schemas Ecto y módulos HTTP. Vuelve a
`devstral` para el wizard y a `Thinker` para refinar las fórmulas del router.

V1.0 es la versión más larga (~8.000 tokens de especificación). Si el contexto se
ajusta, divide el prompt: primero carga los bloques Config + ModelManager, luego
Context + Router, luego HTTP + Security.

## Propósito de este prompt

Este prompt define e implementa los cuatro bloques estructurales de ElPaso V1.0,
partiendo de un proyecto Elixir vacío (V0). Al finalizar, ElPaso debe ser capaz de:
recibir un request de chat, decidir qué modelo usar, arrancarlo si está apagado,
construir el contexto completo de la sesión, ejecutar la inferencia y devolver la
respuesta, todo sin que el usuario note el cambio de modelo entre turnos.

Los cuatro bloques:

1. **Shared Prompt Prefix** — bloque canónico estable que maximiza el KV cache
2. **Portable Session Context** — contexto de sesión portable entre modelos
3. **Heuristic Routing Engine** — selección inteligente del modelo por tarea
4. **Sistema de Configuración** — config validada, wizard, gestión de motores

Para cada bloque este prompt define: qué es exactamente, qué se implementa, cómo
funciona en tiempo de ejecución, qué módulos y structs requiere, y qué criterios
verifican que está completo. Todos los módulos se crean desde cero.

---

## PILAR 1: Shared Prompt Prefix

### Definición precisa

El Shared Prompt Prefix es el mecanismo mediante el cual ElPaso construye y mantiene un bloque
de texto canónico, estable y determinista que se coloca siempre al inicio de cada prompt enviado
a cualquier motor de inferencia. Este bloque está diseñado para maximizar los beneficios del KV
cache de los motores de inferencia: si el prefijo es idéntico token a token entre llamadas
consecutivas, el motor no necesita reprocesarlo.

Aclaración crítica: el KV cache no se comparte entre modelos distintos. Cada modelo tiene su
propia arquitectura, sus propios pesos y sus propias dimensiones de embedding. Compartir KV cache
entre Gemma 4B y Llama 3 8B es técnicamente imposible. Lo que se comparte es el texto del
prefijo, no la computación. Sin embargo, el beneficio es real: cuando un modelo recibe el mismo
prefijo que recibió en la llamada anterior, su cache interno hace hit y la primera llamada
post-arranque o post-cambio es significativamente más rápida que si el prefijo variara.

Este pilar NO es un output cache (no guarda respuestas para reutilizarlas). Tampoco es un
historial de mensajes. Es exclusivamente la gestión del bloque estático de instrucciones base
que define el comportamiento del asistente para una sesión o tipo de sesión.

### Punto de partida

Este módulo no existe. Se crea desde cero en V1.0. El proyecto Elixir tiene
la estructura base de V0 (repo, OTP tree, tipos compartidos) pero ninguna
lógica de inferencia ni gestión de contexto. Todo lo que sigue se implementa
por primera vez en este prompt.

### Qué se necesita implementar

#### 1.1 Módulo `ElPaso.Context.PrefixManager`

Este módulo es el responsable de construir y gestionar el bloque canónico. Sus responsabilidades:

- Construir el bloque canónico en el inicio de cada sesión a partir de la configuración del
  sistema (system prompt base, instrucciones globales, documentos de referencia fijos si los hay)
- Serializar el bloque de forma completamente determinista: mismo contenido siempre produce
  el mismo texto, byte a byte
- Almacenar el bloque en ETS con la clave de sesión para acceso de baja latencia
- Marcar el bloque como inmutable una vez construido; cualquier cambio en el bloque requiere
  crear una nueva versión con hash diferente, nunca mutar el existente
- Exponer el bloque a `ElPaso.Context.Builder` para que lo use como primera sección del prompt

Interfaz pública esperada:

```elixir
ElPaso.Context.PrefixManager.get(session_id) :: {:ok, prefix_block()} | {:error, :not_found}
ElPaso.Context.PrefixManager.build(session_id, config) :: {:ok, prefix_block()}
ElPaso.Context.PrefixManager.invalidate(session_id) :: :ok
ElPaso.Context.PrefixManager.hash(session_id) :: {:ok, binary()}
```

La estructura `prefix_block()` debe contener al menos:

```elixir
%PrefixBlock{
  session_id: String.t(),
  content: String.t(),         # texto serializado listo para inyectar
  hash: binary(),              # SHA256 del contenido, para detectar cambios
  token_estimate: non_neg_integer(),  # estimación de tokens que ocupa
  built_at: DateTime.t(),
  version: non_neg_integer()
}
```

#### 1.2 Estructura del bloque canónico

El bloque canónico se compone de secciones ordenadas y estrictamente serializadas. El orden
importa porque determina la tokenización y por tanto la posibilidad de cache hit:

```
[SECCIÓN 1: System prompt base]
Instrucciones globales del asistente. Comportamiento general, tono, restricciones.
Este texto viene de la configuración del usuario y no debe cambiar durante la sesión.

[SECCIÓN 2: Perfil de capacidades]
Descripción de qué puede y qué no puede hacer el sistema. Opcional pero útil para que el
modelo tenga expectativas correctas sobre su propio rol dentro de ElPaso.

[SECCIÓN 3: Documentos de referencia fijos]
Si el usuario ha configurado documentos que deben estar siempre disponibles (una base de
conocimiento, una especificación técnica, un manual), se inyectan aquí. Estos documentos
no cambian durante la sesión.

[SEPARADOR EXPLÍCITO]
Una línea de separación clara y consistente entre el bloque canónico y el contenido dinámico.
Por ejemplo: "---BEGIN DYNAMIC CONTEXT---". Este separador debe ser siempre idéntico.
```

#### 1.3 Integración con backends que soportan cache explícito

Cada backend tiene su propio mecanismo de cache y ElPaso debe conocerlos:

- **llama-server**: el KV cache es implícito. Si el prefijo es idéntico entre llamadas, llama-server
  lo detecta automáticamente. No requiere ningún parámetro especial. ElPaso solo necesita garantizar
  que el prefijo es estable.

- **vLLM**: similar a llama-server, el prefix caching es automático si está habilitado en la
  configuración del servidor (`--enable-prefix-caching`). ElPaso debe documentar esta dependencia.

- **Anthropic API**: soporta `cache_control` explícito en los mensajes. ElPaso debe añadir
  `{"type": "ephemeral"}` al mensaje del system prompt cuando usa este backend. El módulo
  `ElPaso.Engine.Anthropic` debe ser consciente de esto y aplicarlo automáticamente cuando
  detecta que hay un bloque canónico configurado.

- **OpenAI API**: desde modelos recientes soporta prompt caching automático para prefijos
  de más de 1024 tokens. No requiere parámetro especial, pero ElPaso debe documentar que el
  beneficio del cache es mayor cuanto más largo sea el bloque canónico estable.

El módulo `ElPaso.Engine.Base` (o un behaviour que implementen todos los engines) debe tener
un callback `prepare_prefix/2` que adapte el bloque canónico al formato que espera cada backend.

#### 1.4 Output cache (ETS) como mecanismo complementario

El output cache existente en `ElPaso.Domain.Cache` debe mantenerse, pero renombrarse y
redocumentarse claramente como `ElPaso.Domain.OutputCache` para evitar confusión con el prefix
management. Sus responsabilidades son distintas: almacenar respuestas completas para inputs
idénticos. Debe tener TTL configurable y límite de entradas para no consumir memoria
indefinidamente.

### Criterios de completitud para V1.0

- El bloque canónico se construye una vez por sesión y no varía durante ella
- El hash del bloque es verificable y registrado en cada llamada
- La integración con Anthropic API usa `cache_control` automáticamente
- Los motores llama-server y vLLM tienen documentada la dependencia de configuración
  para que el prefix caching funcione en el servidor
- El output cache y el prefix manager son módulos separados con responsabilidades distintas
- El token_estimate del bloque canónico está disponible para que el Context Builder
  calcule cuánto espacio queda para el contenido dinámico

---

## PILAR 2: Portable Session Context

### Definición precisa

El Portable Session Context es el sistema que garantiza que el estado completo de una
conversación vive en ElPaso, no en ningún modelo. Cada vez que ElPaso hace una llamada a un
motor de inferencia, construye y envía el contexto completo de la sesión desde cero, como si
el modelo lo viera por primera vez. El modelo nunca retiene estado entre llamadas.

El adjetivo "portable" es la clave: el contexto puede ser entregado a cualquier modelo
configurado en ElPaso sin que el usuario perciba discontinuidad. El modelo receptor entiende
la conversación porque el contexto es completo y coherente, no porque "recuerde" nada.

Este pilar NO significa que la información se pierda. Significa que la información persiste
en ElPaso (PostgreSQL + ETS) y se reconstitituye en cada llamada, adaptada al modelo de destino.

Nota sobre nomenclatura: el término "stateless context" es una contradicción que genera
confusión. "Stateless" describe al modelo, no al contexto. El contexto es, de hecho, muy
stateful: se acumula, se comprime, se recupera. "Portable Session Context" describe con
precisión lo que hace: un contexto de sesión que es portable entre modelos.

### Punto de partida

Este módulo no existe. Se crea desde cero en V1.0. Los módulos
`ElPaso.Context.Manager`, `ElPaso.Context.Builder`, `ElPaso.Context.Storage`
y `ElPaso.Context.TokenCounter` son nuevos. La estructura de directorios de V0
reserva sus paths pero no tienen implementación. Este prompt define e implementa
cada uno con las siguientes capacidades obligatorias:

- Estrategia de compresión del historial: resumen incremental con estrategia eager
- Context Builder con acceso al límite de tokens del modelo de destino
- Cambio de modelo transparente o declarativo, configurable por sesión

### Las tres capas del contexto

El Portable Session Context debe operar en tres capas complementarias. Cada capa aporta un tipo
distinto de información al modelo receptor:

#### Capa 1: Ventana deslizante (Recency Layer)

Contiene los N mensajes más recientes de la conversación en formato completo, sin compresión.
Esta capa garantiza precisión absoluta en lo inmediato: el modelo tiene acceso al intercambio
exacto de los últimos turnos.

Parámetros configurables:

- `window_size`: número de mensajes a mantener (recomendado: configurable entre 4 y 20)
- `window_token_budget`: límite en tokens que puede ocupar esta capa (por defecto: 40% del
  context size del modelo destino, descontado el bloque canónico)

Comportamiento esperado:

- Cuando un nuevo mensaje entra, se añade a la ventana
- Si la ventana supera el `window_token_budget`, el mensaje más antiguo de la ventana es
  promovido a la Capa 2 (compresión), nunca descartado
- La ventana siempre empieza desde el mensaje más reciente hacia atrás

#### Capa 2: Resumen incremental (Compression Layer)

Contiene un resumen acumulativo de la conversación que ya no cabe en la ventana deslizante.
Este resumen es incremental: no se rehace desde cero en cada turno, sino que se actualiza
añadiendo un resumen del bloque de mensajes que acaba de salir de la ventana.

La estrategia de actualización debe ser eager, no lazy:

- **Eager (correcto para V1.0)**: cuando la ventana llega al 80% de su presupuesto de tokens,
  ElPaso dispara en background un job de resumen del bloque más antiguo. Cuando ese bloque
  finalmente sale de la ventana, el resumen ya está listo. El usuario no nota latencia adicional.

- **Lazy (no recomendado para V1.0)**: el resumen se genera justo cuando el bloque sale de la
  ventana. Añade latencia en el momento en que el usuario está esperando respuesta. Aceptable
  para MVP, problemático para V1.0.

El resumen incremental se genera llamando al propio sistema de inferencia de ElPaso (puede
ser el modelo más ligero disponible) con un prompt de resumen bien diseñado. Este prompt de
resumen es parte de la configuración del sistema y debe ser ajustable.

Formato del resumen almacenado:

```elixir
%ConversationSummary{
  session_id: String.t(),
  content: String.t(),           # texto del resumen
  covers_until_message_id: integer(),  # hasta qué mensaje cubre
  token_estimate: non_neg_integer(),
  generated_at: DateTime.t(),
  generated_by_model: String.t()  # qué modelo generó este resumen
}
```

Nota importante: el campo `generated_by_model` es más relevante de lo que parece. Si el
resumen fue generado por un modelo de baja calidad o con un contexto incompleto, la calidad
del resumen puede degradarse. En V1.0 se registra pero no se actúa sobre ello; en versiones
futuras se puede usar para invalidar resúmenes de baja confianza.

#### Capa 3: Recuperación semántica (Relevance Layer)

Esta capa es opcional para V1.0 pero define la diferencia entre un sistema correcto y un
sistema realmente bueno. Permite recuperar mensajes del historial profundo (ya comprimidos
o fuera de la ventana) que son semánticamente relevantes para el mensaje actual del usuario.

Implementación:

- Cada mensaje almacenado en PostgreSQL tiene asociado un vector de embedding generado en
  el momento de su almacenamiento. Para generarlos se usa un modelo de embeddings local
  (recomendado: `nomic-embed-text` o equivalente ligero vía llama-server) o un endpoint de
  embeddings de los backends remotos.

- Cuando llega un mensaje nuevo del usuario, ElPaso genera su embedding y hace una búsqueda
  de similitud coseno contra el historial archivado.

- Los K mensajes más similares semánticamente (recomendado K entre 3 y 8, configurable) se
  inyectan en el prompt después del resumen y antes de la ventana deslizante, marcados
  claramente como "contexto recuperado" para que el modelo los interprete correctamente.

- La extensión `pgvector` de PostgreSQL maneja la búsqueda vectorial sin dependencias externas
  adicionales. La tabla de mensajes necesita una columna `embedding vector(N)` donde N es la
  dimensión del modelo de embeddings elegido.

Cuando esta capa no está configurada o activa, el sistema funciona correctamente con las
Capas 1 y 2. La Capa 3 es aditiva, no sustitutiva.

### Interfaz pública del Context.Builder

El módulo `ElPaso.Context.Builder` debe exponer una interfaz clara que separe la construcción
del prompt de la lógica de gestión de estado. Es un módulo funcional puro: recibe datos,
devuelve un prompt construido. No persiste nada.

```elixir
ElPaso.Context.Builder.build(session_id, current_message, context_spec)
  :: {:ok, built_prompt()} | {:error, reason()}

ElPaso.Context.Builder.estimate_budget(context_spec, prefix_block)
  :: %{prefix: integer(), summary: integer(), semantic: integer(), window: integer()}
```

La estructura `built_prompt()` contiene:

```elixir
%BuiltPrompt{
  messages: [%{role: String.t(), content: String.t()}],  # lista de mensajes en formato chat
  system: String.t() | nil,          # system prompt separado si el modelo lo soporta
  token_estimate: non_neg_integer(), # estimación total de tokens del prompt completo
  budget_used: %{                    # desglose de tokens por capa, para telemetría
    prefix: non_neg_integer(),
    summary: non_neg_integer(),
    semantic: non_neg_integer(),
    window: non_neg_integer(),
    current: non_neg_integer()
  },
  model_id: String.t(),
  session_id: String.t(),
  built_at: DateTime.t()
}
```

El campo `messages` sigue el formato estándar de chat completions (compatible con OpenAI y
llama-server). El campo `system` se usa solo cuando `context_spec.supports_system_prompt`
es `true`; en ese caso el bloque canónico va en `system` y no en el primer mensaje de `messages`.

### Construcción del prompt final

El módulo `ElPaso.Context.Builder` debe ensamblar el prompt en este orden invariable:

```
1. Bloque Canónico (PrefixManager)          ← inmutable por sesión
2. Resumen incremental (Compression Layer)  ← acumulativo, comprimido
3. Contexto recuperado semánticamente       ← opcional, marcado como tal
4. Ventana deslizante (Recency Layer)       ← mensajes completos recientes
5. Mensaje actual del usuario
```

Este orden no es arbitrario. Coloca lo más estable al principio (maximiza el KV cache) y lo
más reciente y específico al final (lo que el modelo debe priorizar en su respuesta).

### Adaptación al modelo de destino: el problema del token budget

Este es el punto más crítico y actualmente ausente en la arquitectura de ElPaso. El Context
Builder debe recibir como parámetro el `context_spec` del modelo de destino, que incluye:

```elixir
%ContextSpec{
  model_id: String.t(),
  max_tokens: non_neg_integer(),      # límite total del contexto del modelo
  reserved_for_output: non_neg_integer(), # tokens reservados para la respuesta
  usable_tokens: non_neg_integer()    # max_tokens - reserved_for_output
}
```

Con este spec, el Builder calcula el token budget disponible para cada capa:

```
usable_tokens
  - canonical_prefix_tokens    → espacio para capas dinámicas
  - summary_tokens             → espacio para ventana + contexto semántico
  - semantic_context_tokens    → espacio para ventana deslizante
  = window_budget              → cuántos tokens puede ocupar la ventana
```

Si el window_budget es insuficiente para mantener todos los mensajes de la ventana, el Builder
reduce la ventana desde el extremo más antiguo hasta que cabe. Esta reducción debe estar
logueada y, si el sistema de telemetría está activo, registrada como evento de compresión forzada.

El context_spec de cada modelo viene de su definición en `elpaso.conf` y debe ser obligatorio
para todos los modelos locales. Para modelos remotos (OpenAI, Anthropic) los límites son
conocidos y el sistema puede tenerlos como defaults actualizables.

### Cambio de modelo: transparencia o declaración

Cuando ElPaso redirige una sesión a un modelo distinto del que atendió el turno anterior,
tiene dos opciones de comportamiento configurable:

- **Modo transparente**: el contexto se inyecta sin ninguna mención al cambio de modelo.
  El modelo receptor no sabe que hubo un cambio. El usuario tampoco lo ve en la respuesta.
  Adecuado cuando los modelos tienen capacidades similares y el cambio es por razones de
  rendimiento o disponibilidad.

- **Modo declarativo**: ElPaso añade una nota al final del contexto inyectado: algo como
  `[Continuando sesión. Modelo anterior: fast. Modelo actual: heavy.]`. Esto puede mejorar
  la coherencia si el cambio es de un modelo con capacidades muy distintas.

El modo se configura a nivel de sesión o de perfil y debe ser respetado por el Builder.

- El Context Builder acepta `context_spec` como parámetro obligatorio y lo usa para calcular
  el token budget de cada capa
- La Capa 1 (ventana deslizante) está implementada con reducción automática si supera el budget
- La Capa 2 (resumen incremental) está implementada con estrategia eager y job en background
- La Capa 3 (recuperación semántica) está implementada con pgvector, activable por configuración
- El orden de ensamblado del prompt es invariable y documentado
- El cambio de modelo no rompe la coherencia del contexto en ningún caso
- El modo transparente y el declarativo están implementados y son configurables
- Los resúmenes se almacenan con metadatos suficientes para diagnóstico futuro

---

## Context.Storage: persistencia de sesiones y mensajes

`ElPaso.Context.Storage` es el módulo que gestiona toda la persistencia del contexto en
PostgreSQL (datos de largo plazo) y ETS (caché de acceso rápido). Es puramente de acceso
a datos: no tiene lógica de negocio. Todos los módulos del sistema que necesiten leer o
escribir historial de conversación pasan por aquí.

### Schema PostgreSQL

Las cuatro tablas que ElPaso necesita en V1.0. Este schema debe implementarse como
migraciones Ecto y es la única fuente de verdad para la estructura de datos persistente.

```sql
-- Sesiones de conversación
CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  context_mode TEXT NOT NULL DEFAULT 'transparent',  -- 'transparent' | 'declarative'
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_sessions_last_active ON sessions(last_active_at);

-- Mensajes individuales (historial completo)
CREATE TABLE messages (
  id BIGSERIAL PRIMARY KEY,
  session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  sequence_number INTEGER NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  token_estimate INTEGER NOT NULL DEFAULT 0,
  model_id TEXT,                        -- qué modelo generó la respuesta (null para user)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ,              -- null si está en la ventana activa
  embedding vector(768)                 -- null si Capa 3 no está activa; dimensión configurable
);

CREATE INDEX idx_messages_session_seq ON messages(session_id, sequence_number);
CREATE INDEX idx_messages_session_active ON messages(session_id, archived_at)
  WHERE archived_at IS NULL;
CREATE INDEX idx_messages_embedding ON messages USING ivfflat (embedding vector_cosine_ops)
  WHERE embedding IS NOT NULL;          -- índice aproximado para búsqueda vectorial eficiente

-- Resúmenes incrementales
CREATE TABLE conversation_summaries (
  id BIGSERIAL PRIMARY KEY,
  session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  covers_until_message_id BIGINT REFERENCES messages(id),
  token_estimate INTEGER NOT NULL DEFAULT 0,
  generated_by_model TEXT NOT NULL,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_summaries_session ON conversation_summaries(session_id, generated_at DESC);

-- Historial de decisiones del router (para feedback loop y diagnóstico)
CREATE TABLE routing_decisions (
  request_id TEXT PRIMARY KEY,
  session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
  selected_model TEXT NOT NULL,
  runner_up TEXT,
  task_type TEXT NOT NULL,
  complexity_score FLOAT NOT NULL,
  token_estimate INTEGER NOT NULL,
  feature_vector JSONB NOT NULL,        -- FeatureVector serializado completo
  scores JSONB NOT NULL,                -- scores por modelo en esta decisión
  reason TEXT NOT NULL,
  outcome TEXT,                         -- null hasta que se llama record_outcome
  latency_ms INTEGER,                   -- null hasta que se llama record_outcome
  decided_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_routing_session ON routing_decisions(session_id, decided_at DESC);
CREATE INDEX idx_routing_model_task ON routing_decisions(selected_model, task_type);
```

### Interfaz pública de Context.Storage

```elixir
# Sesiones
ElPaso.Context.Storage.create_session(opts \\ [])
  :: {:ok, session_id()} | {:error, reason()}
# opts: [context_mode: :transparent | :declarative, metadata: map()]

ElPaso.Context.Storage.touch_session(session_id)
  :: :ok | {:error, :not_found}
# Actualiza last_active_at

ElPaso.Context.Storage.delete_session(session_id)
  :: :ok | {:error, :not_found}
# Borra sesión y todos sus mensajes (CASCADE)

# Mensajes
ElPaso.Context.Storage.save_message(session_id, role, content, opts \\ [])
  :: {:ok, message_id()} | {:error, reason()}
# opts: [model_id: string, token_estimate: integer]

ElPaso.Context.Storage.get_window(session_id, limit)
  :: {:ok, [message()]} | {:error, reason()}
# Devuelve los últimos `limit` mensajes no archivados, ordenados por sequence_number ASC

ElPaso.Context.Storage.archive_messages_before(session_id, message_id)
  :: {:ok, archived_count()} | {:error, reason()}
# Marca como archivados todos los mensajes con id <= message_id

ElPaso.Context.Storage.search_semantic(session_id, embedding, limit)
  :: {:ok, [message()]} | {:error, :pgvector_unavailable} | {:error, reason()}
# Búsqueda coseno en mensajes archivados; devuelve los `limit` más similares

# Resúmenes
ElPaso.Context.Storage.get_latest_summary(session_id)
  :: {:ok, ConversationSummary.t()} | {:error, :not_found}

ElPaso.Context.Storage.save_summary(session_id, content, opts)
  :: {:ok, ConversationSummary.t()} | {:error, reason()}
# opts: [covers_until_message_id: integer, token_estimate: integer, generated_by_model: string]

# Routing decisions
ElPaso.Context.Storage.save_routing_decision(decision)
  :: :ok | {:error, reason()}

ElPaso.Context.Storage.update_routing_outcome(request_id, outcome, latency_ms)
  :: :ok | {:error, :not_found}
```

---

## Context.Manager: coordinación del ciclo de vida del contexto

`ElPaso.Context.Manager` es el módulo que coordina el estado activo de las sesiones.
A diferencia de `Context.Storage` (que solo persiste), el Manager mantiene el estado
en memoria (ETS), toma decisiones sobre cuándo comprimir, y dispara los jobs de resumen.
Es un GenServer que gestiona un único proceso para todas las sesiones activas.

### Ciclo de vida de una sesión

Una sesión tiene el siguiente ciclo:

```
INEXISTENTE
    │ get_or_create_session/1 (primer mensaje del usuario)
    ▼
ACTIVA
    │ append_turn/3 (cada turno de conversación)
    │ [cuando ventana alcanza 80% del budget]
    │   → dispara SummarizationWorker en background
    │ [cuando SummarizationWorker completa]
    │   → archive_messages_before + save_summary
    │
    │ [sin actividad durante session_expiry_minutes]
    ▼
EXPIRADA (limpieza lógica, no borrado físico)
    │ expire_session/1 (limpia estado ETS, el historial queda en PostgreSQL)
    ▼
INEXISTENTE en memoria (datos históricos en PostgreSQL)
```

La expiración limpia el estado en ETS pero NO borra los datos de PostgreSQL. Si el
usuario retoma la sesión, `get_or_create_session/1` la recarga desde PostgreSQL.

### Asignación de session_id

El `session_id` es un UUID v4 generado por ElPaso. El cliente recibe el `session_id`
en el campo `id` de la primera respuesta de chat completions y lo envía en todas las
llamadas subsiguientes en el campo `session_id` (extensión al formato OpenAI estándar).
Si el cliente no envía `session_id`, ElPaso crea una nueva sesión implícita.

Para compatibilidad con clientes que no soportan `session_id`, ElPaso puede usar el
campo `user` del request OpenAI como identificador de sesión (configurable).

### Interfaz pública de Context.Manager

```elixir
# Obtiene la sesión activa o la crea si no existe.
# Si existe en ETS, retorna inmediatamente. Si no, carga desde PostgreSQL o crea nueva.
ElPaso.Context.Manager.get_or_create_session(session_id \\ nil)
  :: {:ok, session_id(), session_state()} | {:error, reason()}

# Registra un turno completo (mensaje usuario + respuesta asistente).
# Actualiza ETS, persiste en PostgreSQL, y evalúa si disparar resumen eager.
ElPaso.Context.Manager.append_turn(session_id, user_message, assistant_response, model_id)
  :: :ok | {:error, reason()}

# Devuelve las tres capas de contexto listas para pasar al Context.Builder.
# Consulta ETS para la ventana y el resumen; lanza búsqueda semántica si Capa 3 activa.
ElPaso.Context.Manager.get_context_layers(session_id, context_spec)
  :: {:ok, %{
    summary: String.t() | nil,
    window: [message()],
    semantic: [message()]    # vacío si Capa 3 no está activa
  }} | {:error, reason()}

# Expira la sesión: limpia ETS pero mantiene PostgreSQL.
ElPaso.Context.Manager.expire_session(session_id)
  :: :ok

# Fuerza recarga de sesión desde PostgreSQL (útil tras arranque del sistema).
ElPaso.Context.Manager.reload_session(session_id)
  :: {:ok, session_state()} | {:error, reason()}
```

### Estado en ETS por sesión

```elixir
%SessionState{
  session_id: String.t(),
  context_mode: :transparent | :declarative,
  window: [message()],              # mensajes en la ventana activa, en orden ASC
  window_token_count: integer(),    # tokens actuales de la ventana (sin recalcular cada vez)
  last_summary_id: integer() | nil, # ID del resumen más reciente en PostgreSQL
  last_summary_tokens: integer(),   # tokens del resumen (para el budget del Builder)
  last_model_id: String.t() | nil,  # modelo que atendió el turno anterior
  summarization_in_progress: boolean(),  # true si hay un job de resumen corriendo
  created_at: DateTime.t(),
  last_active_at: DateTime.t()
}
```

---

## ElPaso.HTTP: capa de entrada HTTP

`ElPaso.HTTP` es el servidor HTTP de ElPaso, construido sobre Plug y Cowboy. Es el punto
de entrada de todos los requests externos. Recibe, valida, enruta al pipeline interno,
y devuelve respuestas en formato compatible con OpenAI.

### Endpoints implementados en V1.0

| Método | Path                   | Descripción                                                       |
| ------ | ---------------------- | ----------------------------------------------------------------- |
| POST   | `/v1/chat/completions` | Chat completion (streaming y no-streaming)                        |
| POST   | `/v1/completions`      | Text completion (legacy, redirige a chat internamente)            |
| GET    | `/v1/models`           | Lista los modelos configurados y su estado                        |
| GET    | `/health`              | Health check del servidor (siempre 200 si está vivo)              |
| GET    | `/status`              | Estado completo del sistema (modelos, sesiones activas, métricas) |

### Formato de request de chat completions

ElPaso acepta el formato estándar de OpenAI con las siguientes extensiones:

```json
{
  "model": "fast", // model_id de ElPaso, o "auto" para dejar que el router decida
  "messages": [{ "role": "user", "content": "¿Qué es Elixir?" }],
  "stream": false, // true para SSE streaming
  "temperature": 0.7, // sobreescribe inference_defaults del modelo
  "max_tokens": 1024,
  "session_id": "uuid-v4", // extensión ElPaso; omitir para nueva sesión
  "model_preference": "heavy" // extensión ElPaso; sugerencia al router, no obligación
}
```

Si `model` es `"auto"` o está ausente, el router decide. Si es un `model_id` concreto,
ElPaso intenta usar ese modelo pero puede hacer fallback si está en error.

### Formato de respuesta (no-streaming)

Formato estándar OpenAI con extensión `elpaso` para metadatos:

```json
{
  "id": "chatcmpl-xyz",
  "object": "chat.completion",
  "created": 1234567890,
  "model": "fast",
  "choices": [
    {
      "index": 0,
      "message": { "role": "assistant", "content": "Elixir es..." },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 120,
    "completion_tokens": 85,
    "total_tokens": 205
  },
  "elpaso": {
    "session_id": "uuid-v4",
    "routing_decision": "fast: best fit for question_answer (score: 0.87)",
    "context_layers_used": ["prefix", "summary", "window"],
    "model_switched": false
  }
}
```

El objeto `elpaso` es opcional pero siempre presente en V1.0. Los clientes compatibles
con OpenAI lo ignoran; los clientes conscientes de ElPaso pueden usarlo para diagnóstico.

### Formato de respuesta streaming (SSE)

Cuando `stream: true`, ElPaso usa Server-Sent Events (SSE) con el formato de OpenAI:

```
data: {"id":"chatcmpl-xyz","object":"chat.completion.chunk","choices":[{"delta":{"content":"Eli"},"index":0}],"elpaso":{"session_id":"uuid-v4"}}

data: {"id":"chatcmpl-xyz","object":"chat.completion.chunk","choices":[{"delta":{"content":"xir"},"index":0}]}

data: [DONE]
```

El primer chunk siempre incluye el objeto `elpaso` con el `session_id` y la decisión
de routing, para que el cliente lo capture antes de que llegue el contenido.

ElPaso hace proxy del stream del motor de inferencia directamente al cliente. No espera
a que el motor termine para empezar a enviar. La latencia hasta primer token (TTFT) es
directamente la del motor, sin overhead de buffering en ElPaso.

### Formato de error estructurado

Todos los errores siguen el formato de error de OpenAI para compatibilidad:

```json
{
  "error": {
    "message": "No hay modelos disponibles. Todos en estado :error.",
    "type": "no_models_available",
    "code": "elpaso_503",
    "param": null
  }
}
```

Códigos de error específicos de ElPaso:

| Código        | HTTP Status | Causa                        |
| ------------- | ----------- | ---------------------------- |
| `elpaso_503`  | 503         | No hay modelos disponibles   |
| `elpaso_504`  | 504         | Timeout esperando cold start |
| `elpaso_422`  | 422         | Request con formato inválido |
| `elpaso_500`  | 500         | Error interno en el pipeline |
| `model_error` | 502         | El motor devolvió un error   |

### Respuesta de `/v1/models`

```json
{
  "object": "list",
  "data": [
    {
      "id": "fast",
      "object": "model",
      "owned_by": "elpaso",
      "elpaso": {
        "label": "Gemma 3 4B (rápido)",
        "status": "hot",
        "engine": "llama_server",
        "ram_mb": 4200,
        "vram_mb": 3800,
        "queue_depth": 0
      }
    }
  ]
}
```

### Respuesta de `/status`

```json
{
  "elpaso_version": "1.0.0",
  "uptime_seconds": 3600,
  "models": {
    "fast": { "status": "hot", "ram_mb": 4200, "vram_mb": 3800 },
    "heavy": { "status": "cold", "ram_mb": 0, "vram_mb": 0 }
  },
  "active_sessions": 3,
  "router": {
    "decisions_last_hour": 47,
    "fallback_rate_pct": 2.1
  }
}
```

### Integración HTTP → Router → Pipeline

El flujo completo desde que llega un request HTTP hasta que se invoca el router:

```elixir
# ElPaso.HTTP.Router (Plug.Router, no confundir con ElPaso.Domain.Router)
plug :match
plug :dispatch

post "/v1/chat/completions" do
  with {:ok, body}    <- read_body(conn),
       {:ok, params}  <- validate_request(body),
       session_id     <- params[:session_id] || generate_session_id(),
       {:ok, _}       <- Context.Manager.get_or_create_session(session_id),
       {:ok, model_id, decision} <- Domain.Router.route(
                                      params[:request_id],
                                      session_id,
                                      params[:messages] |> last_user_message()
                                    ),
       {:ok, _}       <- ModelManager.ensure_hot(model_id, latency_tolerance_ms(conn)),
       {:ok, prompt}  <- Context.Builder.build(session_id, last_user_message(params),
                                               context_spec_for(model_id)),
       response       <- Engine.infer(model_id, prompt, params)
  do
    Context.Manager.append_turn(session_id, last_user_message(params), response, model_id)
    Domain.Router.record_outcome(params[:request_id], :success, response.latency_ms)
    send_response(conn, response, session_id, decision)
  else
    {:error, reason} -> send_error(conn, reason)
  end
end
```

### Seguridad básica en V1.0

`ElPaso.Security` implementa protección mínima suficiente para uso local:

- **API key local**: si `system.api_key` está configurado en `elpaso.conf`, todos los
  requests deben incluir `Authorization: Bearer <key>`. Si no está configurado, no se
  requiere autenticación (adecuado para uso estrictamente local).
- **Rate limiting**: límite de N requests/minuto configurable en `system.rate_limit_rpm`
  (default: 60). Implementado como token bucket en ETS. Respuesta: HTTP 429.
- **Sanitización de input**: longitud máxima de mensajes configurable en
  `system.max_message_length_chars` (default: 32768). Respuesta: HTTP 422.
- **CORS**: deshabilitado por defecto. Configurable en `system.cors_enabled` para
  uso desde aplicaciones web locales.

---

## PILAR 3: Heuristic Routing Engine

### Definición precisa

El Heuristic Routing Engine es el componente que decide, para cada request entrante, qué modelo
debe atenderlo. Esta decisión se basa en múltiples dimensiones: características del request,
estado del sistema en ese momento, historial de rendimiento y preferencias de la sesión.

El objetivo no es hacer la decisión perfecta en cada caso, sino hacer consistentemente la
decisión suficientemente buena con latencia de decisión despreciable (menos de 5ms). El router
no puede ser un cuello de botella.

### Punto de partida

Este módulo no existe. Se crea desde cero en V1.0. El módulo
`ElPaso.Domain.Router` es nuevo. Este prompt define e implementa el pipeline
completo de decisión en 5 fases con todas las siguientes capacidades:

- Clasificación de tarea y cálculo de complexity_score con fórmula definida
- Scoring con penalización por cold start, cola y errores consecutivos
- Feedback loop que actualiza ModelState tras cada inferencia
- Registro de cada decisión en la tabla `routing_decisions` de PostgreSQL

### Pipeline de decisión del router

#### Fase 1: Feature Extraction

Para cada request, el router extrae las siguientes features antes de decidir:

**Features del prompt:**

- `token_estimate`: número estimado de tokens del prompt completo (incluido el contexto).
  No hace falta ser exacto; una estimación por caracteres/3 es suficiente para el router.
- `task_type`: clasificación del tipo de tarea. En V1.0 se soportan estas categorías:
  `code`, `reasoning`, `summarization`, `question_answer`, `creative`, `translation`, `unknown`
- `complexity_score`: valor float entre 0.0 y 1.0 que combina múltiples señales
- `language`: idioma detectado del mensaje (ISO 639-1)
- `has_structured_output_request`: booleano; el usuario pide JSON, tabla, código, etc.
- `is_continuation`: booleano; es un mensaje de seguimiento de la misma sesión o turno nuevo
- `prompt_length_chars`: longitud bruta en caracteres del mensaje actual, sin el contexto acumulado

Estas siete features se agrupan en el struct `FeatureVector`, que se pasa al scoring y
se persiste en `RoutingDecision` para diagnóstico posterior:

```elixir
%FeatureVector{
  token_estimate: non_neg_integer(),
  task_type: :code | :reasoning | :summarization | :question_answer |
             :creative | :translation | :unknown,
  complexity_score: float(),
  language: String.t(),
  has_structured_output_request: boolean(),
  is_continuation: boolean(),
  prompt_length_chars: non_neg_integer()
}
```

**Cómo calcular `task_type` sin un clasificador ML:**

Para V1.0 se usa un clasificador basado en heurísticas léxicas (keywords + regex), no un
modelo ML. Esto garantiza latencia mínima y comportamiento predecible:

````
code:          presencia de ``` , "función", "implement", "debug", "código", "script",
               "error en línea", nombres de lenguajes de programación
reasoning:     "por qué", "explica", "razona", "analiza", "diferencia entre",
               "ventajas y desventajas", "compara"
summarization: "resume", "sintetiza", "en pocas palabras", "puntos clave", "TL;DR"
question_answer: preguntas directas cortas, "qué es", "cuándo", "quién", "define"
creative:      "escribe", "redacta", "crea", "inventa", "historia", "poema"
translation:   "traduce", "en inglés", "en español", "cómo se dice"
unknown:       cuando ninguna señal es suficientemente fuerte
````

**Cómo calcular `complexity_score`:**

Es una función lineal de varias señales normalizadas:

```
complexity_score =
  0.30 * normalize(token_estimate, 0, max_expected_tokens) +
  0.25 * task_type_weight[task_type] +       # code=0.8, reasoning=0.9, qa=0.3, etc.
  0.20 * sentence_depth_score(prompt) +       # longitud media de oraciones, anidamiento
  0.15 * vocabulary_density(prompt) +         # ratio palabras únicas / total palabras
  0.10 * normalize(question_count(prompt), 0, 5)  # número de preguntas en el prompt
```

Los pesos son configurables. Los defaults son un punto de partida razonable, no verdad absoluta.

#### Fase 2: System State Check

Antes de decidir el modelo, el router consulta el estado actual del sistema:

```elixir
%ModelState{
  model_id: String.t(),
  status: :hot | :warming | :cold | :error | :disabled,
  current_queue_depth: non_neg_integer(),
  avg_latency_ms: non_neg_integer(),    # media móvil de las últimas N llamadas
  last_error_at: DateTime.t() | nil,
  consecutive_errors: non_neg_integer(),
  ram_mb: non_neg_integer()             # consumo actual de RAM del proceso
}
```

El status `:hot` significa que el modelo está cargado y respondiendo. `:warming` significa que
está en proceso de arranque. `:cold` significa que está apagado. `:error` significa que el
último arranque o llamada fallaron.

#### Fase 3: Scoring con penalización por cold start

Para cada modelo candidato, el router calcula un score final:

```
base_score = fit_score(model, features)
           - cold_start_penalty(model.status, session.latency_tolerance)
           - queue_penalty(model.current_queue_depth)
           - error_penalty(model.consecutive_errors)

final_score = base_score * capability_multiplier(model, features)
```

**`fit_score`**: combina la afinidad declarada del modelo para el tipo de tarea con el
complexity_score del request. No es solo `task_affinity[task_type]`; el complexity_score
escala la afinidad para penalizar a modelos ligeros cuando la tarea es compleja incluso
dentro de su categoría favorita:

```
fit_score(model, features) =
  task_affinity[features.task_type] * (1.0 - complejidad_penalizer)

donde:
  complejidad_penalizer = max(0, features.complexity_score - model.complexity_ceiling) * 0.5
  model.complexity_ceiling = el punto a partir del cual el modelo empieza a rendir peor
                              (configurable por modelo, default: 0.7 para fast, 1.0 para heavy)
```

El campo `complexity_ceiling` se añade a la sección `routing` de cada modelo en el config:

```json
"routing": {
  "priority": 1,
  "complexity_ceiling": 0.7,
  "cold_start_estimate_ms": 8000,
  "task_affinity": { ... }
}
```

**`capability_multiplier`**: penaliza o bonifica según capacidades estructurales del modelo
que no dependen de la tarea sino del tipo de output requerido. Para V1.0:

```
capability_multiplier =
  1.0
  * (features.has_structured_output_request ? model.structured_output_score : 1.0)
  * (features.language != "en" ? model.multilingual_score : 1.0)

donde:
  model.structured_output_score: capacidad del modelo para JSON/código estructurado (0.5-1.0)
  model.multilingual_score: calidad en idiomas distintos al inglés (0.5-1.0)
```

Ambos campos son opcionales en el config; si no se declaran, el default es 1.0.
Se añaden a la sección `routing` del modelo:

```json
"routing": {
  "structured_output_score": 0.9,
  "multilingual_score": 0.85,
  ...
}
```

**`cold_start_penalty`**: penalización proporcional al tiempo de espera estimado respecto
a la tolerancia de latencia de la sesión:

```
cold_start_penalty(model, session) =
  if model.status == :cold:
    min(1.0, model.cold_start_estimate_ms / session.latency_tolerance_ms) * penalty_factor
  else:
    0.0

# penalty_factor viene de routing.cold_start_penalty_factor en elpaso.conf (default 1.5)
# clampear a 1.0 evita scores negativos; un score de 0.0 ya es suficientemente malo
```

**`queue_penalty`**: penalización lineal por cola de requests:

```
queue_penalty(model) = model.current_queue_depth * 0.05
# Cada request en cola reduce el score en 0.05; con 5 en cola la penalización es 0.25
# El factor 0.05 es configurable en routing.queue_penalty_per_request (default 0.05)
```

**`error_penalty`**: exclusión progresiva por errores consecutivos:

```
error_penalty(model) =
  if model.consecutive_errors >= max_consecutive_errors: infinity  # excluido
  else: model.consecutive_errors * 0.15
```

### Interfaz pública del Router

El router expone una interfaz clara. El punto de entrada principal es `route/3`:

```elixir
# Punto de entrada principal: recibe el request y devuelve el model_id seleccionado.
# Gestiona el pipeline completo: feature extraction, scoring, fallback.
ElPaso.Domain.Router.route(request_id, session_id, user_message)
  :: {:ok, model_id(), RoutingDecision.t()} | {:error, :no_models_available}

# Notifica al router el resultado de una inferencia completada o fallida.
# Actualiza ModelState via ModelManager y las estadísticas internas.
ElPaso.Domain.Router.record_outcome(request_id, outcome, latency_ms)
  :: :ok
# outcome :: :success | {:error, reason()} | :timeout

# Devuelve las últimas N decisiones de routing para diagnóstico.
ElPaso.Domain.Router.recent_decisions(limit \\ 50)
  :: [RoutingDecision.t()]

# Devuelve las estadísticas de routing agrupadas por task_type y model_id.
ElPaso.Domain.Router.stats()
  :: %{task_type => %{model_id => %{count: integer(), avg_latency_ms: integer()}}}
```

### Mecanismo de actualización cruzada Router → ModelManager

Cuando `record_outcome/3` recibe el resultado de una inferencia, necesita actualizar
`avg_latency_ms` y `p95_latency_ms` en el `ModelState` que posee el `ModelManager`.
El mecanismo es una llamada directa a `ModelManager`:

```elixir
# Dentro de Router.record_outcome/3:
ElPaso.Domain.ModelManager.record_call_result(model_id, latency_ms, outcome)
  :: :ok

# ModelManager actualiza en su estado interno:
# - avg_latency_ms (media móvil exponencial, alpha=0.1)
# - p95_latency_ms (ventana deslizante de 50 llamadas)
# - consecutive_errors (reset a 0 en :success, +1 en :error/:timeout)
# - last_call_at (timestamp)
```

Esta función se añade a la interfaz pública de `ModelManager` y es llamada únicamente
por el router. El Router no accede directamente al estado del ModelManager; toda
comunicación va a través de esta función.

#### Fase 4: Decisión final y fallback

El modelo con mayor `final_score` es el elegido. Pero antes de confirmar la decisión:

1. Si el modelo elegido está en estado `:cold`, el router informa al `ModelManager` para
   que inicie el arranque. El request espera (con timeout configurable). Si el arranque
   supera el timeout, el router elige el siguiente mejor candidato disponible en caliente.

2. Si ningún modelo está disponible en caliente y todos están en frío, el router arranca
   el más ligero disponible (el de menor `cold_start_estimate_ms`) y espera.

3. Si todos los modelos están en estado `:error` o `:disabled`, el router devuelve un error
   estructurado al cliente HTTP con información del problema.

El router registra cada decisión:

```elixir
%RoutingDecision{
  request_id: String.t(),
  session_id: String.t(),
  selected_model: String.t(),
  runner_up: String.t() | nil,
  features: %FeatureVector{},
  scores: %{String.t() => float()},
  reason: String.t(),              # texto legible para logs: "best fit for reasoning task"
  decided_at: DateTime.t(),
  decision_latency_us: non_neg_integer()  # microsegundos que tardó la decisión
}
```

Este registro va a la telemetría y es fundamental para diagnosticar comportamientos
inesperados del router.

#### Fase 5: Feedback loop

Cuando el modelo completa (o falla) la inferencia, el router recibe un feedback:

```elixir
ElPaso.Domain.Router.record_outcome(request_id, outcome)
# outcome :: :success | {:error, reason} | :timeout
```

Este feedback actualiza:

- La media móvil de latencia del modelo
- El contador de errores consecutivos
- Las estadísticas de `task_type` → `model` para cada combinación

En V1.0, este feedback actualiza las estadísticas pero no ajusta automáticamente las
heurísticas. El ajuste automático (aprendizaje online) es V1.1+. Lo que sí hace V1.0 es
registrar suficiente información para que el usuario pueda ajustar manualmente los pesos
y las afinidades si el comportamiento no le convence.

#### Hot-swap: cambio de modelo en mitad de conversación

El router puede cambiar de modelo entre turnos de la misma sesión. Este es el caso de uso
normal y debe funcionar de forma completamente transparente. El `ModelManager` gestiona el
ciclo de vida (parar/arrancar procesos) y el `PortableSessionContext` garantiza la continuidad
del contexto. El router simplemente decide el mejor modelo para el turno actual sin importar
cuál atendió el anterior.

Lo que el router NO hace:

- No cambia de modelo a mitad de un stream (una vez empezado el streaming, ese turno termina
  con el modelo asignado)
- No fuerza el cambio de modelo si el elegido es el mismo que el turno anterior (no hay
  rotación por rotación)

## Integración entre los cuatro bloques en una llamada completa

Para que quede claro cómo se conectan todos los bloques en tiempo de ejecución:

```
Request HTTP entrante
│
├─ [Config.Loader] Leer context_spec del modelo si es necesario (desde ETS, no disco)
│
├─ [Router] Feature extraction del prompt (task_type, complexity_score, token_estimate...)
│
├─ [Router] System state check: consulta ModelManager.all_states()
│
├─ [Router] ConditionEvaluator evalúa use_when/prefer_when/avoid_when de cada modelo
│
├─ [Router] Scoring + decisión → model_id seleccionado + RoutingDecision registrada
│
├─ [ModelManager] ensure_hot(model_id, timeout_ms)
│     ├─ Si :hot → :ok inmediato
│     ├─ Si :cold → arrancar proceso, esperar health check, :ok o :timeout
│     └─ Si :error → {:error, :model_unavailable}, router activa fallback
│
├─ [PrefixManager] get(session_id)
│     ├─ Si existe en ETS → devuelve bloque canónico inmediatamente
│     └─ Si no existe → build(session_id, config), almacenar en ETS, devolver
│
├─ [Context.Builder] build(session_id, current_message, context_spec)
│     ├─ estimate_budget calcula tokens disponibles por capa
│     ├─ Capa 1: bloque canónico del PrefixManager (en system si el modelo lo soporta)
│     ├─ Capa 2: resumen incremental de Context.Storage
│     ├─ Capa 3: recuperación semántica vía pgvector (si está activa)
│     ├─ Capa 4: ventana deslizante de mensajes recientes
│     └─ Mensaje actual del usuario
│
├─ [Engine.X] Llamada al backend con built_prompt.messages (y built_prompt.system si aplica)
│     └─ Streaming o respuesta completa según lo que el cliente solicitó
│
├─ [Context.Storage] Persistir mensaje usuario + respuesta en PostgreSQL
│     └─ Generar embedding del mensaje si Capa 3 está activa
│
├─ [Context.Manager] Actualizar ventana deslizante
│     └─ Si ventana ≥ 80% del budget → disparar job eager de resumen en background
│
├─ [Router] record_outcome(request_id, :success | {:error, reason}, latency_ms)
│     └─ Actualiza avg_latency_ms, p95_latency_ms y consecutive_errors en ModelState
│
└─ Respuesta HTTP al cliente
```

### Criterios de completitud para V1.0

- El router expone `route/3` como punto de entrada y gestiona el pipeline completo
- El router extrae las 7 features definidas en `FeatureVector` con latencia menor de 5ms
- El clasificador de task_type basado en heurísticas léxicas cubre los 7 tipos definidos
- El complexity_score usa la función lineal ponderada con pesos configurables
- El ModelState se mantiene actualizado en tiempo real para todos los modelos
- La penalización por cold start está implementada y es configurable por sesión
- La penalización por cola y por errores consecutivos están implementadas
- El fallback cuando el modelo elegido no arranca a tiempo está implementado
- Cada decisión de routing se registra con `RoutingDecision` en la telemetría
- El feedback loop actualiza latencia media y errores consecutivos
- Las task_affinity son configurables por modelo en `elpaso.conf`
- El hot-swap entre turnos funciona sin que el usuario perciba discontinuidad

---

## ModelManager: ciclo de vida de los procesos de motor

El `ModelManager` no es un pilar independiente, pero es la pieza de infraestructura que
conecta los tres pilares con el hardware. Sin él, el router decide pero no puede ejecutar
su decisión. Se define aquí por separado porque su comportamiento debe quedar explícito.

### Árbol de supervisión

El `ModelManager` no es un único GenServer monolítico. La estructura correcta es:

```
ElPaso.Application
├── Zaguan.Application          ← árbol OTP de Zaguan (incluye Engine.Leader,
│   └── Zaguan.AppSupervisor       Engine.WorkerSupervisor, Engine.Monitor)
│
└── ElPaso.Domain.ModelSupervisor  (Supervisor, strategy: :one_for_one)
    ├── ElPaso.Domain.ModelRegistry   (Registry, para lookup por model_id)
    └── ElPaso.Domain.ModelPool       (DynamicSupervisor)
        ├── ElPaso.Domain.ModelWorker{fast}     (GenServer, uno por modelo)
        ├── ElPaso.Domain.ModelWorker{heavy}    (GenServer, uno por modelo)
        └── ElPaso.Domain.ModelWorker{...}
```

`ElPaso.Domain.ModelManager` es el módulo de fachada que enruta llamadas al
`ModelWorker` correcto via el `ModelRegistry`. Los clientes externos (router, CLI)
siempre llaman a `ModelManager`, nunca a un `ModelWorker` directamente.

Cada `ModelWorker` delega a `Zaguan.Engine.execute/2` para el arranque real del
proceso del motor, aprovechando el `WorkerSupervisor` y las `Policies` de Zaguan.
Si el Engine Worker de Zaguan falla, el `ModelWorker` de ElPaso recibe el evento
vía `Engine.subscribe()` y actualiza el `ModelState`.

Los modelos con `autostart: true` son iniciados por `ModelSupervisor.init/1` durante
el arranque de la aplicación, en secuencia (no en paralelo) para no saturar VRAM.
El orden de arranque es el `priority` de routing de menor a mayor.

### Backoff exponencial

El backoff y los reintentos los gestiona `Zaguan.Engine.Policies`. Los parámetros
del documento (`restart_backoff_initial_ms`, `restart_backoff_multiplier`, etc.)
se mapean a `Policies.new(retry_delay: initial_ms, max_retries: n)`. No hay lógica
de backoff manual en `ModelWorker`. La política concreta por modelo se construye en
`ModelWorker.engine_policy/1` usando los valores de `model_config.lifecycle`.

````

La secuencia de esperas para un modelo con los defaults es: 2s, 4s, 8s, 16s, 32s, 60s,
60s... (se capa en 60s). Si el modelo lleva más de `max_restart_attempts` sin éxito,
el `ModelWorker` se marca como `:disabled` y emite un log de error con instrucciones
de diagnóstico. No se reinicia automáticamente hasta que el usuario lo habilita
explícitamente con `mix elpaso models enable <id>`.

### Gestión de requests durante `:warming`

Cuando el router llama a `ensure_hot/2` para un modelo en estado `:warming` (ya está
arrancando), el comportamiento es:

1. `ensure_hot/2` se subscribe al ModelWorker del modelo para recibir una notificación
   cuando el estado cambie a `:hot`
2. Espera hasta `timeout_ms` milisegundos
3. Si recibe `:hot` antes del timeout, retorna `:ok`
4. Si el timeout se agota antes, retorna `{:error, :timeout}` y el router activa fallback

Los requests no se colan: no hay una cola de requests pendientes en el ModelWorker.
La responsabilidad de esperar o hacer fallback es del router, no del ModelManager.

### Qué es y qué responsabilidades tiene

`ElPaso.Domain.ModelManager` es un GenServer que gestiona el ciclo de vida completo de cada
proceso de motor (llama-server, vllm) o conexión a API remota. Sus responsabilidades son:

- Arrancar el proceso del motor con los argumentos fusionados (base_args + model_args)
- Monitorizar que el proceso sigue vivo (via Port + health check periódico)
- Detectar y reportar fallos al router para actualizar el ModelState
- Parar el proceso cuando lleva más de `max_idle_minutes` sin recibir requests
- Reiniciar el proceso si `restart_on_error` es true y no se ha superado `max_restart_attempts`
- Exponer el estado actual de cada modelo para que el router pueda consultarlo

### Interfaz pública

```elixir
ElPaso.Domain.ModelManager.ensure_hot(model_id, timeout_ms)
  :: :ok | {:error, :timeout} | {:error, :max_retries_exceeded}

ElPaso.Domain.ModelManager.stop(model_id)
  :: :ok | {:error, :not_running}

ElPaso.Domain.ModelManager.state(model_id)
  :: {:ok, %ModelState{}} | {:error, :unknown_model}

ElPaso.Domain.ModelManager.all_states()
  :: [%ModelState{}]
````

`ensure_hot/2` es la función crítica: el router la llama antes de enviar el request. Si el
modelo está `:hot`, retorna `:ok` inmediatamente. Si está `:cold`, inicia el arranque y
espera hasta `timeout_ms`. Si está `:warming`, simplemente espera. Si está `:error`, retorna
error inmediatamente sin reintentar (eso es responsabilidad del restart automático, no del caller).

### Arranque de un proceso local

El arranque de un proceso llama-server usa `Zaguan.Engine` para la ejecución
con tolerancia a fallos. El flujo:

1. `Config.Merger` fusiona `engine.base_args` con `model.engine_args`
2. `ModelWorker` construye la función de arranque y la entrega a `Zaguan.Engine.execute/2`
3. Zaguan.Engine arranca el Worker bajo su `DynamicSupervisor` interno con la política configurada
4. El Worker abre el Port de Erlang al binario del motor
5. `ModelWorker` hace polling al health check cada 500ms para detectar cuándo está listo
6. Cuando responde 200, actualiza el ModelState a `:hot` y notifica a `ensure_hot/2`
7. Si el arranque supera `startup_timeout_ms`, Zaguan.Engine aplica la política
   (reintenta N veces o para definitivamente según `Policies.on_timeout`)

```elixir
defmodule ElPaso.Domain.ModelWorker do
  use GenServer
  alias Zaguan.Engine
  alias Zaguan.Engine.Policies

  # Política para motores locales: reintentar con backoff exponencial
  def engine_policy(model_config) do
    max_retries = model_config.lifecycle.max_restart_attempts
    Policies.new(
      on_error:    if(model_config.lifecycle.restart_on_error, do: :retry, else: :stop),
      max_retries: max_retries,
      retry_delay: 2_000,
      on_timeout:  :stop,
      timeout:     model_config.engine_config.startup_timeout_ms
    )
  end

  def start_engine(model_config, merged_args) do
    policy = engine_policy(model_config)
    binary = model_config.engine_binary

    Engine.execute(
      fn -> open_port_and_wait(binary, merged_args, model_config) end,
      policy: policy
    )
  end

  # Para health checks paralelos de todos los modelos activos
  def check_all_health(model_ids) do
    tasks = Enum.map(model_ids, fn id -> fn -> {id, do_health_check(id)} end end)
    Engine.run(tasks, workers: length(model_ids), timeout: 5_000)
  end
end
```

El circuit breaker de `Zaguan.Engine.Policies` reemplaza la lógica manual de
`consecutive_errors` y el backoff exponencial — Zaguan ya los gestiona internamente.

### Monitorización en caliente

Una vez el modelo está `:hot`, el `ModelWorker` usa `Zaguan.Engine.Monitor`
para estadísticas de workers y suscripción a eventos:

```elixir
# Suscribirse a eventos del engine para recibir notificaciones de fallos
Engine.subscribe()

# En handle_info — recibir eventos de Zaguan.Engine.Leader
def handle_info({:leader_event, %{type: :worker_error, worker_id: id, reason: reason}}, state) do
  update_model_state(id, :error, reason)
  {:noreply, state}
end
```

El health check periódico propio de ElPaso (cada 30s) sigue siendo necesario
para detectar si el proceso del motor ha muerto sin que Zaguan lo sepa
(por ejemplo, OOM killer del SO). Se implementa como `handle_info(:health_check)`:

- Lee `/proc/{pid}/status` para RAM y usa `nvidia-smi` para VRAM
- Llama al endpoint `/health` del motor con timeout 5s
- Si falla 3 veces, actualiza el ModelState a `:error` y el circuit breaker de Zaguan
  se activará en el siguiente intento de ejecución

### Parada por inactividad

El ModelManager lleva un timestamp de la última llamada completada para cada modelo. En un
ciclo periódico (cada minuto), evalúa:

```
tiempo_inactivo = now() - last_call_at
if tiempo_inactivo > max_idle_minutes * 60 * 1000:
  if keepalive activo y tiempo_inactivo < keepalive_minutes * 60 * 1000:
    # dentro del keepalive, no parar
    :skip
  else:
    stop(model_id)
    log "Modelo {id} parado por inactividad tras {tiempo_inactivo}ms"
```

Esta lógica no aplica a modelos remotos (type: remote_api) ni a modelos con `keepalive_minutes: null`.

### El ModelState ampliado

```elixir
%ModelState{
  model_id: String.t(),
  status: :hot | :warming | :cold | :error | :disabled,
  pid: pid() | nil,                      # PID del Port si está activo
  port: port() | nil,                    # Port de Erlang del proceso
  current_queue_depth: non_neg_integer(),
  avg_latency_ms: non_neg_integer(),
  p95_latency_ms: non_neg_integer(),     # percentil 95, más útil que la media para el router
  last_error_at: DateTime.t() | nil,
  last_error_reason: String.t() | nil,
  consecutive_errors: non_neg_integer(),
  restart_count: non_neg_integer(),      # cuántas veces se ha reiniciado en total
  ram_mb: non_neg_integer(),
  vram_mb: non_neg_integer(),            # consumo de VRAM si aplica (0 para modelos remotos)
  started_at: DateTime.t() | nil,
  last_call_at: DateTime.t() | nil
}
```

El campo `vram_mb` se obtiene via `nvidia-smi --query-compute-apps=pid,used_memory` filtrando
por el PID del proceso. Si no hay GPU o el comando no está disponible, el valor es 0 y no
se emite error. El `p95_latency_ms` usa una ventana deslizante de las últimas 50 llamadas
y es más representativo que la media aritmética para penalizar modelos inestables.

### Criterios de completitud del ModelManager para V1.0

- `ensure_hot/2` gestiona correctamente los cuatro estados: `:hot`, `:cold`, `:warming`, `:error`
- El arranque usa Port de Erlang con los args fusionados por `Config.Merger`
- El health check periódico detecta caídas del proceso y actualiza el ModelState
- El backoff exponencial en reinicio está implementado y respeta `max_restart_attempts`
- La parada por inactividad respeta `keepalive_minutes` y `max_idle_minutes`
- `ram_mb` y `vram_mb` se actualizan en cada ciclo de health check
- `p95_latency_ms` se calcula sobre ventana deslizante de 50 llamadas
- Los modelos remotos (`type: remote_api`) no tienen proceso que gestionar;
  `ensure_hot/2` retorna `:ok` inmediatamente para ellos
- Los eventos `[:elpaso, :model, :cold_start]` y `[:elpaso, :model, :health_check]`
  se emiten con measurements y metadata completos

---

## Consideraciones transversales

### Token counting

El `ElPaso.Context.TokenCounter` es un módulo compartido por todos los bloques. La estimación
de tokens no es trivial y hay que ser honesto sobre sus limitaciones.

La regla `characters / 4` es una aproximación válida para inglés con tokenización BPE estándar.
Para español es sistemáticamente incorrecta: las palabras españolas son más largas en promedio
y el tokenizador las divide en más tokens. Un factor más conservador para español es
`characters / 3`. Para contenido mixto español/código, usar `characters / 3.5`.

El módulo debe exponer dos funciones con semántica distinta:

```elixir
# Estimación rápida, sin conocer el modelo. Usa el factor conservador (/ 3).
# Para uso en el router (feature extraction) y en decisiones de budget no críticas.
ElPaso.Context.TokenCounter.estimate(text :: String.t()) :: non_neg_integer()

# Conteo con el mejor tokenizador disponible para el modelo dado.
# Para uso en Context.Builder cuando el budget es ajustado.
# Si el tokenizador específico no está disponible, hace fallback a estimate/1.
ElPaso.Context.TokenCounter.count(text :: String.t(), model_id :: String.t())
  :: {:ok, non_neg_integer()} | {:fallback, non_neg_integer()}
```

El Context.Builder usa `count/2` con el model_id de destino. Cuando retorna `{:fallback, n}`,
aplica un margen de seguridad del 15% en lugar del 10% estándar, para compensar la imprecisión.
Este modo de operación queda registrado en los metadatos del evento `[:elpaso, :context, :built]`.

Tokenizadores soportados en V1.0:

- `tiktoken` (vía Port NIF o script Python): para modelos OpenAI
- Estimación conservadora `characters / 3`: para todos los modelos locales en V1.0
- Tokenizadores HuggingFace via Tokenizers NIF: V1.1+

### Telemetría y observabilidad

Todos los bloques emiten eventos via `:telemetry` de Elixir. Cada evento tiene tres
componentes: nombre (lista de átomos), measurements (mapa de valores numéricos) y
metadata (mapa de contexto). Esta separación es la convención estándar de `:telemetry`
y permite que handlers externos (LiveDashboard, Prometheus, etc.) consuman los eventos
sin conocer la implementación interna.

```elixir
# Prefix cache hit
[:elpaso, :prefix, :hit]
  measurements: %{token_count: integer()}
  metadata: %{session_id: string, hash: binary, model_id: string}

# Prefix cache miss: reconstrucción necesaria
[:elpaso, :prefix, :miss]
  measurements: %{token_count: integer(), build_duration_us: integer()}
  metadata: %{session_id: string, reason: :new_session | :invalidated | :version_bump}

# Contexto construido exitosamente
[:elpaso, :context, :built]
  measurements: %{
    total_tokens: integer(),
    prefix_tokens: integer(),
    summary_tokens: integer(),
    semantic_tokens: integer(),
    window_tokens: integer(),
    current_tokens: integer(),
    build_duration_us: integer()
  }
  metadata: %{
    session_id: string,
    model_id: string,
    token_counter_mode: :precise | :fallback,
    layers_active: [:prefix, :summary, :semantic, :window]
  }

# Ventana reducida por presupuesto insuficiente
[:elpaso, :context, :window_trimmed]
  measurements: %{messages_removed: integer(), tokens_recovered: integer()}
  metadata: %{session_id: string, model_id: string, budget_available: integer()}

# Resumen incremental generado (Capa 2)
[:elpaso, :context, :compressed]
  measurements: %{
    messages_compressed: integer(),
    original_tokens: integer(),
    summary_tokens: integer(),
    compression_ratio: float(),
    generation_duration_ms: integer()
  }
  metadata: %{session_id: string, summarizer_model_id: string, strategy: :eager | :lazy}

# Decisión del router
[:elpaso, :router, :decision]
  measurements: %{decision_latency_us: integer(), candidate_count: integer()}
  metadata: %{
    request_id: string,
    session_id: string,
    selected_model: string,
    runner_up: string | nil,
    task_type: atom,
    complexity_score: float,
    token_estimate: integer,
    selected_model_status: atom,
    reason: string
  }

# Fallback activado
[:elpaso, :router, :fallback]
  measurements: %{fallback_latency_ms: integer()}
  metadata: %{
    request_id: string,
    original_model: string,
    fallback_model: string | nil,
    reason: :timeout | :cold_start_failed | :model_error | :no_candidates
  }

# Modelo arrancado desde frío
[:elpaso, :model, :cold_start]
  measurements: %{startup_duration_ms: integer()}
  metadata: %{model_id: string, triggered_by: :request | :autostart, attempt: integer}

# Health check periódico
[:elpaso, :model, :health_check]
  measurements: %{latency_ms: integer(), ram_mb: integer(), vram_mb: integer()}
  metadata: %{model_id: string, status: atom, consecutive_failures: integer()}

# Inferencia completada
[:elpaso, :inference, :complete]
  measurements: %{
    latency_ms: integer(),
    prompt_tokens: integer(),
    completion_tokens: integer(),
    total_tokens: integer()
  }
  metadata: %{
    request_id: string,
    session_id: string,
    model_id: string,
    streamed: boolean,
    task_type: atom
  }

# Inferencia fallida
[:elpaso, :inference, :error]
  measurements: %{latency_ms: integer()}
  metadata: %{
    request_id: string,
    model_id: string,
    error_type: :timeout | :http_error | :parse_error | :model_crash,
    http_status: integer() | nil
  }
```

### Campos recargables en caliente vs. requieren reinicio

Esta distinción es crítica para el usuario que ajusta el comportamiento sin interrumpir
sesiones activas. El `Config.Loader` detecta cambios en el archivo vía `inotify` (Linux)
o polling como fallback, y clasifica los cambios antes de aplicarlos:

**Recargables en caliente** (sin detener ElPaso ni los modelos):

- `session_defaults.*` — aplica solo a nuevas sesiones
- `canonical_prefix.system_prompt_file` — invalida el PrefixManager; las sesiones afectadas
  reconstruyen el bloque en la siguiente llamada con `reason: :version_bump`
- `routing.complexity_weights` — el router usa los nuevos pesos en la siguiente decisión
- `model.routing.task_affinity` — ídem
- `model.routing.conditions.*` — ídem
- `model.inference_defaults.*` — aplica en el siguiente request al motor
- `model.lifecycle.keepalive_minutes` y `max_idle_minutes`

**Requieren recarga explícita** (`mix elpaso reload`; detiene y reinicia los modelos afectados):

- `model.engine_args.*` — solo se leen al arrancar el proceso del motor
- `model.context_spec.*` — el Builder usa el spec cacheado en ETS; hay que invalidarlo
- `engines.*` — cambia la configuración base de un motor

**Requieren reinicio completo** (`mix elpaso daemon restart`):

- `system.db_url` — la conexión a PostgreSQL se establece al arrancar
- `system.http_port` — requiere reiniciar el servidor HTTP
- Añadir o eliminar una entrada en `models` — el supervisor se inicializa al arrancar
- `meta.version` — cambio de schema incompatible

El comando `mix elpaso config reload` muestra qué tipo de cambio se detectó y qué acción
tomará antes de aplicarlo, pidiendo confirmación si el impacto es alto.

### Prompt de resumen incremental

El resumen incremental (Capa 2 del Portable Session Context) lo genera ElPaso llamando
internamente al modelo configurado en `session_defaults.summarize_with_model`. El prompt
de resumen vive en un fichero separado, es ajustable por el usuario, y tiene el siguiente
contenido por defecto:

```
Eres un asistente especializado en resumir conversaciones de forma concisa y precisa.
Tu tarea es actualizar un resumen acumulativo incorporando un nuevo bloque de mensajes.

RESUMEN EXISTENTE (vacío si es el primero):
{existing_summary}

NUEVOS MENSAJES A INCORPORAR:
{messages_to_compress}

Genera un resumen actualizado que:
1. Preserve todos los hechos concretos: nombres de variables, decisiones tomadas,
   errores identificados, código escrito, rutas de archivos, comandos ejecutados.
2. Elimine saludos, reformulaciones y contenido sin información nueva.
3. Mantenga orden cronológico de los eventos relevantes.
4. No supere {max_summary_tokens} tokens.
5. Esté escrito en el mismo idioma que los mensajes.

Responde ÚNICAMENTE con el texto del resumen. Sin preámbulo ni explicación.
```

`{max_summary_tokens}` se calcula como el 20% del `window_token_budget` del modelo de destino.
Si el archivo `summarize.txt` no existe, se usa este default embebido en el código.

### El campo `--alias` en motores locales

El argumento `--alias` de llama-server determina el nombre del modelo que aparece en las
respuestas de `GET /v1/models` y en el campo `model` de las respuestas de chat completions.
Es relevante porque clientes como Continue.dev o Claude Code usan este nombre para identificar
el modelo en su propia configuración.

Se declara en `engine_args` como cualquier otro argumento del motor:

```json
"engine_args": {
  "--alias": "elpaso-fast",
  "--port": 8080
}
```

Si no se especifica, llama-server usa el nombre del fichero GGUF, que puede ser una ruta
larga y completamente inútil para el cliente. El wizard debe preguntar por este valor
y sugerir un nombre limpio derivado del `label` del modelo.

Para motores remotos, el alias no aplica. El nombre que ve el cliente es el `model_name`
del campo `source`.

### Recarga en caliente del bloque canónico

Cuando el usuario modifica `canonical_prefix.system_prompt_file` en caliente, el flujo es:

1. `Config.Loader` detecta el cambio y envía `{:config_changed, :canonical_prefix}` al PrefixManager
2. PrefixManager recalcula el hash del nuevo contenido
3. Invalida las entradas de ETS cuyo hash no coincida
4. Las sesiones activas reconstruirán su bloque en el siguiente request;
   el evento `[:elpaso, :prefix, :miss]` se emite con `reason: :version_bump`
5. Las llamadas en curso en el momento del cambio terminan con el bloque anterior;
   el cambio aplica solo desde el siguiente request

---

## BLOQUE 4: Sistema de Configuración de Modelos y Motores

### Definición precisa

La configuración de ElPaso es el sistema mediante el cual el usuario declara qué modelos
existen, qué motor arranca cada uno, con qué argumentos, bajo qué condiciones debe usarse
cada combinación, y qué comportamiento debe tener el sistema cuando una condición cambia.

Este sistema no es trivial. Un error de configuración silencioso puede hacer que ElPaso
arranque el modelo equivocado, pase argumentos inválidos al motor, o nunca use el modelo
heavy porque la condición está mal expresada. Por tanto, la configuración debe ser:

- **Declarativa**: el usuario describe qué quiere, no cómo implementarlo
- **Validada en lectura**: ElPaso rechaza configuraciones inválidas al arrancar, no en tiempo
  de ejecución cuando ya es tarde
- **Versionada**: los cambios de configuración tienen historial para poder hacer rollback
- **Generada por wizard**: el usuario no tiene que escribir JSON o TOML a mano; el wizard
  construye la configuración mediante preguntas interactivas y la valida antes de guardar
- **Recargable en caliente** (parcialmente): cambios en ciertos parámetros (pesos del router,
  temperaturas, system prompt) no requieren reiniciar ElPaso; cambios estructurales (añadir
  un modelo, cambiar el puerto de un motor) sí requieren reinicio o recarga explícita

### Formato y ubicación del archivo de configuración

El archivo de configuración vive en `~/.config/elpaso/elpaso.conf` y está en formato JSON con
comentarios desactivados (JSON estricto, sin JSONC). La razón de JSON sobre TOML o YAML es que
Elixir tiene soporte nativo para JSON via `Jason` sin dependencias adicionales y la estructura
jerárquica del JSON encaja bien con el schema de ElPaso.

Además del archivo principal, existen archivos auxiliares en el mismo directorio:

```
~/.config/elpaso/
├── elpaso.conf             ← configuración principal, generada/editada por el usuario
├── elpaso.conf.bak         ← backup automático antes de cada modificación vía wizard
├── models/
│   ├── fast.conf           ← configuración detallada de cada modelo (opcional, para no
│   └── heavy.conf              inflar el archivo principal)
├── prompts/
│   └── system_base.txt     ← system prompt base referenciado desde elpaso.conf
└── elpaso.lock             ← estado en tiempo de ejecución, no editado por el usuario
```

El archivo `elpaso.lock` es generado y mantenido por ElPaso en tiempo de ejecución. Contiene
el estado actual de cada modelo (hot/cold/error), las estadísticas del router y los hashes
de los bloques canónicos activos. No debe ser editado manualmente y no persiste entre reinicios
completos del sistema.

### Schema completo de configuración para V1.0

El schema es el contrato entre el usuario y ElPaso. Debe estar completamente documentado y
validado. A continuación se define cada sección con sus campos, tipos, valores por defecto
y restricciones:

#### Sección `meta`

```json
{
  "meta": {
    "version": "1.0",
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-01T00:00:00Z",
    "created_by": "wizard"
  }
}
```

El campo `version` identifica el schema, no ElPaso. Si en el futuro el schema cambia de forma
incompatible, ElPaso detecta el mismatch y puede migrar o advertir. `created_by` puede ser
`"wizard"` o `"manual"`, lo que permite al sistema saber si el archivo fue generado
automáticamente o editado a mano (útil para decidir si ofrecer asistencia de migración).

#### Sección `system`

```json
{
  "system": {
    "http_port": 5555,
    "log_level": "info",
    "telemetry_enabled": true,
    "db_url": "postgresql://localhost/elpaso",
    "data_dir": "~/.local/share/elpaso",
    "port_range": [8080, 8200]
  }
}
```

`data_dir` es donde ElPaso almacena embeddings, resúmenes y el historial de decisiones del
router. Separado de `~/.config` porque son datos mutables de usuario, no configuración.
`port_range` define el rango de puertos disponibles para asignación automática cuando un
modelo no declara port en sus `engine_args`.

#### Sección `session_defaults`

```json
{
  "session_defaults": {
    "latency_tolerance_ms": 5000,
    "context_mode": "transparent",
    "semantic_retrieval": false,
    "window_size": 10,
    "summary_strategy": "eager",
    "summary_trigger_pct": 0.8,
    "summarize_with_model": "auto"
  }
}
```

- `latency_tolerance_ms`: tiempo máximo que el usuario acepta esperar por un cold start antes
  de que el router haga fallback al siguiente candidato disponible.
- `context_mode`: `"transparent"` o `"declarative"`. Controla si el cambio de modelo se
  anuncia en el contexto inyectado.
- `semantic_retrieval`: activa la Capa 3 del contexto. Requiere `pgvector` instalado.
- `window_size`: número de mensajes completos en la ventana deslizante.
- `summary_strategy`: `"eager"` (recomendado) o `"lazy"`.
- `summary_trigger_pct`: porcentaje del window_budget que dispara el resumen eager.
- `summarize_with_model`: `"auto"` usa el modelo más ligero disponible. Puede especificarse
  un `model_id` concreto para usar siempre el mismo modelo para resumir.

Estos son los valores por defecto para todas las sesiones. En V1.1+ se podrán sobreescribir
por sesión mediante parámetros en el request.

#### Sección `engines`

Esta sección declara los motores disponibles con sus binarios, rutas y configuración base.
Un motor es el proceso externo que ejecuta la inferencia (llama-server, vllm, etc.) o la API
remota a la que ElPaso se conecta.

```json
{
  "engines": {
    "llama_server": {
      "type": "local_process",
      "binary": "/usr/local/bin/llama-server",
      "base_args": {
        "--host": "0.0.0.0",
        "--batch-size": 2048,
        "--ubatch-size": 256,
        "--threads": 12,
        "--prio": 3,
        "--flash-attn": "on",
        "--cache-type-k": "q4_0",
        "--cache-type-v": "q4_0"
      },
      "health_check_endpoint": "/health",
      "health_check_timeout_ms": 5000,
      "startup_timeout_ms": 30000,
      "shutdown_timeout_ms": 10000
    },
    "vllm": {
      "type": "local_process",
      "binary": "python3",
      "subcommand": ["-m", "vllm.entrypoints.openai.api_server"],
      "base_args": {
        "--dtype": "auto",
        "--trust-remote-code": true
      },
      "health_check_endpoint": "/health",
      "health_check_timeout_ms": 5000,
      "startup_timeout_ms": 60000,
      "shutdown_timeout_ms": 15000
    },
    "openai": {
      "type": "remote_api",
      "base_url": "https://api.openai.com/v1",
      "api_key_env": "OPENAI_API_KEY",
      "timeout_ms": 30000,
      "max_retries": 3
    },
    "anthropic": {
      "type": "remote_api",
      "base_url": "https://api.anthropic.com",
      "api_key_env": "ANTHROPIC_API_KEY",
      "timeout_ms": 30000,
      "max_retries": 3
    }
  }
}
```

Separar los motores de los modelos es una decisión de diseño importante. Un motor (llama-server)
puede servir a múltiples modelos secuencialmente; un modelo (Gemma 4B) siempre usa el mismo
motor. Esta separación evita duplicar la configuración del binario y sus args base en cada modelo.

Los `base_args` son argumentos que se pasan siempre al motor, independientemente del modelo.
Los argumentos específicos del modelo se definen en la sección `models` y se fusionan en tiempo
de arranque. La fusión es aditiva: model_args se añaden a base_args, nunca los reemplazan.
Si hay conflicto de flags (por ejemplo, `--ctx-size` aparece en ambos), los `model_args` tienen
precedencia.

Para motores de tipo `remote_api`, las API keys nunca se almacenan en el archivo de configuración.
Se referencian por nombre de variable de entorno (`api_key_env`). ElPaso lee la variable en
tiempo de arranque y falla con error claro si no está definida.

#### Sección `models`

Esta es la sección más crítica. Cada entrada define un modelo con todo lo necesario para que
ElPaso pueda arrancarlo, usarlo y detenerlo correctamente.

```json
{
  "models": [
    {
      "id": "fast",
      "label": "Gemma 3 4B (rápido)",
      "enabled": true,
      "engine": "llama_server",

      "source": {
        "type": "local_file",
        "path": "~/modelos/gemma-3-4b-q4_k_m.gguf"
      },

      "engine_args": {
        "--port": 8080,
        "--ctx-size": 8192,
        "--n-gpu-layers": 999,
        "--cont-batching": true,
        "--context-shift": true,
        "--cache-type-k": "q8_0"
      },

      "inference_defaults": {
        "temperature": 0.2,
        "min_p": 0.05,
        "repeat_penalty": 1.1,
        "max_tokens": 1024
      },

      "context_spec": {
        "max_context_tokens": 8192,
        "reserved_output_tokens": 1024,
        "supports_system_prompt": true,
        "chat_template": "gemma"
      },

      "routing": {
        "priority": 1,
        "cold_start_estimate_ms": 8000,
        "task_affinity": {
          "code": 0.5,
          "reasoning": 0.4,
          "summarization": 0.8,
          "question_answer": 0.9,
          "creative": 0.7,
          "translation": 0.9,
          "unknown": 0.6
        },
        "conditions": {
          "use_when": [
            { "complexity_score": { "lt": 0.5 } },
            {
              "task_type": {
                "in": ["question_answer", "translation", "summarization"]
              }
            },
            { "token_estimate": { "lt": 2000 } }
          ],
          "prefer_when": [
            { "model_status": { "eq": "hot" } },
            { "queue_depth": { "lt": 3 } }
          ],
          "avoid_when": [
            { "task_type": { "in": ["reasoning"] } },
            { "complexity_score": { "gt": 0.75 } }
          ]
        }
      },

      "lifecycle": {
        "autostart": false,
        "keepalive_minutes": 30,
        "max_idle_minutes": 60,
        "restart_on_error": true,
        "max_restart_attempts": 3
      }
    },
    {
      "id": "heavy",
      "label": "Qwen 2.5 14B (potente)",
      "enabled": true,
      "engine": "llama_server",

      "source": {
        "type": "local_file",
        "path": "~/modelos/qwen2.5-14b-q4_k_m.gguf"
      },

      "engine_args": {
        "--port": 8081,
        "--ctx-size": 32768,
        "--n-gpu-layers": 999,
        "--cont-batching": true,
        "--context-shift": true,
        "--cache-type-k": "q8_0"
      },

      "inference_defaults": {
        "temperature": 0.7,
        "min_p": 0.05,
        "repeat_penalty": 1.05,
        "max_tokens": 4096
      },

      "context_spec": {
        "max_context_tokens": 32768,
        "reserved_output_tokens": 4096,
        "supports_system_prompt": true,
        "chat_template": "chatml"
      },

      "routing": {
        "priority": 2,
        "cold_start_estimate_ms": 25000,
        "task_affinity": {
          "code": 0.95,
          "reasoning": 0.98,
          "summarization": 0.7,
          "question_answer": 0.7,
          "creative": 0.85,
          "translation": 0.8,
          "unknown": 0.7
        },
        "conditions": {
          "use_when": [
            { "complexity_score": { "gte": 0.5 } },
            { "task_type": { "in": ["code", "reasoning"] } },
            { "token_estimate": { "gte": 2000 } }
          ],
          "prefer_when": [{ "complexity_score": { "gte": 0.75 } }],
          "avoid_when": [
            { "token_estimate": { "lt": 500 } },
            { "task_type": { "in": ["translation"] } }
          ]
        }
      },

      "lifecycle": {
        "autostart": false,
        "keepalive_minutes": 60,
        "max_idle_minutes": 90,
        "restart_on_error": true,
        "max_restart_attempts": 2
      }
    },
    {
      "id": "remote_claude",
      "label": "Claude Sonnet (remoto)",
      "enabled": true,
      "engine": "anthropic",

      "source": {
        "type": "remote_model",
        "model_name": "claude-sonnet-4-5"
      },

      "engine_args": {},

      "inference_defaults": {
        "temperature": 0.5,
        "max_tokens": 8192
      },

      "context_spec": {
        "max_context_tokens": 200000,
        "reserved_output_tokens": 8192,
        "supports_system_prompt": true,
        "chat_template": "anthropic"
      },

      "routing": {
        "priority": 3,
        "cold_start_estimate_ms": 500,
        "task_affinity": {
          "code": 0.98,
          "reasoning": 0.99,
          "summarization": 0.9,
          "question_answer": 0.85,
          "creative": 0.95,
          "translation": 0.9,
          "unknown": 0.8
        },
        "conditions": {
          "use_when": [
            { "all_local_models_status": { "eq": "error" } },
            { "token_estimate": { "gt": 30000 } }
          ],
          "prefer_when": [
            { "task_type": { "in": ["reasoning", "code"] } },
            { "complexity_score": { "gt": 0.9 } }
          ],
          "avoid_when": [{ "network_available": { "eq": false } }]
        }
      },

      "lifecycle": {
        "autostart": false,
        "keepalive_minutes": null,
        "max_idle_minutes": null,
        "restart_on_error": false,
        "max_restart_attempts": 0
      }
    }
  ],

  "routing": {
    "complexity_weights": {
      "token_estimate": 0.3,
      "task_type": 0.25,
      "sentence_depth": 0.2,
      "vocabulary_density": 0.15,
      "question_count": 0.1
    },
    "cold_start_penalty_factor": 1.5,
    "max_consecutive_errors_before_exclude": 3,
    "fallback_timeout_ms": 15000,
    "score_tie_threshold": 0.01
  },

  "canonical_prefix": {
    "system_prompt_file": "~/.config/elpaso/prompts/system_base.txt",
    "reference_documents": [
      {
        "id": "doc-1",
        "label": "Especificación del proyecto",
        "path": "~/proyecto/SPEC.md",
        "max_tokens": 2000
      }
    ],
    "version": 1
  },

  "summarization": {
    "prompt_file": "~/.config/elpaso/prompts/summarize.txt"
  }
}
```

### Anatomía de un model entry: explicación campo a campo

#### `source`

Define de dónde viene el modelo. Tipos soportados en V1.0:

- `local_file`: modelo en disco en formato GGUF o compatible con el motor especificado.
  La ruta acepta `~` y variables de entorno (`$MODELS_DIR/gemma.gguf`). ElPaso resuelve
  la ruta al arrancar y falla con error descriptivo si el fichero no existe.

- `remote_model`: modelo accesible vía API remota. El campo `model_name` es el identificador
  que se envía en el campo `model` de las llamadas a la API. ElPaso no descarga nada.

- `hf_repo` (V1.1+): descarga automática desde HuggingFace Hub. No se implementa en V1.0
  pero el schema debe reservar el tipo para no romper compatibilidad futura.

#### `engine_args`

Argumentos que se pasan directamente al proceso del motor al arrancarlo. Hay tres tipos
de argumentos y el schema debe representarlos a todos:

**Tipo 1: Par clave-valor** — argumento con un valor explícito:

```json
"--ctx-size": 128000,
"--n-gpu-layers": 999,
"--cache-type-k": "q4_0"
```

ElPaso serializa esto como `--ctx-size 128000 --n-gpu-layers 999 --cache-type-k q4_0`.

**Tipo 2: Flag booleano** — argumento sin valor, su presencia activa la opción:

```json
"--cont-batching": true,
"--context-shift": true,
"--flash-attn": "on"
```

Cuando el valor es `true`, ElPaso emite solo el flag: `--cont-batching --context-shift`.
Cuando el valor es `false`, el flag se omite completamente (no se emite `--no-cont-batching`
a menos que el motor lo requiera explícitamente; en ese caso se pone como string).
Cuando el valor es un string como `"on"`, se emite como par: `--flash-attn on`.

**Tipo 3: Eliminación de un base_arg** — valor `null` elimina un argumento heredado del motor:

```json
"--numa": null
```

Si `base_args` del motor incluye `"--numa": "distribute"` pero este modelo no debe usarlo
(porque va full GPU y no necesita NUMA), poner `null` lo elimina del comando final.

Reglas de fusión con `base_args` del motor:

1. Se parte de una copia de `engine.base_args`
2. Se aplican los `model.engine_args` encima, clave por clave
3. Si la clave existe en base y el modelo la sobreescribe, gana el modelo
4. Si el valor del modelo es `null`, la clave se elimina del resultado
5. El resultado se serializa en orden: primero los args heredados, luego los propios del modelo

Ejemplo concreto basado en un caso real. El motor tiene estos base_args:

```json
"base_args": {
  "--host": "0.0.0.0",
  "--batch-size": 2048,
  "--threads": 12,
  "--ubatch-size": 256,
  "--flash-attn": "on",
  "--cache-type-k": "q4_0",
  "--cache-type-v": "q4_0",
  "--prio": 3
}
```

El modelo gemma define estos engine_args:

```json
"engine_args": {
  "--port": 8080,
  "--ctx-size": 128000,
  "--n-gpu-layers": 999,
  "--ubatch-size": 512,
  "--cont-batching": true,
  "--context-shift": true,
  "--cache-ram": 12288,
  "--ctx-checkpoints": 128
}
```

El resultado fusionado que se pasa al proceso es:

```
--host 0.0.0.0
--batch-size 2048
--threads 12
--ubatch-size 512          ← modelo sobreescribió el 256 del base
--flash-attn on
--cache-type-k q4_0
--cache-type-v q4_0
--prio 3
--port 8080
--ctx-size 128000
--n-gpu-layers 999
--cont-batching            ← flag booleano, sin valor
--context-shift
--cache-ram 12288
--ctx-checkpoints 128
```

ElPaso valida en tiempo de lectura que no se pasan argumentos mutuamente excluyentes.
La lista de pares incompatibles para cada motor se mantiene en `ElPaso.Engine.Validation`.

El port declarado en `engine_args` es el que ElPaso usa para conectarse al motor. Si un
modelo no declara port, ElPaso asigna uno disponible del rango configurable
(`port_range: [8080, 8200]` en `system`). No puede haber dos modelos con el mismo port.
Esta validación ocurre al leer la configuración, no al arrancar.

#### Separación entre `engine_args` e `inference_defaults`: qué va dónde

Este es un punto de confusión frecuente que hay que resolver explícitamente. Algunos
parámetros como `--temperature`, `--min-p` o `--repeat-penalty` pueden pasarse de dos formas:

- **Como argumento del servidor** (en `engine_args`): establece el valor default del proceso
  del motor. Cualquier request que no especifique ese parámetro usará este valor. Es el
  comportamiento del motor en ausencia de instrucciones del cliente.

- **Como parámetro de inferencia** (en `inference_defaults`): es el valor que ElPaso inyecta
  explícitamente en cada request antes de enviarlo al motor. Tiene precedencia sobre el default
  del servidor porque se envía como parte del body del request.

La regla para ElPaso es la siguiente:

Los parámetros de inferencia como temperature, top_p, min_p, repeat_penalty y max_tokens
van ÚNICAMENTE en `inference_defaults`, nunca en `engine_args`. Esto da a ElPaso control
total sobre ellos en cada request, sin depender de los defaults del proceso del motor.

Si el usuario los pone en `engine_args`, el wizard debe advertirlo y el validador debe
emitir un warning (no error, para no bloquear configuraciones legacy), recomendando moverlos
a `inference_defaults`.

La razón de fondo es que si defines temperature en el servidor Y en inference_defaults, no
está claro cuál gana (depende de la implementación del motor y puede cambiar entre versiones).
Centralizar en `inference_defaults` hace el comportamiento predecible independientemente del
motor.

Los parámetros que sí van en `engine_args` y nunca en `inference_defaults` son los que
afectan al proceso del servidor, no a la inferencia individual:
`--ctx-size`, `--n-gpu-layers`, `--threads`, `--batch-size`, `--ubatch-size`,
`--cache-type-k`, `--cache-type-v`, `--cont-batching`, `--flash-attn`, `--numa`,
`--cache-ram`, `--ctx-checkpoints`, `--context-shift`.

#### `inference_defaults`

Parámetros de inferencia que se usan cuando el cliente no los especifica explícitamente.
Si el cliente envía `temperature: 0.9` en su request, ese valor tiene precedencia sobre
el default. Si no lo envía, se usa el default del modelo.

Los defaults de inferencia son por modelo, no globales. Un modelo fast configurado para
tareas de Q&A tiene sentido con temperatura 0.2; un modelo de escritura creativa con 0.8.

#### `context_spec`

Define las capacidades y límites del modelo desde el punto de vista del gestor de contexto:

- `max_context_tokens`: límite físico del contexto del modelo. El Context Builder nunca
  construirá un prompt que supere este valor (con margen de seguridad del 10%).
- `reserved_output_tokens`: tokens reservados para la respuesta. Se restan del presupuesto
  disponible para el contexto de entrada.
- `supports_system_prompt`: si el modelo acepta un mensaje de rol `system` separado del
  historial. Si es `false`, el bloque canónico se inyecta como primer mensaje de usuario.
- `chat_template`: identificador del template de formateo del prompt. Valores soportados
  en V1.0: `"gemma"`, `"chatml"`, `"llama3"`, `"mistral"`, `"anthropic"`, `"openai"`.
  Este campo es crítico: un template incorrecto produce respuestas degradadas o tokens
  inválidos sin ningún error obvio.

#### `routing.conditions`

Este es el corazón de la configuración de enrutamiento. Define cuándo debe usarse cada modelo
con tres niveles de expresividad:

**`use_when`**: condiciones que, si se cumplen, hacen que este modelo sea candidato fuerte.
Son condiciones inclusivas: si se cumple alguna, el modelo entra en el pool de candidatos
con score elevado.

**`prefer_when`**: condiciones que, si se cumplen sobre un modelo ya candidato, incrementan
su score. Son un bonus, no requisito.

**`avoid_when`**: condiciones que, si se cumplen, penalizan fuertemente al modelo. No lo
excluyen automáticamente (eso lo hace el error_penalty del router), pero reducen su score
de forma significativa. Permiten expresar "no uses este modelo para traducción" sin hacer
esa restricción absoluta (si es el único disponible, se usa igualmente).

El sistema de condiciones usa un DSL simple de operadores:

```
{"campo": {"operador": valor}}

Operadores numéricos:   lt, lte, gt, gte, eq, neq
Operadores de conjunto: in, not_in
Operadores booleanos:   eq (true/false)
Operadores especiales:  exists, not_exists
```

Campos disponibles en las condiciones:

```
complexity_score          float 0.0-1.0, calculado por el router
task_type                 string, clasificado por el router
token_estimate            integer, tokens estimados del prompt
model_status              string: hot, warming, cold, error
queue_depth               integer, requests en cola para este modelo
all_local_models_status   string: hot, cold, error (estado del conjunto)
network_available         boolean, conectividad de red disponible
time_of_day               string: morning, afternoon, evening, night (extensión futura)
session_preference        string: model_id explícito si el usuario lo forzó
```

Las condiciones se evalúan en el router en tiempo de decisión, antes del scoring. Los
resultados de `use_when` y `avoid_when` modifican el `base_score` del modelo antes de
aplicar las penalizaciones de estado del sistema.

**Semántica de evaluación de las listas:**

- Dentro de `use_when`: lógica **OR**. Si cualquiera de las condiciones se cumple, el modelo
  recibe el bonus de candidato fuerte. El usuario declara múltiples razones por las que un
  modelo es buena elección, no múltiples requisitos simultáneos.

- Dentro de `prefer_when`: lógica **OR**. Si cualquiera se cumple, se añade el bonus.

- Dentro de `avoid_when`: lógica **OR**. Si cualquiera se cumple, se aplica la penalización.

Si se necesita lógica AND (el modelo solo debe usarse cuando se cumplen varias condiciones
a la vez), se usa el operador `all_of` como wrapper:

```json
"use_when": [
  {"all_of": [
    {"complexity_score": {"gte": 0.5}},
    {"task_type": {"in": ["code", "reasoning"]}}
  ]}
]
```

Para V1.0, `all_of` y `any_of` son los dos operadores de agrupación soportados.
`none_of` es V1.1+.

**El campo `priority`:**

El campo `routing.priority` es un desempate de último recurso, no un peso en el scoring.
Solo se usa cuando dos modelos tienen `final_score` idéntico (o dentro de un umbral de
diferencia de 0.01). En ese caso, el modelo con `priority` más bajo gana. Un modelo con
`priority: 1` se prefiere sobre uno con `priority: 2` si todo lo demás es igual.

En la práctica, esto permite al usuario definir un orden de preferencia para casos donde
el router genuinamente no puede distinguir entre candidatos (por ejemplo, dos modelos
fast de capacidades similares ambos en caliente y sin cola).

#### `lifecycle`

Define el comportamiento del ciclo de vida del proceso del motor:

- `autostart`: si ElPaso debe arrancar este modelo al iniciar el daemon. Por defecto `false`
  para todos; los modelos se arrancan bajo demanda. Útil para el modelo más usado si el
  usuario quiere que siempre esté caliente.
- `keepalive_minutes`: tiempo que ElPaso mantiene el modelo cargado después de la última
  llamada antes de plantearse apagarlo. `null` significa "nunca apagar solo".
- `max_idle_minutes`: tiempo máximo sin actividad antes de apagar el modelo para liberar
  recursos. Si es `null`, el modelo nunca se apaga por inactividad.
- `restart_on_error`: si ElPaso debe intentar reiniciar el motor si muere inesperadamente.
- `max_restart_attempts`: número máximo de reinicios consecutivos antes de marcar el modelo
  como `:error` y dejar de intentarlo. Con `0`, nunca se reinicia automáticamente.

Para modelos remotos (`type: remote_api`), los campos `keepalive_minutes`, `max_idle_minutes`
y `restart_on_error` no aplican y deben ser `null` o `false`. El wizard no debe pedirlos
para modelos remotos.

### El wizard de configuración: `mix elpaso config wizard`

El wizard es la interfaz principal para crear y modificar la configuración. No es opcional
ni cosmético: para V1.0 es el mecanismo canónico de configuración, y el archivo generado
por el wizard debe ser siempre válido.

**Implementación con Zaguan**: el wizard usa `Zaguan.UI.Components` para toda la
interacción y `Zaguan.Drawer.Components` para toda la salida visual. No se usa
`IO.gets/1` directamente; se usa `Zaguan.UI.Components.Input`, `Select` y `Confirm`.
El header del wizard se imprime con `Zaguan.Drawer.Components.Header.print/2`.
Los errores de validación se muestran con `Zaguan.Drawer.Printer.print(:error, msg)`.

```elixir
# Ejemplo de implementación del Paso 1 con Zaguan
defmodule ElPaso.Config.Wizard do
  alias Zaguan.Drawer.Components.{Header, Message, Table}
  alias Zaguan.UI.Components.{Input, Select, Confirm}

  def run do
    Header.print("ElPaso Config Wizard", subtitle: "Elixir 1.19.5 / OTP 28")
    env = ElPaso.Config.EnvironmentDetector.detect_all()
    print_environment_summary(env)
    step_system(env)
  end

  defp print_environment_summary(env) do
    Table.print(
      headers: ["Componente", "Estado", "Versión"],
      rows: [
        ["llama-server", status_str(env.llama_server), env.llama_server_version || "-"],
        ["PostgreSQL",   status_str(env.postgres),     "-"],
        ["GPU",          status_str(env.gpu != nil),   env.gpu || "-"]
      ],
      headers_color: :cyan,
      table_border: :rounded
    )
  end

  defp step_system(_env) do
    Message.print(:info, "Configuración del sistema")
    {:ok, port} = Input.prompt("Puerto HTTP [5555]:",
      default: "5555",
      validate: &valid_port?/1,
      error_msg: "Puerto inválido o en uso"
    )
    # ...
  end
end
```

#### Flujo del wizard

El wizard tiene tres modos:

**Modo creación** (`mix elpaso config wizard`):
Se activa cuando no existe `elpaso.conf` o el usuario lo invoca explícitamente. Guía al
usuario desde cero por todas las secciones.

**Modo edición** (`mix elpaso config wizard --edit`):
Carga la configuración existente y permite modificar secciones concretas sin rehacerlo todo.
El usuario elige qué sección editar.

**Modo add-model** (`mix elpaso config wizard add-model`):
Flujo especializado para añadir un modelo nuevo a una configuración existente. No toca
las secciones que no son `models`.

#### Pasos del wizard en modo creación

```
Paso 1: Bienvenida y detección del entorno
  - Detecta si llama-server está instalado y su versión
  - Detecta si vllm está disponible
  - Detecta GPUs disponibles y VRAM (via nvidia-smi o rocm-smi)
  - Detecta RAM del sistema
  - Informa al usuario de qué puede y qué no puede usar según su hardware

Paso 2: Configuración del sistema
  - Puerto HTTP (default: 5555, validar que está libre)
  - Nivel de log (debug/info/warn/error)
  - Directorio de datos

Paso 3: Configuración de base de datos
  - URL de PostgreSQL
  - Verificar conexión y crear tablas si no existen

Paso 4: Primer modelo (al menos uno es obligatorio)
  - Nombre/label del modelo
  - Tipo de fuente (local/remoto)
  - Si local: ruta al archivo GGUF (con autocompletado de paths)
  - Si remoto: selección del proveedor y nombre del modelo
  - Motor a usar (mostrar solo los disponibles según detección del Paso 1)
  - Argumentos del motor:
      - Port (sugerir siguiente disponible a partir de 8080)
      - Tamaño de contexto (sugerir según RAM/VRAM disponible)
      - Capas en GPU (sugerir automáticamente según VRAM y tamaño del modelo)
      - Threads de CPU (sugerir según cores disponibles)
  - Chat template (mostrar opciones, intentar detectar del nombre del archivo)
  - Rol del modelo: fast / heavy / specialist / fallback (afecta conditions generadas)
  - ¿Quieres configurar las condiciones de uso? (sí/no; si no, se usan defaults por rol)

Paso 5: ¿Añadir más modelos? (repetir Paso 4 hasta que el usuario diga no)

Paso 6: System prompt base
  - El usuario puede escribirlo inline o indicar la ruta a un archivo .txt
  - Si es inline, se guarda en ~/.config/elpaso/prompts/system_base.txt y se referencia

Paso 7: Revisión y confirmación
  - Mostrar el JSON generado con syntax highlighting
  - Validar el schema antes de guardar
  - Pedir confirmación
  - Guardar y mostrar el path del archivo

Paso 8: Test de arranque (opcional)
  - ¿Quieres verificar que el primer modelo arranca correctamente?
  - Si sí: arranca el motor, envía un ping de health check, muestra el resultado, para el motor
```

#### Validaciones del wizard antes de guardar

El wizard valida lo siguiente antes de escribir el archivo:

- No hay dos modelos con el mismo `id`
- No hay dos modelos con el mismo port (para motores locales)
- Todos los archivos GGUF referenciados existen en disco
- Todas las rutas de binarios de motores existen y son ejecutables
- Las variables de entorno para API keys remotas están definidas (o advertir si no)
- No hay condiciones en `use_when`/`avoid_when` con campos o operadores inválidos
- Los `cold_start_estimate_ms` son razonables (el wizard advierte si son menores de 1000ms
  para modelos de más de 7B, ya que probablemente sea incorrecto)
- El `max_context_tokens` de cada modelo no supera los límites conocidos del modelo
  (tabla de referencia incluida en el módulo de validación)
- Hay al menos un modelo con `enabled: true`

#### Comportamiento ante configuración inválida al arrancar ElPaso

Si `elpaso.conf` existe pero es inválido (editado manualmente con errores), ElPaso hace lo
siguiente al arrancar:

1. Intenta parsear el JSON. Si falla, imprime el error de parse con línea y columna,
   sugiere ejecutar `mix elpaso config validate` y termina.

2. Si el JSON es válido pero el schema no, lista todos los campos inválidos con descripción
   del problema y termina.

3. Si el schema es válido pero hay inconsistencias semánticas (puerto duplicado, archivo
   que no existe), lista las inconsistencias y pregunta si continuar en modo degradado
   (ignorando los modelos con problemas) o terminar.

El modo degradado es útil cuando tienes 3 modelos configurados, uno tiene el GGUF en un
disco desmontado y no quieres que todo ElPaso falle por eso. ElPaso arranca con los 2
modelos válidos y marca el tercero como `:disabled` con el motivo registrado en el lock file.

### Módulos necesarios para este bloque

#### `ElPaso.Config.Schema`

Módulo que define el schema completo de configuración usando un sistema de validación
estructurada. En Elixir, esto se implementa con patrones de validación sobre mapas o,
preferiblemente, con `NimbleOptions` para validación declarativa con mensajes de error
descriptivos. El schema es la fuente de verdad: cualquier cambio al formato de configuración
empieza aquí.

Interfaz pública:

```elixir
ElPaso.Config.Schema.validate(map()) :: {:ok, validated_config()} | {:error, [String.t()]}
ElPaso.Config.Schema.default(field_path :: [atom()]) :: term()
ElPaso.Config.Schema.document() :: String.t()  # genera documentación del schema
```

#### `ElPaso.Config.Loader`

Responsable de leer el archivo de configuración, parsearlo, validarlo contra el schema y
devolverlo en una estructura accesible. Gestiona también el backup automático y la detección
de cambios para la recarga en caliente.

```elixir
ElPaso.Config.Loader.load(path :: String.t()) :: {:ok, config()} | {:error, reason()}
ElPaso.Config.Loader.reload() :: {:ok, config()} | {:error, reason()}
ElPaso.Config.Loader.watch(pid()) :: :ok  # notifica al pid cuando el archivo cambia
```

#### `ElPaso.Config.Merger`

Gestiona la fusión de `engine.base_args` con `model.engine_args` para producir los argumentos
finales que se pasan al proceso del motor. Maneja conflictos, valores null y conversión de
tipos a string para la CLI.

```elixir
ElPaso.Config.Merger.merge_engine_args(base_args :: map(), model_args :: map()) :: [String.t()]
```

#### `ElPaso.Config.Wizard`

Implementa el flujo interactivo de configuración usando `Zaguan.UI.Components` para
la entrada del usuario y `Zaguan.Drawer.Components` para la salida visual. No usa
`IO.gets/1` directamente. Depende de `ElPaso.Config.Schema` para la validación y de
módulos de detección del entorno para las sugerencias automáticas.

Componentes Zaguan usados:

- `Zaguan.UI.Components.Input` — campos de texto con validación inline
- `Zaguan.UI.Components.Select` — menús de selección con flechas
- `Zaguan.UI.Components.Confirm` — confirmaciones S/N con default
- `Zaguan.Drawer.Components.Header` — cabeceras de sección
- `Zaguan.Drawer.Components.Table` — tablas de resumen de configuración
- `Zaguan.Drawer.Printer` — mensajes de éxito, error, info, warning

#### `ElPaso.Config.EnvironmentDetector`

Módulo auxiliar usado por el wizard para inspeccionar el entorno antes de hacer sugerencias:

```elixir
ElPaso.Config.EnvironmentDetector.detect_gpus() :: [%{name: String.t(), vram_mb: integer()}]
ElPaso.Config.EnvironmentDetector.detect_ram_mb() :: integer()
ElPaso.Config.EnvironmentDetector.detect_cpu_threads() :: integer()
ElPaso.Config.EnvironmentDetector.find_binary(name :: String.t()) :: {:ok, path()} | :not_found
ElPaso.Config.EnvironmentDetector.next_available_port(from :: integer()) :: integer()
```

#### `ElPaso.Config.ConditionEvaluator`

Evalúa las condiciones declaradas en `routing.conditions` de cada modelo contra el contexto
actual de un request. Es usado por el router en la Fase 3 del pipeline de decisión.

```elixir
ElPaso.Config.ConditionEvaluator.evaluate(conditions :: [condition()], context :: map())
  :: {:match, score_modifier :: float()} | :no_match
```

### Criterios de completitud para V1.0

- El schema completo está implementado en `ElPaso.Config.Schema` y cubre todos los campos
  definidos en este documento
- La validación rechaza configuraciones inválidas con mensajes descriptivos y localizados
  (indicando el campo exacto y el motivo del error)
- El wizard cubre los 8 pasos del flujo de creación y los tres modos (crear, editar, add-model)
- El `EnvironmentDetector` detecta GPUs, RAM, CPU threads y binarios disponibles
- La fusión de `base_args` y `model_args` es correcta en todos los casos de borde (conflictos,
  valores null, tipos no string)
- El `chat_template` es validado contra la lista de templates soportados y usado correctamente
  por cada engine al formatear el prompt
- Las condiciones en `routing.conditions` son evaluadas por el `ConditionEvaluator` en cada
  decisión del router
- El arranque en modo degradado funciona cuando hay modelos con configuración inválida
- El backup automático se crea antes de cada modificación del archivo via wizard
- `mix elpaso config validate` existe como comando independiente que valida sin modificar

---

## Resumen ejecutivo para el agente (V1.0)

Implementa los cuatro bloques de este prompt partiendo del proyecto Elixir vacío
entregado por V0. Todos los módulos se crean desde cero. Antes de implementar
cualquier módulo, verifica que los tipos compartidos de `ElPaso.Types` están
disponibles y las 4 migraciones de PostgreSQL están ejecutadas.

Produce un plan de implementación ordenado por bloque antes de escribir código.

No implementes el siguiente bloque hasta que el anterior pase sus criterios de
completitud. El orden recomendado es el que sigue la prioridad definida abajo.

La prioridad de implementación es la siguiente:

1. Config.Schema + Config.Loader + Config.Merger + Config.ConditionEvaluator
2. Config.EnvironmentDetector + Config.Wizard (flujo de creación completo)
3. ModelSupervisor + ModelManager + ModelWorker (árbol de supervisión completo)
4. Context.Storage con schemas Ecto + Context.TokenCounter
5. Context.PrefixManager + Context.Manager + Context.SummarizationWorker
6. Context.Builder con token budget awareness (Capas 1 y 2)
7. Engine.ChatTemplate + Engine.Dispatcher + engine adapters (LlamaServer, VLLM, OpenAI, Anthropic, Ollama)
8. Domain.OutputCache
9. ElPaso.HTTP (endpoints + streaming + formato de error)
10. Router (FeatureVector + scoring completo + feedback loop + interfaz pública)
11. ElPaso.Security (API key + rate limiting básico)
12. Telemetría completa (measurements + metadata de todos los eventos)

---

## Módulos adicionales obligatorios en V1.0

Estos módulos no tienen sección propia en el documento pero son necesarios.
Se implementan siguiendo las descripciones del bloque de Consideraciones.

### `ElPaso.Engine.ChatTemplate`

Módulo funcional (sin estado) que formatea la lista de mensajes al formato textual
que espera cada motor local. Los motores remotos (OpenAI, Anthropic) no necesitan
template de texto: usan el array de mensajes directamente.

```elixir
defmodule ElPaso.Engine.ChatTemplate do
  @doc """
  Formatea una lista de mensajes al string que espera el motor.
  Para openai y anthropic devuelve {:passthrough, messages} sin modificar.
  Para el resto devuelve {:formatted, string}.
  """
  def format(messages, system_prompt, template) do
    case template do
      :gemma      -> format_gemma(messages, system_prompt)
      :chatml     -> format_chatml(messages, system_prompt)
      :llama3     -> format_llama3(messages, system_prompt)
      :mistral    -> format_mistral(messages, system_prompt)
      :openai     -> {:passthrough, messages}
      :anthropic  -> {:passthrough, messages}
    end
  end

  defp format_gemma(messages, system_prompt) do
    # <start_of_turn>user\ncontenido<end_of_turn>\n<start_of_turn>model\ncontenido<end_of_turn>
    # El system_prompt va prepended al primer mensaje de usuario
    {:formatted, build_gemma_string(messages, system_prompt)}
  end

  defp format_chatml(messages, system_prompt) do
    # <|im_start|>system\n...<|im_end|>\n<|im_start|>user\n...<|im_end|>\n<|im_start|>assistant\n
    {:formatted, build_chatml_string(messages, system_prompt)}
  end

  defp format_llama3(messages, system_prompt) do
    # <|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n...<|eot_id|>
    # <|start_header_id|>user<|end_header_id|>\n\n...<|eot_id|>
    # <|start_header_id|>assistant<|end_header_id|>\n\n
    {:formatted, build_llama3_string(messages, system_prompt)}
  end

  defp format_mistral(messages, system_prompt) do
    # [INST] system + primer user [/INST] respuesta [INST] siguiente user [/INST]
    {:formatted, build_mistral_string(messages, system_prompt)}
  end
end
```

### `ElPaso.Engine.Dispatcher`

Punto de entrada único para ejecutar inferencia. Consulta la config para obtener
el engine del modelo y delega al adapter correspondiente.

```elixir
defmodule ElPaso.Engine.Dispatcher do
  @doc "Inferencia completa (sin streaming)"
  def infer(model_id, %BuiltPrompt{} = prompt, params) do
    with {:ok, model_config} <- Config.Loader.get_model(model_id),
         {:ok, engine_module} <- resolve_engine(model_config.engine),
         {:ok, engine_config} <- build_engine_config(model_config) do
      engine_module.infer(prompt, merge_params(model_config, params), engine_config)
    end
  end

  @doc "Inferencia con streaming; chunk_callback se llama por cada ElPaso.Engine.Chunk"
  def stream(model_id, %BuiltPrompt{} = prompt, params, chunk_callback) do
    with {:ok, model_config} <- Config.Loader.get_model(model_id),
         {:ok, engine_module} <- resolve_engine(model_config.engine),
         {:ok, engine_config} <- build_engine_config(model_config) do
      engine_module.stream(prompt, merge_params(model_config, params), engine_config, chunk_callback)
    end
  end

  defp resolve_engine("llama_server"), do: {:ok, ElPaso.Engine.LlamaServer}
  defp resolve_engine("vllm"),         do: {:ok, ElPaso.Engine.VLLM}
  defp resolve_engine("openai"),       do: {:ok, ElPaso.Engine.OpenAI}
  defp resolve_engine("anthropic"),    do: {:ok, ElPaso.Engine.Anthropic}
  defp resolve_engine("ollama"),       do: {:ok, ElPaso.Engine.Ollama}
  defp resolve_engine(other),
    do: ElPaso.Engine.Registry.lookup(other)   # plugins V2.0+
end
```

### `ElPaso.Engine.Ollama`

Ollama es API-compatible con OpenAI. El adapter es un wrapper mínimo:

```elixir
defmodule ElPaso.Engine.Ollama do
  @behaviour ElPaso.Engine

  # Ollama expone la API de OpenAI en localhost:11434
  # Simplemente delega a OpenAI con la base_url sobreescrita
  defdelegate infer(prompt, params, config),  to: ElPaso.Engine.OpenAI
  defdelegate stream(prompt, params, config, cb), to: ElPaso.Engine.OpenAI
  defdelegate prepare_prefix(prefix, config), to: ElPaso.Engine.OpenAI
  defdelegate format_messages(msgs, spec),    to: ElPaso.Engine.OpenAI

  def name, do: :ollama
  def type, do: :remote_api

  def health_check(config) do
    url = Map.get(config, :base_url, "http://localhost:11434") <> "/api/tags"
    case Finch.build(:get, url) |> Finch.request(ElPasoFinch) do
      {:ok, %{status: 200}} -> :ok
      _                     -> {:error, :ollama_unavailable}
    end
  end
end
```

El engine config para Ollama tiene `base_url: "http://localhost:11434/v1"` y
`api_key: nil`. El OpenAI adapter debe aceptar `api_key: nil` sin error.

### `ElPaso.Domain.OutputCache`

```elixir
defmodule ElPaso.Domain.OutputCache do
  use GenServer

  @default_ttl_s 300
  @default_max_entries 100

  # ETS tabla: {hash, response, inserted_at_monotonic}
  # Eviction: LRU cuando se supera max_entries

  def get(hash) do
    case :ets.lookup(:output_cache, hash) do
      [{^hash, response, inserted_at}] ->
        if expired?(inserted_at), do: :miss, else: {:hit, response}
      [] -> :miss
    end
  end

  def put(hash, response) do
    GenServer.cast(__MODULE__, {:put, hash, response})
  end

  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # TTL y eviction gestionados en handle_cast y handle_info(:cleanup)
end
```

### Schemas Ecto (en `lib/elpaso/context/schemas/`)

El agente debe crear un módulo por tabla. Ejemplo de `session.ex`:

```elixir
defmodule ElPaso.Context.Schemas.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "sessions" do
    field :context_mode, Ecto.Enum, values: [:transparent, :declarative],
          default: :transparent
    field :user_id, :string
    field :metadata, :map, default: %{}
    timestamps(type: :utc_datetime_usec, inserted_at: :created_at,
               updated_at: :last_active_at)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:context_mode, :user_id, :metadata])
    |> validate_inclusion(:context_mode, [:transparent, :declarative])
  end
end
```

El mismo patrón se aplica a `Message`, `ConversationSummary` y `RoutingDecision`.
La columna `embedding` de `Message` usa `field :embedding, Pgvector.Ecto.Vector`.

### `ElPaso.Context.SummarizationWorker`

```elixir
defmodule ElPaso.Context.SummarizationWorker do
  require Logger

  @doc """
  Genera un resumen incremental de forma asíncrona.
  Llamado por Context.Manager cuando la ventana supera el trigger del 80%.
  No bloquea: la llamada retorna inmediatamente y el resumen se guarda cuando termina.
  """
  def trigger_async(session_id, messages_to_compress, existing_summary, opts \\ []) do
    model_id = opts[:model_id] || resolve_summarizer_model()
    max_tokens = opts[:max_summary_tokens] || 512

    Task.start(fn ->
      do_summarize(session_id, messages_to_compress, existing_summary, model_id, max_tokens)
    end)
  end

  defp do_summarize(session_id, messages, existing_summary, model_id, max_tokens) do
    prompt_text = build_summarization_prompt(messages, existing_summary, max_tokens)

    # Marca la sesión como "summarization_in_progress" en ETS
    Context.Manager.set_summarization_flag(session_id, true)

    start = System.monotonic_time(:millisecond)
    result = Engine.Dispatcher.infer(model_id, %BuiltPrompt{
      messages: [%{role: "user", content: prompt_text}],
      system: nil,
      token_estimate: TokenCounter.estimate(prompt_text),
      budget_used: %{prefix: 0, summary: 0, semantic: 0, window: 0, current: TokenCounter.estimate(prompt_text)},
      model_id: model_id,
      session_id: session_id,
      built_at: DateTime.utc_now()
    }, %{max_tokens: max_tokens, temperature: 0.3})

    duration = System.monotonic_time(:millisecond) - start

    case result do
      {:ok, response} ->
        {:ok, summary} = Context.Storage.save_summary(session_id, response.content, [
          generated_by_model: model_id,
          token_estimate: TokenCounter.estimate(response.content)
        ])
        Context.Manager.on_summary_complete(session_id, summary)
        :telemetry.execute([:elpaso, :context, :compressed], %{
          messages_compressed: length(messages),
          original_tokens: messages |> Enum.map(& &1.token_estimate) |> Enum.sum(),
          summary_tokens: summary.token_estimate,
          compression_ratio: Float.round(summary.token_estimate / max(1, Enum.sum(Enum.map(messages, & &1.token_estimate))), 2),
          generation_duration_ms: duration
        }, %{session_id: session_id, summarizer_model_id: model_id, strategy: :eager})

      {:error, reason} ->
        Logger.warning("Summarization failed for session #{session_id}: #{reason}")
        Context.Manager.set_summarization_flag(session_id, false)
    end
  end
end
```

---

La V1.0 es completa cuando todos los bloques cumplen sus criterios de completitud y
existe un test de integración end-to-end que cubra el flujo completo desde un request
HTTP hasta la respuesta, pasando por routing, context building, inferencia y persistencia,
usando una configuración generada por el wizard.

═══════════════════════════════════════════════════════════════════════════════════
FIN PROMPT V1.0
═══════════════════════════════════════════════════════════════════════════════════

---

═══════════════════════════════════════════════════════════════════════════════════
PROMPT V1.1 — MADUREZ OPERACIONAL Y CONTEXTO SEMÁNTICO
Prerequisito: V1.0 completamente funcional con telemetría activa.
Objetivo: sesiones largas sin pérdida de coherencia, tokenización precisa,
overrides por request, y visibilidad directa del contexto.
Entregables que V1.0 ya tiene listos para este prompt:

- Columna `embedding vector(768)` en tabla `messages` (nullable, sin índice)
- Campo `context_spec.tokenizer` en el schema de config (valor: "estimate")
- Sección `embeddings` en el schema de config (campos presentes, `enabled: false`)
- `Config.Migrator` stub creado en V1.0
- Telemetría activa con todos los eventos definidos
  ═══════════════════════════════════════════════════════════════════════════════════

## V1.1 — Madurez operacional y contexto semántico

## Modelos para esta versión

| Fase                                              | Modelo     | Comando               | Por qué                                                  |
| ------------------------------------------------- | ---------- | --------------------- | -------------------------------------------------------- |
| EmbeddingClient, SemanticRetriever, pgvector      | `coder`    | `./llama.sh coder`    | Código técnico de vectores y SQL con pgvector            |
| Tokenizer backends (tiktoken port Python)         | `coder`    | `./llama.sh coder`    | Integración de Puerto Python                             |
| Session overrides, `SessionOverrides` struct      | `devstral` | `./llama.sh devstral` | Cambios en el pipeline HTTP y el router                  |
| Config.Migrator (migración 1.0 → 1.1)             | `devstral` | `./llama.sh devstral` | Razona sobre compatibilidad y transformaciones de config |
| `mix elpaso context show` (CLI output con Zaguan) | `devstral` | `./llama.sh devstral` | Diseño de la presentación CLI                            |

**Nota**: el paso de embeddings del wizard (añadido aquí) lo hace `devstral`.
El índice IVFFlat de pgvector no se crea automáticamente; hay que ejecutarlo
manualmente tras superar las 100 filas con embedding.

**Objetivo**: el sistema es robusto para uso diario continuo. Las sesiones largas no pierden
coherencia. El usuario tiene visibilidad directa sobre el estado del contexto.

**Dependencias**: V1.0 completamente funcional con telemetría activa.

---

### 1.1.1 Capa 3 del Portable Session Context (pgvector + embeddings)

Ya definida en V1.0 como opcional. En V1.1 se activa por defecto si pgvector está
disponible y hay un modelo de embeddings configurado.

#### Módulo `ElPaso.Context.EmbeddingClient`

Cliente que abstrae la generación de embeddings, independientemente del motor que los
produzca. llama-server expone el endpoint `/v1/embeddings` compatible con OpenAI.

```elixir
# Genera embedding para un texto dado usando el modelo configurado en embeddings.model_id
ElPaso.Context.EmbeddingClient.embed(text :: String.t())
  :: {:ok, [float()]} | {:error, :model_unavailable} | {:error, reason()}

# Genera embeddings para un lote de textos en una sola llamada
ElPaso.Context.EmbeddingClient.embed_batch(texts :: [String.t()])
  :: {:ok, [[float()]]} | {:error, reason()}

# Verifica que el modelo de embeddings está disponible y responde
ElPaso.Context.EmbeddingClient.ping()
  :: :ok | {:error, reason()}

# Devuelve la dimensión del vector del modelo de embeddings activo
ElPaso.Context.EmbeddingClient.dimensions()
  :: {:ok, non_neg_integer()} | {:error, :not_configured}
```

El cliente lee `embeddings.model_id` desde la config y llama al engine correspondiente
vía la interfaz interna de ElPaso (no directamente al motor). Esto permite que el modelo
de embeddings cambie de engine sin afectar al cliente.

#### Flujo de generación de embeddings (asíncrono)

La generación es asíncrona para no bloquear el response al usuario. El flujo exacto:

```
Context.Manager.append_turn/4 persiste el mensaje en PostgreSQL
  │
  └─ Task.start(fn ->
       case EmbeddingClient.embed(message.content) do
         {:ok, vector} →
           Context.Storage.save_embedding(message.id, vector)
           :telemetry.execute([:elpaso, :embedding, :generated], %{dim: length(vector)}, %{message_id: message.id})
         {:error, reason} →
           Logger.warning("Embedding failed for message #{message.id}: #{reason}")
           # No reintentos en V1.1; el mensaje queda sin embedding
           # mix elpaso embeddings rebuild lo regenerará después
       end
     end)
  │
  └─ La task no está supervisada (fire and forget)
     Si falla, el mensaje queda con embedding NULL en PostgreSQL
     El sistema funciona correctamente sin ese embedding
```

#### Módulo `ElPaso.Context.SemanticRetriever`

Encapsula la búsqueda semántica para que `Context.Manager.get_context_layers/2` no
acceda directamente a pgvector:

```elixir
# Busca los K mensajes archivados más similares semánticamente al query_text.
# Solo busca en mensajes archivados (archived_at IS NOT NULL) de la sesión.
ElPaso.Context.SemanticRetriever.search(session_id, query_text, k, min_similarity)
  :: {:ok, [message()]} | {:error, :pgvector_unavailable} | {:error, reason()}

# Busca usando un embedding ya calculado (evita recalcular si ya está disponible)
ElPaso.Context.SemanticRetriever.search_by_vector(session_id, vector, k, min_similarity)
  :: {:ok, [message()]} | {:error, reason()}
```

La búsqueda usa la métrica coseno (`<=>` en pgvector). El parámetro `min_similarity`
es un threshold de similitud coseno: mensajes con similitud menor se descartan aunque
sean los K más cercanos. Default: `0.75`.

#### Cambios en `Context.Manager.get_context_layers/2`

Cuando `session_defaults.semantic_retrieval: true`:

```elixir
def get_context_layers(session_id, context_spec) do
  with {:ok, state}   <- get_session_state(session_id),
       {:ok, summary} <- Storage.get_latest_summary(session_id),
       window         <- state.window,
       semantic       <- get_semantic_layer(session_id, window, context_spec) do
    {:ok, %{summary: summary?.content, window: window, semantic: semantic}}
  end
end

defp get_semantic_layer(session_id, window, context_spec) do
  if semantic_retrieval_enabled?() and pgvector_available?() do
    # Genera embedding del último mensaje del usuario en la ventana
    last_user_msg = window |> Enum.filter(&(&1.role == "user")) |> List.last()
    case last_user_msg do
      nil -> []
      msg ->
        k = config(:semantic_retrieval_k, 5)
        min_sim = config(:min_similarity_threshold, 0.75)
        # Calcula cuántos tokens podemos gastar en semántica según el budget
        semantic_budget = estimate_semantic_budget(context_spec, window, summary)
        case SemanticRetriever.search(session_id, msg.content, k, min_sim) do
          {:ok, results} -> truncate_to_budget(results, semantic_budget)
          {:error, _}    -> []  # fallo silencioso; la sesión funciona sin semántica
        end
    end
  else
    []
  end
end
```

#### Evento de telemetría nuevo

```elixir
[:elpaso, :embedding, :generated]
  measurements: %{duration_ms: integer(), dimensions: integer()}
  metadata: %{message_id: integer(), session_id: string, model_id: string}

[:elpaso, :embedding, :failed]
  measurements: %{duration_ms: integer()}
  metadata: %{message_id: integer(), session_id: string, reason: string}

[:elpaso, :semantic, :search]
  measurements: %{duration_ms: integer(), results_count: integer()}
  metadata: %{session_id: string, query_length_chars: integer(), k: integer()}
```

#### Comando `mix elpaso embeddings rebuild`

```bash
mix elpaso embeddings rebuild                    # reconstruye todos los embeddings faltantes
mix elpaso embeddings rebuild --session <id>     # solo una sesión
mix elpaso embeddings rebuild --since 7d         # mensajes de los últimos 7 días
mix elpaso embeddings rebuild --dry-run          # muestra cuántos reconstruiría sin hacerlo
```

Implementado en `ElPaso.CLI.Commands.Embeddings`. Lee mensajes con `embedding IS NULL`
de PostgreSQL y llama a `EmbeddingClient.embed_batch/1` en lotes de 50. Muestra
progreso. Si el modelo de embeddings no está disponible, falla con mensaje claro.

#### Comando `mix elpaso embeddings stats`

```
$ mix elpaso embeddings stats

EMBEDDING COVERAGE
════════════════════════════════════════
Total mensajes archivados:  1,247
Con embedding:              1,198  (96.1%)
Sin embedding:                 49  (3.9%)
  - Fallos de generación:      12
  - Anteriores a V1.1:         37

Índice IVFFlat: CONSTRUIDO (1,198 filas)
Modelo activo: nomic-embed (768 dims)
Última generación: hace 2 minutos
```

#### Cambios de config (sección nueva `embeddings`)

```json
"embeddings": {
  "enabled": true,
  "model_id": "nomic-embed",
  "dimensions": 768,
  "embedding_timeout_ms": 5000,
  "batch_size": 50,
  "semantic_retrieval_k": 5,
  "min_similarity_threshold": 0.75,
  "ivfflat_build_threshold": 100
}
```

El modelo de embeddings se añade a la sección `models` con rol especial:

```json
{
  "id": "nomic-embed",
  "label": "Nomic Embed Text v1.5",
  "enabled": true,
  "engine": "llama_server",
  "source": {
    "type": "local_file",
    "path": "~/modelos/nomic-embed-text-v1.5.Q8_0.gguf"
  },
  "engine_args": {
    "--port": 8082,
    "--ctx-size": 8192,
    "--n-gpu-layers": 0,
    "--embedding": true
  },
  "role": "embeddings"
}
```

El campo `role: "embeddings"` indica al ModelManager que este modelo no debe usarse
para inferencia de chat. El router lo excluye del pool de candidatos siempre.
El ModelManager lo gestiona igual que cualquier otro modelo local.

#### Cambios de schema PostgreSQL (migración V1.1)

```sql
-- La columna embedding ya existe de V1.0; solo se construye el índice cuando hay datos
-- Migration 002_v1_1_ivfflat_index.exs (se ejecuta manualmente tras V1.1 con datos)
CREATE INDEX CONCURRENTLY idx_messages_embedding_ivfflat
  ON messages USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100)
  WHERE embedding IS NOT NULL;

-- Añadir tabla para tracking de cobertura de embeddings
CREATE TABLE embedding_stats (
  session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  total_archived INTEGER NOT NULL DEFAULT 0,
  with_embedding INTEGER NOT NULL DEFAULT 0,
  last_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (session_id)
);
```

---

### 1.1.2 Tokenizadores reales para modelos locales

#### Módulo `ElPaso.Context.Tokenizer`

Reemplaza el rol de `TokenCounter.count/2` con backends reales. Coexiste con
`TokenCounter` (que sigue siendo la estimación rápida para el router).

```elixir
# Registra el tokenizador para un model_id. Llamado por ModelWorker al arrancar.
ElPaso.Context.Tokenizer.register(model_id :: String.t(), config :: tokenizer_config())
  :: :ok

# Cuenta tokens usando el tokenizador registrado para ese modelo.
# Si no hay tokenizador registrado, hace fallback a TokenCounter.estimate/1.
ElPaso.Context.Tokenizer.count(text :: String.t(), model_id :: String.t())
  :: {:ok, integer()} | {:fallback, integer()}

# Informa qué backend está usando un modelo
ElPaso.Context.Tokenizer.info(model_id :: String.t())
  :: %{backend: :tiktoken | :estimate, registered_at: DateTime.t() | nil}

# Lista todos los modelos y sus backends registrados
ElPaso.Context.Tokenizer.list()
  :: [%{model_id: String.t(), backend: atom()}]
```

La estructura `tokenizer_config()`:

```elixir
%TokenizerConfig{
  backend: :tiktoken | :estimate,
  model_name: String.t() | nil   # para tiktoken: "gpt-4", "cl100k_base", etc.
}
```

#### Registro del tokenizador en ModelWorker

```elixir
# Dentro de ModelWorker.handle_info(:model_started, state):
def register_tokenizer(model_config) do
  tokenizer_backend = get_in(model_config, [:context_spec, :tokenizer]) || "estimate"
  config = case tokenizer_backend do
    "tiktoken" ->
      %TokenizerConfig{backend: :tiktoken, model_name: model_config.id}
    _ ->
      %TokenizerConfig{backend: :estimate}
  end
  Tokenizer.register(model_config.id, config)
end
```

#### Backend tiktoken

Implementado como puerto Python (script que hace `import tiktoken`). El script vive
en `priv/python/tokenizer_server.py` y es iniciado como Port por `Tokenizer` al
registrar el primer modelo que lo necesita.

El protocolo del Port es líneas JSON: `{"text": "...", "model": "gpt-4"}` → `{"count": 42}`.

Si Python no está disponible, el backend cae a `:estimate` silenciosamente.

#### Cambios en `Context.Builder`

`Context.Builder.build/3` llama a `Tokenizer.count/2` en vez de `TokenCounter.count/2`
para el presupuesto de cada capa. El margen de seguridad baja del 15% al 5% cuando
el tokenizador devuelve `{:ok, n}` (conteo preciso).

---

### 1.1.3 Session overrides por request

#### Extracción de overrides en `ElPaso.HTTP`

El parser del body de `/v1/chat/completions` extrae el campo `elpaso` si existe:

```elixir
defmodule ElPaso.HTTP.RequestParser do
  def parse_chat_request(body) do
    with {:ok, params} <- Jason.decode(body),
         overrides     <- extract_elpaso_overrides(params) do
      {:ok, %ChatRequest{
        messages:    params["messages"],
        model:       params["model"] || "auto",
        stream:      params["stream"] || false,
        temperature: params["temperature"],
        max_tokens:  params["max_tokens"],
        session_id:  overrides.session_id || params["user"],
        overrides:   overrides
      }}
    end
  end

  defp extract_elpaso_overrides(params) do
    ep = params["elpaso"] || %{}
    %SessionOverrides{
      session_id:           ep["session_id"],
      context_mode:         ep["context_mode"],
      window_size:          ep["window_size"],
      force_model:          ep["force_model"],
      latency_tolerance_ms: ep["latency_tolerance_ms"],
      summarize_with_model: ep["summarize_with_model"]
    }
  end
end
```

#### Struct `SessionOverrides`

```elixir
%SessionOverrides{
  session_id: String.t() | nil,
  context_mode: :transparent | :declarative | nil,
  window_size: non_neg_integer() | nil,
  force_model: String.t() | nil,
  latency_tolerance_ms: non_neg_integer() | nil,
  summarize_with_model: String.t() | nil
}
```

#### Aplicación de overrides

Los overrides se aplican en capas:

- `session_id`: determina qué sesión usar (o crear)
- `context_mode` y `window_size`: actualizan el `SessionState` en ETS para esta sesión
- `force_model`: bypass completo del scoring del router; se pasa como override al pipeline
- `latency_tolerance_ms`: sobreescribe `session_defaults.latency_tolerance_ms` para esta llamada
- `summarize_with_model`: sobreescribe el modelo de resumen para el job eager si se dispara

`force_model` en el router:

```elixir
def route(request_id, session_id, user_message, overrides \\ %{}) do
  if overrides.force_model do
    model_id = overrides.force_model
    decision = %RoutingDecision{
      selected_model: model_id,
      reason: "force_model override by client",
      ...
    }
    {:ok, model_id, decision}
  else
    # pipeline normal de scoring
    ...
  end
end
```

---

### 1.1.4 Comando `mix elpaso context show`

Implementado en `ElPaso.CLI.Commands.Context` usando Zaguan para la salida:

```elixir
defmodule ElPaso.CLI.Commands.Context do
  alias Zaguan.Drawer.Components.{Header, Table, Message}

  def show(session_id, opts \\ []) do
    format = Keyword.get(opts, :format, :text)

    with {:ok, state}   <- Context.Manager.reload_session(session_id),
         {:ok, summary} <- Storage.get_latest_summary(session_id),
         window         <- state.window do

      if format == :json do
        Zaguan.Drawer.Components.Json.print(build_data(state, summary, window, session_id))
      else
        render_text(state, summary, window, session_id)
      end
    else
      {:error, reason} -> Message.print(:error, "Sesión no encontrada: #{reason}")
    end
  end

  defp render_text(state, summary, window, session_id) do
    Header.print("Sesión #{session_id}",
      subtitle: "Modo: #{state.context_mode} | Último modelo: #{state.last_model_id || "—"}")

    Table.print(
      headers: ["Capa", "Tokens", "Detalle"],
      rows: [
        ["Bloque canónico", to_string(prefix_tokens(session_id)), "estable"],
        ["Resumen",         to_string(summary?.token_estimate || 0),
                            "hasta msg ##{summary?.covers_until_message_id || "—"}, por #{summary?.generated_by_model || "—"}"],
        ["Semántica",       "—", semantic_status()],
        ["Ventana",         to_string(state.window_token_count),
                            "#{length(window)} mensajes"],
        ["TOTAL",           to_string(total_tokens(session_id, state, summary)), ""]
      ],
      headers_color: :cyan, table_border: :rounded
    )

    budget_rows = calculate_budget_per_model(state, summary)
    |> Enum.map(fn {model_id, available} -> [model_id, to_string(available)] end)

    Table.print(
      headers: ["Modelo", "Tokens libres"],
      rows: budget_rows, headers_color: :green, table_border: :rounded
    )
  end

  defp calculate_budget_per_model(state, summary) do
    Config.Loader.get().models
    |> Enum.map(fn model ->
      spec = model.context_spec
      usable = spec.max_context_tokens - spec.reserved_output_tokens
      prefix_tokens = PrefixManager.get(state.session_id) |> elem(1) |> Map.get(:token_estimate, 0)
      available = usable - prefix_tokens - (summary?.token_estimate || 0) - state.window_token_count
      {model.id, max(0, available)}
    end)
  end
end
```

---

### 1.1.5 Migrador de schema de config

#### Módulo `ElPaso.Config.Migrator`

```elixir
defmodule ElPaso.Config.Migrator do
  @migrations %{
    {"1.0", "1.1"} => &migrate_1_0_to_1_1/1
  }

  def migrate(config, from_version, to_version) do
    path = find_migration_path(from_version, to_version)
    Enum.reduce_while(path, {:ok, config}, fn {from, to}, {:ok, acc} ->
      case apply_migration(acc, from, to) do
        {:ok, migrated} -> {:cont, {:ok, migrated}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  def can_migrate?(from, to), do: find_migration_path(from, to) != []

  defp migrate_1_0_to_1_1(config) do
    config
    |> put_in(["meta", "version"], "1.1")
    |> put_in(["embeddings"], default_embeddings_config())
    |> update_in(["models"], fn models ->
      Enum.map(models, fn model ->
        model
        |> put_in_if_missing(["context_spec", "tokenizer"], "estimate")
        |> put_in_if_missing(["context_spec", "supports_vision"], false)
      end)
    end)
  end

  defp default_embeddings_config do
    %{
      "enabled" => false,
      "model_id" => nil,
      "dimensions" => 768,
      "embedding_timeout_ms" => 5000,
      "batch_size" => 50,
      "semantic_retrieval_k" => 5,
      "min_similarity_threshold" => 0.75,
      "ivfflat_build_threshold" => 100
    }
  end
end
```

El comando `mix elpaso config migrate`:

```
$ mix elpaso config migrate

Configuración actual: v1.0 → Objetivo: v1.1
Cambios que se aplicarán:
  + embeddings: {enabled: false, model_id: null, ...}  (sección nueva)
  + models[*].context_spec.tokenizer: "estimate"       (campo nuevo en cada modelo)
  + models[*].context_spec.supports_vision: false      (campo nuevo en cada modelo)

Backup guardado en: ~/.config/elpaso/elpaso.conf.bak.1.0

¿Aplicar migración? [S/n]: S
✓ Migración completada. Versión actualizada a 1.1.
  Activa la Capa 3 añadiendo un modelo de embeddings y poniendo embeddings.enabled: true
```

---

### Criterios de completitud V1.1

- `EmbeddingClient.embed/1` genera vectores correctamente via llama-server `/v1/embeddings`
- La generación es asíncrona y no bloquea el response al usuario
- Mensajes con embedding NULL no causan errores en `get_context_layers/2`
- `SemanticRetriever.search/4` devuelve resultados ordenados por similitud coseno
- `mix elpaso embeddings rebuild` procesa mensajes sin embedding en lotes
- `mix elpaso embeddings stats` muestra cobertura y estado del índice
- El modelo de embeddings con `role: "embeddings"` es excluido del router
- `Tokenizer.register/2` es llamado por ModelWorker al arrancar el modelo
- `Tokenizer.count/2` usa tiktoken para modelos OpenAI y estimate para el resto
- Session overrides se extraen del campo `elpaso` del body y aplican correctamente
- `force_model` bypasea el scoring del router y usa el modelo indicado
- `mix elpaso context show` muestra las tres capas con tokens y budget disponible
- `Config.Migrator.migrate/3` migra de V1.0 a V1.1 sin pérdida de datos
- `mix elpaso config migrate` ejecuta la migración con backup automático

═══════════════════════════════════════════════════════════════════════════════════
FIN PROMPT V1.1
═══════════════════════════════════════════════════════════════════════════════════

---

═══════════════════════════════════════════════════════════════════════════════════
PROMPT V1.2 — DIAGNÓSTICO Y AJUSTE FINO
Prerequisito: V1.1 completo (embeddings activos, tokenizadores, session overrides).
Objetivo: el usuario puede entender qué hace el router, detectar problemas
y ajustar el comportamiento con datos reales sin tocar código.
Entregables que V1.1 ya tiene listos para este prompt:

- Tabla `routing_decisions` con datos acumulados (al menos 24h de uso)
- `RouterTuner` stub creado en V1.1 con `analyze/1` básico
- `Config.Diff` stub creado en V1.1
  ═══════════════════════════════════════════════════════════════════════════════════

## V1.2 — Comandos de diagnóstico y ajuste fino

## Modelos para esta versión

| Fase                                              | Modelo     | Comando               | Por qué                                       |
| ------------------------------------------------- | ---------- | --------------------- | --------------------------------------------- |
| RouterStats (queries SQL, agregaciones)           | `coder`    | `./llama.sh coder`    | Queries complejas sobre routing_decisions     |
| RouterTuner (algoritmo de sugerencias, confianza) | `Thinker`  | `./llama.sh Thinker`  | Razonamiento estadístico sobre las fórmulas   |
| `mix elpaso bench` (runner de prompts)            | `coder`    | `./llama.sh coder`    | Lógica de ejecución y métricas                |
| Config.Diff (clasificación de impacto por path)   | `devstral` | `./llama.sh devstral` | Razona sobre qué cambios requieren qué acción |
| Exportación de sesión (markdown + JSON)           | `coder`    | `./llama.sh coder`    | Renderizado de formatos de salida             |

**Nota**: RouterTuner con `Thinker` porque la fórmula de confianza y la regresión
hacia la afinidad sugerida requieren razonamiento matemático, no solo código.

**Objetivo**: el usuario puede entender qué está haciendo el sistema, detectar problemas
de routing, y ajustar el comportamiento con datos reales.

**Dependencias**: V1.1.

---

### 1.2.1 `mix elpaso router stats`

#### Módulo `ElPaso.Domain.RouterStats`

```elixir
defmodule ElPaso.Domain.RouterStats do
  @doc """
  Agrega estadísticas de routing desde la tabla routing_decisions.
  since: :last_hour | :last_24h | :last_7d | {:since, DateTime.t()}
  """
  def aggregate(since \\ :last_24h) do
    since_dt = resolve_since(since)

    decisions = Storage.query_routing_decisions(since: since_dt)

    %RouterStatsReport{
      period: since,
      total_decisions: length(decisions),
      fallback_count: Enum.count(decisions, &(&1.selected_model != &1.runner_up and fallback?(&1))),
      fallback_rate_pct: calculate_fallback_rate(decisions),
      by_task_type: aggregate_by_task_type(decisions),
      by_model: aggregate_by_model(decisions),
      cold_starts: Enum.count(decisions, &cold_start?(&1)),
      error_count: Enum.count(decisions, &(&1.outcome == "error")),
      generated_at: DateTime.utc_now()
    }
  end

  defp aggregate_by_task_type(decisions) do
    decisions
    |> Enum.group_by(&String.to_atom(&1.task_type))
    |> Map.new(fn {type, group} ->
      models = Enum.group_by(group, & &1.selected_model)
      total = length(group)
      {type, %{
        total: total,
        by_model: Map.new(models, fn {m, ds} ->
          latencies = Enum.filter_map(ds, & &1.latency_ms, & &1.latency_ms)
          {m, %{
            count: length(ds),
            pct: Float.round(length(ds) / total * 100, 1),
            avg_latency_ms: safe_avg(latencies),
            p95_latency_ms: safe_p95(latencies)
          }}
        end)
      }}
    end)
  end
end
```

Struct `RouterStatsReport`:

```elixir
%RouterStatsReport{
  period: atom() | tuple(),
  total_decisions: integer(),
  fallback_count: integer(),
  fallback_rate_pct: float(),
  by_task_type: %{atom() => %{total: integer(), by_model: map()}},
  by_model: %{String.t() => %{
    total_calls: integer(),
    success_rate_pct: float(),
    avg_latency_ms: integer(),
    p95_latency_ms: integer(),
    error_count: integer()
  }},
  cold_starts: integer(),
  error_count: integer(),
  generated_at: DateTime.t()
}
```

Implementado en `ElPaso.CLI.Commands.RouterStats` usando Zaguan para el output:

```elixir
defmodule ElPaso.CLI.Commands.RouterStats do
  alias Zaguan.Drawer.Components.{Header, Table, Message}

  def run(opts) do
    since = opts[:since] || :last_24h
    report = ElPaso.Domain.RouterStats.aggregate(since)

    Header.print("Routing Stats", subtitle: "#{period_label(since)}")

    # Tabla resumen global
    Table.print(
      headers: ["Métrica", "Valor"],
      rows: [
        ["Total decisiones",  to_string(report.total_decisions)],
        ["Fallbacks",         "#{report.fallback_count} (#{report.fallback_rate_pct}%)"],
        ["Cold starts",       to_string(report.cold_starts)],
        ["Errores",           to_string(report.error_count)]
      ],
      headers_color: :cyan, table_border: :rounded
    )

    # Tabla por modelo
    model_rows = report.by_model |> Enum.map(fn {model, s} ->
      [model, to_string(s.total_calls), "#{s.avg_latency_ms}ms",
       "#{s.p95_latency_ms}ms", to_string(s.error_count)]
    end)
    Table.print(
      headers: ["Modelo", "Calls", "Avg", "p95", "Errores"],
      rows: model_rows, headers_color: :yellow, table_border: :rounded
    )

    if opts[:format] == "json" do
      Zaguan.Drawer.Components.Json.print(report)
    end
  end
end
```

Opciones:

```bash
mix elpaso router stats
mix elpaso router stats --since 7d
mix elpaso router stats --since 1h
mix elpaso router stats --model heavy
mix elpaso router stats --task-type code
mix elpaso router stats --format json
```

Query SQL subyacente:

```sql
SELECT * FROM routing_decisions
WHERE decided_at >= $1
  AND ($2::text IS NULL OR selected_model = $2)
  AND ($3::text IS NULL OR task_type = $3)
ORDER BY decided_at DESC;
```

---

### 1.2.2 `mix elpaso router tune`

#### Módulo `ElPaso.Domain.RouterTuner`

```elixir
defmodule ElPaso.Domain.RouterTuner do
  @min_decisions_for_suggestion 20
  @min_confidence 0.6
  @min_affinity_delta 0.05

  @doc """
  Analiza routing_decisions y genera sugerencias de ajuste de afinidades.
  Solo genera sugerencias cuando hay datos suficientes y la mejora potencial es significativa.
  """
  def analyze(since \\ :last_24h) do
    decisions = Storage.query_routing_decisions(since: resolve_since(since), with_outcome: true)

    all_combinations =
      decisions
      |> Enum.group_by(fn d -> {d.selected_model, String.to_atom(d.task_type)} end)
      |> Enum.flat_map(fn {{model_id, task_type}, group} ->
          analyze_combination(model_id, task_type, group)
        end)
      |> Enum.filter(& &1 != nil)
      |> Enum.sort_by(& -&1.confidence)

    all_combinations
  end

  defp analyze_combination(model_id, task_type, decisions) do
    n = length(decisions)
    return nil if n < @min_decisions_for_suggestion

    success_rate = Enum.count(decisions, &(&1.outcome == "success")) / n
    avg_latency = safe_avg(Enum.map(decisions, & &1.latency_ms))
    current_affinity = Config.get_affinity(model_id, task_type)

    suggested = calculate_suggested_affinity(success_rate, avg_latency, current_affinity)
    delta = abs(suggested - current_affinity)
    confidence = calculate_confidence(n, success_rate)

    return nil if delta < @min_affinity_delta or confidence < @min_confidence

    %AffinitySuggestion{
      model_id: model_id,
      task_type: task_type,
      current_affinity: current_affinity,
      suggested_affinity: Float.round(suggested, 2),
      delta: Float.round(delta, 2),
      confidence: Float.round(confidence, 2),
      based_on_n_decisions: n,
      reason: build_reason(success_rate, avg_latency, n, delta)
    }
  end

  # La afinidad sugerida se basa en éxito y latencia normalizada contra el mejor modelo
  defp calculate_suggested_affinity(success_rate, avg_latency, current) do
    latency_score = normalize_latency_score(avg_latency)
    performance_score = success_rate * 0.7 + latency_score * 0.3
    # Movemos la afinidad hacia el performance_score, pero con inercia
    current * 0.4 + performance_score * 0.6
  end

  defp calculate_confidence(n, success_rate) do
    # Confianza sube con N y baja cuando la tasa de éxito es muy alta o muy baja
    # (extremos son poco informativos)
    n_factor = min(1.0, n / 100)
    variance_factor = 4 * success_rate * (1 - success_rate)  # max en 0.5
    n_factor * 0.6 + variance_factor * 0.4
  end
end
```

Struct `AffinitySuggestion`:

```elixir
%AffinitySuggestion{
  model_id: String.t(),
  task_type: atom(),
  current_affinity: float(),
  suggested_affinity: float(),
  delta: float(),
  confidence: float(),      # 0.0-1.0
  based_on_n_decisions: integer(),
  reason: String.t()
}
```

Flujo del wizard `mix elpaso router tune`:

```
$ mix elpaso router tune --since 7d

Analizando 1,247 decisiones de los últimos 7 días...

SUGERENCIAS DE AJUSTE (confianza > 60%, delta > 0.05):

1. heavy → code: 0.95 → 0.82 (confianza: 78%, n=143)
   Razón: Alta latencia media (4.8s) en tareas de código. fast tiene mejor ratio latencia/éxito.

2. fast → reasoning: 0.40 → 0.28 (confianza: 71%, n=67)
   Razón: Tasa de éxito 61% en razonamiento. Demasiados fallbacks al heavy después.

[S]iguiente  [A]plicar  [R]echazar  [Q]salir > A

✓ Aplicado: heavy.task_affinity.code: 0.95 → 0.82 (recarga en caliente)
```

---

### 1.2.3 `mix elpaso bench`

#### Módulo `ElPaso.CLI.Commands.Bench`

```elixir
defmodule ElPaso.CLI.Commands.Bench do
  alias Zaguan.Drawer.Components.{Header, Table, Bar, Message}

  @default_prompts %{
    question_answer: "¿Qué es la programación funcional y en qué se diferencia de la imperativa?",
    code: "Escribe una función en Elixir que calcule el número de Fibonacci usando recursión con memoización.",
    reasoning: "Analiza las ventajas y desventajas de usar microservicios frente a una arquitectura monolítica para una startup con 3 desarrolladores.",
    summarization: "Resume en 3 puntos clave el concepto de programación reactiva.",
    creative: "Escribe un párrafo introductorio para un artículo técnico sobre Elixir.",
    translation: "Traduce al inglés: 'El procesamiento concurrente es una ventaja clave de Erlang/OTP'.",
    unknown: "Hola, ¿cómo estás?"
  }

  def run(opts) do
    model_id = opts[:model]
    n = opts[:requests] || 7
    prompts = load_prompts(opts[:prompts_dir])

    Header.print("Benchmark ElPaso", subtitle: "#{model_id || "auto"} — #{n} requests")

    results = Enum.map(1..n, fn i ->
      {task_type, prompt} = select_prompt(prompts, i, n)
      Bar.print(i - 1, n, label: "#{i}/#{n} (#{task_type})", width: 40)

      start = System.monotonic_time(:millisecond)
      result = ElPaso.HTTP.InternalClient.chat(prompt,
        model: model_id,
        session_id: "bench-#{System.unique_integer()}",
        stream: false
      )
      latency = System.monotonic_time(:millisecond) - start
      ttft = result[:ttft_ms] || 0
      cache_hit = result[:elpaso][:context_layers_used] |> List.first() == "prefix+cache_hit"

      status = if result[:ok], do: :success, else: :error
      Message.print(status, "#{task_type}: #{latency}ms #{if cache_hit, do: "[cache hit]", else: ""}")
      %{task_type: task_type, latency_ms: latency, ttft_ms: ttft, cache_hit: cache_hit, ok: result[:ok]}
    end)

    print_summary(results)
  end

  defp print_summary(results) do
    latencies = Enum.map(results, & &1.latency_ms)
    ttfts = Enum.map(results, & &1.ttft_ms)
    cache_hits = Enum.count(results, & &1.cache_hit)
    errors = Enum.count(results, &(not &1.ok))

    Table.print(
      headers: ["Métrica", "Media", "p95"],
      rows: [
        ["TTFT",            "#{safe_avg(ttfts)}ms",     "#{safe_p95(ttfts)}ms"],
        ["Latencia total",  "#{safe_avg(latencies)}ms", "#{safe_p95(latencies)}ms"],
        ["Cache hits",      "#{cache_hits}/#{length(results)} (#{round(cache_hits/length(results)*100)}%)", "-"],
        ["Errores",         to_string(errors), "-"]
      ],
      headers_color: :cyan, table_border: :rounded
    )
  end
end
```

Los ficheros de prompt en `~/.config/elpaso/bench/` son texto plano, uno por task_type:
`code.txt`, `reasoning.txt`, etc. Si no existen, se usan los defaults embebidos.

---

### 1.2.4 Diff visual en `mix elpaso config reload`

#### Módulo `ElPaso.Config.Diff`

```elixir
defmodule ElPaso.Config.Diff do
  @doc """
  Compara dos configuraciones y devuelve una lista de cambios con su tipo de impacto.
  """
  def diff(old_config, new_config) do
    flat_old = flatten(old_config)
    flat_new = flatten(new_config)

    added   = Map.keys(flat_new) -- Map.keys(flat_old)
    removed = Map.keys(flat_old) -- Map.keys(flat_new)
    changed = for k <- Map.keys(flat_old) -- removed,
                  Map.get(flat_old, k) != Map.get(flat_new, k), do: k

    (Enum.map(added,   fn k -> {k, :added,   nil,                flat_new[k]} end) ++
     Enum.map(removed, fn k -> {k, :removed, flat_old[k],        nil} end) ++
     Enum.map(changed, fn k -> {k, :changed, flat_old[k],        flat_new[k]} end))
    |> Enum.map(fn {path, type, old, new} ->
      %ConfigChange{
        path: path,
        type: type,
        old_value: old,
        new_value: new,
        impact: classify_impact(path)
      }
    end)
    |> Enum.sort_by(& impact_order(&1.impact))
  end

  defp classify_impact(path) do
    cond do
      path =~ ~r/^models\[\d+\]\.engine_args/ -> :requires_model_restart
      path =~ ~r/^models\[\d+\]\.context_spec/ -> :requires_model_restart
      path =~ ~r/^engines\./ -> :requires_model_restart
      path =~ ~r/^system\.db_url|^system\.http_port/ -> :requires_full_restart
      path =~ ~r/^models\./ -> :hot_reload
      path =~ ~r/^routing\.|^session_defaults\.|^canonical_prefix\./ -> :hot_reload
      true -> :hot_reload
    end
  end
end
```

---

### 1.2.5 Exportación de sesión

```elixir
defmodule ElPaso.CLI.Commands.Context do
  def export(session_id, opts) do
    format = opts[:format] || :markdown
    include_metadata = opts[:include_metadata] || false

    with {:ok, session}  <- Storage.get_session(session_id),
         {:ok, messages} <- Storage.get_all_messages(session_id),
         {:ok, summary}  <- Storage.get_latest_summary(session_id) do
      case format do
        :markdown -> render_markdown(session, messages, summary, include_metadata)
        :json     -> render_json(session, messages, summary, include_metadata)
      end
    end
  end

  defp render_markdown(session, messages, summary, include_metadata) do
    header = if include_metadata do
      """
      # Sesión #{session.id}
      Creada: #{session.created_at} | Última actividad: #{session.last_active_at}

      """
    else
      "# Conversación exportada\n\n"
    end

    summary_block = if summary do
      "## Resumen del historial\n#{summary.content}\n\n---\n\n"
    else
      ""
    end

    messages_text = messages
    |> Enum.map(fn msg ->
      role = String.capitalize(msg.role)
      "**#{role}**: #{msg.content}\n"
    end)
    |> Enum.join("\n")

    header <> summary_block <> messages_text
  end
end
```

---

### Criterios de completitud V1.2

- `RouterStats.aggregate/1` lee correctamente de `routing_decisions` y agrupa por task_type y modelo
- `mix elpaso router stats` formatea la tabla con porcentajes, latencias y cold starts
- `RouterTuner.analyze/1` genera sugerencias con confianza y no sugiere cambios menores de 0.05
- `mix elpaso router tune` aplica cambios aprobados como recarga en caliente
- `mix elpaso bench` ejecuta prompts por task_type y reporta TTFT, latencia total y cache hits
- Los prompts de bench son configurables en `~/.config/elpaso/bench/`
- `Config.Diff.diff/2` clasifica cambios por impacto (hot_reload/model_restart/full_restart)
- `mix elpaso config reload` muestra diff antes de aplicar y pide confirmación
- `mix elpaso context export` genera markdown y JSON con historial completo incluyendo archivados

═══════════════════════════════════════════════════════════════════════════════════
FIN PROMPT V1.2
═══════════════════════════════════════════════════════════════════════════════════

---

═══════════════════════════════════════════════════════════════════════════════════
PROMPT V1.3 — OBSERVABILIDAD Y MULTI-USUARIO BÁSICO
Prerequisito: V1.2 completo (stats, bench, tune, config diff operativos).
Objetivo: ElPaso es observable desde herramientas estándar y puede usarse
en red local compartida por varios usuarios de forma segura.
Entregables que V1.2 ya tiene listos para este prompt:

- `Telemetry.Store` stub presente (recibe eventos pero no los sirve al dashboard aún)
- Campo `user_id` en tabla `sessions` (nullable, añadido en migración de V1.2)
- `ElPaso.Security.Auth` stub con función `authenticate/1` básica
  ═══════════════════════════════════════════════════════════════════════════════════

## V1.3 — Observabilidad y seguridad multi-usuario básica

## Modelos para esta versión

| Fase                                                | Modelo     | Comando               | Por qué                                                        |
| --------------------------------------------------- | ---------- | --------------------- | -------------------------------------------------------------- |
| Dashboard HTML+JS (Telemetry.Store, HTTP.Dashboard) | `gemma`    | `./llama.sh gemma`    | Generación de HTML/JS, diseño visual de la interfaz            |
| Prometheus metrics (PrometheusExporter)             | `coder`    | `./llama.sh coder`    | Código declarativo de métricas con telemetry_metrics           |
| Auth system (Auth, AuthPlug, RateLimiter)           | `devstral` | `./llama.sh devstral` | Seguridad, aislamiento de sesiones, decisiones arquitectónicas |
| WebSocket handler (cowboy_websocket)                | `coder`    | `./llama.sh coder`    | Implementación protocolo WebSocket                             |
| Migración `user_id` en sessions                     | `coder`    | `./llama.sh coder`    | Migración Ecto simple                                          |

**Nota importante para el dashboard**: usa `gemma` con contexto largo (128k).
El HTML del dashboard es un string embebido en el módulo Elixir. Genera primero
el HTML/JS standalone, luego `devstral` lo integra en `ElPaso.HTTP.Dashboard`.

**Objetivo**: ElPaso puede usarse en red local compartida y los datos son observables
desde herramientas estándar como Grafana o Prometheus.

**Dependencias**: V1.2.

---

### 1.3.1 Dashboard web local

#### Módulo `ElPaso.HTTP.Dashboard`

Plug que sirve el dashboard como HTML estático + JavaScript vanilla. No requiere
dependencias frontend externas.

```elixir
defmodule ElPaso.HTTP.Dashboard do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/" do
    html = dashboard_html()
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  get "/api/state" do
    state = %{
      models: ModelManager.all_states() |> Enum.map(&serialize_model_state/1),
      sessions: %{
        active: Context.Manager.active_session_count(),
        tokens_24h: Storage.tokens_consumed_last_24h()
      },
      router: %{
        decisions_1h: RouterStats.aggregate(:last_hour).total_decisions,
        fallback_rate: RouterStats.aggregate(:last_hour).fallback_rate_pct
      },
      prefix_cache: %{
        hit_ratio: Telemetry.Store.prefix_cache_hit_ratio()
      },
      recent_events: Telemetry.Store.recent_events(10)
    }
    json_response(conn, state)
  end
end
```

El `Telemetry.Store` es un GenServer nuevo que suscribe a los eventos `:telemetry` y
guarda un buffer en ETS para consultas del dashboard:

```elixir
defmodule ElPaso.Telemetry.Store do
  use GenServer

  # Al arrancar, se suscribe a todos los eventos de ElPaso
  def init(_) do
    :telemetry.attach_many("elpaso-store", [
      [:elpaso, :prefix, :hit],
      [:elpaso, :prefix, :miss],
      [:elpaso, :inference, :complete],
      [:elpaso, :inference, :error],
      [:elpaso, :model, :cold_start],
      [:elpaso, :router, :fallback]
    ], &handle_event/4, nil)
    {:ok, %{events: :queue.new(), prefix_hits: 0, prefix_misses: 0}}
  end

  def recent_events(n), do: GenServer.call(__MODULE__, {:recent, n})
  def prefix_cache_hit_ratio(), do: GenServer.call(__MODULE__, :hit_ratio)

  def handle_event(event_name, measurements, metadata, _) do
    GenServer.cast(__MODULE__, {:record, event_name, measurements, metadata})
  end
end
```

El HTML del dashboard es un string embebido en el módulo que incluye JavaScript inline.
El JS hace `fetch("/dashboard/api/state")` cada 5 segundos y actualiza el DOM.
No se necesita WebSocket para el dashboard (el polling es suficiente para uso local).

---

### 1.3.2 Exportación Prometheus

#### Módulo `ElPaso.Telemetry.PrometheusExporter`

Usa `telemetry_metrics_prometheus` con métricas declaradas:

```elixir
defmodule ElPaso.Telemetry.PrometheusExporter do
  def metrics do
    [
      counter("elpaso.inference.complete.total",
        tags: [:model_id, :task_type],
        description: "Total de inferencias completadas"
      ),
      distribution("elpaso.inference.complete.latency_ms",
        event_name: [:elpaso, :inference, :complete],
        measurement: :latency_ms,
        tags: [:model_id],
        buckets: [100, 500, 1000, 2000, 5000, 10000],
        description: "Latencia de inferencia en ms"
      ),
      last_value("elpaso.model.status",
        event_name: [:elpaso, :model, :health_check],
        measurement: fn measurements, metadata ->
          case metadata.status do
            :hot -> 1
            :warming -> 0.5
            _ -> 0
          end
        end,
        tags: [:model_id],
        description: "Estado del modelo (1=hot, 0.5=warming, 0=cold/error)"
      ),
      counter("elpaso.router.fallback.total",
        tags: [:reason],
        description: "Total de fallbacks del router"
      ),
      last_value("elpaso.prefix.cache_hit_ratio",
        event_name: [:elpaso, :prefix, :hit_ratio_updated],
        measurement: :ratio,
        description: "Ratio actual de cache hit del prefijo"
      ),
      distribution("elpaso.model.cold_start.startup_duration_ms",
        event_name: [:elpaso, :model, :cold_start],
        measurement: :startup_duration_ms,
        tags: [:model_id],
        buckets: [1000, 5000, 10000, 30000, 60000],
        description: "Duración de arranque desde frío"
      )
    ]
  end
end
```

Montado en `GET /metrics` con `PromEx` o directamente con el módulo de Prometheus.

---

### 1.3.3 Usuarios y API keys múltiples

#### Módulo `ElPaso.Security.Auth`

```elixir
defmodule ElPaso.Security.Auth do
  @doc """
  Autentica un request por su API key. Devuelve el user_id si es válido.
  """
  def authenticate(api_key) do
    auth_config = Config.Loader.get().auth
    cond do
      not auth_config.enabled ->
        {:ok, "anonymous"}
      api_key == nil and auth_config.allow_anonymous ->
        {:ok, "anonymous"}
      api_key == nil ->
        {:error, :missing_api_key}
      true ->
        case find_user_by_key(auth_config.users, api_key) do
          nil  -> {:error, :invalid_api_key}
          user -> {:ok, user.id}
        end
    end
  end

  defp find_user_by_key(users, api_key) do
    Enum.find(users, fn u -> u.api_key == api_key end)
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
end
```

#### Plug `ElPaso.HTTP.AuthPlug`

```elixir
defmodule ElPaso.HTTP.AuthPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    api_key = ElPaso.Security.Auth.extract_api_key(conn)
    case ElPaso.Security.Auth.authenticate(api_key) do
      {:ok, user_id} ->
        conn |> assign(:current_user_id, user_id)
      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{
            error: %{
              message: auth_error_message(reason),
              type: "authentication_error",
              code: "elpaso_401"
            }
          }))
        |> halt()
    end
  end
end
```

#### Aislamiento de sesiones por usuario

Cuando el sistema tiene `auth.enabled: true`, el `session_id` se construye como:
`"#{user_id}-#{uuid}"`. La consulta a `Context.Storage.get_window/2` filtra por
`session_id LIKE '#{user_id}-%'` para garantizar que un usuario no accede a sesiones
de otro. El campo `user_id` en la tabla `sessions` se usa para índices eficientes.

#### Rate limiting por usuario

```elixir
defmodule ElPaso.Security.RateLimiter do
  # Token bucket por user_id en ETS
  # Tabla ETS: {user_id, tokens_available, last_refill_at}

  def check_rate(user_id, max_rpm) do
    now = System.monotonic_time(:second)
    key = {__MODULE__, user_id}

    case :ets.lookup(:rate_limiter, key) do
      [] ->
        :ets.insert(:rate_limiter, {key, max_rpm - 1, now})
        :ok
      [{^key, tokens, last_refill}] ->
        elapsed_minutes = (now - last_refill) / 60
        refilled = min(max_rpm, tokens + elapsed_minutes * max_rpm)

        if refilled >= 1 do
          :ets.insert(:rate_limiter, {key, refilled - 1, now})
          :ok
        else
          {:error, :rate_limited}
        end
    end
  end
end
```

---

### 1.3.4 WebSocket para chat

#### Módulo `ElPaso.HTTP.WebSocketHandler`

```elixir
defmodule ElPaso.HTTP.WebSocketHandler do
  @behaviour :cowboy_websocket

  def init(req, state) do
    session_id = :cowboy_req.parse_qs(req)["session_id"]
    user_id = authenticate_ws(req)
    {:cowboy_websocket, req, %{session_id: session_id, user_id: user_id}}
  end

  def websocket_init(state) do
    {:ok, session_id, _} = Context.Manager.get_or_create_session(state.session_id)
    {:ok, %{state | session_id: session_id}}
  end

  def websocket_handle({:text, json}, state) do
    case Jason.decode(json) do
      {:ok, %{"messages" => messages} = params} ->
        handle_chat_request(params, state)
      _ ->
        error = Jason.encode!(%{error: %{message: "Invalid JSON", type: "parse_error"}})
        {:reply, {:text, error}, state}
    end
  end

  defp handle_chat_request(params, state) do
    # El streaming se envía como frames WebSocket individuales
    # Mismo pipeline que HTTP pero los chunks se envían via websocket_handle
    Task.start(fn ->
      stream_callback = fn chunk ->
        send(self(), {:ws_chunk, chunk})
      end
      # ... invocar pipeline con stream_callback
    end)
    {:ok, state}
  end

  def websocket_info({:ws_chunk, chunk}, state) do
    {:reply, {:text, Jason.encode!(chunk)}, state}
  end

  def websocket_info(:done, state) do
    {:reply, {:text, ~s({"type":"done"})}, state}
  end
end
```

El endpoint se monta en el router Cowboy como upgrade:

```elixir
# En ElPaso.HTTP.Router
get "/v1/chat/ws" do
  :cowboy_websocket.upgrade(conn.private.cowboy_req, ElPaso.HTTP.WebSocketHandler, %{})
end
```

---

### Criterios de completitud V1.3

- Dashboard accesible en `/dashboard` muestra estado real actualizado cada 5s
- `Telemetry.Store` captura los eventos principales y los sirve al dashboard
- `/metrics` devuelve métricas Prometheus válidas que Prometheus puede scraper
- `Auth.authenticate/1` distingue correctamente entre anónimo, usuario válido e inválido
- `AuthPlug` devuelve 401 con formato de error estándar cuando la autenticación falla
- Las sesiones de cada usuario están aisladas: no pueden acceder a sesiones ajenas
- Rate limiting por usuario funciona con token bucket en ETS
- WebSocket acepta conexiones, procesa mensajes y envía streaming como frames separados

═══════════════════════════════════════════════════════════════════════════════════
FIN PROMPT V1.3
═══════════════════════════════════════════════════════════════════════════════════

---

═══════════════════════════════════════════════════════════════════════════════════
PROMPT V2.0 — INTEGRACIONES EXTERNAS Y EXTENSIBILIDAD
Prerequisito: V1.3 completo (multi-usuario, dashboard, Prometheus, WebSocket).
Objetivo: ElPaso se integra con Claude Code y otros clientes del ecosistema,
acepta plugins externos de engine, descarga modelos de HuggingFace
Hub y soporta entradas multimodales (imagen + texto).
Entregables que V1.3 ya tiene listos para este prompt:

- `ElPaso.Engine` behaviour definido internamente (se publica aquí)
- `ElPaso.Engine.Registry` stub para registro de engines dinámicos
- Campo `supports_vision: false` en `context_spec` de todos los modelos
- Campo `has_image_input: false` y `image_count: 0` en `FeatureVector`
- Sección `integrations` en el schema de config (campos presentes, vacíos)
- Sección `plugins` en el schema de config (lista vacía por defecto)
  ═══════════════════════════════════════════════════════════════════════════════════

## V2.0 — Integraciones externas y extensibilidad

## Modelos para esta versión

| Fase                                            | Modelo     | Comando               | Por qué                                     |
| ----------------------------------------------- | ---------- | --------------------- | ------------------------------------------- |
| AnthropicProxy (conversión de formatos)         | `devstral` | `./llama.sh devstral` | Arquitectura del proxy y mapeo de modelos   |
| SSE streaming en formato Anthropic              | `coder`    | `./llama.sh coder`    | Implementación de los event types SSE       |
| Plugin.Loader (Code.compile_file, Registry)     | `devstral` | `./llama.sh devstral` | Diseño del sistema de extensibilidad        |
| ModelDownloader (streaming HTTP, checksum)      | `coder`    | `./llama.sh coder`    | I/O asíncrono, Finch.stream                 |
| Soporte visión (FeatureVector, Context.Builder) | `coder`    | `./llama.sh coder`    | Cambios incrementales en módulos existentes |

**Nota**: el `model_mapping` (qué modelo Anthropic mapea a qué model_id de ElPaso)
lo decide `devstral`. La implementación de los SSE events de streaming de Claude
Code la hace `coder` siguiendo el formato documentado.

**Objetivo**: ElPaso se convierte en un hub que conecta clientes del ecosistema
(Claude Code, IDEs) con modelos locales y remotos. Otros pueden extenderlo.

**Dependencias**: V1.3.

---

### 2.0.1 Integración con Claude Code

#### Formato Anthropic API

Claude Code usa el endpoint `/v1/messages` de Anthropic. El request tiene este formato:

```json
{
  "model": "claude-opus-4-6",
  "max_tokens": 1024,
  "messages": [{ "role": "user", "content": "Explica este código..." }],
  "system": "Eres un asistente de programación."
}
```

La respuesta Anthropic tiene este formato:

```json
{
  "id": "msg_01xyz",
  "type": "message",
  "role": "assistant",
  "content": [{ "type": "text", "text": "El código hace..." }],
  "model": "claude-opus-4-6",
  "stop_reason": "end_turn",
  "usage": { "input_tokens": 120, "output_tokens": 85 }
}
```

#### Módulo `ElPaso.HTTP.AnthropicProxy`

```elixir
defmodule ElPaso.HTTP.AnthropicProxy do
  @doc """
  Convierte un request Anthropic al formato interno de ElPaso.
  """
  def from_anthropic(anthropic_params) do
    messages = anthropic_params["messages"]
    system = anthropic_params["system"]

    # Si hay system prompt en el request Anthropic, lo añadimos como override
    # del bloque canónico (no lo reemplaza; se añade después del canónico)
    %InternalRequest{
      messages: messages,
      system_override: system,
      model_hint: map_anthropic_model(anthropic_params["model"]),
      max_tokens: anthropic_params["max_tokens"],
      temperature: anthropic_params.dig("temperature"),
      stream: anthropic_params["stream"] || false
    }
  end

  @doc """
  Convierte una respuesta interna de ElPaso al formato Anthropic.
  """
  def to_anthropic(internal_response, original_model) do
    %{
      "id" => "msg_#{generate_id()}",
      "type" => "message",
      "role" => "assistant",
      "content" => [%{"type" => "text", "text" => internal_response.content}],
      "model" => original_model,
      "stop_reason" => map_finish_reason(internal_response.finish_reason),
      "usage" => %{
        "input_tokens" => internal_response.prompt_tokens,
        "output_tokens" => internal_response.completion_tokens
      }
    }
  end

  @doc """
  Convierte un chunk de streaming Anthropic al formato SSE de Anthropic.
  Claude Code espera eventos SSE con tipos específicos.
  """
  def to_anthropic_stream_chunk(chunk, event_type) do
    # Anthropic SSE: event: content_block_delta\ndata: {...}\n\n
    data = case event_type do
      :start ->
        %{"type" => "message_start", "message" => %{"role" => "assistant", "content" => []}}
      :delta ->
        %{"type" => "content_block_delta",
          "delta" => %{"type" => "text_delta", "text" => chunk.content}}
      :stop ->
        %{"type" => "message_delta",
          "delta" => %{"stop_reason" => "end_turn"},
          "usage" => %{"output_tokens" => chunk.tokens}}
    end
    "event: #{to_string(event_type)}\ndata: #{Jason.encode!(data)}\n\n"
  end

  defp map_anthropic_model(model_name) do
    # Mapeo de modelos Anthropic a model_ids de ElPaso según config
    policy = Config.Loader.get().integrations.claude_code.model_mapping
    Map.get(policy, model_name, "auto")
  end
end
```

#### Endpoint `/v1/messages`

```elixir
# En ElPaso.HTTP.Router
post "/v1/messages" do
  with {:ok, body}    <- read_body(conn),
       {:ok, params}  <- Jason.decode(body),
       internal_req   <- AnthropicProxy.from_anthropic(params),
       # ... mismo pipeline que /v1/chat/completions
       {:ok, response} <- run_pipeline(internal_req, conn) do
    anthropic_resp = AnthropicProxy.to_anthropic(response, params["model"])
    json_response(conn, anthropic_resp)
  end
end
```

#### Cambios de config

```json
"integrations": {
  "claude_code": {
    "enabled": true,
    "policy": "prefer_local",
    "fallback_to_remote": true,
    "model_mapping": {
      "claude-opus-4-6": "heavy",
      "claude-sonnet-4-6": "fast",
      "claude-haiku-4-5-20251001": "fast"
    }
  }
}
```

El `policy` afecta al router: con `"prefer_local"`, los modelos remotos reciben una
penalización adicional de 0.2 en el score cuando hay un modelo local disponible.
Con `"always_remote"`, solo se usan modelos con `source.type: "remote_model"`.

---

### 2.0.2 Sistema de plugins para engines

#### `ElPaso.Engine` behaviour público

```elixir
defmodule ElPaso.Engine do
  @doc "Nombre del engine, usado como identificador en config"
  @callback name() :: atom()

  @doc "Tipo del engine: local_process o remote_api"
  @callback type() :: :local_process | :remote_api

  @doc "Ejecuta inferencia y devuelve la respuesta completa"
  @callback infer(prompt :: ElPaso.Context.BuiltPrompt.t(), params :: map(), config :: map())
    :: {:ok, ElPaso.Engine.Response.t()} | {:error, reason()}

  @doc "Ejecuta inferencia en streaming, llamando callback por cada chunk"
  @callback stream(prompt :: ElPaso.Context.BuiltPrompt.t(), params :: map(), config :: map(),
                   chunk_callback :: (ElPaso.Engine.Chunk.t() -> :ok))
    :: :ok | {:error, reason()}

  @doc "Adapta el PrefixBlock al formato que este engine espera"
  @callback prepare_prefix(prefix :: ElPaso.Context.PrefixBlock.t(), config :: map())
    :: term()

  @doc "Verifica que el engine está operativo"
  @callback health_check(config :: map())
    :: :ok | {:error, reason()}

  @doc "Formatea la lista de mensajes al formato específico del engine"
  @callback format_messages(messages :: [map()], context_spec :: map())
    :: term()
end
```

Structs de respuesta del engine:

```elixir
defmodule ElPaso.Engine.Response do
  defstruct [
    :content,           # String.t()
    :finish_reason,     # :stop | :length | :error
    :prompt_tokens,     # integer()
    :completion_tokens, # integer()
    :latency_ms         # integer()
  ]
end

defmodule ElPaso.Engine.Chunk do
  defstruct [
    :content,    # String.t() - texto del chunk
    :done,       # boolean() - true en el último chunk
    :tokens      # integer() | nil - tokens usados (solo en el último chunk)
  ]
end
```

#### Módulo `ElPaso.Plugin.Loader`

```elixir
defmodule ElPaso.Plugin.Loader do
  def load_all(plugins_config) do
    Enum.each(plugins_config[:engines] || [], fn plugin ->
      load_engine_plugin(plugin)
    end)
  end

  defp load_engine_plugin(%{"path" => path, "module" => module_name}) do
    resolved_path = Path.expand(path)
    unless File.exists?(resolved_path) do
      Logger.warning("Plugin no encontrado: #{resolved_path}")
      :skip
    end

    try do
      Code.compile_file(resolved_path)
      module = String.to_atom("Elixir.#{module_name}")

      unless function_exported?(module, :name, 0) and
             function_exported?(module, :infer, 3) do
        Logger.warning("Plugin #{module_name} no implementa ElPaso.Engine behaviour completo")
        :skip
      end

      ElPaso.Engine.Registry.register(module.name(), module)
      Logger.info("Plugin de engine cargado: #{module_name} (#{module.name()})")
    rescue
      e ->
        Logger.error("Error cargando plugin #{module_name}: #{Exception.message(e)}")
        :skip
    end
  end
end
```

Los plugins se cargan en `ElPaso.Application.start/2` antes de iniciar los modelos.

---

### 2.0.3 Descarga de modelos desde HuggingFace Hub

#### Módulo `ElPaso.ModelDownloader`

```elixir
defmodule ElPaso.ModelDownloader do
  @hf_base_url "https://huggingface.co"
  @download_dir Application.compile_env(:elpaso, :default_models_dir, "~/modelos")

  def download(source_config, opts \\ []) do
    %{"repo_id" => repo_id, "filename" => filename} = source_config
    revision = source_config["revision"] || "main"
    dest_path = opts[:dest] || Path.join([@download_dir, repo_id |> Path.basename(), filename])

    download_id = generate_download_id()
    url = build_url(repo_id, filename, revision)

    # Registra el download en ETS para consultas de progreso
    DownloadRegistry.register(download_id, %{url: url, dest: dest_path, status: :starting})

    Task.start(fn ->
      do_download(download_id, url, dest_path, source_config["sha256"])
    end)

    {:ok, download_id}
  end

  defp do_download(download_id, url, dest_path, expected_sha256) do
    File.mkdir_p!(Path.dirname(dest_path))
    temp_path = dest_path <> ".tmp"

    with {:ok, response} <- Finch.build(:get, url) |> Finch.stream(ElPasoFinch, fn
           {:status, status}, acc when status == 200 -> {:cont, acc}
           {:status, status}, _acc -> {:halt, {:error, "HTTP #{status}"}}
           {:headers, headers}, acc ->
             total = get_content_length(headers)
             DownloadRegistry.update(download_id, %{total_bytes: total})
             {:cont, acc}
           {:data, chunk}, {file, downloaded} ->
             IO.binwrite(file, chunk)
             new_downloaded = downloaded + byte_size(chunk)
             DownloadRegistry.update(download_id, %{downloaded_bytes: new_downloaded})
             {:cont, {file, new_downloaded}}
         end, {File.open!(temp_path, [:write, :binary]), 0}) do

      :ok ->
        if expected_sha256, do: verify_checksum(temp_path, expected_sha256)
        File.rename!(temp_path, dest_path)
        DownloadRegistry.update(download_id, %{status: :complete, dest_path: dest_path})
        :telemetry.execute([:elpaso, :model, :downloaded], %{}, %{dest: dest_path})
    end
  end

  def progress(download_id) do
    case DownloadRegistry.get(download_id) do
      nil -> {:error, :not_found}
      info ->
        pct = if info.total_bytes > 0 do
          round(info.downloaded_bytes / info.total_bytes * 100)
        else
          0
        end
        {:ok, Map.put(info, :percent, pct)}
    end
  end

  def verify_checksum(path, expected_sha256) do
    actual = :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)
    if actual == expected_sha256 do
      :ok
    else
      File.rm!(path)
      {:error, :checksum_mismatch}
    end
  end
end
```

El comando CLI:

```bash
mix elpaso models download <model_id>    # descarga el modelo definido en config
mix elpaso models download --progress    # muestra progreso de descargas activas
mix elpaso models download <model_id> --dest ~/otro/dir
```

---

### 2.0.4 Soporte para modelos multimodales básico

#### Cambios en `FeatureVector`

```elixir
%FeatureVector{
  # ... campos existentes ...
  has_image_input: boolean(),         # nuevo campo V2.0
  image_count: non_neg_integer()      # nuevo campo V2.0
}
```

#### Detección de imágenes en feature extraction

```elixir
defp extract_image_features(messages) do
  last_msg = List.last(messages)
  content = last_msg["content"]

  case content do
    text when is_binary(text) ->
      {false, 0}
    parts when is_list(parts) ->
      images = Enum.count(parts, &(&1["type"] == "image_url"))
      {images > 0, images}
  end
end
```

#### Cambios en `Context.Builder` para imágenes

Los mensajes con imágenes no pueden ser resumidos (la Capa 2 no puede comprimir imágenes).
El Context.Builder los trata como mensajes de alta prioridad que nunca salen de la ventana:

```elixir
defp promote_to_compression_layer(message) do
  has_image = message.content |> content_has_image?()
  if has_image do
    # Los mensajes con imagen nunca se archivan ni comprimen
    # Si la ventana está llena, se eliminan mensajes de texto más antiguos primero
    :keep_in_window
  else
    :promote_to_summary
  end
end
```

---

### Criterios de completitud V2.0

- `/v1/messages` acepta el formato Anthropic y devuelve respuestas en formato Anthropic
- El streaming en formato Anthropic SSE (event types correctos) funciona con Claude Code
- `model_mapping` en config traduce modelos Anthropic a model_ids de ElPaso
- `ElPaso.Engine` behaviour está documentado y los engines internos lo implementan
- `Plugin.Loader` carga plugins desde disco, valida el behaviour y los registra
- Un plugin de ejemplo trivial (echo engine) funciona correctamente
- `ModelDownloader.download/2` descarga con streaming, muestra progreso y verifica checksum
- `mix elpaso models download` funciona para fuentes `hf_repo`
- Mensajes con imágenes en formato OpenAI Vision pasan al motor correctamente
- Los modelos sin `supports_vision: true` tienen `capability_multiplier: 0.0` para requests con imagen

═══════════════════════════════════════════════════════════════════════════════════
FIN PROMPT V2.0
═══════════════════════════════════════════════════════════════════════════════════

---

═══════════════════════════════════════════════════════════════════════════════════
PROMPT V2.1 — CLUSTERING MULTI-NODO
Prerequisito: V2.0 completo (Claude Code integrado, plugins, HF Hub, visión).
Objetivo: varias instancias ElPaso en red local comparten sesiones y distribuyen
la carga de inferencia sin duplicar trabajo.
Entregables que V2.0 ya tiene listos para este prompt:

- PostgreSQL con `session_id UUID` sin estado crítico local en payload
  (diseño desde V1.0 compatible con multi-nodo)
- `mix.exs` ya incluye `libcluster ~> 3.4` (añadido en V0, ahora se activa)
- Sección `cluster` en el schema de config (campos presentes, `enabled: false`)
- `ModelState` ya tiene campo `node: atom() | nil` (valor nil hasta ahora)
- `Context.Manager` ya tiene la lógica condicional `cluster_mode?()` preparada
  ═══════════════════════════════════════════════════════════════════════════════════

## V2.1 — Clustering multi-nodo

## Modelos para esta versión

| Fase                                                    | Modelo     | Comando               | Por qué                                  |
| ------------------------------------------------------- | ---------- | --------------------- | ---------------------------------------- |
| NodeRegistry, arquitectura coordinator/worker           | `devstral` | `./llama.sh devstral` | Diseño distribuido con Erlang clustering |
| Router.Cluster (RPC, Task.async_stream sobre nodos)     | `devstral` | `./llama.sh devstral` | Razona sobre fallos de red y degradación |
| Context.Manager modo cluster (TTL, PostgreSQL fallback) | `coder`    | `./llama.sh coder`    | Cambios concretos en módulo existente    |
| libcluster config (Gossip vs static)                    | `devstral` | `./llama.sh devstral` | Conoce las estrategias de libcluster     |

**Nota**: esta versión requiere dos máquinas o dos instancias en la misma máquina
para testear. Los tests de integración de cluster son los más difíciles de automatizar;
acepta tests manuales para los criterios de completitud de V2.1.

**Objetivo**: varias instancias de ElPaso en una red local comparten sesiones y distribuyen
la carga de inferencia sin duplicar trabajo.

**Dependencias**: V2.0.

---

### 2.1.1 Arquitectura de nodos

Cada nodo tiene un rol configurado:

```json
"cluster": {
  "enabled": true,
  "node_name": "elpaso@192.168.1.10",
  "role": "both",
  "coordinator_nodes": ["elpaso@192.168.1.10"],
  "worker_nodes": ["elpaso@192.168.1.10", "elpaso@192.168.1.11"],
  "discovery": "static"
}
```

Roles: `coordinator`, `worker`, `both` (default para single-node; en cluster, los nodos
suelen especializarse).

#### Módulo `ElPaso.Cluster.NodeRegistry`

```elixir
defmodule ElPaso.Cluster.NodeRegistry do
  use GenServer

  # Registra el nodo actual en el cluster al arrancar
  def init(_) do
    if Config.cluster_enabled?() do
      :net_kernel.start([node_name(), :shortnames])
      connect_to_configured_nodes()
    end
    {:ok, %{nodes: %{}, my_role: Config.node_role()}}
  end

  # Devuelve todos los nodos activos con sus roles
  def all_nodes() :: [%{node: atom(), role: atom(), status: :up | :down}]

  # Devuelve todos los modelos disponibles en todos los nodos
  def all_model_states() :: %{atom() => [%ModelState{}]}

  # RPC: obtiene ModelStates de un nodo remoto con timeout
  def remote_model_states(node, timeout \\ 500) do
    case :rpc.call(node, ElPaso.Domain.ModelManager, :all_states, [], timeout) do
      {:badrpc, _} -> {:error, :unreachable}
      states       -> {:ok, states}
    end
  end
end
```

---

### 2.1.2 Descubrimiento de nodos

En modo `static`, los nodos se conectan al arrancar:

```elixir
defp connect_to_configured_nodes() do
  config_nodes = Config.cluster_nodes()
  Enum.each(config_nodes, fn node ->
    case Node.connect(node) do
      true  -> Logger.info("Conectado a nodo: #{node}")
      false -> Logger.warning("No se pudo conectar a nodo: #{node}")
    end
  end)
end
```

En modo `gossip` (con `libcluster`), la detección es automática. Se añade `libcluster`
como dependencia en `mix.exs` y se configura en el Application supervisor:

```elixir
# En Application.start/2 (solo si cluster.discovery == "gossip")
{Cluster.Supervisor, [
  [gossip: [strategy: Cluster.Strategy.Gossip,
            config: [port: 45892, multicast_addr: "230.1.1.251"]]]
]}
```

---

### 2.1.3 Router distribuido

```elixir
defmodule ElPaso.Domain.Router.Cluster do
  @doc """
  Versión distribuida de all_model_states que agrega estados de todos los nodos.
  Los estados remotos tienen timeout de 500ms para no bloquear el routing.
  """
  def all_model_states_global() do
    local = ModelManager.all_states()

    remote = NodeRegistry.all_nodes()
    |> Enum.filter(& &1.role in [:worker, :both] and &1.node != node())
    |> Task.async_stream(fn node_info ->
         case NodeRegistry.remote_model_states(node_info.node) do
           {:ok, states}     -> Enum.map(states, & Map.put(&1, :node, node_info.node))
           {:error, _reason} -> []  # nodo no responde; sus modelos no se consideran
         end
       end, timeout: 600, on_timeout: :kill_task)
    |> Enum.flat_map(fn
         {:ok, states} -> states
         {:exit, _}    -> []
       end)

    local_with_node = Enum.map(local, & Map.put(&1, :node, node()))
    local_with_node ++ remote
  end
end
```

El ModelState en modo cluster tiene un campo adicional:

```elixir
%ModelState{
  # ... campos existentes ...
  node: atom() | nil    # nil para nodo local, atom() para nodo remoto
}
```

Cuando el router elige un modelo en un nodo remoto, el request se reenvía vía RPC:

```elixir
defp forward_to_remote_node(node, model_id, prompt, params) do
  :rpc.call(node, ElPaso.Engine.Dispatcher, :infer, [model_id, prompt, params], 60_000)
end
```

---

### 2.1.4 Context.Manager en modo cluster

En modo cluster, el `SessionState` en ETS tiene TTL de 30 segundos. Tras ese tiempo,
se recarga desde PostgreSQL automáticamente:

```elixir
defmodule ElPaso.Context.Manager do
  @cluster_ets_ttl_ms 30_000

  defp get_session_state(session_id) do
    case :ets.lookup(:session_state, session_id) do
      [{^session_id, state, inserted_at}] when cluster_mode?() ->
        if System.monotonic_time(:millisecond) - inserted_at < @cluster_ets_ttl_ms do
          {:ok, state}
        else
          reload_session(session_id)  # TTL expirado, recargar desde PostgreSQL
        end
      [{^session_id, state, _}] ->
        {:ok, state}
      [] ->
        reload_session(session_id)
    end
  end
end
```

---

### Criterios de completitud V2.1

- Dos nodos ElPaso con PostgreSQL compartida comparten sesiones correctamente
- El coordinator agrega ModelStates remotos con timeout de 500ms
- Nodos que no responden son marcados como `:unreachable` y excluidos del routing
- Un request que llega al coordinator se ejecuta en el worker correcto vía RPC
- `Context.Manager` en modo cluster recarga el SessionState desde PostgreSQL tras TTL
- `mix elpaso cluster status` muestra todos los nodos, sus roles y sus modelos

═══════════════════════════════════════════════════════════════════════════════════
FIN PROMPT V2.1
═══════════════════════════════════════════════════════════════════════════════════

---

═══════════════════════════════════════════════════════════════════════════════════
PROMPT V2.2 — APRENDIZAJE ADAPTATIVO DEL ROUTER
Prerequisito: V1.2 completo (RouterStats + RouterTuner) y base de datos con
al menos 500 routing_decisions acumuladas.
Objetivo: el router mejora automáticamente sus decisiones con el uso,
con supervisión activa del usuario para aprobar cambios.
Entregables que V1.2 ya tiene listos para este prompt:

- `RouterTuner.analyze/1` básico (sugerencias manuales, sin tendencias)
- Tabla `routing_decisions` con campo `outcome` y datos históricos
- Sección `routing.auto_tune` en el schema de config (campo presente, `false`)
- Evento `[:elpaso, :router, :auto_tuned]` definido en telemetría (no emitido aún)
  ═══════════════════════════════════════════════════════════════════════════════════

## V2.2 — Aprendizaje adaptativo del router

## Modelos para esta versión

| Fase                                                    | Modelo    | Comando              | Por qué                                                           |
| ------------------------------------------------------- | --------- | -------------------- | ----------------------------------------------------------------- |
| RouterAnalyzer (regresión lineal, tendencias semanales) | `Thinker` | `./llama.sh Thinker` | Análisis estadístico, pendiente de regresión, ventanas temporales |
| Detección de retry (heurística temporal)                | `Thinker` | `./llama.sh Thinker` | Razona sobre los falsos positivos y el umbral del 30%             |
| AutoTuner GenServer (periódico, backoff)                | `coder`   | `./llama.sh coder`   | GenServer con handle_info periódico, patrón conocido              |
| Alertas de degradación en /status y dashboard           | `coder`   | `./llama.sh coder`   | Cambios en módulos HTTP existentes                                |
| Migración tabla auto_tune_runs                          | `coder`   | `./llama.sh coder`   | Migración Ecto simple                                             |

**Prerequisito crítico**: necesitas al menos 500 `routing_decisions` en la base de
datos antes de que las sugerencias de RouterAnalyzer sean estadísticamente relevantes.
Ejecuta `mix elpaso router stats` primero para confirmar el volumen de datos.

**Objetivo**: el router mejora automáticamente con el uso, con supervisión activa del usuario.

**Dependencias**: V1.2 (RouterStats + RouterTuner) y al menos 500 routing_decisions en BD.

---

### 2.2.1 Análisis estadístico de rendimiento

El `RouterAnalyzer` de V2.2 extiende el `RouterTuner` de V1.2 con análisis temporal:

```elixir
defmodule ElPaso.Domain.RouterAnalyzer do
  @doc """
  Analiza el rendimiento de cada combinación (model, task_type) a lo largo del tiempo.
  Detecta tendencias: ¿está mejorando o empeorando?
  """
  def analyze_trends(since \\ :last_30d) do
    decisions = Storage.query_routing_decisions(since: resolve_since(since), with_outcome: true)

    decisions
    |> group_by_combination()
    |> Enum.map(fn {{model, task}, group} ->
      # Dividir en ventanas temporales de 7 días para detectar tendencias
      windows = split_into_weekly_windows(group)
      success_rates = Enum.map(windows, &success_rate/1)
      latencies = Enum.map(windows, &median_latency/1)

      trend = calculate_trend(success_rates)
      retry_rate = calculate_retry_rate(group)

      %CombinationAnalysis{
        model_id: model,
        task_type: task,
        n_decisions: length(group),
        overall_success_rate: success_rate(group),
        success_trend: trend,          # :improving | :stable | :degrading
        median_latency_ms: median_latency(group),
        retry_rate_pct: retry_rate,
        alert: should_alert?(retry_rate, trend)
      }
    end)
  end

  defp calculate_trend(rates_over_time) do
    # Regresión lineal simple sobre las tasas de éxito semanales
    if length(rates_over_time) < 2 do
      :stable
    else
      slope = linear_regression_slope(rates_over_time)
      cond do
        slope > 0.02  -> :improving
        slope < -0.02 -> :degrading
        true          -> :stable
      end
    end
  end

  defp calculate_retry_rate(decisions) do
    # Retry: dos mensajes del mismo usuario en la misma sesión en menos de 10 segundos
    # con contenido semánticamente similar (similitud > 0.7)
    # Implementación simplificada para V2.2: dos mensajes en menos de 10s en la misma sesión
    decisions
    |> Enum.group_by(& &1.session_id)
    |> Enum.flat_map(fn {_, session_decisions} ->
         detect_retries(session_decisions)
       end)
    |> length()
    |> Kernel./(length(decisions))
    |> Kernel.*(100)
    |> Float.round(1)
  end
end
```

---

### 2.2.2 Generación de sugerencias mejorada

```elixir
%AffinitySuggestion{
  # Campos de V1.2 más:
  trend: :improving | :stable | :degrading,
  retry_rate_pct: float(),
  weekly_breakdown: [%{week: Date.t(), success_rate: float(), n: integer()}],
  auto_appliable: boolean()  # true si confianza > 0.85 y n > 50
}
```

---

### 2.2.3 Modo `auto_tune`

```json
"routing": {
  "auto_tune": true,
  "auto_tune_min_confidence": 0.85,
  "auto_tune_min_decisions": 50,
  "auto_tune_check_interval_hours": 24
}
```

El `AutoTuner` es un GenServer que se ejecuta periódicamente:

```elixir
defmodule ElPaso.Domain.AutoTuner do
  use GenServer

  def handle_info(:run_auto_tune, state) do
    if Config.auto_tune_enabled?() do
      suggestions = RouterAnalyzer.analyze_trends()
      |> Enum.filter(& &1.auto_appliable)

      Enum.each(suggestions, fn s ->
        Config.Loader.update_affinity(s.model_id, s.task_type, s.suggested_affinity)
        Logger.info("Auto-tune: #{s.model_id}.#{s.task_type}: #{s.current_affinity} → #{s.suggested_affinity}")
        :telemetry.execute([:elpaso, :router, :auto_tuned], %{delta: s.delta}, %{
          model_id: s.model_id,
          task_type: s.task_type,
          confidence: s.confidence
        })
      end)

      Storage.save_auto_tune_run(%{applied: length(suggestions), at: DateTime.utc_now()})
    end

    schedule_next_run(state)
    {:noreply, state}
  end
end
```

---

### 2.2.4 Alertas de degradación

La alerta se emite cuando `retry_rate_pct > 30` para una combinación con `n > 20`:

```elixir
[:elpaso, :router, :quality_alert]
  measurements: %{retry_rate_pct: float(), n_decisions: integer()}
  metadata: %{model_id: string, task_type: atom, trend: atom}
```

La alerta aparece en:

- El log con nivel `:warning`
- El endpoint `/status` bajo un campo `"alerts": [...]`
- El dashboard de V1.3 como notificación visual

---

### Criterios de completitud V2.2

- `RouterAnalyzer.analyze_trends/1` calcula tendencias semanales correctamente
- La detección de retry no produce falsos positivos en conversaciones normales
- Las sugerencias `auto_appliable` se aplican automáticamente cuando `auto_tune: true`
- Los cambios auto-aplicados se registran en la tabla `auto_tune_runs`
- El comando `mix elpaso router tune --revert-auto` deshace el último auto-tune
- Las alertas de degradación aparecen en `/status` y en el dashboard

═══════════════════════════════════════════════════════════════════════════════════
FIN PROMPT V2.2
═══════════════════════════════════════════════════════════════════════════════════

---

═══════════════════════════════════════════════════════════════════════════════════
PROMPT V3.0 — ELPASO COMO SERVICIO
Prerequisito: V2.1 completo (clustering multi-nodo operativo).
Objetivo: ElPaso desplegable como servicio compartido con gestión de costes,
autenticación JWT, almacenamiento cloud y API de administración.
Entregables que V2.1 ya tiene listos para este prompt:

- `mix.exs` ya incluye `jose ~> 1.11`, `ex_aws ~> 2.5`, `ex_aws_s3 ~> 2.5`
  (añadidos en V0, ahora se activan)
- Sección `auth` en el schema de config (campos listos para tipo "jwt")
- Sección `cost_management` en el schema de config (campos presentes, disabled)
- `AuthPlug` preparado para aceptar JWT además de API keys estáticas
- `system.api_key` ya funciona (modo single-key de V1.0); aquí se extiende
  ═══════════════════════════════════════════════════════════════════════════════════

## V3.0 — ElPaso como servicio

## Modelos para esta versión

| Fase                                                | Modelo     | Comando               | Por qué                                             |
| --------------------------------------------------- | ---------- | --------------------- | --------------------------------------------------- |
| CostManager (presupuestos, penalizaciones de score) | `devstral` | `./llama.sh devstral` | Lógica de negocio y decisiones de routing con coste |
| JWT (JOSE library, sign/verify)                     | `devstral` | `./llama.sh devstral` | Seguridad y configuración correcta de JOSE          |
| S3Adapter (ex_aws streaming)                        | `coder`    | `./llama.sh coder`    | I/O asíncrono con ex_aws, patrón streaming          |
| API Admin (controladores Plug)                      | `coder`    | `./llama.sh coder`    | Controladores CRUD estándar                         |
| Schemas Ecto model_pricing y api_usage              | `coder`    | `./llama.sh coder`    | Schemas con tipos Decimal, índices                  |

**Nota**: esta versión está pensada para despliegue en servidor, no para uso local.
Si ElPaso sigue siendo solo local, V3.0 es opcional. Las versiones V1.x y V2.x
son autosuficientes para uso intensivo de un usuario en red local.

**Objetivo**: ElPaso puede desplegarse como servicio compartido con gestión de costes,
autenticación robusta y almacenamiento en cloud.

**Dependencias**: V2.1 (clustering) para modo servidor.

---

### 3.0.1 Gestión de costes para APIs remotas

#### Schema de tablas de costes

```sql
-- Precios por modelo (actualizables sin reiniciar)
CREATE TABLE model_pricing (
  model_id TEXT NOT NULL,
  input_price_per_1k DECIMAL(10, 6) NOT NULL,
  output_price_per_1k DECIMAL(10, 6) NOT NULL,
  valid_from DATE NOT NULL,
  valid_until DATE,
  PRIMARY KEY (model_id, valid_from)
);

-- Uso acumulado por usuario y modelo
CREATE TABLE api_usage (
  id BIGSERIAL PRIMARY KEY,
  user_id TEXT NOT NULL,
  model_id TEXT NOT NULL,
  date DATE NOT NULL,
  input_tokens BIGINT NOT NULL DEFAULT 0,
  output_tokens BIGINT NOT NULL DEFAULT 0,
  cost_usd DECIMAL(10, 6) NOT NULL DEFAULT 0,
  request_count INTEGER NOT NULL DEFAULT 0,
  UNIQUE (user_id, model_id, date)
);

CREATE INDEX idx_api_usage_user_date ON api_usage(user_id, date);
CREATE INDEX idx_api_usage_model_date ON api_usage(model_id, date);
```

#### Módulo `ElPaso.CostManager`

```elixir
defmodule ElPaso.CostManager do
  @doc """
  Registra el uso de tokens de un request. Llamado por el pipeline tras cada inferencia remota.
  """
  def record_usage(user_id, model_id, input_tokens, output_tokens) do
    price = get_price(model_id)
    cost = (input_tokens * price.input_per_1k + output_tokens * price.output_per_1k) / 1000

    # Upsert en api_usage
    Storage.upsert_api_usage(%{
      user_id: user_id,
      model_id: model_id,
      date: Date.utc_today(),
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      cost_usd: cost
    })

    # Verificar si supera el budget
    check_budget(user_id)
  end

  def check_budget(user_id) do
    budget = Config.Loader.get().cost_management
    daily_spend = Storage.daily_spend(user_id)

    cond do
      daily_spend >= budget.daily_usd ->
        Logger.warning("Usuario #{user_id} superó el budget diario (#{daily_spend}$)")
        :budget_exceeded
      daily_spend >= budget.daily_usd * budget.alert_at_pct / 100 ->
        :telemetry.execute([:elpaso, :cost, :budget_alert], %{spend: daily_spend, budget: budget.daily_usd}, %{user_id: user_id})
        :approaching_budget
      true ->
        :ok
    end
  end

  @doc "Penalización de score para modelos remotos cuando el usuario está cerca del budget"
  def remote_model_penalty(user_id) do
    case check_budget(user_id) do
      :budget_exceeded    -> 999.0   # efectivamente excluye los modelos remotos
      :approaching_budget -> 0.3     # penalización significativa
      :ok                 -> 0.0     # sin penalización
    end
  end
end
```

---

### 3.0.2 Autenticación JWT

#### Módulo `ElPaso.Security.JWT`

```elixir
defmodule ElPaso.Security.JWT do
  @secret_key System.get_env("ELPASO_JWT_SECRET") || raise "ELPASO_JWT_SECRET no definida"
  @ttl_hours 24

  def generate_token(user_id, role \\ :user) do
    claims = %{
      "sub" => user_id,
      "role" => to_string(role),
      "iat" => DateTime.utc_now() |> DateTime.to_unix(),
      "exp" => DateTime.utc_now() |> DateTime.add(@ttl_hours * 3600) |> DateTime.to_unix()
    }
    JOSE.JWT.sign(JOSE.JWK.from_oct(@secret_key), %{"alg" => "HS256"}, claims)
    |> JOSE.JWS.compact()
    |> elem(1)
  end

  def verify_token(token) do
    case JOSE.JWT.verify(JOSE.JWK.from_oct(@secret_key), token) do
      {true, jwt, _jws} ->
        claims = jwt.fields
        exp = claims["exp"]
        if DateTime.utc_now() |> DateTime.to_unix() > exp do
          {:error, :expired}
        else
          {:ok, %{user_id: claims["sub"], role: String.to_atom(claims["role"])}}
        end
      {false, _, _} -> {:error, :invalid_signature}
    end
  end
end
```

Endpoint de autenticación:

```
POST /auth/token
Body: {"user_id": "alice", "api_key": "sk-alice-xxx"}
Response: {"token": "eyJ...", "expires_in": 86400}
```

---

### 3.0.3 S3Adapter para modelos y configuración

```elixir
defmodule ElPaso.Storage.S3Adapter do
  @doc "Descarga un modelo desde S3 al directorio local de modelos"
  def download_model(s3_uri, local_path) do
    # s3_uri: "s3://bucket/path/to/model.gguf"
    %{bucket: bucket, key: key} = parse_s3_uri(s3_uri)
    ExAws.S3.download_file(bucket, key, local_path)
    |> ExAws.stream!()
    |> Stream.run()
  end

  @doc "Sube el elpaso.conf a S3 para backup en cluster"
  def backup_config(local_path, s3_uri) do
    %{bucket: bucket, key: key} = parse_s3_uri(s3_uri)
    local_path
    |> File.stream!([], 65_536)
    |> ExAws.S3.upload(bucket, key)
    |> ExAws.request()
  end
end
```

El `source.type: "s3"` en config de modelos:

```json
"source": {
  "type": "s3",
  "uri": "s3://mi-bucket/modelos/gemma-4b.gguf",
  "local_cache_path": "~/modelos/gemma-4b.gguf"
}
```

Al arrancar, el ModelManager verifica si el fichero local existe. Si no, lo descarga
desde S3 antes de arrancar el motor. Si el bucket no es accesible, el modelo se marca
como `:disabled` con motivo `s3_unavailable`.

---

### 3.0.4 API de administración

Todos los endpoints bajo `/admin` requieren `role: :admin` en el JWT:

```elixir
# En ElPaso.HTTP.Router
scope "/admin" do
  plug ElPaso.HTTP.AdminAuthPlug  # verifica role: :admin

  post "/models/:id/enable",  ElPaso.HTTP.Admin.ModelsController, :enable
  post "/models/:id/disable", ElPaso.HTTP.Admin.ModelsController, :disable
  get  "/sessions",           ElPaso.HTTP.Admin.SessionsController, :index
  delete "/sessions/:id",     ElPaso.HTTP.Admin.SessionsController, :delete
  get  "/users",              ElPaso.HTTP.Admin.UsersController, :index
  post "/users",              ElPaso.HTTP.Admin.UsersController, :create
  delete "/users/:id",        ElPaso.HTTP.Admin.UsersController, :delete
  get  "/usage/report",       ElPaso.HTTP.Admin.UsageController, :report
  get  "/usage/report.csv",   ElPaso.HTTP.Admin.UsageController, :report_csv
end
```

---

### Criterios de completitud V3.0

- `CostManager.record_usage/4` persiste el uso en `api_usage` después de cada inferencia remota
- Los modelos remotos reciben penalización de score cuando el usuario se acerca al budget
- Los modelos remotos se deshabilitan automáticamente cuando se supera el budget diario
- `JWT.generate_token/2` y `JWT.verify_token/1` funcionan correctamente
- El endpoint `POST /auth/token` devuelve un JWT válido
- `AuthPlug` acepta tanto JWT (en `Authorization: Bearer`) como API keys estáticas
- `S3Adapter.download_model/2` descarga el GGUF completo con streaming
- Los modelos con `source.type: "s3"` se descargan automáticamente al arrancar
- Todos los endpoints de `/admin` requieren `role: :admin` y devuelven 403 sin él
- `GET /admin/usage/report` devuelve el uso por usuario y modelo del período solicitado

═══════════════════════════════════════════════════════════════════════════════════
FIN PROMPT V3.0
═══════════════════════════════════════════════════════════════════════════════════

---

## Tabla resumen del roadmap

| Versión | Objetivo                       | Módulos nuevos principales                                            |
| ------- | ------------------------------ | --------------------------------------------------------------------- |
| V0      | Definición del proyecto        | —                                                                     |
| V1.0    | Sistema funcional local        | Config, ModelManager, Context.\*, Router, HTTP, Security básica       |
| V1.1    | Contexto semántico + madurez   | EmbeddingClient, SemanticRetriever, Tokenizer, Config.Migrator        |
| V1.2    | Diagnóstico y ajuste           | RouterStats, RouterTuner, CLI.Bench, Config.Diff                      |
| V1.3    | Observabilidad + multi-usuario | HTTP.Dashboard, Telemetry.Store, Security.Auth, HTTP.WebSocketHandler |
| V2.0    | Integraciones + extensibilidad | HTTP.AnthropicProxy, Plugin.Loader, ModelDownloader                   |
| V2.1    | Clustering multi-nodo          | Cluster.NodeRegistry, Router.Cluster, libcluster                      |
| V2.2    | Aprendizaje adaptativo         | RouterAnalyzer, AutoTuner                                             |
| V3.0    | ElPaso como servicio           | CostManager, Security.JWT, Storage.S3Adapter, HTTP.Admin              |

**Caminos de dependencia obligatorios**:

- V3.0 requiere V2.1 (clustering necesario para modo servicio real)
- V2.2 requiere V1.2 (RouterTuner base + datos acumulados)
- V2.1 requiere V1.3 (multi-usuario prerequisito de multi-nodo)
- Cada versión requiere la inmediatamente anterior; las no-críticas se pueden saltar
  (por ejemplo, V2.0 antes de V2.2 si el aprendizaje no es prioritario)

═══════════════════════════════════════════════════════════════════════════════════
FIN DEL DOCUMENTO MAESTRO DE ELPASO
═══════════════════════════════════════════════════════════════════════════════════
