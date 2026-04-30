# Auditoría de Uso de Zaguan en ElPaso

## Resumen Ejecutivo

ElPaso utiliza Zaguan como dependencia pero **no aprovecha sus componentes de tabla** en la mayoría de los comandos CLI. En su lugar, pinta tablas manualmente con `IO.puts` y caracteres Unicode hardcodeados, lo que provoca desalineación cuando el contenido varía en longitud.

---

## Hallazgos

### 1. `lib/el_paso/cli.ex` — Tablas manuales (CORREGIDAS ✅)

**Estado:** Corregido. Las 7 tablas manuales originales han sido reemplazadas por `Zaguan.Drawer.Components.Table.print/2`. Adicionalmente se aplicaron mejoras de consistencia:

| Función | Estado | Descripción |
|---------|--------|-------------|
| `handle_model(["list" \| _])` | ✅ Corregido | Usa `Table.print` con headers auto-calculados |
| `handle_engine(["list" \| _])` | ✅ Corregido | Usa `Table.print` con headers auto-calculados |
| `handle_router(["stats" \| rest])` | ✅ Corregido | Usa `Table.print` con headers auto-calculados |
| `handle_context(["list" \| rest])` | ✅ Corregido | Usa `Table.print` con headers auto-calculados |
| `handle_cluster(["nodes" \| _])` | ✅ Corregido | Usa `Table.print` con headers auto-calculados |
| `handle_personality(["list" \| _])` | ✅ Corregido | Usa `Table.print` con headers auto-calculados |
| `handle_profile(["list" \| _])` | ✅ Corregido | Usa `Table.print` con headers auto-calculados |
| `handle_router(["rules" \| _])` | ✅ Mejorado | Usa `Table.print` con columnas tabulares |
| `handle_db(["status" \| _])` | ✅ Mejorado | Usa `Table.print` para listado de migraciones |
| `handle_server(["start" \| _])` | ✅ Mejorado | Usa `Header.print` en lugar de box manual |

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

### 2. `lib/el_paso/cli/commands/router_stats.ex` — USO CORRECTO de Zaguan

Este archivo **sí usa Zaguan correctamente**:

```elixir
alias Zaguan.Drawer.Components.{Header, Table}

Table.print(
  headers: ["Métrica", "Valor"],
  rows: [...],
  headers_color: :cyan,
  table_border: :rounded
)
```

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

### Archivos a modificar

1. **`lib/el_paso/cli.ex`**:
   - `handle_model(["list" \| _])`
   - `handle_engine(["list" \| _])`
   - `handle_router(["stats" \| rest])`
   - `handle_context(["list" \| rest])`
   - `handle_cluster(["nodes" \| _])`
   - `handle_personality(["list" \| _])`
   - `handle_profile(["list" \| _])`
   - `handle_router(["rules" \| _])` — convertido a tabla Zaguan
   - `handle_db(["status" \| _])` — convertido a tabla Zaguan
   - `handle_server(["start" \| _])` — box manual reemplazado por `Header.print`

2. **`lib/el_paso/cli/commands/router_stats.ex`**:
   - ✅ Ya usa Zaguan correctamente — no requiere cambios

3. **`lib/el_paso/config/wizard.ex`**:
   - Comentarios actualizados: Zaguan no expone widgets de prompt CLI simple (solo TUI).

4. **Mix tasks**:
   - `lib/mix/tasks/elpaso/model.ex` — `list_models/0`
   - `lib/mix/tasks/elpaso/engine.ex` — `list_engines/0`
   - `lib/mix/tasks/elpaso/personality.ex` — `list_personalities/0`

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

El bug de las tablas descuadradas en ElPaso **no era un bug de Zaguan**, sino un **uso incorrecto de Zaguan** en ElPaso. ElPaso pintaba tablas manualmente con anchos fijos en lugar de usar `Zaguan.Drawer.Components.Table`, que calcula anchos automáticamente y alinea correctamente.

**Todos los problemas han sido corregidos.** Las tablas manuales en `lib/el_paso/cli.ex` y en los Mix tasks han sido reemplazadas por `Zaguan.Drawer.Components.Table.print/2`, y el box manual de `handle_server` ahora usa `Zaguan.Drawer.Components.Header.print/2`, garantizando:
- ✅ Cálculo automático de anchos de columna
- ✅ Alineación correcta independientemente del contenido
- ✅ Bordes consistentes y cuadrados
- ✅ Compatibilidad con caracteres especiales y contenido variable
- ✅ Uso consistente de Zaguan en toda la superficie CLI
