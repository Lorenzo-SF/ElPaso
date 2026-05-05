defmodule ElPaso.Domain.DecisionEngine.LLMClassifier do
  @moduledoc """
  Capa 3 del DecisionEngine: usar un modelo pequeño/rápido para decidir
  qué personalidad usar cuando las capas anteriores son ambiguas.

  Solo se invoca si:
    - Keyword matching dio confianza < threshold
    - Embedding similarity dio confianza < threshold
    - Hay al menos 2 personalidades candidatas viables

  Usa un modelo ligero configurado con tag "[classifier]" en description.
  Si no hay modelo clasificador, devuelve {:error, :no_classifier}.
  """

  require Logger

  defstruct [:personality, :confidence, :reasoning]

  @type t :: %__MODULE__{
          personality: map() | nil,
          confidence: float(),
          reasoning: String.t()
        }

  @classification_prompt_template """
  Eres un clasificador de intenciones. Tu tarea es decidir qué especialista
  debe atender la siguiente consulta del usuario.

  Personalidades disponibles:
  ~personalities~

  Consulta del usuario:
  "~content~"

  Responde EXCLUSIVAMENTE con el nombre de la personalidad más adecuada.
  Si ninguna es claramente adecuada, responde "general".
  Solo el nombre, nada más. No añadas puntuación ni explicaciones.
  """

  @doc """
  Clasifica el contenido usando un modelo pequeño configurado como classifier.

  Busca un modelo con "[classifier]" en su campo description.
  Si no existe, devuelve error.
  """
  @spec classify([map()], String.t()) :: {:ok, t()} | {:error, atom()}
  def classify(personalities, content) do
    # Construir descripciones para el prompt
    descriptions =
      Enum.map(personalities, fn p ->
        "- #{p.name}: #{p.description || p.semantic_description || "sin descripción"}"
      end)
      |> Enum.join("\n")

    prompt =
      @classification_prompt_template
      |> String.replace("~personalities~", descriptions)
      |> String.replace("~content~", content)

    messages = [%{role: "user", content: prompt}]

    case infer_classifier(messages) do
      {:ok, response} ->
        chosen_name = String.trim(response) |> String.downcase()
        chosen = Enum.find(personalities, &(String.downcase(&1.name) == chosen_name))

        if chosen do
          {:ok,
           %__MODULE__{
             personality: chosen,
             confidence: 0.85,
             reasoning: "LLM classifier selected '#{chosen.name}'"
           }}
        else
          # El LLM devolvió algo que no coincide → fallback a default
          default = Enum.find(personalities, & &1.is_default) || hd(personalities)
          Logger.warning("[LLMClassifier] LLM returned '#{chosen_name}' but no match found. Using default: #{default.name}")

          {:ok,
           %__MODULE__{
             personality: default,
             confidence: 0.4,
             reasoning: "LLM returned unrecognized '#{chosen_name}', fallback to default"
           }}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Classifier inference ────────────────────────────────────────────────

  defp infer_classifier(messages) do
    classifier_model = find_classifier_model()

    if classifier_model do
      Logger.debug("[LLMClassifier] Using model: #{classifier_model.name}")

      # Inferencia directa SIN pasar por el Router (evitar recursión)
      case ElPaso.Domain.ModelManager.infer(classifier_model.name, %{messages: messages}, 30_000) do
        {:ok, {:ok, response}} when is_map(response) ->
          content = Map.get(response, :content) || Map.get(response, "content") || ""
          {:ok, content}

        {:ok, response} when is_map(response) ->
          content = Map.get(response, :content) || Map.get(response, "content") || ""
          {:ok, content}

        {:error, reason} ->
          Logger.warning("[LLMClassifier] Inference failed: #{inspect(reason)}")
          {:error, reason}
      end

    else
      Logger.info("[LLMClassifier] No classifier model configured. Add a model with '[classifier]' in description.")
      {:error, :no_classifier_model}
    end
  end

  defp find_classifier_model do
    import Ecto.Query

    ElPaso.Repo.one(
      from(m in ElPaso.Models.Model,
        where: m.active == true and like(m.description, "%[classifier]%"),
        limit: 1
      )
    )
  end
end
