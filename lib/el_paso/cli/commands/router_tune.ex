defmodule ElPaso.CLI.Commands.RouterTune do
  @moduledoc """
  Comando para ajustar automáticamente las afinidades del router.
  """

  alias Zaguan.Drawer.Components.{Header, Table, Message}
  alias ElPaso.Domain.RouterTuner
  alias ElPaso.Domain.Types.AffinitySuggestion

  @doc """
  Ejecuta el comando de ajuste de routing.
  """
  def run(_opts) do
    since = :last_24h

    Header.print("Router Tuning", subtitle: "Análisis con datos de #{period_label(since)}")

    suggestions = RouterTuner.analyze(since)

    if suggestions != [] do
      print_suggestions(suggestions, _opts)
    else
      Message.print(:info, "No hay sugerencias de ajuste significativas")
    end
  end

  defp period_label(since) do
    case since do
      :last_hour -> "última hora"
      :last_24h -> "últimas 24 horas"
      :last_7d -> "últimos 7 días"
      {:since, _} -> "período personalizado"
    end
  end

  defp print_suggestions(suggestions, _opts) do
    # Mostrar sugerencias de ajuste
    Message.print(:info, "Sugerencias de ajuste (confianza > 60%, delta > 0.05):")

    Enum.with_index(suggestions, fn suggestion, index ->
      reason =
        case {suggestion.current_affinity, suggestion.suggested_affinity} do
          {curr, sug} when curr < sug -> "Afinidad mayor sugerida"
          {curr, sug} when curr > sug -> "Afinidad menor sugerida"
          _ -> "Ajuste sugerido"
        end

      Message.print(
        :info,
        "#{index + 1}. #{suggestion.model_id} → #{suggestion.task_type}: #{suggestion.current_affinity} → #{suggestion.suggested_affinity} (confianza: #{suggestion.confidence}, n=#{suggestion.based_on_n_decisions})"
      )

      Message.print(:info, "   Razón: #{suggestion.reason}")
    end)

    # Si no se especifica --apply, solo mostrar sugerencias
    if _opts[:apply] do
      apply_suggestions(suggestions)
    else
      Message.print(:info, "[S]iguiente  [A]plicar  [R]echazar  [Q]salir > ")
    end
  end

  defp apply_suggestions(_suggestions) do
    # Aplicar las sugerencias
    Message.print(:success, "Aplicando sugerencias...")
    # En producción se aplicaría el cambio a la configuración y recargaría los modelos
    :ok
  end
end
