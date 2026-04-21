defmodule ElPaso.MixProject do
  use Mix.Project

  def project do
    [
      app: :elpaso,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ElPaso.Application, []}
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.7"},
      {:finch, "~> 0.19"},
      {:jason, "~> 1.4"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, "~> 0.17"},
      {:pgvector, "~> 0.2"},
      {:nimble_options, "~> 1.1"},
      {:telemetry, "~> 1.2"},
      {:zaguan, path: "../zaguan"}
    ]
  end
end
