defmodule Mix.Tasks.Elpaso.Engine.Add do
  @moduledoc """
  Añade un nuevo motor de inferencia a ElPaso.

  Uso:
      mix elpaso.engine.add <nombre> --adapter <adapter> --url <url> [opciones]

  Opciones:
      --adapter   Tipo de adapter (ej: llama_cpp, openai, ollama)
      --url       URL base del engine (ej: http://localhost:8081/v1)
      --api-key   API key opcional

  Ejemplo:
      mix elpaso.engine.add llama-local --adapter llama_cpp --url http://localhost:8081/v1 --api-key sk-local
  """

  use Mix.Task

  alias ElPaso.Repo
  alias ElPaso.Models.Engine

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {name, switches} =
      case args do
        [n | rest] -> {n, rest}
        _ -> {nil, args}
      end

    {opts, _, _} =
      OptionParser.parse(switches,
        strict: [
          adapter: :string,
          url: :string,
          api_key: :string
        ]
      )

    if is_nil(name) or is_nil(opts[:adapter]) or is_nil(opts[:url]) do
      IO.puts(:stderr, "Uso: mix elpaso.engine.add <nombre> --adapter <adapter> --url <url>")
      System.halt(1)
    end

    case Repo.get_by(Engine, name: name) do
      nil ->
        %Engine{}
        |> Engine.changeset(%{
          name: name,
          adapter: opts[:adapter],
          base_url: opts[:url],
          api_key: opts[:api_key],
          active: true
        })
        |> Repo.insert!()

        IO.puts("✅ Engine '#{name}' registrado.")

      existing ->
        IO.puts("ℹ️  Engine '#{existing.name}' ya existe.")
    end
  end
end
