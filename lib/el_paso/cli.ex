defmodule ElPaso.CLI do
  @moduledoc """
  Módulo principal para las comandos de línea de comandos.
  """

  def run(args) do
    case args do
      ["router", "stats"] ++ rest ->
        ElPaso.CLI.Commands.RouterStats.run(parse_options(rest))

      ["router", "tune"] ++ rest ->
        ElPaso.CLI.Commands.RouterTune.run(parse_options(rest))

      ["bench"] ++ rest ->
        ElPaso.CLI.Commands.Bench.run(parse_options(rest))

      ["context", "export"] ++ rest ->
        ElPaso.CLI.Commands.Context.run(parse_options(rest))

      ["config", "reload"] ++ rest ->
        ElPaso.CLI.Commands.ConfigReload.run(parse_options(rest))

      ["cluster", "status"] ++ rest ->
        ElPaso.CLI.Commands.ClusterStatus.run(parse_options(rest))

      _ ->
        IO.puts("Comandos disponibles:")
        IO.puts("  mix elpaso router stats")
        IO.puts("  mix elpaso router tune")
        IO.puts("  mix elpaso bench")
        IO.puts("  mix elpaso context export")
        IO.puts("  mix elpaso config reload")
        IO.puts("  mix elpaso cluster status")
    end
  end

  defp parse_options(args) do
    Enum.reduce(args, %{}, fn arg, acc ->
      case String.split(arg, "=", parts: 2) do
        [key, value] -> Map.put(acc, String.to_atom(key), value)
        [key] -> Map.put(acc, String.to_atom(key), true)
      end
    end)
  end
end
