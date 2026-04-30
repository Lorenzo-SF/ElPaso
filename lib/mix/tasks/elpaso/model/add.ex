defmodule Mix.Tasks.Elpaso.Model.Add do
  @moduledoc """
  Añade un nuevo modelo a ElPaso.

  Uso:
      mix elpaso.model.add <nombre> --engine <engine_nombre> --url <url> [opciones]

  Opciones:
      --engine      Nombre del engine asociado (requerido)
      --url         URL del modelo (requerido)
      --max-tokens  Límite de tokens (default: 4096)
      --temp        Temperatura de sampling (default: 0.7)
      --description Descripción del modelo

  Ejemplo:
      mix elpaso.model.add local-thinker --engine llama-local --url http://localhost:8081/v1 --max-tokens 128000 --temp 0.4 --description "Razonamiento"
  """

  use Mix.Task

  alias ElPaso.CLI.Output
  alias ElPaso.Repo
  alias ElPaso.Models.{Engine, Model}

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
          engine: :string,
          url: :string,
          max_tokens: :integer,
          temp: :float,
          description: :string
        ]
      )

    if is_nil(name) or is_nil(opts[:engine]) or is_nil(opts[:url]) do
      Output.error("Uso: mix elpaso.model.add <nombre> --engine <engine> --url <url>")
      System.halt(1)
    end

    engine = Repo.get_by(Engine, name: opts[:engine])

    if is_nil(engine) do
      Output.error(
        "Engine '#{opts[:engine]}' no existe. Regístralo primero con: mix elpaso engine add"
      )

      System.halt(1)
    end

    case Repo.get_by(Model, name: name) do
      nil ->
        %Model{}
        |> Model.changeset(%{
          name: name,
          engine_id: engine.id,
          url: opts[:url],
          api_key: engine.api_key,
          active: true,
          max_tokens: opts[:max_tokens] || 4096,
          temperature: opts[:temp] || 0.7,
          description: opts[:description]
        })
        |> Repo.insert!()

        Output.success("Model '#{name}' registrado (engine: #{engine.name}).")

      existing ->
        Output.info("Model '#{existing.name}' ya existe.")
    end
  end
end
