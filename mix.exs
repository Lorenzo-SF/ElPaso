defmodule ElPaso.MixProject do
  use Mix.Project

  def project do
    [
      app: :elpaso,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps_path: "deps",
      build_path: "_build",
      description: "ElPaso project",
      deps: deps(),
      package: %{
        files: ["lib", "mix.exs", "README.md"],
        maintainers: [],
        licenses: ["MIT"],
        links: %{}
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ElPaso.Application, []}
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
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
      {:zaguan, path: "../zaguan"},
      {:telemetry_metrics_prometheus, "~> 1.1"}
    ]
  end

  # Escript configuration (unused but documented for future CLI)
  # defp escript do
  #   [
  #     main_module: ElPaso.CLI.Commands.RouterStats,
  #     name: "elpaso"
  #   ]
  # end
end
