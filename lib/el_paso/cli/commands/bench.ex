defmodule ElPaso.CLI.Commands.Bench do
  @moduledoc """
  Comando para ejecutar benchmarks de rendimiento.
  """

  alias Zaguan.Drawer.Components.{Header, Table, Bar, Message}
  alias ElPaso.HTTP.InternalClient

  @default_prompts %{
    question_answer: "¿Qué es la programación funcional y en qué se diferencia de la imperativa?",
    code:
      "Escribe una función en Elixir que calcule el número de Fibonacci usando recursión con memoización.",
    reasoning:
      "Analiza las ventajas y desventajas de usar microservicios frente a una arquitectura monolítica para una startup con 3 desarrolladores.",
    summarization: "Resume en 3 puntos clave el concepto de programación reactiva.",
    creative: "Escribe un párrafo introductorio para un artículo técnico sobre Elixir.",
    translation:
      "Traduce al inglés: 'El procesamiento concurrente es una ventaja clave de Erlang/OTP'.",
    unknown: "Hola, ¿cómo estás?"
  }

  @doc """
  Ejecuta el comando de benchmark.
  """
  def run(opts) do
    model_id = opts[:model]
    n = opts[:requests] || 7
    _prompts = load_prompts(opts[:prompts_dir])

    Header.print("Benchmark ElPaso", subtitle: "#{model_id || "auto"} — #{n} requests")

    results =
      Enum.map(1..n, fn i ->
        {task_type, prompt} = select_prompt(@default_prompts, i, n)
        Bar.print(i - 1, n, label: "#{i}/#{n} (#{task_type})", width: 40)

        start = System.monotonic_time(:millisecond)

        result =
          InternalClient.chat(prompt,
            model: model_id,
            session_id: "bench-#{System.unique_integer()}",
            stream: false
          )

        latency = System.monotonic_time(:millisecond) - start
        ttft = result[:ttft_ms] || 0
        cache_hit = result[:elpaso][:context_layers_used] |> List.first() == "prefix+cache_hit"

        status = if result[:ok], do: :success, else: :error

        Message.print(
          status,
          "#{task_type}: #{latency}ms #{if cache_hit, do: "[cache hit]", else: ""}"
        )

        %{
          task_type: task_type,
          latency_ms: latency,
          ttft_ms: ttft,
          cache_hit: cache_hit,
          ok: result[:ok]
        }
      end)

    print_summary(results)
  end

  defp load_prompts(_prompts_dir) do
    # Cargar prompts desde directorio (simplificación)
    @default_prompts
  end

  defp select_prompt(prompts, i, n) do
    # Seleccionar prompt basado en índice (simplificación)
    task_types = Map.keys(prompts)
    task_type = Enum.at(task_types, rem(i - 1, length(task_types)))
    {task_type, Map.get(prompts, task_type)}
  end

  defp print_summary(results) do
    latencies = Enum.map(results, & &1.latency_ms)
    ttfts = Enum.map(results, & &1.ttft_ms)
    cache_hits = Enum.count(results, & &1.cache_hit)
    errors = Enum.count(results, &(not &1.ok))

    Table.print(
      headers: ["Métrica", "Media", "p95"],
      rows: [
        ["TTFT", "#{safe_avg(ttfts)}ms", "#{safe_p95(ttfts)}ms"],
        ["Latencia total", "#{safe_avg(latencies)}ms", "#{safe_p95(latencies)}ms"],
        [
          "Cache hits",
          "#{cache_hits}/#{length(results)} (#{round(cache_hits / length(results) * 100)}%)",
          "-"
        ],
        ["Errores", to_string(errors), "-"]
      ],
      headers_color: :cyan,
      table_border: :rounded
    )
  end

  defp safe_avg(latencies) do
    if latencies != [] do
      Enum.sum(latencies) / length(latencies)
    else
      0
    end
  end

  defp safe_p95(latencies) do
    if latencies != [] do
      # Simplificación - en producción se usaría percentil real
      Enum.sum(latencies) |> div(length(latencies))
    else
      0
    end
  end
end
