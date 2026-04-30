defmodule Mix.Tasks.Elpaso.Engine.List do
  @moduledoc """
  Lista todos los motores de inferencia configurados.

  mix elpaso engine list
  """

  use Mix.Task

  alias ElPaso.CLI.Output

  def run(_args) do
    Output.info("Listing all engines...")

    # In this simplified version, just show a sample
    IO.puts("""
    Engine List:
    - llama_server (local)
    - openai (remote)
    - vllm (remote)
    - anthropic (remote)
    - ollama (local)
    """)

    Output.success("Engines listed successfully!")
  end
end
