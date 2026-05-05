defmodule ElPaso.Domain.DecisionEngine.Scorer do
  @moduledoc """
  Capa 1 del DecisionEngine: scoring determinista por keywords, regex y task_types.

  Evalúa cada personalidad contra el contenido del prompt y devuelve
  la mejor match con su nivel de confianza (0.0 - 1.0).

  Señales evaluadas:
    - Trigger keywords (n-gram aware)
    - Regex patterns (campo regex_patterns de la personalidad)
    - Task type heuristics (delegado en TaskCategories)
    - Prioridad de la personalidad
  """

  alias ElPaso.Domain.Router.TaskCategories

  defstruct [:personality, :confidence, :trigger, :all_scores]

  @type t :: %__MODULE__{
          personality: map(),
          confidence: float(),
          trigger: String.t() | nil,
          all_scores: [{map(), float()}]
        }

  @doc """
  Evalúa todas las personalidades contra el contenido y devuelve
  la mejor match con su confianza.

  Si la confianza es >= threshold, el DecisionEngine puede usarla
  directamente sin consultar capas superiores.
  """
  @spec score([map()], String.t()) :: t()
  def score(personalities, content) do
    normalized = String.downcase(content)
    keywords = tokenize_ngrams(normalized)

    scores =
      Enum.map(personalities, fn p ->
        s = calculate_score(p, normalized, keywords)
        {p, s}
      end)

    best = Enum.max_by(scores, fn {_, s} -> s end, fn -> {hd(personalities), 0.0} end)

    {personality, raw_score} = best
    max_possible = max_possible_score(personality)
    confidence = if max_possible > 0, do: Float.round(raw_score / max_possible, 3), else: 0.0

    %__MODULE__{
      personality: personality,
      confidence: confidence,
      trigger: find_best_trigger(personality, normalized, keywords),
      all_scores: Enum.map(scores, fn {p, s} -> {p.name, s} end)
    }
  end

  # ── Scoring ────────────────────────────────────────────────────────────

  defp calculate_score(personality, content, keywords) do
    kw_score = keyword_trigger_score(personality.trigger_keywords || [], keywords, content)
    regex_score = regex_trigger_score(personality.regex_patterns || [], content)
    task_score = task_type_score(personality.trigger_task_types || [], content)

    # Pesos: keywords 50%, regex 30%, task_type 20%
    kw_score * 0.5 + regex_score * 0.3 + task_score * 0.2
  end

  defp keyword_trigger_score([], _keywords, _content), do: 0.0
  defp keyword_trigger_score(triggers, keywords, content) do
    matched =
      Enum.count(triggers, fn trigger ->
        trigger_down = String.downcase(trigger)
        Enum.any?(keywords, fn kw -> kw == trigger_down end) or
          String.contains?(content, trigger_down)
      end)

    matched / length(triggers)
  end

  defp regex_trigger_score([], _content), do: 0.0
  defp regex_trigger_score(patterns, content) do
    matched =
      Enum.count(patterns, fn pattern ->
        case Regex.compile(pattern) do
          {:ok, regex} -> Regex.match?(regex, content)
          _ -> false
        end
      end)

    matched / length(patterns)
  end

  defp task_type_score([], _content), do: 0.0
  defp task_type_score(task_types, content) do
    detected = TaskCategories.detect(content)
    detected_names = Enum.map(detected, &Atom.to_string(&1.type))

    matched =
      Enum.count(task_types, fn tt ->
        tt in detected_names
      end)

    if Enum.empty?(detected), do: 0.0, else: matched / length(task_types)
  end

  defp max_possible_score(_personality), do: 1.0

  # ── N-gram tokenization ─────────────────────────────────────────────────

  defp tokenize_ngrams(content) do
    tokens =
      content
      |> String.split(~r/[\s,.;:!?¡¿"'\\(\\)\\[\\]{}]+/, trim: true)
      |> Enum.reject(&(String.length(&1) < 2))

    bigrams = tokens |> Enum.chunk_every(2, 1, :discard) |> Enum.map(&Enum.join(&1, " "))
    trigrams = tokens |> Enum.chunk_every(3, 1, :discard) |> Enum.map(&Enum.join(&1, " "))

    tokens ++ bigrams ++ trigrams
  end

  defp find_best_trigger(personality, content, keywords) do
    triggers = personality.trigger_keywords || []
    Enum.find(triggers, fn t ->
      t_down = String.downcase(t)
      Enum.any?(keywords, fn kw -> kw == t_down end) or String.contains?(content, t_down)
    end)
  end
end
