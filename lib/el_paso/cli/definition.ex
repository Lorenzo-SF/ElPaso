defmodule ElPaso.CLI.Definition do
  @moduledoc """
  CLI declaration for ElPaso using `Alaja.CLI.Definition`.

  This module replaces the 1915-LOC hand-rolled `ElPaso.CLI` with a
  declarative DSL.  Each top-level command is declared with
  `command name, description do ... end`.  Subcommands are
  declared with `subcommand name, description do ... end`.

  The legacy hand-rolled dispatcher is preserved in
  `ElPaso.CLI.legacy_dispatch/1` for backwards compatibility with
  internal tests and edge cases not yet migrated.

  See `docs/ressurrection/audit_fase_16_elpaso_cli_dsl.md` for
  the migration plan.

  ## Why DSL

  - **Auto-generated help**: `Alaja.CLI.Help.render/2` produces
    formatted help text from the DSL.
  - **Type-safe flags**: each flag has a type and validation.
  - **Self-documenting**: the command map is the documentation.
  - **No argv parsing logic in the back**: all parsing is the DSL's job.
  """

  use Alaja.CLI.Definition, otp_app: :elpaso

  # ─── init ───────────────────────────────────────────────────────────────

  command "init", "Inicializar ElPaso (crea DB, schema, default config)" do
    run fn _opts -> Elpaso.Init.run() end
  end

  # ─── model ──────────────────────────────────────────────────────────────

  command "model", "Gestión de modelos de inferencia" do
    subcommand "list", "Lista todos los modelos" do
      run fn _opts -> Elpaso.Model.list() end
    end

    subcommand "add", "Añadir un modelo" do
      argument :name, :string, required: true
      flag :provider, :atom, default: :openai
      flag :model, :string, default: nil

      run fn opts ->
        Elpaso.Model.add(opts.name, opts.provider, opts.model)
      end
    end

    subcommand "delete", "Eliminar un modelo" do
      argument :name, :string, required: true

      run fn opts -> Elpaso.Model.delete(opts.name) end
    end

    subcommand "update", "Actualizar un modelo" do
      argument :name, :string, required: true
      flag :provider, :atom, default: nil
      flag :model, :string, default: nil

      run fn opts -> Elpaso.Model.update(opts.name, opts) end
    end

    subcommand "show", "Mostrar detalles de un modelo" do
      argument :name, :string, required: true

      run fn opts -> Elpaso.Model.show(opts.name) end
    end

    subcommand "start", "Iniciar un modelo" do
      argument :name, :string, required: true

      run fn opts -> Elpaso.Model.start(opts.name) end
    end

    subcommand "stop", "Detener un modelo" do
      argument :name, :string, required: true

      run fn opts -> Elpaso.Model.stop(opts.name) end
    end
  end

  # ─── engine ─────────────────────────────────────────────────────────────

  command "engine", "Gestión de motores de inferencia" do
    subcommand "list", "Lista motores" do
      run fn _opts -> Elpaso.Engines.list() end
    end

    subcommand "add", "Añadir motor" do
      argument :name, :string, required: true
      flag :binary, :string, default: nil
      flag :host, :string, default: "127.0.0.1"
      flag :port, :integer, default: 8080

      run fn opts -> Elpaso.Engines.add(opts.name, opts) end
    end

    subcommand "delete", "Eliminar motor" do
      argument :name, :string, required: true

      run fn opts -> Elpaso.Engines.delete(opts.name) end
    end

    subcommand "update", "Actualizar motor" do
      argument :name, :string, required: true
      flag :binary, :string, default: nil
      flag :host, :string, default: nil
      flag :port, :integer, default: nil

      run fn opts -> Elpaso.Engines.update(opts.name, opts) end
    end

    subcommand "show", "Mostrar detalles de motor" do
      argument :name, :string, required: true

      run fn opts -> Elpaso.Engines.show(opts.name) end
    end

    subcommand "test", "Probar un motor" do
      argument :name, :string, required: true

      run fn opts -> Elpaso.Engines.test(opts.name) end
    end
  end

  # ─── personality ────────────────────────────────────────────────────────

  command "personality", "Gestión de personalidades/roles" do
    subcommand "list", "Lista personalidades" do
      run fn _opts -> Elpaso.Personality.list() end
    end

    subcommand "add", "Añadir personalidad" do
      argument :name, :string, required: true
      flag :system_prompt, :string, default: ""

      run fn opts -> Elpaso.Personality.add(opts.name, opts.system_prompt) end
    end

    subcommand "delete", "Eliminar personalidad" do
      argument :name, :string, required: true

      run fn opts -> Elpaso.Personality.delete(opts.name) end
    end

    subcommand "show", "Mostrar personalidad" do
      argument :name, :string, required: true

      run fn opts -> Elpaso.Personality.show(opts.name) end
    end

    subcommand "use", "Usar personalidad para una sesión" do
      argument :name, :string, required: true
      argument :session_id, :string, required: true

      run fn opts -> Elpaso.Personality.use(opts.name, opts.session_id) end
    end

    subcommand "embed", "Calcular embeddings para personalidad" do
      argument :name, :string, required: true

      run fn opts -> Elpaso.Personality.embed(opts.name) end
    end
  end

  # ─── config ──────────────────────────────────────────────────────────────

  command "config", "Gestión de configuración" do
    subcommand "show", "Muestra configuración actual" do
      run fn _opts -> Elpaso.Config.show() end
    end

    subcommand "set", "Establece un valor de configuración" do
      argument :key, :string, required: true
      argument :value, :string, required: true

      run fn opts -> Elpaso.Config.set(opts.key, opts.value) end
    end

    subcommand "reload", "Recarga configuración desde disco" do
      run fn _opts -> Elpaso.Config.reload() end
    end
  end

  # ─── db ─────────────────────────────────────────────────────────────────

  command "db", "Gestión de base de datos" do
    subcommand "create", "Crea la base de datos" do
      run fn _opts -> Elpaso.Db.create() end
    end

    subcommand "migrate", "Aplica migraciones pendientes" do
      run fn _opts -> Elpaso.Db.migrate() end
    end

    subcommand "status", "Muestra el estado de la DB" do
      run fn _opts -> Elpaso.Db.status() end
    end
  end

  # ─── server ─────────────────────────────────────────────────────────────

  command "server", "Gestión del servidor HTTP" do
    subcommand "start", "Inicia el servidor" do
      flag :port, :integer, default: 4000
      flag :host, :string, default: "0.0.0.0"

      run fn opts -> Elpaso.Server.start(port: opts.port, host: opts.host) end
    end

    subcommand "stop", "Detiene el servidor" do
      run fn _opts -> Elpaso.Server.stop() end
    end

    subcommand "restart", "Reinicia el servidor" do
      run fn _opts -> Elpaso.Server.restart() end
    end

    subcommand "status", "Muestra estado del servidor" do
      run fn _opts -> Elpaso.Server.status() end
    end

    subcommand "log", "Muestra logs del servidor" do
      flag :lines, :integer, default: 100

      run fn opts -> Elpaso.Server.log(lines: opts.lines) end
    end
  end

  # ─── doctor ─────────────────────────────────────────────────────────────

  command "doctor", "Diagnóstico completo del entorno" do
    flag :fix, :boolean, default: false

    run fn opts ->
      if opts.fix do
        ElPaso.Doctor.fix()
      else
        ElPaso.Doctor.run()
      end
    end
  end

  # ─── router ─────────────────────────────────────────────────────────────

  command "router", "Estadísticas y auto-tuneo del router" do
    subcommand "stats", "Muestra estadísticas del router" do
      run fn _opts -> Elpaso.Router.stats() end
    end

    subcommand "tune", "Auto-tune del router" do
      run fn _opts -> Elpaso.Router.tune() end
    end

    subcommand "rules", "Muestra reglas de routing" do
      run fn _opts -> Elpaso.Router.rules() end
    end
  end

  # ─── bench ──────────────────────────────────────────────────────────────

  command "bench", "Ejecutar benchmarks" do
    subcommand "run", "Ejecuta el benchmark" do
      flag :target, :string, default: "all"
      flag :duration, :integer, default: 60

      run fn opts -> Elpaso.Bench.run(target: opts.target, duration: opts.duration) end
    end
  end

  # ─── context ────────────────────────────────────────────────────────────

  command "context", "Gestionar contextos de sesión" do
    subcommand "list", "Lista contextos" do
      run fn _opts -> Elpaso.Context.list() end
    end

    subcommand "show", "Muestra contexto" do
      argument :id, :string, required: true

      run fn opts -> Elpaso.Context.show(opts.id) end
    end

    subcommand "delete", "Elimina contexto" do
      argument :id, :string, required: true

      run fn opts -> Elpaso.Context.delete(opts.id) end
    end
  end

  # ─── cluster ────────────────────────────────────────────────────────────

  command "cluster", "Estado del cluster" do
    run fn _opts -> Elpaso.Cluster.status() end
  end
end
