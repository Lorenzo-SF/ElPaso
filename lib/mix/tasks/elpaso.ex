defmodule Mix.Tasks.Elpaso do
  @moduledoc """
  Comandos de ElPaso para diagnóstico y ajuste fino.

  Este comando permite ejecutar las diferentes herramientas de diagnóstico:

  mix elpaso router stats
  mix elpaso router tune [--revert-auto]
  mix elpaso bench
  mix elasto context export
  mix elpaso config reload
  mix elpaso cluster status
  """

  use Mix.Task

  @shortdoc "Comandos de diagnóstico y ajuste fino"

  def run(args) do
    ElPaso.CLI.main(args)
  end
end
