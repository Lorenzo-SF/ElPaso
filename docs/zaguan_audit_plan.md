# Plan Completo de Mejora del Uso de Zaguan en ElPaso

## Resumen Ejecutivo

Este documento define un plan exhaustivo para maximizar el uso de Zaguan en ElPaso. Tras la primera y segunda pasada de correcciones, ElPaso ya utiliza `Table`, `Header` y `Separator` de forma consistente. Este plan identifica **todas las oportunidades restantes**: archivos sin Zaguan, componentes no explotados (`Box`, `Bar`, `Breadcrumbs`, `Json`), inconsistencias de estilo, duplicación funcional, y la necesidad de un módulo helper centralizado.

---

## 1. Inventario de Componentes Zaguan Disponibles

### 1.1 Drawer Components (salida estática, ideales para CLI)

| Componente | Usado en ElPaso | API clave | Útil para |
|------------|----------------|-----------|-----------|
| `Table` | SÍ (extensivo) | `print/1`, `render/1` | Listados, tablas de datos |
| `Header` | SÍ (extensivo) | `print/2`, `render/2` | Títulos de sección, encabezados |
| `Separator` | SÍ (moderado) | `print/2`, `render/2` | División visual entre secciones |
| `Box` | **NO** | `print/2`, `render/2` | Resaltar mensajes importantes, alertas |
| `Bar` | **NO** | `print/3`, `render/3` | Barras de progreso, métricas porcentuales |
| `Breadcrumbs` | **NO** | `print/2`, `render/2` | Rutas de navegación, jerarquía |
| `Json` | SÍ (router_stats) | `print/2`, `render/2` | Pretty-print JSON con syntax highlighting |
| `AnimatedBar` | **NO** | `start/3`, `render_frame/4` | Progreso animado (requiere loop) |
| `ColorWheel` | **NO** | `show_color_info/2` | Herramientas de color (específico) |

### 1.2 UI Components (sistema TUI con buffer/canvas)

**NO aplicables a CLI tradicional.** Requieren `Zaguan.UI.start/0`, buffer de renderizado y bucle de eventos. ElPaso es una herramienta CLI, no una TUI interactiva.

---

## 2. Estado Actual del Uso de Zaguan en ElPaso

### 2.1 Archivos que YA usan Zaguan (post-corrección)

| Archivo | Componentes Zaguan | Cobertura |
|---------|-------------------|-----------|
| `lib/el_paso/cli.ex` | `Header`, `Separator`, `Table` | Alta (~15 handlers) |
| `lib/el_paso/cli/commands/router_stats.ex` | `Header`, `Separator`, `Table`, `Json` | Completa |

### 2.2 Archivos que NO usan Zaguan (pendientes)

| Archivo | Líneas | Output actual | Prioridad |
|---------|--------|---------------|-----------|
| `lib/el_paso/cli/commands/embeddings.ex` | 44 | Tabla ASCII manual con espaciado | **ALTA** |
| `lib/el_paso/cli/commands/cluster_status.ex` | 59 | Jerarquía manual con indentación | **ALTA** |
| `lib/el_paso/cli/commands/router_tune.ex` | 62 | Análisis línea a línea con iconos | **ALTA** |
| `lib/el_paso/cli/commands/context.ex` | 74 | Texto plano con `=== ===` | **ALTA** |
| `lib/el_paso/cli/commands/bench.ex` | 49 | Header manual + resumen plano | **MEDIA** |
| `lib/mix/tasks/elpaso/register_wrapper.ex` | 255 | Progreso con `→` + resumen manual | **MEDIA** |
| `lib/mix/tasks/elpaso/init.ex` | 51 | Mensajes planos con emoji | **MEDIA** |
| `lib/mix/tasks/elpaso/model/add.ex` | 82 | Mensajes planos con emoji | **BAJA** |
| `lib/mix/tasks/elpaso/model/list.ex` | 24 | Lista hardcodeada estática | **BAJA** |
| `lib/mix/tasks/elpaso/engine/list.ex` | 25 | Lista hardcodeada estática | **BAJA** |
| `lib/mix/tasks/elpaso/model/*.ex` (start/stop/remove) | ~20 c/u | Mensajes planos simples | **BAJA** |
| `lib/mix/tasks/elpaso/engine/*.ex` (test/remove) | ~20 c/u | Mensajes planos simples | **BAJA** |

### 2.3 Inconsistencias detectadas

