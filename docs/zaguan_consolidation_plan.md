# Plan de Consolidación ElPaso ↔ Zaguan (Actualizado)

## Estado actual de Zaguan (post-cambios)

Zaguan ha recibido una reescritura masiva del CLI y mejoras significativas en drawer/engine:

### Drawer Components — Nuevas capacidades

| Componente | Estado | Novedades relevantes para ElPaso |
|------------|--------|----------------------------------|
| `Table` | ✅ Mejorado | Por-fila-coloreado (`rows_0_color`), por-columna, alineación, efectos, borders custom, padding, `table_align` |
| `Box` | ✅ Mejorado | Título en borde, padding, width, border styles (`single`, `double`, `rounded`, `bold`, `none`) |
| `Header` | ✅ Estable | `size: :small` / `:medium` / `:large` |
| `Separator` | ✅ Estable | `char`, `width`, `color` |
| `Bar` | ✅ Estable | Métricas porcentuales |
| `Breadcrumbs` | ✅ Estable | Rutas de navegación |
| `Json` | ✅ Estable | Pretty-print con syntax highlighting |
| `Message` (nuevo) | ✅ Nuevo | `Zaguan.CLI.Commands.Show.Message` — mensajes tipados nativos |

### CLI de Zaguan — Nuevos subcomandos tipados

```
zaguan show success "mensaje"
zaguan show error "mensaje"
zaguan show warning "mensaje"
zaguan show info "mensaje"
zaguan show debug "mensaje"
zaguan show notice "mensaje"
zaguan show critical "mensaje"
zaguan show alert "mensaje"
zaguan show emergency "mensaje"
zaguan show happy "mensaje"
zaguan show sad "mensaje"
```

Cada uno con emojis, colores y efectos predefinidos. **ElPaso podría delegar directamente en estos** en lugar de reimplementar `Output.success/error/warning/info`.

### Engine — Componentes de orquestación

| Módulo | Función | Estado en ElPaso |
|--------|---------|------------------|
| `Zaguan.Engine` | Fachada de ejecución (shell/funciones) | No usado — ElPaso usa `Domain.ModelManager` |
| `Zaguan.Engine.Leader` | Coordina workers paralelos, batches, stats | No usado — ElPaso no tiene orquestación |
| `Zaguan.Engine.CircuitBreaker` | Tolerancia a fallos con estados `:closed/:open/:half_open` | No usado — ElPaso no tiene circuit breaker |
| `Zaguan.Engine.Parallel` | Ejecución paralela de comandos | No usado — `bench.ex` usa `Enum.map` secuencial |
| `Zaguan.Engine.Worker` | Worker GenServer para tareas | No usado — `SummarizationWorker` es manual |
| `Zaguan.Engine.Supervisor` | Árbol de supervisión completo | No usado — supervisores de ElPaso están vacíos |

### Configuración — Sistema de temas

| Módulo | Función | Estado en ElPaso |
|--------|---------|------------------|
| `Zaguan.Config` | Get/set por capas | Duplicado por `ElPaso.Config` |
| `Zaguan.Config.Loader` | Carga JSON, temas, semantic tokens | Duplicado por `ElPaso.Config.Loader` (TOML/INI) |
| `Zaguan.Config.Global` | Paths de config y themes | Duplicado por paths hardcodeados en ElPaso |

### Telemetry — Métricas

| Módulo | Función | Estado en ElPaso |
|--------|---------|------------------|
| `Zaguan.Telemetry` | `measure/1`, `emit/3`, `measure_with_result/1` | Duplicado por `ElPaso.Telemetry.Store` |
| `Zaguan.Telemetry.CommunicationMetrics` | Métricas de comunicación | No usado en ElPaso |
| `Zaguan.Telemetry.Metrics` | Setup de handlers | No usado en ElPaso |

---

## Duplicaciones funcionales detectadas (actualizado)

### Alta prioridad — Eliminar duplicación directa

