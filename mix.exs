if System.otp_release() < "28" do
  raise "ElPaso requires OTP 28+."
end

defmodule ElPaso.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/Lorenzo-SF/ElPaso"
  @elixir_vsn "1.19.5"
  @erlang_vsn "28.0"
  @otp_vsn "28"
  @binary_name "elpaso"

  def project do
    [
      app: :elpaso,
      version: @version,
      elixir: "~> " <> @elixir_vsn,
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      batamanta: batamanta(),
      test_coverage: test_coverage(),
      dialyzer: dialyzer(),
      docs: docs(),
      package: package(),
      aliases: aliases()
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    if Mix.env() == :test do
      [extra_applications: [:logger, :crypto]]
    else
      [
        mod: {ElPaso.Application, []},
        extra_applications: [:logger, :crypto]
      ]
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:plug, "~> 1.19"},
      {:plug_cowboy, "~> 2.7"},
      {:finch, "~> 0.19"},
      {:jason, "~> 1.4"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, "~> 0.17"},
      {:pgvector, "~> 0.2"},
      {:nimble_options, "~> 1.1"},
      {:telemetry, "~> 1.2"},
      {:libcluster, "~> 3.4"},
      {:jose, "~> 1.11"},
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:telemetry_metrics_prometheus, "~> 1.1"},
      # batamanta is private; CI for the public repos cannot access it.
      # ElPaso uses batamanta at release time only (mix batamanta).
      # Tests run without it; the runtime side that references it is
      # defensive (Code.ensure_loaded? guards).
      # {:batamanta, path: "../batamanta", runtime: false},

      # Dev/Test only
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}

      # Zaguan and apero are intentionally NOT included in deps here.
      # ElPaso uses poke at runtime via the Code.ensure_loaded guards;
      # the optional/sibling_or_git pattern tried earlier caused mix to
      # fetch zaguan in test env and fail because private-repo deps can't
      # be reached in CI. The runtime side that references these libs is
      # defensive (already uses Code.ensure_loaded?).
    ]
  end

  defp escript do
    [main_module: ElPaso.CLI]
  end

  defp batamanta do
    [
      format: :escript,
      execution_mode: :cli,
      compression: 1,
      binary_name: @binary_name
    ]
  end

  defp test_coverage do
    [
      ignore_modules: [
        ElPaso.CLI,
        ElPaso.CLI.Commands,
        ElPaso.CLI.Commands.RouterStats,
        ElPaso.HTTP.Server,
        ElPaso.HTTP.WebSocketHandler,
        ElPaso.HTTP.Dashboard,
        ElPaso.Engine.Plugin.Echo,
        ElPaso.Application,
        ElPaso.Examples.Pipeline,
        ElPaso.Repo,
        Mix.Tasks.Elpaso,
        Mix.Tasks.Elpaso.Engine,
        Mix.Tasks.Elpaso.Engine.Add,
        Mix.Tasks.Elpaso.Engine.List,
        Mix.Tasks.Elpaso.Engine.Remove,
        Mix.Tasks.Elpaso.Engine.Test,
        Mix.Tasks.Elpaso.Init,
        Mix.Tasks.Elpaso.Model,
        Mix.Tasks.Elpaso.Model.Add,
        Mix.Tasks.Elpaso.Model.List,
        Mix.Tasks.Elpaso.Model.Remove,
        Mix.Tasks.Elpaso.Model.Start,
        Mix.Tasks.Elpaso.Model.Stop,
        Mix.Tasks.Elpaso.Personality,
        Mix.Tasks.Elpaso.RegisterWrapper
      ],
      summary: [
        threshold: 70
      ]
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "_build/plts/dialyzer.plt"},
      plt_core_path: "_build/plts",
      flags: ["-Wno_return", "-Wno_match"],
      plt_add_apps: [:mix],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "README_ES.md"],
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      description:
        "Multi-model LLM proxy for Elixir. OpenAI-compatible gateway with smart routing, session management, and support for local (Ollama, vLLM) and remote (OpenAI, Anthropic) inference engines.",
      licenses: ["MIT"],
      maintainers: ["Lorenzo-SF"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md README_ES.md LICENSE .formatter.exs)
    ]
  end

  defp aliases do
    [
      gen: ["compile", "batamanta", "deploy", "tools_version"],
      quality: [
        "format",
        "compile",
        "credo --strict",
        "dialyzer"
      ],
      setup: ["deps.get"],
      "test.coverage": ["test --cover"],
      lint: ["format --check-formatted", "credo --strict"],
      "lint.fix": ["format", "credo --strict"],
      deploy: fn _ ->
        dest_dir = Path.expand("~/.elpaso")
        File.mkdir_p!(dest_dir)

        case File.cp("elpaso", Path.join(dest_dir, "elpaso")) do
          :ok ->
            File.chmod!(Path.join(dest_dir, "elpaso"), 0o755)
            Mix.shell().info("✅ Escript installed in #{dest_dir}/elpaso")

          {:error, _} ->
            Mix.shell().error("❌ Could not copy executable")
        end
      end,
      tools_version: fn _ ->
        dest_dir = Path.expand("~/.elpaso")
        path = Path.join(dest_dir, ".tool-versions")
        File.write!(path, "erlang #{@erlang_vsn}\nelixir #{@elixir_vsn}-otp-#{@otp_vsn}\n")
        Mix.shell().info("✅ .tool-versions updated")
      end
    ]
  end
end
