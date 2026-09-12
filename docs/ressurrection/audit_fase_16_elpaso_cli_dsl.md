# elpaso — CLI 100% alaja DSL (iter-049)

> **Fecha**: 2026-09-12
> **Mandato**: elpaso CLI debe usar 100% el DSL de alaja.
> **Estrategia**: reescribir top-level commands + subcommands via DSL, mantener
> legacy handler como fallback.

---

## Estado actual

`lib/el_paso/cli.ex` (1915 LOC, 80 funciones) — hand-rolled con pattern
matching.

## Plan iter-049

### Fase 1: Top-level commands via DSL

```elixir
defmodule ElPaso.CLI.Definition do
  use Alaja.CLI.Definition, otp_app: :elpaso

  command "init", "Inicializar ElPaso" do
    run fn _opts -> Elpaso.Init.run() end
  end

  command "model", "Gestión de modelos" do
    subcommand "list", "Lista modelos", do: run fn _ -> Elpaso.Model.list() end
    subcommand "add", "Añadir modelo", do: ...
    ...
  end

  command "engine", "Gestión de motores" do
    subcommand "list", "Lista motores", do: ...
    ...
  end

  command "config", "Gestión de configuración" do
    subcommand "show", "Muestra config", do: ...
    subcommand "set", "Establece key/value", do: ...
    ...
  end

  ...
end
```

### Fase 2: Main delega a Definition

```elixir
defmodule ElPaso.CLI do
  def main(args), do: ElPaso.CLI.Definition.main(args)
end
```

### Fase 3: Legacy fallback

`lib/el_paso/cli.ex` mantiene `legacy_dispatch/1` para tests internos.

## Acceptance

- [ ] `ElPaso.CLI.Definition` reescrito con DSL.
- [ ] `ElPaso.CLI.main/1` delega a `Definition.main/1`.
- [ ] Tests verifican help + comandos principales.