#### 1. Mensajes flash semánticos
**Zaguan ahora tiene:** `Zaguan.CLI.Commands.Show.Message.run_typed/2` con 11 tipos de mensajes.

**ElPaso tiene:** `ElPaso.CLI.Output.success/1`, `error/1`, `info/1`, `warning/1` que usan emojis Unicode.

**Acción:** Migrar `Output` para que use `Zaguan.Drawer.Components.Message` o los tipados de CLI. Si Zaguan expone una API pública directa (no solo CLI), usarla. Si no, mantener `Output` como wrapper pero documentar que es un bridge temporal.

#### 2. Engine Registry
**Zaguan tiene:** `Zaguan.Engine.Registry` (Registry de Elixir nativo) dentro del supervision tree.

**ElPaso tiene:** `ElPaso.Engine.Registry` — GenServer manual con ETS que hace exactamente lo mismo.

**Acción:** Reemplazar `ElPaso.Engine.Registry` por `Zaguan.Engine.Registry`. Ajustar `ElPaso.Application` para incluir el `Zaguan.Engine.Supervisor` en el árbol de supervisión.

#### 3. Supervisores vacíos
**Zaguan tiene:** `Zaguan.Engine.Supervisor` con Registry, CircuitBreaker.Registry, Monitor, Leader, WorkerSupervisor.

**ElPaso tiene:** `SessionSupervisor`, `SummarizationSupervisor`, `Event.Supervisor` — todos con `children = []`.

**Acción:** Eliminar los supervisores vacíos. Si ElPaso necesita workers para sesiones o resúmenes, usarlos bajo el `WorkerSupervisor` de Zaguan.

### Media prioridad — Consolidar funcionalidad

#### 4. Benchmark paralelo
**Zaguan tiene:** `Zaguan.Engine.Parallel.run/2` y `Zaguan.Engine.Leader` para ejecución paralela con monitoreo.

**ElPaso tiene:** `ElPaso.CLI.Commands.Bench.run/1` usa `Enum.map/2` secuencial.

**Acción:** Refactorizar `Bench` para usar `Zaguan.Engine.run/2` o `Zaguan.Engine.Leader`. Esto añadiría circuit breaker, timeout y monitoreo nativo.

#### 5. Circuit breaker para modelos
**Zaguan tiene:** `Zaguan.Engine.CircuitBreaker` con estados `:closed/:open/:half_open`, threshold configurable, timeout.

**ElPaso tiene:** Nada. `ModelManager.infer/2` no maneja fallos consecutivos ni desactivación automática de modelos.

**Acción:** Integrar `Zaguan.Engine.CircuitBreaker` en `ElPaso.Domain.ModelManager`. Cada modelo tendría su propio breaker. Si falla N veces, se marca como `:disabled` hasta que el breaker se cierre.

#### 6. Sistema de config/temas
**Zaguan tiene:** Sistema completo de temas JSON con semantic tokens, color harmonies, validación.

**ElPaso tiene:** Parseo manual de TOML/INI, colores RGB hardcodeados en `Output`.

**Acción:** Evaluar migrar configuración de ElPaso a JSON para usar `Zaguan.Config.Loader`. Definir un tema "elpaso" en Zaguan con los colores corporativos. Esto eliminaría `ElPaso.Config.Loader` y permitiría temas oscuros/claros.

### Baja prioridad — Oportunidades futuras

#### 7. Telemetry
**Zaguan tiene:** `Zaguan.Telemetry` con `measure/1`, eventos estructurados.

**ElPaso tiene:** `ElPaso.Telemetry.Store` — GenServer manual con cola de eventos.

**Acción:** Evaluar si `Zaguan.Telemetry` cubre las necesidades de ElPaso (dashboard queries, ratios de cache). Si es suficiente, migrar.

#### 8. Colores corporativos
**Zaguan tiene:** `Zaguan.Drawer.Colour.Orchestrator.parse_color/1`, gradients, harmonies.

