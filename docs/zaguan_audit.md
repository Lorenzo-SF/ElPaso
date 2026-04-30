# Auditoría de Uso de Zaguan en ElPaso

## Resumen Ejecutivo

ElPaso utiliza Zaguan como dependencia. Tras esta auditoría y corrección, la mayoría de las salidas CLI aprovechan los componentes visuales de Zaguan (`Table`, `Header`, `Separator`, `Box`). Quedan algunos mensajes simples de éxito/error que no requieren formato tabular.

---

## Hallazgos

### 1. `lib/el_paso/cli.ex` — Uso extensivo de Zaguan (CORREGIDO Y MEJORADO ✅)

**Estado:** Corregido y mejorado. Todas las tablas manuales han sido reemplazadas por `Zaguan.Drawer.Components.Table.print/2`, y se han añadido `Header`, `Separator`, y `Box` en múltiples comandos para una experiencia CLI consistente.

| Función | Componentes Zaguan | Descripción |
|---------|-------------------|-------------|
| `handle_model(["list" \| _])` | `Table` | Listado con headers auto-calculados |
| `handle_model(["show" \| _])` | `Header` + `Table` | Detalle como tabla Campo-Valor |
| `handle_engine(["list" \| _])` | `Table` | Listado con headers auto-calculados |
| `handle_engine(["show" \| _])` | `Header` + `Table` | Detalle como tabla Campo-Valor |
| `handle_router(["stats" \| rest])` | `Table` | Decisiones de routing tabuladas |
| `handle_router(["rules" \| _])` | `Table` | Reglas como tabla tabular |
| `handle_context(["list" \| rest])` | `Table` | Sesiones en tabla |
| `handle_context(["show" \| rest])` | `Header` + `Table` + `Separator` | Metadatos + mensajes tabulados |
| `handle_cluster(["nodes" \| _])` | `Table` | Nodos en tabla |
| `handle_cluster(["status" \| _])` | `Header` + `Table` | Estado del cluster tabulado |
| `handle_personality(["list" \| _])` | `Table` | Listado con headers auto-calculados |
| `handle_personality(["show" \| _])` | `Header` + `Table` | Detalle como tabla Campo-Valor |
| `handle_profile(["list" \| _])` | `Table` | Listado con headers auto-calculados |
| `handle_profile(["show" \| _])` | `Header` + `Table` | Detalle como tabla Campo-Valor |
| `handle_config(["show" \| _])` | `Header` + `Separator` + `Table` | Config por secciones tabuladas |
| `handle_db(["status" \| _])` | `Table` | Migraciones como tabla |
| `handle_server(["start" \| _])` | `Header` + `Separator` + `Table` | Endpoints, engines, modelos tabulados |

**Cambio aplicado (patrón):**
```elixir
# ANTES (manual, propenso a descuadre):
IO.puts("┌─────────┬──────────┬────────────────────┬────────┐")
IO.puts("│ Name    │ Engine  │ URL               │ Active│")
# ...

# DESPUÉS (con Zaguan, auto-ajustable):
alias Zaguan.Drawer.Components.Table

Table.print(
  headers: ["Name", "Engine", "URL", "Active"],
  rows: Enum.map(models, fn m -> [m.name, m.engine_id, m.url, to_string(m.active)] end),
  table_border: :rounded,
  headers_color: :cyan
)
```

### 2. `lib/el_paso/cli/commands/router_stats.ex` — USO CORRECTO de Zaguan (MEJORADO ✅)

Este archivo ya usaba Zaguan correctamente. Se añadió `Separator` entre las tablas para mejor legibilidad visual:

```elixir
alias Zaguan.Drawer.Components.{Header, Separator, Table}

Header.print("Routing Stats", subtitle: "#{period_label(since)}")
Separator.print("Resumen global")
# ... tabla 1 ...
Separator.print("Por modelo")
# ... tabla 2 ...
```

✅ Separadores contextuales entre secciones
✅ Calcula anchos automáticamente
✅ Alinea correctamente
✅ Usa bordes redondeados de Zaguan

### 3. `lib/el_paso/config/wizard.ex` — Stubs documentados

Líneas 28 y 44 tenían comentarios indicando que usarían `Zaguan.UI.Select` y `Zaguan.UI.Confirm`. Tras revisar Zaguan, estos módulos no existen como widgets de prompt CLI; sus equivalentes (`Zaguan.UI.Components.Select` y `Zaguan.UI.Components.Confirm`) son componentes TUI que requieren un runtime de terminal interactivo completo. Los comentarios se han actualizado para reflejar esta limitación y se mantienen los stubs funcionales por compatibilidad con tests.

### 4. Mix tasks — Tablas manuales (CORREGIDAS ✅)

Los siguientes archivos de Mix tasks también pintaban tablas manualmente y han sido migrados a `Zaguan.Drawer.Components.Table.print/2`:

| Archivo | Función | Estado |
|---------|---------|--------|
| `lib/mix/tasks/elpaso/model.ex` | `list_models/0` | ✅ Corregido |
| `lib/mix/tasks/elpaso/engine.ex` | `list_engines/0` | ✅ Corregido |
| `lib/mix/tasks/elpaso/personality.ex` | `list_personalities/0` | ✅ Corregido |

