defmodule ElPaso.CLI.Commands.Bench do
  @moduledoc """
  Comando para ejecutar benchmarks del sistema.
  """

  @default_prompts %{
    question_answer: "¿Qué es la programación funcional?",
    code: "Escribe una función en Elixir para Fibonacci.",
    reasoning: "Analiza ventajas de microservicios vs monolito.",
    summarization: "Resume en 3 puntos clave la programación reactiva.",
    creative: "Escribe un párrafo introductorio sobre Elixir.",
    translation: "Traduce al inglés: 'El procesamiento concurrente es clave'.",
    unknown: "Hola, ¿cómo estás?"
  }

  def run(opts) do
    model_id = opts[:model]
    n = opts[:requests] || 7
    prompts = @default_prompts

    IO.puts("=== Benchmark ElPaso: #{model_id || "auto"} — #{n} requests ===\n")

    results =
      Enum.map(1..n, fn i ->
        {task_type, _prompt} = select_prompt(prompts, i)
        IO.puts("#{i}/#{n} (#{task_type})...")

        # Simulación de benchmark
        %{task_type: task_type, latency_ms: :rand.uniform(1000), ok: true}
      end)

    print_summary(results)
  end

  defp select_prompt(prompts, i) do
    task_types = Map.keys(prompts)
    task_type = Enum.at(task_types, rem(i - 1, length(task_types)))
    {task_type, Map.get(prompts, task_type)}
  end

  defp print_summary(results) do
    latencies = Enum.map(results, & &1.latency_ms)
    avg = if latencies != [], do: Enum.sum(latencies) |> div(length(latencies)), else: 0

    IO.puts("\n=== Resumen ===")
    IO.puts("Latencia media: #{avg}ms")
    IO.puts("Total requests: #{length(results)}")
  end
end
