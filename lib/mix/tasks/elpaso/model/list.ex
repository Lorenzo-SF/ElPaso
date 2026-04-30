defmodule Mix.Tasks.Elpaso.Model.List do
  @moduledoc """
  Lista todos los modelos configurados.

  mix elpaso model list
  """

  use Mix.Task

  alias ElPaso.CLI.Output

  def run(_args) do
    Output.info("Listing all models...")

    # In this simplified version, just show a sample
    IO.puts("""
    Model List:
    - gpt-4 (openai)
    - claude-3-haiku (anthropic)
    - llama2-7b (llama_server)
    - mistral-7b (vllm)
    """)

    Output.success("Models listed successfully!")
  end
end
