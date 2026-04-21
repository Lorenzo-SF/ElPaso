defmodule Mix.Tasks.Elpaso do
  @moduledoc """
  Comandos de ElPaso para diagnóstico y ajuste fino.

  Este comando permite ejecutar las diferentes herramientas de diagnóstico:

  mix elpaso router stats
  mix elpaso router tune
  mix elpaso bench
  mix elpaso context export
  mix elpaso config reload
  """

  use Mix.Task

  @shortdoc "Comandos de diagnóstico y ajuste fino"

  def run(args) do
    ElPaso.CLI.run(args)
  end
end
