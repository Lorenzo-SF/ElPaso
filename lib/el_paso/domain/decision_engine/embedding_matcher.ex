defmodule ElPaso.Domain.DecisionEngine.EmbeddingMatcher do
  @moduledoc """
  Capa 2 del DecisionEngine: matching por similitud semántica usando pgvector.

  Flujo:
    1. Generar embedding del prompt del usuario via EmbeddingClient (Ollama)
    2. Comparar cosine similarity contra embeddings precomputados de cada personalidad
    3. Devolver la mejor match con score de confianza

  Requiere que las personalidades tengan su embedding precomputado
  (campo `embedding` tipo `vector(768)` en PostgreSQL).
  """

  alias ElPaso.Repo
  alias ElPaso.Models.Personality
  alias ElPaso.Context.EmbeddingClient
  import Ecto.Query

  defstruct [:personality, :confidence, :top_matches]

  @type t :: %__MODULE__{
          personality: map() | nil,
          confidence: float(),
          top_matches: [map()]
        }

  @doc """
  Busca la personalidad más cercana semánticamente al contenido.

  Usa cosine similarity via pgvector. Las personalidades deben tener
  su embedding precomputado.

  Devuelve {:ok, result} con la mejor match o {:error, reason}.
  """
  @spec match([map()], String.t()) :: {:ok, t()} | {:error, atom()}
  def match(personalities, content) do
    # 1. Generar embedding del contenido del usuario
    case EmbeddingClient.embed(content) do
      {:ok, query_embedding} ->
        # 2. Obtener IDs de personalidades activas
        active_ids = Enum.map(personalities, & &1.id)

        # 3. Query pgvector: cosine similarity
        results = query_similar(active_ids, query_embedding)

        case results do
          [best | _rest] ->
            personality = Enum.find(personalities, & &1.id == best.id)
            confidence = calculate_confidence(results, best)

            {:ok,
             %__MODULE__{
               personality: personality,
               confidence: confidence,
               top_matches: results
             }}

          [] ->
            {:error, :no_embeddings_available}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── pgvector query ──────────────────────────────────────────────────────

  defp query_similar(active_ids, query_embedding) do
    # Convertir el embedding a formato pgvector usando Pgvector.new/1
    vector = Pgvector.new(query_embedding)

    from(p in Personality,
      where: p.id in ^active_ids and not is_nil(p.embedding),
      select: %{
        id: p.id,
        name: p.name,
        similarity:
          fragment(
            "1 - (? <=> ?)",
            p.embedding,
            ^vector
          )
      },
      order_by: [
        desc:
          fragment(
            "1 - (? <=> ?)",
            p.embedding,
            ^vector
          )
      ],
      limit: 5
    )
    |> Repo.all()
  end

  # ── Confidence calculation ──────────────────────────────────────────────

  defp calculate_confidence([], _best), do: 0.0

  defp calculate_confidence([best | rest], _best_match) do
    best_sim = best.similarity || 0.0

    # Si el mejor es significativamente mejor que el segundo, alta confianza
    second_sim =
      case rest do
        [second | _] -> second.similarity || 0.0
        [] -> 0.0
      end

    margin = best_sim - second_sim
    # Normalizar: similitud base + margen de ventaja sobre el segundo
    confidence = Float.round(best_sim * 0.7 + margin * 0.3, 3)
    # Clampear a [0, 1]
    max(0.0, min(1.0, confidence))
  end
end
