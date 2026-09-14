defmodule ElPaso.Doctor do
  @moduledoc """
  Diagnóstico del entorno ElPaso. Delega en `Apero.Doctor`.

  Comandos:
    elpaso doctor          — diagnóstico completo
    elpaso doctor --fix    — diagnóstico + reparación automática
  """

  @doc "Ejecuta diagnóstico."
  @spec run() :: :ok
  def run, do: ElPaso.Ecosystem.doctor_run(config())

  @doc "Ejecuta diagnóstico y repara automáticamente."
  @spec fix() :: :ok
  def fix, do: ElPaso.Ecosystem.doctor_fix(config())

  # ═══════════════════════════════════════════
  # CONFIGURACIÓN DE CHECKS
  # ═══════════════════════════════════════════

  defp config do
    pkg = ElPaso.Ecosystem.pkg_detect()

    %{
      app_name: "ElPaso",
      checks: [
        os_check(),
        elixir_otp_check(),
        pkg_manager_check(pkg),
        postgres_check(pkg),
        pgvector_check(),
        database_check(),
        migrations_check(),
        ollama_check(),
        embedding_model_check(),
        config_check(),
        deps_check()
      ]
    }
  end

  # ═══════════════════════════════════════════
  # CHECKS
  # ═══════════════════════════════════════════

  defp os_check do
    %{
      id: :os, name: "Sistema operativo", description: "SO compatible", priority: 1,
      check: fn ->
        case :os.type() do
          {:unix, _} ->
            distro = case File.read("/etc/os-release") do
              {:ok, c} -> c |> String.split("\n")
                |> Enum.find_value(fn l -> case String.split(l, "=", parts: 2) do
                  ["ID", id] -> String.trim(id, "\"")
                  _ -> nil
                end end) |> Kernel.||("linux")
              _ -> "linux"
            end
            {:ok, "Linux (#{distro})"}

          {:win32, _} ->
            {:error, "Windows no soportado. Usa WSL2."}
        end
      end,
      fix: fn ->
        case :os.type() do
          {:win32, _} -> {:error, "Instala WSL2 con Ubuntu 24.04"}
          _ -> :skipped
        end
      end,
      fix_command: "Instala WSL2 con Ubuntu 24.04"
    }
  end

  defp elixir_otp_check do
    %{
      id: :elixir_otp, name: "Elixir / OTP", description: "Versiones requeridas", priority: 2,
      check: fn ->
        ev = System.version()
        ov = System.otp_release()
        e_ok = Version.match?(ev, "~> 1.19")
        o_ok = String.to_integer(ov) >= 28

        if e_ok and o_ok do
          {:ok, "Elixir #{ev} / OTP #{ov}"}
        else
          {:error, "Elixir #{ev} / OTP #{ov} — necesita ≥ 1.19 / ≥ 28"}
        end
      end,
      fix: fn -> {:error, "Usa asdf: asdf install elixir 1.19.5-otp-28 && asdf global elixir 1.19.5-otp-28"} end,
      fix_command: "asdf install elixir 1.19.5-otp-28 && asdf global elixir 1.19.5-otp-28"
    }
  end

  defp pkg_manager_check(pkg) do
    %{
      id: :pkg_manager, name: "Gestor paquetes", description: "Para instalar dependencias", priority: 3,
      check: fn ->
        if pkg, do: {:ok, pkg.name()}, else: {:warning, "No detectado"}
      end,
      fix: fn -> :skipped end,
      fix_command: nil
    }
  end

  defp postgres_check(pkg) do
    docker_img = "pgvector/pgvector:pg17"

    %{
      id: :postgres, name: "PostgreSQL", description: "Base de datos + pgvector", priority: 10,
      check: fn ->
        cond do
          pg_ready_via_docker?() ->
            img = current_docker_image()
            if String.contains?(img || "", "pgvector") do
              {:ok, "Docker (pgvector incluido)"}
            else
              {:warning, "Docker SIN pgvector. Ejecuta: localdocker pgvector"}
            end
          pg_installed?() and pg_running?() -> {:ok, "Local (servicio activo)"}
          pg_installed?() -> {:warning, "Instalado pero no corriendo"}
          docker_installed?() -> {:warning, "No instalado. Usa: localdocker start"}
          true -> {:error, "No instalado"}
        end
      end,
      fix: fn ->
        cond do
          pg_ready_via_docker?() ->
            img = current_docker_image()
            if String.contains?(img || "", "pgvector") do
              {:ok, "Docker ya configurado con pgvector"}
            else
              {:error, "El contenedor no tiene pgvector. Ejecuta: localdocker pgvector"}
            end
          pg_installed?() and not pg_running?() ->
            cmd = pkg && pkg.service_command("postgresql", :start)
            case System.cmd("sudo", ["systemctl", "start", "postgresql"], stderr_to_stdout: true) do
              {_, 0} -> {:ok, "PostgreSQL arrancado"}
              _ -> {:error, cmd || "Arranca PostgreSQL manualmente"}
            end
          docker_installed?() ->
            case System.cmd("docker", ["run", "-d", "--name", "elpaso-pg",
                   "-e", "POSTGRES_PASSWORD=postgres", "-e", "POSTGRES_DB=elpaso_dev",
                   "-p", "5432:5432", docker_img], stderr_to_stdout: true) do
              {_, 0} -> {:ok, "Contenedor #{docker_img} creado"}
              {out, _} -> {:error, String.slice(out, 0, 100)}
            end
          true ->
            cmd = pkg && pkg.install_command(["postgresql-14", "postgresql-14-pgvector"])
            {:error, cmd || "Instala PostgreSQL + pgvector manualmente"}
        end
      end,
      fix_command: cond do
        docker_installed?() and not pg_ready_via_docker?() ->
          "localdocker start    # Crea contenedor con pgvector/pgvector:pg17 incluido"
        docker_installed?() and pg_ready_via_docker?() ->
          "localdocker pgvector # Instala pgvector en el contenedor existente (sin borrar datos)"
        true ->
          pkg && pkg.install_command(["postgresql-14", "postgresql-14-pgvector"])
      end
    }
  end

  defp pgvector_check do
    docker = pg_ready_via_docker?()

    %{
      id: :pgvector, name: "pgvector", description: "Extensión PostgreSQL", priority: 11,
      check: fn ->
        if pg_available?() do
          with_pg(fn conn ->
            case Postgrex.query(conn, "SELECT 1 FROM pg_extension WHERE extname = 'vector'", []) do
              {:ok, %{num_rows: 1}} -> {:ok, "Instalado"}
              {:ok, %{num_rows: 0}} -> {:error, "No instalado"}
              {:error, r} -> {:error, inspect(r)}
            end
          end) || {:warning, "No se pudo conectar"}
        else
          {:warning, "PostgreSQL no disponible"}
        end
      end,
      fix: fn ->
        with_pg(fn conn ->
          case Postgrex.query(conn, "SELECT 1 FROM pg_extension WHERE extname = 'vector'", []) do
            {:ok, %{num_rows: 1}} -> {:ok, "Ya instalado"}
            {:ok, %{num_rows: 0}} ->
              case Postgrex.query(conn, "CREATE EXTENSION IF NOT EXISTS vector", []) do
                {:ok, _} -> {:ok, "Extensión pgvector creada"}
                {:error, %{postgres: %{code: :undefined_file}}} ->
                  {:error, "pgvector no encontrado en el contenedor. Usa la imagen pgvector/pgvector:pg14"}
                {:error, r} -> {:error, inspect(r)}
              end
            {:error, r} -> {:error, inspect(r)}
          end
        end) || {:error, "No se pudo conectar a PostgreSQL"}
      end,
      fix_command: if docker do
        "localdocker pgvector    # Instala pgvector en el contenedor SIN borrar datos"
      else
        "sudo apt install postgresql-14-pgvector && psql -U postgres -d elpaso_dev -c \"CREATE EXTENSION vector;\""
      end
    }
  end

  defp database_check do
    %{
      id: :database, name: "Base de datos", description: "BD de ElPaso", priority: 12,
      check: fn ->
        if pg_available?() do
          with_pg(fn conn ->
            db = db_name()
            case Postgrex.query(conn, "SELECT 1 FROM pg_database WHERE datname = $1", [db]) do
              {:ok, %{num_rows: 1}} -> {:ok, "'#{db}' existe"}
              {:ok, %{num_rows: 0}} -> {:error, "'#{db}' no existe"}
              {:error, r} -> {:error, inspect(r)}
            end
          end) || {:warning, "No se pudo conectar"}
        else
          {:warning, "PostgreSQL no disponible"}
        end
      end,
      fix: fn ->
        with_pg(fn conn ->
          db = db_name()
          case Postgrex.query(conn, "SELECT 1 FROM pg_database WHERE datname = $1", [db]) do
            {:ok, %{num_rows: 1}} -> {:ok, "Ya existe"}
            {:ok, %{num_rows: 0}} ->
              Postgrex.query!(conn, "CREATE DATABASE #{db}", [])
              {:ok, "Base de datos '#{db}' creada"}
            {:error, r} -> {:error, inspect(r)}
          end
        end) || {:error, "No se pudo conectar"}
      end,
      fix_command: "mix ecto.create"
    }
  end

  defp migrations_check do
    %{
      id: :migrations, name: "Migraciones", description: "Schema BD", priority: 13,
      check: fn ->
        if pg_available?() do
          with_pg(fn conn ->
            db = db_name()
            case Postgrex.query(conn, "SELECT 1 FROM pg_database WHERE datname = $1", [db]) do
              {:ok, %{num_rows: 0}} -> {:warning, "BD no existe — pendiente"}
              {:ok, %{num_rows: 1}} ->
                case System.cmd("mix", ["ecto.migrate", "--dry-run"], stderr_to_stdout: true, cd: File.cwd!()) do
                  {output, 0} ->
                    if String.contains?(output, "already up") or String.contains?(output, "no migrations"),
                      do: {:ok, "Al día"},
                      else: {:warning, "Pendientes"}
                  {output, _} -> {:error, String.slice(output, 0, 150)}
                end
              {:error, r} -> {:error, inspect(r)}
            end
          end) || {:warning, "No se pudo conectar"}
        else
          {:warning, "PostgreSQL no disponible"}
        end
      end,
      fix: fn ->
        case System.cmd("mix", ["ecto.migrate"], stderr_to_stdout: true, cd: File.cwd!()) do
          {output, 0} ->
            {:ok, String.slice(String.trim(output), 0, 80)}
          {output, _} ->
            if String.contains?(output, "already up"),
              do: {:ok, "Ya al día"},
              else: {:error, String.slice(output, 0, 150)}
        end
      end,
      fix_command: "mix ecto.migrate"
    }
  end

  defp ollama_check do
    %{
      id: :ollama, name: "Ollama", description: "Servidor de modelos", priority: 20,
      check: fn ->
        installed = System.find_executable("ollama") != nil
        cond do
          !installed -> {:error, "No instalado"}
          ollama_running?() ->
            models = list_ollama_models()
            {:ok, "OK — #{length(models)} modelo(s)"}
          true -> {:warning, "Instalado pero no corriendo"}
        end
      end,
      fix: fn ->
        if System.find_executable("ollama") == nil do
          {:error, "curl -fsSL https://ollama.com/install.sh | sh"}
        else
          if ollama_running?() do
            {:ok, "Ya está corriendo"}
          else
            case System.cmd("ollama", ["serve"], stderr_to_stdout: true) do
              {_, 0} -> {:ok, "Ollama arrancado"}
              {_out, _} -> {:error, "Arranca manualmente: ollama serve"}
            end
          end
        end
      end,
      fix_command: "curl -fsSL https://ollama.com/install.sh | sh"
    }
  end

  defp embedding_model_check do
    %{
      id: :embedding_model, name: "Modelo embeddings", description: "nomic-embed-text o bge-m3", priority: 21,
      check: fn ->
        if ollama_running?() do
          available = detect_embedding_models()
          if available != [],
            do: {:ok, Enum.join(available, ", ")},
            else: {:warning, "No descargado"}
        else
          {:warning, "Ollama no disponible"}
        end
      end,
      fix: fn ->
        if ollama_running?() do
          model = "nomic-embed-text"
          unless model_available?(model) do
            IO.puts("   ⬇  Descargando #{model} (274 MB)...")
            case System.cmd("ollama", ["pull", model], stderr_to_stdout: true) do
              {_, 0} -> {:ok, "#{model} descargado"}
              {out, c} -> {:error, "ollama pull falló (#{c}): #{String.slice(out, 0, 100)}"}
            end
          else
            {:ok, "Ya descargado"}
          end
        else
          {:error, "Ollama no está corriendo. Arranca: ollama serve"}
        end
      end,
      fix_command: "ollama pull nomic-embed-text"
    }
  end

  defp config_check do
    %{
      id: :config, name: "Configuración", description: "~/.config/elpaso/elpaso.conf", priority: 30,
      check: fn ->
        path = Path.join(System.user_home!(), ".config/elpaso/elpaso.conf")
        if File.exists?(path),
          do: {:ok, path},
          else: {:warning, "No existe"}
      end,
      fix: fn ->
        case System.cmd("mix", ["elpaso", "init"], stderr_to_stdout: true, cd: File.cwd!()) do
          {_, 0} -> {:ok, "Configuración creada"}
          {out, _} -> {:error, String.slice(out, 0, 100)}
        end
      end,
      fix_command: "mix elpaso init"
    }
  end

  defp deps_check do
    %{
      id: :deps, name: "Dependencias", description: "Mix", priority: 31,
      check: fn ->
        if File.exists?("mix.lock"),
          do: {:ok, "Instaladas"},
          else: {:warning, "Falta mix.lock"}
      end,
      fix: fn ->
        case System.cmd("mix", ["deps.get"], stderr_to_stdout: true, cd: File.cwd!()) do
          {_, 0} -> {:ok, "Dependencias instaladas"}
          {out, _} -> {:error, String.slice(out, 0, 100)}
        end
      end,
      fix_command: "mix deps.get"
    }
  end

  # ═══════════════════════════════════════════
  # HELPERS (compartidos con Bootstrap)
  # ═══════════════════════════════════════════

  defp pg_ready_via_docker? do
    docker_installed?() and
      case System.cmd("docker", ["ps", "--format", "{{.Names}}"], stderr_to_stdout: true) do
        {output, 0} -> String.contains?(output, "postgres") or String.contains?(output, "pg")
        _ -> false
      end
  end

  defp current_docker_image do
    case System.cmd("docker", ["ps", "--format", "{{.Image}}", "--filter", "ancestor=postgres", "--filter", "ancestor=pgvector"], stderr_to_stdout: true) do
      {output, 0} ->
        output |> String.split("\n") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")) |> List.first()
      _ -> nil
    end
  end

  defp docker_installed?, do: System.find_executable("docker") != nil

  defp pg_installed? do
    System.find_executable("psql") != nil or
      System.find_executable("pg_isready") != nil or
      File.exists?("/usr/lib/postgresql") or
      File.exists?("/opt/homebrew/opt/postgresql@14")
  end

  defp pg_running? do
    {out, code} = System.cmd("pg_isready", ["-q"], stderr_to_stdout: true)

    if code == 0 do
      true
    else
      _ = out
      false
    end
  end

  defp pg_available?, do: pg_ready_via_docker?() or (pg_installed?() and pg_running?())

  defp ollama_running? do
    case Finch.build(:get, "http://localhost:11434/api/tags")
         |> Finch.request(ElPaso.Finch, receive_timeout: 3_000) do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  end

  defp list_ollama_models do
    case Finch.build(:get, "http://localhost:11434/api/tags")
         |> Finch.request(ElPaso.Finch, receive_timeout: 3_000) do
      {:ok, %{status: 200, body: b}} ->
        case Jason.decode(b) do
          {:ok, %{"models" => m}} -> Enum.map(m, &(&1["name"] || ""))
          _ -> []
        end
      _ -> []
    end
  end

  defp detect_embedding_models do
    models = list_ollama_models()
    Enum.filter(["nomic-embed-text", "bge-m3"], fn c ->
      Enum.any?(models, &String.starts_with?(&1, c))
    end)
  end

  defp model_available?(model) do
    case Finch.build(:get, "http://localhost:11434/api/tags")
         |> Finch.request(ElPaso.Finch, receive_timeout: 5_000) do
      {:ok, %{status: 200, body: b}} ->
        case Jason.decode(b) do
          {:ok, %{"models" => m}} ->
            Enum.any?(m, fn x -> String.starts_with?(x["name"] || "", model) end)
          _ -> false
        end
      _ -> false
    end
  end

  defp with_pg(fun) do
    config = db_config()

    case Postgrex.start_link(
           hostname: config[:host] || "localhost",
           username: config[:user] || "postgres",
           password: config[:password] || "postgres",
           database: "postgres",
           port: config[:port] || 5432,
           sync_connect: true,
           backoff_type: :stop,
           max_restarts: 0
         ) do
      {:ok, pid} ->
        try do
          fun.(pid)
        after
          Process.unlink(pid)
          GenServer.stop(pid, :normal, 1000)
        end

      {:error, _} -> nil
    end
  end

  defp db_config do
    config = ElPaso.Config.Loader.get!()
    db = config[:database] || %{}
    %{
      host: db[:host] || "localhost",
      user: db[:user] || "postgres",
      password: db[:password] || "postgres",
      name: db[:name] || "elpaso_dev",
      port: db[:port] || 5432
    }
  end

  defp db_name, do: db_config()[:name] || "elpaso_dev"
end
