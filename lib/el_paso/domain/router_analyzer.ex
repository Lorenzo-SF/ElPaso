defmodule ElPaso.Domain.RouterAnalyzer do
  @moduledoc """
  Analiza el rendimiento del router a lo largo del tiempo.

  Calcula tendencias, tasas de retry y genera sugerencias auto-aplicables.
  """

  require Logger

  alias ElPaso.Context.Storage

  @type trend :: :improving | :stable | :degrading

  defstruct [
    :model_id,
    :task_type,
    :n_decisions,
    :overall_success_rate,
    :success_trend,
    :median_latency_ms,
    :retry_rate_pct,
    :alert,
    :weekly_breakdown
  ]

  @type t :: %__MODULE__{
          model_id: String.t(),
          task_type: atom(),
          n_decisions: non_neg_integer(),
          overall_success_rate: float(),
          success_trend: trend(),
          median_latency_ms: non_neg_integer(),
          retry_rate_pct: float(),
          alert: boolean(),
          weekly_breakdown: [%{week: Date.t(), success_rate: float(), n: integer()}]
        }

  @doc """
  Analiza tendencias de rendimiento para cada combinación (model, task_type).

  Argumentos:
  - since: :last_7d, :last_30d, :last_90d (default: :last_30d)
  """
  @spec analyze_trends(:last_7d | :last_30d | :last_90d) :: [t()]
  def analyze_trends(since \\ :last_30d) do
    decisions = Storage.query_routing_decisions(since: resolve_since(since), with_outcome: true)

    decisions
    |> group_by_combination()
    |> Enum.map(fn {{model, task}, group} ->
      analyze_combination(model, task, group)
    end)
  end

  @doc """
  Devuelve combinaciones que requieren alerta (retry > 30% o trend degrading).
  """
  @spec alerts :: [t()]
  def alerts do
    analyze_trends(:last_30d)
    |> Enum.filter(fn analysis -> analysis.alert end)
  end

  # Private functions

  defp analyze_combination(model, task, group) do
    windows = split_into_weekly_windows(group)
    success_rates = Enum.map(windows, &success_rate/1)

    trend = calculate_trend(success_rates)
    retry_rate = calculate_retry_rate(group)

    %__MODULE__{
      model_id: model,
      task_type: task,
      n_decisions: length(group),
      overall_success_rate: success_rate(group),
      success_trend: trend,
      median_latency_ms: median_latency(group),
      retry_rate_pct: retry_rate,
      alert: should_alert?(retry_rate, trend, length(group)),
      weekly_breakdown: Enum.map(windows, &week_breakdown/1)
    }
  end

  defp group_by_combination(decisions) do
    Enum.group_by(decisions, fn d -> {d.model_id, d.task_type} end)
  end

  defp split_into_weekly_windows(decisions) do
    # Ordenar por fecha
    sorted = Enum.sort_by(decisions, & &1.decided_at, Date)

    # Obtener rango de fechas
    case {List.first(sorted), List.last(sorted)} do
      {nil, _} ->
        []

      {first, last} ->
        # Crear ventanas de 7 días
        date_range = Date.range(DateTime.to_date(first.decided_at), DateTime.to_date(last.decided_at))
        weeks = Enum.chunk_every(date_range, 7)

        Enum.map(weeks, fn week_range ->
          Enum.filter(sorted, fn d ->
            Date.compare(d.decided_at, List.first(week_range)) in [:gt, :eq] and
              Date.compare(d.decided_at, List.last(week_range)) in [:lt, :eq]
          end)
        end)
    end
  end

  defp success_rate(decisions) do
    return_count = Enum.count(decisions, fn d -> d.outcome == "retry" end)
    total = length(decisions)

    if total == 0 do
      0.0
    else
      (total - return_count) / total * 100
    end
  end

  defp median_latency(decisions) do
    latencies =
      Enum.map(decisions, & &1.decision_latency_us) |> Enum.reject(&(&1 == nil or &1 == 0))

    case latencies do
      [] ->
        0

      list ->
        sorted = Enum.sort(list)
        mid = div(length(sorted), 2)
        Enum.at(sorted, mid)
    end
  end

  defp calculate_trend(rates_over_time) do
    if length(rates_over_time) < 2 do
      :stable
    else
      slope = linear_regression_slope(rates_over_time)

      cond do
        slope > 0.02 -> :improving
        slope < -0.02 -> :degrading
        true -> :stable
      end
    end
  end

  defp linear_regression_slope(values) when is_list(values) do
    n = length(values)

    if n < 2 do
      0.0
    else
      # Simple linear regression: y = mx + b
      x = Enum.to_list(0..(n - 1))
      y = values

      sum_x = Enum.sum(x)
      sum_y = Enum.sum(y)
      sum_xy = Enum.zip(x, y) |> Enum.map(fn {a, b} -> a * b end) |> Enum.sum()
      sum_xx = Enum.map(x, fn a -> a * a end) |> Enum.sum()

      denominator = n * sum_xx - sum_x * sum_x

      if denominator == 0 do
        0.0
      else
        (n * sum_xy - sum_x * sum_y) / denominator
      end
    end
  end

  defp calculate_retry_rate(decisions) do
    # Retry = dos mensajes del mismo usuario en menos de 10 segundos
    # agrupados por sesión
    retry_count =
      decisions
      |> Enum.group_by(fn d -> d.session_id end)
      |> Enum.flat_map(fn {_sid, session_decisions} ->
        detect_retries(session_decisions)
      end)
      |> length()

    total = length(decisions)

    if total == 0 do
      0.0
    else
      retry_count / total * 100
    end
    |> Float.round(1)
  end

  defp detect_retries(decisions) do
    # Ordenar por tiempo
    sorted = Enum.sort_by(decisions, & &1.decided_at)

    # Encontrar pares consecutivos en menos de 10 segundos
    Enum.reduce(sorted, [], fn
      curr, acc ->
        case acc do
          [] ->
            [curr]

          [prev | rest] ->
            diff = DateTime.diff(curr.decided_at, prev.decided_at, :second)

            if diff > 0 and diff < 10 do
              [curr, prev | rest]
            else
              [curr | acc]
            end
        end
    end)
  end

  defp should_alert?(_retry_rate, _trend, n) when n < 20 do
    false
  end

  defp should_alert?(retry_rate, trend, _n) do
    retry_rate > 30.0 or trend == :degrading
  end

  defp week_breakdown(decisions) do
    first_date =
      case List.first(decisions) do
        nil -> Date.utc_today()
        d -> d.decided_at
      end

    %{
      week: first_date,
      success_rate: success_rate(decisions),
      n: length(decisions)
    }
  end

  defp resolve_since(:last_7d), do: Date.add(Date.utc_today(), -7)
  defp resolve_since(:last_30d), do: Date.add(Date.utc_today(), -30)
  defp resolve_since(:last_90d), do: Date.add(Date.utc_today(), -90)
end