1. **Duplicación funcional:** `Mix.Tasks.Elpaso.Model` (usa Zaguan.Table) vs `Mix.Tasks.Elpaso.Model.List` (lista hardcodeada estática). Lo mismo con `Engine` vs `Engine.List`.
2. **Mezcla de estilos en `cli.ex`:** Los handlers `model add`, `engine add`, etc. usan `IO.puts("✅ ...")` mientras que `model show` usa `Header + Table`.
3. **Espaciado inconsistente:** Algunos comandos hacen `IO.puts("")` manualmente, otros no. Zaguan maneja espaciado de forma uniforme.
4. **Mensajes flash sin estandarizar:** Los mensajes de éxito/error (`✅`, `❌`, `ℹ️`, `⚠️`) tienen espaciado irregular (a veces 2 espacios después del emoji, a veces 1).
5. **Wizard bloqueado:** `config/wizard.ex` tiene stubs porque Zaguan no expone prompts CLI simples (solo TUI).

---

## 3. Plan de Implementación

### Fase 1: Infraestructura — Módulo helper `ElPaso.CLI.Output`

**Objetivo:** Centralizar toda la salida CLI para garantizar consistencia visual y reducir duplicación.

**Acciones:**

1. Crear `lib/el_paso/cli/output.ex`:
   ```elixir
   defmodule ElPaso.CLI.Output do
     @moduledoc """
     Helper centralizado para toda la salida formateada de ElPaso CLI.
     Abstrae Zaguan.Drawer.Components con los colores y estilos corporativos.
     """

     alias Zaguan.Drawer.Components.{Box, Header, Separator, Table}

     # Colores corporativos ElPaso
     @color_primary {0, 180, 216}      # Cyan
     @color_success {46, 204, 113}     # Verde
     @color_error {231, 76, 60}        # Rojo
     @color_warning {241, 196, 15}     # Amarillo
     @color_info {52, 152, 219}        # Azul
     @color_muted {149, 165, 166}      # Gris

     # --- Mensajes flash semánticos ---
     def success(message), do: IO.puts("✅ #{message}")
     def error(message), do: IO.puts("❌ #{message}")
     def info(message), do: IO.puts("ℹ️  #{message}")
     def warning(message), do: IO.puts("⚠️  #{message}")

     # --- Headers ---
     def section(title, subtitle \\ nil) do
       Header.print(title, subtitle: subtitle, color: @color_primary)
     end

     # --- Separadores ---
     def divider(label \\ nil) do
       Separator.print(label, color: @color_muted)
     end

     # --- Tablas ---
     def data_table(headers, rows, opts \\ []) do
       Table.print(
         [headers: headers, rows: rows] ++
           Keyword.merge(
             [table_border: :rounded, headers_color: :cyan],
             opts
           )
       )
     end

     # --- Cajas de alerta ---
     def alert_box(message, opts \\ []) do
       type = Keyword.get(opts, :type, :info)
       color = alert_color(type)
       Box.print(message, border: :rounded, border_color: color)
     end

     # --- JSON ---
     def json(data) do
       Zaguan.Drawer.Components.Json.print(data)
     end

     # --- Breadcrumbs ---
     def breadcrumbs(items) do
       Zaguan.Drawer.Components.Breadcrumbs.print(items)
     end

     defp alert_color(:success), do: @color_success
     defp alert_color(:error), do: @color_error
     defp alert_color(:warning), do: @color_warning
     defp alert_color(:info), do: @color_info
   end
   ```

2. Refactorizar `lib/el_paso/cli.ex` para usar `ElPaso.CLI.Output` en lugar de alias directos a Zaguan.
3. Actualizar `lib/el_paso/cli/commands/router_stats.ex` para usar `ElPaso.CLI.Output`.

**Impacto:**
- Un solo punto de cambio para ajustar colores, bordes o estilo global.
- Elimina la duplicación de `alias Zaguan.Drawer.Components.{Header, Separator, Table}` en múltiples archivos.
- Mensajes flash consistentes (espaciado, emojis, colores).

---

### Fase 2: Migrar archivos sin Zaguan (Prioridad ALTA)

#### 2.1 `lib/el_paso/cli/commands/embeddings.ex`

**Estado actual:** Tabla ASCII manual con espaciado por espacios.

**Cambio:**
```elixir
alias ElPaso.CLI.Output

# ANTES:
IO.puts("EMBEDDING COVERAGE")
IO.puts("═══════════════════════════════════════")
IO.puts("Total mensajes archivados:  1,247")
...

# DESPUÉS:
Output.section("Embedding Coverage")
Output.data_table(
  ["Métrica", "Valor"],
  [
    ["Total mensajes archivados", "1,247"],
    ["Con embedding", "1,198 (96.1%)"],
    ["Sin embedding", "49 (3.9%)"],
    ["  - Fallos de generación", "12"],
    ["  - Anteriores a V1.1", "37"],
    ["Índice IVFFlat", "CONSTRUIDO (1,198 filas)"],
    ["Modelo activo", "nomic-embed (768 dims)"],
    ["Última generación", "hace 2 minutos"]
  ]
)
```

