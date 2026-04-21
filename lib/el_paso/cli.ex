defmodule ElPaso.CLI do
  @moduledoc """
  CLI module for ElPaso commands.
  """

  @doc """
  Main entry point for escript.
  """
  def main(args \\ []) do
    run(args)
  end

  @doc """
  Executes a command.
  """
  def run([]), do: help()

  def run(args) do
    case args do
      ["router", "stats"] ++ rest ->
        ElPaso.CLI.Commands.RouterStats.run(parse_options(rest))

      ["router", "tune"] ++ rest ->
        ElPaso.CLI.Commands.RouterTune.run(parse_options(rest))

      ["bench"] ++ rest ->
        ElPaso.CLI.Commands.Bench.run(parse_options(rest))

      ["context"] ++ rest ->
        ElPaso.CLI.Commands.Context.run(parse_options(rest))

      ["config"] ++ rest ->
        ElPaso.CLI.Commands.ConfigReload.run(parse_options(rest))

      ["cluster"] ++ rest ->
        ElPaso.CLI.Commands.ClusterStatus.run(parse_options(rest))

      _ ->
        help()
    end
  end

  defp help do
    IO.puts("""
    ElPaso CLI

    Usage: elpaso <command> [options]

    Available commands:
      mix elpaso router stats    # Router statistics
      mix elpaso router tune    # Router auto-tuning
      mix elpaso bench          # Benchmark
      mix elpaso context       # Context management
      mix elpaso config         # Reload configuration
      mix elpaso cluster       # Cluster status
    """)
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
