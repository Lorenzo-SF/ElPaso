defmodule ElPaso.CLI.Commands.RouterTune do
  @moduledoc """
  Comando para ajustar el enrutamiento de modelos.
  """

  @doc """
  Ejecuta el comando de ajuste del enrutamiento.
  """
  def run(_opts) do
    # Simular sugerencias de afinidad (simplificación)
    suggestions = [
      %ElPaso.Domain.Types.AffinitySuggestion{
        model_id: "fast",
        task_type: :question_answer,
        current_affinity: 0.8,
        suggested_affinity: 0.9,
        delta: 0.1,
        confidence: 0.95,
        based_on_n_decisions: 24,
        reason: "Mejor ajuste para preguntas"
      },
      %ElPaso.Domain.Types.AffinitySuggestion{
        model_id: "heavy",
        task_type: :code,
        current_affinity: 0.7,
        suggested_affinity: 0.8,
        delta: 0.1,
        confidence: 0.92,
        based_on_n_decisions: 18,
        reason: "Mejor ajuste para código"
      }
    ]

    print_suggestions(suggestions)

    IO.puts("[A]plicar cambios  [R]efrescar  [Q]salir > ")
  end

  defp print_suggestions(suggestions) do
    IO.puts("Sugerencias de ajuste (confianza > 60%, delta > 0.05):")

    suggestions
    |> Enum.with_index()
    |> Enum.each(fn {suggestion, index} ->
      IO.puts(
        "#{index + 1}. #{suggestion.model_id} → #{suggestion.task_type}: #{suggestion.current_affinity} → #{suggestion.suggested_affinity} (confianza: #{suggestion.confidence}, n=#{suggestion.based_on_n_decisions})"
      )

      IO.puts("   Razón: #{suggestion.reason}")
    end)
  end
end