#### 2.2 `lib/el_paso/cli/commands/cluster_status.ex`

**Estado actual:** Jerarquía manual con `IO.puts` e indentación.

**Cambio:**
- Usar `Output.section/2` para el título.
- Usar `Output.data_table/3` para nodos (columnas: Nodo, Rol, Estado).
- Usar `Output.data_table/3` para modelos por nodo (columnas: Nodo, Modelo, Estado).
- Usar `Output.divider/1` entre secciones.

#### 2.3 `lib/el_paso/cli/commands/router_tune.ex`

**Estado actual:** Análisis impreso línea por línea con iconos Unicode.

**Cambio:**
- Usar `Output.section/2` para "Análisis de tendencias".
- Usar `Output.data_table/3` con columnas: Modelo@Tarea, Success Rate, Trend, N, Alerta.
- Aplicar colores semánticos a filas (`rows_0_color`, etc.) si Zaguan.Table lo soporta.

#### 2.4 `lib/el_paso/cli/commands/context.ex`

**Estado actual:** Texto plano con `=== Sesión X ===` y campos clave-valor.

**Cambio:**
- `render_text/1` → `Output.section(session_id, subtitle: "Sesión")` + `Output.data_table/3` Campo-Valor.
- `render_json/1` → `Output.json/1` (mejor que `Jason.encode!` plano).
- `list_sessions/0` → implementar con `Output.data_table/3` (actualmente es un stub).

---

### Fase 3: Migrar archivos sin Zaguan (Prioridad MEDIA)

#### 3.1 `lib/el_paso/cli/commands/bench.ex`

**Estado actual:** Header manual `=== Benchmark ... ===` y resumen plano.

**Cambio:**
- Usar `Output.section/2` para el título del benchmark.
- Usar `Zaguan.Drawer.Components.Bar` para mostrar progreso por iteración (si es viable sin animación).
- Usar `Output.data_table/3` para el resumen final (Task Type, Latencia, Estado).

#### 3.2 `lib/mix/tasks/elpaso/register_wrapper.ex`

**Estado actual:** Progreso con `→` y emojis sueltos, resumen final manual.

**Cambio:**
- Usar `Output.section/2` al inicio.
- Usar `Output.info/1` para pasos de parsing.
- Usar `Output.data_table/3` para el resumen final de registros (Tipo, Nombre, Estado/URL).
- Usar `Output.success/1` / `Output.info/1` para resultados idempotentes.

#### 3.3 `lib/mix/tasks/elpaso/init.ex`

**Estado actual:** Mensajes planos con emoji.

**Cambio:**
- Usar `Output.section/2` para "Inicialización".
- Usar `Output.success/1` para confirmación de creación.
- Usar `Output.info/1` para "ya existe".
- Usar `Output.data_table/3` para mostrar la ruta del archivo creado y su contenido.

#### 3.4 `lib/mix/tasks/elpaso/model/add.ex` & `engine/add.ex`

**Estado actual:** Mensajes planos con emoji.

**Cambio:**
- Usar `Output.error/1` para errores de validación.
- Usar `Output.success/1` para confirmación de registro.
- Usar `Output.info/1` para "ya existe".
- Opcional: usar `Box.print/2` para enmarcar el mensaje de uso (help) cuando faltan argumentos.

---

### Fase 4: Resolver inconsistencias y duplicaciones

#### 4.1 Unificar `Mix.Tasks.Elpaso.Model` vs `Mix.Tasks.Elpaso.Model.List`

**Problema:** `Model` ya usa `Zaguan.Table` para `list_models`. `Model.List` tiene una lista hardcodeada estática.

**Solución:**
- Hacer que `Model.List.run/1` delegue a `Model.list_models/0` (o viceversa).
- Eliminar la lista hardcodeada de `Model.List`.
- Aplicar lo mismo con `Engine` vs `Engine.List`.

#### 4.2 Estandarizar mensajes flash en `cli.ex`

**Problema:** 200+ líneas de `IO.puts("✅ ...")` e `IO.puts("❌ ...")` dispersas.

**Solución:**
- Reemplazar todos los mensajes flash en `cli.ex` por `Output.success/1`, `Output.error/1`, `Output.info/1`, `Output.warning/1`.
- Esto garantiza espaciado consistente y permite cambiar el estilo global desde un solo archivo.

