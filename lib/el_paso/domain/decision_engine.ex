defmodule ElPaso.Domain.DecisionEngine do
  @moduledoc """
  Motor de decisión multi-capa para selección de personalidad en ElPaso v4.0.

  Pipeline de 4 capas:
    1. Keyword + Regex matching (Scorer) — determinista, <1ms
    2. Embedding similarity (EmbeddingMatcher) — semántico, ~10-50ms
    3. LLM Classification (LLMClassifier) — modelo pequeño, ~500ms, solo si ambiguo
    4. Default fallback — personalidad is_default=true

  Cada capa produce un resultado con nivel de confianza. Si la confianza
  supera el threshold configurado, se usa esa decisión sin consultar
  capas superiores.

  Las decisiones se cachean en ETS (DecisionCache) para evitar re-evaluar
  prompts idénticos en un intervalo corto.
  """

  require Logger

  alias ElPaso.Domain.DecisionEngine.{Scorer, EmbeddingMatcher, LLMClassifier, DecisionCache}
  alias ElPaso.Domain.PersonalityManager

  # Thresholds configurables via application env
  @keyword_confidence_threshold 0.70
  @embedding_confidence_threshold 0.55

  @doc """
  Selecciona la mejor personalidad para los mensajes dados.

  Devuelve:
    {:ok, personality_map, decision_metadata}
    {:error, reason}
  """
  @spec decide(list(map())) :: {:ok, map(), map()} | {:error, atom()}
  def decide(messages) do
    content = extract_full_content(messages)
    active = PersonalityManager.list_active()

    if active == [] do
      {:error, :no_active_personality}
    else
      # Verificar caché primero
      case DecisionCache.get(content) do
        {:hit, personality_name} ->
          personality = Enum.find(active, &(&1.name == personality_name))
          if personality do
            Logger.debug("[DecisionEngine] Cache HIT → #{personality_name}")
            metadata = %{layer: :cache, confidence: 0.95, matched_trigger: "cached"}
            {:ok, personality, metadata}
          else
            do_decide(active, content)
          end

        :miss ->
          do_decide(active, content)
      end
    end
  end

  defp do_decide(personalities, content) do
    # ── Capa 1: Keyword + Regex scoring ─────────────────────────────────
    scorer_result = Scorer.score(personalities, content)

    Logger.debug("[DecisionEngine] Layer 1 (keyword): confidence=#{scorer_result.confidence} trigger=#{scorer_result.trigger}")

    if scorer_result.confidence >= @keyword_confidence_threshold do
      DecisionCache.put(content, scorer_result.personality.name)
      metadata = %{
        layer: :keyword,
        confidence: scorer_result.confidence,
        matched_trigger: scorer_result.trigger,
        all_scores: scorer_result.all_scores
      }
      {:ok, scorer_result.personality, metadata}
    else
      # ── Capa 2: Embedding similarity ──────────────────────────────────
      Logger.debug("[DecisionEngine] Layer 1 confidence #{scorer_result.confidence} < #{@keyword_confidence_threshold}, trying Layer 2...")

      case EmbeddingMatcher.match(personalities, content) do
        {:ok, %{confidence: conf} = embed_result} when conf >= @embedding_confidence_threshold ->
          DecisionCache.put(content, embed_result.personality.name)
          metadata = %{
            layer: :embedding,
            confidence: embed_result.confidence,
            top_matches: embed_result.top_matches
          }
          {:ok, embed_result.personality, metadata}

        {:ok, embed_result} ->
          Logger.debug("[DecisionEngine] Layer 2 confidence #{embed_result.confidence} < #{@embedding_confidence_threshold}, trying Layer 3...")

          # ── Capa 3: LLM Classifier ───────────────────────────────────
          case LLMClassifier.classify(personalities, content) do
            {:ok, %{personality: p} = llm_result} when not is_nil(p) ->
              DecisionCache.put(content, p.name)
              metadata = %{
                layer: :llm,
                confidence: llm_result.confidence,
                reasoning: llm_result.reasoning
              }
              {:ok, p, metadata}

            _ ->
              # ── Capa 4: Default fallback ─────────────────────────────
              fallback_to_default(personalities, content)
          end

        {:error, _reason} ->
          # Embedding falló → intentar LLM o default
          case LLMClassifier.classify(personalities, content) do
            {:ok, %{personality: p} = llm_result} when not is_nil(p) ->
              DecisionCache.put(content, p.name)
              metadata = %{layer: :llm, confidence: llm_result.confidence, reasoning: llm_result.reasoning}
              {:ok, p, metadata}

            _ ->
              fallback_to_default(personalities, content)
          end
      end
    end
  end

  defp fallback_to_default(personalities, content) do
    default = Enum.find(personalities, & &1.is_default) || hd(personalities)
    Logger.debug("[DecisionEngine] Layer 4 (default): #{default.name}")
    DecisionCache.put(content, default.name)
    metadata = %{layer: :default, confidence: 0.5}
    {:ok, default, metadata}
  end

  defp extract_full_content(messages) do
    messages
    |> Enum.map(fn
      %{"content" => c} when is_binary(c) -> c
      %{"content" => c} when is_list(c) ->
        c
        |> Enum.filter(&(Map.get(&1, "type") == "text"))
        |> Enum.map_join(" ", &Map.get(&1, "text", ""))
      %{content: c} when is_binary(c) -> c
      _ -> ""
    end)
    |> Enum.join("\n")
  end
end
