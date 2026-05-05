defmodule ElPaso.Domain.Router do
  @moduledoc """
  Router de personalidades (MoE manual de ElPaso).

  En vez de seleccionar un modelo directamente por task_affinity,
  selecciona una **personalidad** que coincida con la solicitud:

    1. Extraer keywords y task_type del contenido del mensaje
    2. Buscar personalidades que coincidan (por trigger_keywords o trigger_task_types)
    3. Si varias coinciden → elegir la de mayor prioridad
    4. Si ninguna coincide → usar la personalidad por defecto (is_default)
    5. Devolver model + engine + system_prompt + config de la personalidad

  Las keywords se extraen con soporte para n-gramas (unigramas, bigramas, trigramas)
  lo que permite detectar triggers multi-palabra como "to english" o "pros and cons".

  Las task_types se delegan en ElPaso.Domain.Router.TaskCategories.
  """

  alias ElPaso.Domain.PersonalityManager
  alias ElPaso.Domain.Router.TaskCategories
  alias ElPaso.Domain.DecisionEngine

  @doc """
  Selecciona la personalidad óptima para una solicitud.

  Devuelve un mapa con toda la información necesaria para la inferencia:
    - personality_name, system_prompt
    - model_name, model_id, engine_id
    - config (temperature, max_tokens, top_p, etc.)
    - decision_reason (qué trigger activó esta personalidad)
    - matched_with (keyword, task_type, o default)
  """
  @spec select_personality(list()) :: {:ok, map()} | {:error, atom()}
  def select_personality(messages) do
    content = extract_content(messages)

    active = PersonalityManager.list_active()

    if active == [] do
      {:error, :no_active_personality}
    else
      # ── V4.0: Delegar auto-detección al DecisionEngine ──
      case DecisionEngine.decide(messages) do
        {:ok, personality, metadata} ->
          result = build_result_from_decision(personality, metadata)
          {:ok, result}

        {:error, _reason} ->
          # Fallback al sistema legacy si el DecisionEngine falla
          keywords = extract_keywords(content)
          task_types = TaskCategories.detect(content)
          match = find_best_match(active, keywords, task_types, content)
          {:ok, build_result(match, task_types)}
      end
    end
  end

  @doc """
  Versión legacy que devuelve formato compatible con el API HTTP.
  Delega en select_personality/1.
  """
  @spec select_model(list(), map()) :: {:ok, map()} | {:error, any()}
  def select_model(messages, _options) do
    case select_personality(messages) do
      {:ok, result} ->
        {:ok,
         %{
           model_name: result.model_name,
           engine_id: result.engine_id,
           decision_reason: result.decision_reason,
           task_type: result.task_type,
           score: result.score,
           timestamp: DateTime.utc_now()
         }}

      error ->
        error
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PRIVATE
  # ═══════════════════════════════════════════════════════════════════════════

  defp extract_content(messages) do
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
    |> Enum.join(" ")
    |> String.downcase()
  end

  # ── EXTRACCIÓN DE KEYWORDS MEJORADA (v4.0) ────────────────────────────────

  @doc false
  def extract_keywords(content) do
    normalized = String.downcase(content)

    # 1. Tokenizar en palabras individuales (sin filtrar por longitud mínima)
    single_tokens =
      normalized
      |> String.split(~r/[\s,.;:!?¡¿"'\\(\\)\\[\\]{}]+/, trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(String.length(&1) < 2))
      |> Enum.uniq()

    # 2. Generar bigramas y trigramas para capturar frases clave
    bigrams = generate_ngrams(single_tokens, 2)
    trigrams = generate_ngrams(single_tokens, 3)

    # 3. Unir todo: palabras sueltas + bigramas + trigramas
    #    También añadimos el contenido completo para substring matching
    single_tokens ++ bigrams ++ trigrams
  end

  defp generate_ngrams(tokens, n) do
    if length(tokens) >= n do
      tokens
      |> Enum.chunk_every(n, 1, :discard)
      |> Enum.map(&Enum.join(&1, " "))
    else
      []
    end
  end

  # ── FIND BEST MATCH MEJORADO (v4.0) ─────────────────────────────────────

  # Fase 1: keyword matching con n-gramas
  # Fase 2: task_type matching
  # Fase 3: default fallback
  defp find_best_match(personalities, keywords, task_types, content) do
    task_type_names = Enum.map(task_types, & &1.type)

    # ── Fase 1: Keyword matching (mejorado con n-gramas) ──
    keyword_matches =
      Enum.filter(personalities, fn p ->
        triggers = p.trigger_keywords || []
        not Enum.empty?(triggers) and
          Enum.any?(triggers, fn trigger ->
            trigger_matches?(trigger, keywords, content)
          end)
      end)

    unless Enum.empty?(keyword_matches) do
      best = return_highest_priority(keyword_matches)
      trigger = find_matched_trigger(best, keywords, content)
      Map.put(best, :matched_with, "keyword:#{trigger}")
    else
      # ── Fase 2: Match por trigger_task_types ──
      task_matches =
        Enum.filter(personalities, fn p ->
          triggers = p.trigger_task_types || []
          not Enum.empty?(triggers) and
            Enum.any?(triggers, fn tt -> tt in task_type_names end)
        end)

      unless Enum.empty?(task_matches) do
        best = return_highest_priority(task_matches)
        Map.put(best, :matched_with, "task_type:#{hd(task_type_names)}")
      else
        # ── Fase 3: Personalidad por defecto (fallback) ──
        default = Enum.find(personalities, & &1.is_default)

        if default do
          Map.put(default, :matched_with, "default")
        else
          # ── Fase 4: Si no hay default, coger la primera activa ──
          Map.put(hd(personalities), :matched_with, "fallback:first_active")
        end
      end
    end
  end

  # Verifica si un trigger coincide con el contenido.
  # Estrategias en orden:
  #   1. El trigger está en la lista de n-gramas (match exacta)
  #   2. El trigger es substring del contenido completo
  defp trigger_matches?(trigger, keywords, content) do
    trigger_down = String.downcase(trigger)

    # Estrategia 1: match exacta contra n-gramas
    in_ngrams = Enum.any?(keywords, fn kw -> kw == trigger_down end)

    # Estrategia 2: substring matching contra el contenido completo
    # (útil para triggers más largos que podrían no estar en los n-gramas)
    in_content = String.contains?(content, trigger_down)

    in_ngrams or in_content
  end

  defp find_matched_trigger(personality, keywords, content) do
    triggers = personality.trigger_keywords || []

    Enum.find(triggers, fn trigger ->
      trigger_matches?(trigger, keywords, content)
    end) || hd(triggers)
  end

  defp return_highest_priority(matches) do
    matches
    |> Enum.max_by(&(&1.priority || 0), fn -> hd(matches) end)
  end

  # ── BUILD RESULT ────────────────────────────────────────────────────────

  defp build_result_from_decision(personality, metadata) do
    task_types = TaskCategories.detect("")

    build_result(personality, task_types)
    |> Map.put(:decision_layer, metadata.layer)
    |> Map.put(:decision_confidence, metadata.confidence)
    |> Map.put(:decision_reason, "#{personality.name} via #{metadata.layer} (confidence: #{metadata.confidence})")
    |> Map.put(:score, metadata.confidence)
  end

  defp build_result(personality, task_types) do
    model = personality.model
    engine = personality.engine
    config = personality.config || %{}

    %{
      personality_name: personality.name,
      system_prompt: personality.system_prompt,
      model_name: model && model.name,
      model_id: personality.model_id,
      engine_id: personality.engine_id,
      engine_name: engine && engine.name,
      config: config,
      temperature: Map.get(config, "temperature", model && model.temperature),
      max_tokens: Map.get(config, "max_tokens", model && model.max_tokens),
      top_p: Map.get(config, "top_p", model && model.top_p),
      decision_reason: Map.get(personality, :matched_with) ||
        "#{personality.name} (priority: #{personality.priority})",
      matched_with: Map.get(personality, :matched_with, "default"),
      task_type: (task_types |> Enum.map(& &1.type) |> List.first()) || "unknown",
      score: personality.priority,
      timestamp: DateTime.utc_now()
    }
  end
end