#### 4.3 Unificar estilo de `server start` en `cli.ex`

**Problema:** Mezcla de `Header`, `Separator`, `Table` con `IO.puts("[init] ...")` manuales.

**Solución:**
- Reemplazar `IO.puts("[init] Arrancando aplicación OTP...")` por `Output.info/1` o `Output.divider/1`.
- Reemplazar `IO.puts("[init] ✅ Aplicación OTP lista")` por `Output.success/1`.
- Reemplazar mensajes de error de arranque por `Output.error/1`.

---

### Fase 5: Explorar componentes Zaguan no utilizados

#### 5.1 `Box` — Cajas de alerta

**Casos de uso en ElPaso:**
- Cuando un comando requiere argumentos y no se proporcionan: mostrar el uso dentro de una caja con borde rojo (`Box.print/2` con `border_color: @color_error`).
- Mensajes de error importantes (ej: "PostgreSQL no está corriendo").
- Mensajes informativos destacados (ej: "ElPaso inicializado").

**Archivos beneficiados:**
- `cli.ex` — cajas para errores de argumentos.
- `mix/tasks/elpaso/model/add.ex` — caja para help de uso.
- `mix/tasks/elpaso/register_wrapper.ex` — caja para resumen final.

#### 5.2 `Bar` — Barras de progreso

**Casos de uso en ElPaso:**
- `bench.ex` — mostrar progreso de iteraciones del benchmark.
- `embeddings.ex` — mostrar porcentaje de cobertura de embeddings (96.1%).
- Posible uso futuro: progreso de migraciones, importación de datos.

**Ejemplo:**
```elixir
Zaguan.Drawer.Components.Bar.print(96.1, 100,
  label: "Embedding coverage",
  width: 40,
  filled_color: {46, 204, 113}
)
```

#### 5.3 `Breadcrumbs` — Rutas de navegación

**Casos de uso en ElPaso:**
- Contexto en comandos anidados: `elpaso > model > show > gemma`.
- Jerarquía de configuración: `http > port`.

**Archivos beneficiados:**
- `cli.ex` — al mostrar ayuda específica de subcomandos.
- `config/show` — para indicar la ruta de configuración.

**Ejemplo:**
```elixir
Output.breadcrumbs(["elpaso", "model", "show"])
# elpaso › model › show
```

#### 5.4 `Json` — Pretty-print JSON

**Casos de uso en ElPaso:**
- `context.ex` — reemplazar `Jason.encode!(data, pretty: true)` por `Output.json/1` para obtener syntax highlighting con colores.
- `router_stats.ex` — ya lo usa correctamente.
- Posible uso futuro: exportar configuración, logs estructurados.

---

### Fase 6: Wizard interactivo (opcional, futuro)

**Problema:** `config/wizard.ex` tiene stubs porque Zaguan no tiene prompts CLI simples.

**Opciones:**
1. **Corto plazo:** Implementar el wizard con `IO.gets/1` estándar, pero usando `Output.section/2`, `Output.data_table/3` y `Box.print/2` para mostrar opciones de forma elegante.
2. **Largo plazo:** Si Zaguan añade componentes de prompt CLI (`Zaguan.Drawer.Components.Prompt`, `Select`, `Confirm`), migrar el wizard a ellos.

**Implementación propuesta (corto plazo):**
```elixir
def step_engine_type do
  Output.section("Configuración del Engine")

  Output.data_table(
    ["Opción", "Descripción"],
    [
      ["1", "llama.cpp (local)"],
      ["2", "Ollama (local/remoto)"],
      ["3", "OpenAI API (remoto)"],
      ["4", "vLLM (GPU local)"]
    ]
  )

  choice = IO.gets("Selecciona una opción (1-4): ") |> String.trim()
  # ...
end
```

---

## 4. Roadmap de Implementación

### Sprint 1: Infraestructura (1 día)
- [ ] Crear `lib/el_paso/cli/output.ex` con helpers semánticos.
- [ ] Refactorizar `lib/el_paso/cli.ex` para usar `ElPaso.CLI.Output`.
- [ ] Refactorizar `lib/el_paso/cli/commands/router_stats.ex` para usar `ElPaso.CLI.Output`.
- [ ] Ejecutar tests y verificar que todo pasa.

### Sprint 2: Migración ALTA (1-2 días)
- [ ] Migrar `lib/el_paso/cli/commands/embeddings.ex` → `Output` + `Table`.
- [ ] Migrar `lib/el_paso/cli/commands/cluster_status.ex` → `Output` + `Table`.
- [ ] Migrar `lib/el_paso/cli/commands/router_tune.ex` → `Output` + `Table`.
- [ ] Migrar `lib/el_paso/cli/commands/context.ex` → `Output` + `Table` + `Json`.
- [ ] Ejecutar tests y verificar.