**ElPaso tiene:** Tuplas RGB hardcodeadas en `Output`.

**Acción:** Definir un tema Zaguan para ElPaso y cargar colores desde `Zaguan.Config.load_theme/1`.

---

## Plan de acción propuesto

### Fase 1: Mensajes flash (1 día)
- [ ] Investigar si `Zaguan.Drawer.Components.Message` es una API pública (no solo CLI).
- [ ] Si existe API pública: migrar `Output.success/error/info/warning` a Zaguan nativo.
- [ ] Si no existe: mantener `Output` como wrapper pero documentar como bridge temporal.
- [ ] Aprovechar nuevas capacidades de `Box` (título, padding) en `Output.alert_box/2`.

### Fase 2: Engine Registry + Supervisores (1 día)
- [ ] Reemplazar `ElPaso.Engine.Registry` por `Zaguan.Engine.Registry`.
- [ ] Añadir `Zaguan.Engine.Supervisor` al árbol de `ElPaso.Application`.
- [ ] Eliminar `SessionSupervisor`, `SummarizationSupervisor`, `Event.Supervisor` vacíos.
- [ ] Actualizar tests.

### Fase 3: Circuit Breaker para modelos (2 días)
- [ ] Integrar `Zaguan.Engine.CircuitBreaker` en `ElPaso.Domain.ModelManager`.
- [ ] Un breaker por modelo (nombre del modelo como clave).
- [ ] Añadir lógica: si breaker está `:open`, modelo se marca como `active: false` temporalmente.
- [ ] Añadir endpoint/recovery para resetear breakers.
- [ ] Tests.

### Fase 4: Benchmark paralelo (1 día)
- [ ] Refactorizar `ElPaso.CLI.Commands.Bench` para usar `Zaguan.Engine.run/2`.
- [ ] Añadir opción `--workers` para paralelismo.
- [ ] Usar `Zaguan.Engine.Leader.subscribe/0` para monitoreo de progreso.

### Fase 5: Configuración y temas (2 días)
- [ ] Evaluar migrar config de TOML/INI a JSON.
- [ ] Crear tema "elpaso" en `~/.config/zaguan/themes/`.
- [ ] Migrar `ElPaso.Config.Loader` para usar `Zaguan.Config.Loader` donde sea posible.
- [ ] Cargar colores corporativos desde tema en lugar de hardcodear.

### Fase 6: Tablas avanzadas (1 día)
- [ ] Aprovechar nuevas opciones de `Table` en `Output.data_table/3`:
  - `border_color`, `border_effects`
  - `headers_effects: [:bold]`
  - `rows_color` por columna
  - `table_align: :center`
- [ ] Revisar todos los comandos que usan tablas para aplicar estilos consistentes.

---

## Métricas de éxito

| Métrica | Objetivo |
|---------|----------|
| Líneas de código duplicadas eliminadas | -500+ |
| Supervisores vacíos eliminados | 3 |
| Componentes Zaguan adoptados nuevos | 4 (CircuitBreaker, Leader, Message, Theme) |
| Tests sin regresiones | 304+ |

---

## Notas técnicas

### Dependencia circular
ElPaso depende de Zaguan como `path: "../zaguan"`. Para usar `Zaguan.Engine.Supervisor`, ElPaso debe iniciar `:zaguan` como aplicación dependiente o incluir sus supervisores en su propio árbol.

### Compatibilidad de config
`Zaguan.Config.Loader` usa JSON. `ElPaso.Config.Loader` usa TOML/INI. La migración requiere cambiar formato de config o mantener dos loaders (no recomendado).

### Circuit breaker y base de datos
El circuit breaker de Zaguan es en memoria (GenServer). Si ElPaso quiere persistir el estado de breakers entre reinicios, necesitaría una capa adicional sobre `Zaguan.Engine.CircuitBreaker.State`.