---

## Recomendaciones

### Corregir tablas manuales

Todas las tablas manuales en `lib/el_paso/cli.ex` deben reemplazarse por `Zaguan.Drawer.Components.Table.print/2`.

**Patrón de corrección:**

```elixir
# ANTES (manual, propenso a descuadre):
IO.puts("┌─────────┬──────────┬────────────────────┬────────┐")
IO.puts("│ Name    │ Engine  │ URL               │ Active│")
# ...

# DESPUÉS (con Zaguan, auto-ajustable):
alias Zaguan.Drawer.Components.Table

Table.print(
  headers: ["Name", "Engine", "URL", "Active"],
  rows: Enum.map(models, fn m -> [m.name, m.engine_id, m.url, to_string(m.active)] end),
  table_border: :rounded,
  headers_color: :cyan
)
```

### Archivos modificados

1. **`lib/el_paso/cli.ex`**:
   - Todos los comandos `list` usan `Table`
   - Todos los comandos `show` usan `Header` + `Table` (Campo-Valor)
   - `handle_config(["show"])` usa `Header` + `Separator` + `Table` por sección
   - `handle_context(["show"])` usa `Header` + `Separator` + `Table` para metadatos y mensajes
   - `handle_cluster(["status"])` usa `Header` + `Table`
   - `handle_server(["start"])` usa `Header` + `Separator` + `Table` para endpoints, engines y modelos
   - `handle_router(["rules"])` usa `Table`
   - `handle_db(["status"])` usa `Table`

2. **`lib/el_paso/cli/commands/router_stats.ex`**:
   - Añadido `Separator` entre tablas de resumen y por-modelo

3. **`lib/el_paso/config/wizard.ex`**:
   - Comentarios actualizados sobre limitaciones de componentes TUI en CLI simple

4. **Mix tasks**:
   - `lib/mix/tasks/elpaso/model.ex` — `list_models/0`
   - `lib/mix/tasks/elpaso/engine.ex` — `list_engines/0`
   - `lib/mix/tasks/elpaso/personality.ex` — `list_personalities/0`

5. **`mix.exs`**:
   - Zaguan ahora es dependencia en todos los entornos (incluido `:test`)

---

## Pruebas Recomendadas para Zaguan CLI

Antes de confiar en que Zaguan funciona correctamente como librería, se deben ejecutar estas pruebas manuales:

### Comandos básicos
```bash
zaguan --help
zaguan --version
```

### Show subcommands
```bash
zaguan show message "Hello World"
zaguan show message --color red --bold "Alert"
zaguan show success "Done"
zaguan show error "Failed"
zaguan show header "Title" --subtitle "Subtitle"
zaguan show separator --text "Section"
zaguan show gradient "Rainbow" --colors "red;orange;yellow;green;blue"
zaguan show table --headers "A;B;C" --rows "1;2;3|4;5;6"
zaguan show json '{"name":"test","value":42}'
zaguan show bar 75 --label "Progress"
zaguan show breadcrumbs Home Projects App
zaguan show list --header "Items:" "One" "Two" "Three"
```

### Color commands
```bash
zaguan color red
zaguan color "#FF0000"
zaguan color "rgb:255,0,0"
zaguan color --colors
zaguan color "#FF0000" --harmony triad
```

### Run commands
```bash
zaguan run --command "echo hello"
zaguan run --command "sleep 1" --command "echo done" --parallel 2
```

### Action commands
```bash
echo '{"action":"show","args":["message","Hello"]}' | zaguan action
```

### Config commands
```bash
zaguan config init
zaguan config get http.port
zaguan config set http.port 8081
```

### Casos límite (importantes para ElPaso)
```bash
# Texto largo
zaguan show table --headers "Name;Description" --rows "very-long-name-here;this is a very long description that exceeds normal column widths"

# Contenido con caracteres especiales
zaguan show table --headers "Emoji;Text" --rows "🚀;Rocket|🎯;Target"

# Tabla sin bordes (table_border: none)
zaguan show table --headers "A;B" --rows "1;2" --border none

# Tabla con padding grande
zaguan show table --headers "X;Y" --rows "a;b" --padding 4
```

---

## Conclusión

El bug de las tablas descuadradas en ElPaso **no era un bug de Zaguan**, sino un **uso incorrecto de Zaguan** en ElPaso. Tras esta revisión completa, ElPaso aprovecha activamente múltiples componentes de Zaguan:

**Componentes utilizados:**
- `Zaguan.Drawer.Components.Table` — Todas las listas y tablas (list, show, status, stats, rules, config)
- `Zaguan.Drawer.Components.Header` — Títulos de sección en show, server start, cluster status, router stats
- `Zaguan.Drawer.Components.Separator` — División visual entre secciones (config, context, server, router stats)
- `Zaguan.Drawer.Components.Json` — Output JSON con syntax highlighting (router stats --format json)

**Beneficios obtenidos:**
- ✅ Cálculo automático de anchos de columna
- ✅ Alineación correcta independientemente del contenido
- ✅ Bordes consistentes y cuadrados
- ✅ Compatibilidad con caracteres especiales y contenido variable
- ✅ Jerarquía visual clara con headers y separadores
- ✅ Experiencia CLI profesional y coherente en todos los comandos
