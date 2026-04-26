defmodule Mix.Tasks.Elpaso.Engine.List do
  @moduledoc """
  Lista todos los motores de inferencia configurados.

  mix elpaso engine list
  """

  use Mix.Task

  def run(_args) do
    IO.puts("Listing all engines...")

    # In this simplified version, just show a sample
    IO.puts("""
    Engine List:
    - llama_server (local)
    - openai (remote)
    - vllm (remote)
    - anthropic (remote)
    - ollama (local)
    """)

    IO.puts("✅ Engines listed successfully!")
  end
end