### Sprint 3: Migración MEDIA (1 día)
- [ ] Migrar `lib/el_paso/cli/commands/bench.ex` → `Output` + `Table` + `Bar`.
- [ ] Migrar `lib/mix/tasks/elpaso/register_wrapper.ex` → `Output` + `Table`.
- [ ] Migrar `lib/mix/tasks/elpaso/init.ex` → `Output`.
- [ ] Migrar `lib/mix/tasks/elpaso/model/add.ex` y `engine/add.ex` → `Output` + `Box`.
- [ ] Ejecutar tests y verificar.

### Sprint 4: Consistencia y limpieza (1 día)
- [ ] Unificar `Mix.Tasks.Elpaso.Model.List` con `Model`.
- [ ] Unificar `Mix.Tasks.Elpaso.Engine.List` con `Engine`.
- [ ] Estandarizar todos los mensajes flash en `cli.ex` con `Output`.
- [ ] Eliminar todos los `alias Zaguan.Drawer.Components.*` dispersos (centralizar en `Output`).
- [ ] Revisar espaciado inconsistente (`IO.puts("")` manuales).
- [ ] Ejecutar tests y verificar.

### Sprint 5: Nuevos componentes (1 día, opcional)
- [ ] Añadir `Box` para mensajes de error/alerta importantes.
- [ ] Añadir `Bar` para métricas porcentuales (embeddings coverage, bench progreso).
- [ ] Añadir `Breadcrumbs` en ayudas de subcomandos.
- [ ] Evaluar uso de `Json` en `context.ex` y otros comandos.
- [ ] Ejecutar tests y verificar.

### Sprint 6: Wizard (1 día, opcional)
- [ ] Implementar `config/wizard.ex` con `IO.gets` + `Output` helpers.
- [ ] Actualizar tests del wizard.

---

## 5. Métricas de Éxito

| Métrica | Antes | Objetivo |
|---------|-------|----------|
| Archivos usando Zaguan | 5 | 20+ |
| Componentes Zaguan distintos usados | 3 (Table, Header, Separator) | 7+ (añadir Box, Bar, Breadcrumbs, Json) |
| Tablas manuales con Unicode | ~10 | 0 |
| Puntos de alias/import de Zaguan | 5 archivos | 1 (solo `ElPaso.CLI.Output`) |
| Inconsistencias de espaciado/emojis | ~20 | 0 |
| Tests pasando | 304 | 304+ |

---

## 6. Notas Técnicas

### 6.1 Zaguan.Drawer.Components.Table — Opciones avanzadas

`Table` soporta opciones no utilizadas actualmente que podrían mejorar la presentación:

- `:rows_0_color`, `:rows_1_color`, etc. — colores por fila (útil para resaltar errores).
- `:rows_0_effects`, etc. — efectos por fila (`:bold`, `:italic`).
- `:rows_align` — alineación por columna (`:left`, `:center`, `:right`).
- `:padding` — padding interno de celdas.
- `:table_border: :none` — tabla sin bordes (estilo minimalista).

### 6.2 Zaguan.Drawer.Components.Box — Limitaciones

`Box` no trunca contenido automáticamente si excede el ancho. Para contenido variable largo, es mejor usar `Table` o asegurar que las líneas caben en el ancho del terminal.

### 6.3 Dependencia en test

El cambio a `mix.exs` para incluir `{:zaguan, path: "../zaguan"}` en todos los entornos (no solo `:dev`/`:prod`) es permanente y necesario. No debe revertirse.

### 6.4 Compatibilidad CI

Todos los componentes `Drawer` usan ANSI colors y caracteres Unicode. En entornos CI sin TTY, ANSI se ignora automáticamente. Los tests que capturen `IO` con `ExUnit.CaptureIO` seguirán funcionando.

---

## 7. Conclusión

ElPaso actualmente usa ~20% del potencial de Zaguan para CLI. Este plan sistematiza la migración completa:

1. **Centralización** via `ElPaso.CLI.Output`.
2. **Migración exhaustiva** de todos los archivos que aún usan `IO.puts` manual.
3. **Adopción de nuevos componentes** (`Box`, `Bar`, `Breadcrumbs`, `Json`) donde aporten valor.
4. **Eliminación de inconsistencias** (espaciado, emojis, duplicación).
5. **Wizard funcional** usando los helpers de salida.

El resultado será una CLI profesional, consistente y visualmente coherente, aprovechando al máximo la librería Zaguan.
