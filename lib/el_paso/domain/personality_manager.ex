defmodule ElPaso.Domain.PersonalityManager do
  @moduledoc """
  Gestión de personalidades (skills/roles) para el router MoE manual de ElPaso.

  Cada personalidad define:
    - Qué modelo y engine usar
    - Qué system_prompt aplicar
    - Cuándo activarse (trigger_keywords, trigger_task_types, detection_rules)
    - Prioridad y fallback (is_default)
  """

  import Ecto.Query
  require Logger

  alias ElPaso.Repo
  alias ElPaso.Models.Personality
  alias ElPaso.Context.EmbeddingClient

  @doc "Crea una nueva personalidad."
  @spec create_personality(map()) :: {:ok, Personality.t()} | {:error, Ecto.Changeset.t()}
  def create_personality(attrs) do
    %Personality{}
    |> Personality.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Lista todas las personalidades (activas e inactivas)."
  @spec list_personalities() :: [Personality.t()]
  def list_personalities do
    Repo.all(Personality)
  end

  @doc "Lista solo las personalidades activas, ordenadas por prioridad (mayor primero)."
  @spec list_active() :: [Personality.t()]
  def list_active do
    Personality
    |> where(active: true)
    |> order_by(desc: :priority)
    |> preload([:model, :engine])
    |> Repo.all()
  end

  @doc "Obtiene la personalidad por defecto (fallback)."
  @spec get_default() :: Personality.t() | nil
  def get_default do
    Personality
    |> where(active: true, is_default: true)
    |> preload([:model, :engine])
    |> Repo.one()
  end

  @doc "Busca personalidades que coincidan con las keywords dadas."
  @spec matching_keywords([String.t()]) :: [Personality.t()]
  def matching_keywords(keywords) when is_list(keywords) do
    list_active()
    |> Enum.filter(fn p ->
      triggers = p.trigger_keywords || []
      not Enum.empty?(triggers) and
        Enum.any?(triggers, fn tk -> tk in keywords end)
    end)
  end

  @doc "Obtiene una personalidad por nombre."
  @spec get_personality(String.t()) :: Personality.t() | nil
  def get_personality(name) do
    Repo.get_by(Personality, name: name)
    |> Repo.preload([:model, :engine])
  end

  @doc """
  Busca una personalidad que use un modelo concreto (por nombre de modelo).
  Útil cuando un cliente Anthropic/OpenAI solicita un modelo específico.
  """
  @spec find_by_model_name(String.t()) :: Personality.t() | nil
  def find_by_model_name(model_name) do
    Personality
    |> join(:inner, [p], m in assoc(p, :model))
    |> where([p, m], m.name == ^model_name and p.active == true)
    |> order_by([p], desc: p.priority)
    |> limit(1)
    |> preload([:model, :engine])
    |> Repo.one()
  end

  @doc "Elimina una personalidad por nombre."
  @spec delete_personality(String.t()) :: {:ok, Personality.t()} | {:error, String.t()}
  def delete_personality(name) do
    case Repo.get_by(Personality, name: name) do
      nil -> {:error, "Personalidad no encontrada"}
      personality -> Repo.delete(personality)
    end
  end

  @doc "Actualiza una personalidad existente."
  @spec update_personality(String.t(), map()) ::
          {:ok, Personality.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def update_personality(name, attrs) do
    case Repo.get_by(Personality, name: name) do
      nil -> {:error, "Personalidad no encontrada"}
      personality -> personality |> Personality.changeset(attrs) |> Repo.update()
    end
  end

  # ── v4.0: Embedding ──────────────────────────────────────────────────────

  @doc """
  Genera y almacena el embedding semántico de una personalidad concreta.

  Usa `semantic_description` (si existe), `description`, o `name` como texto
  fuente para generar el vector. El embedding se almacena en el campo
  `embedding` (pgvector) para que el DecisionEngine (capa 2) pueda hacer
  cosine similarity.

  Devuelve `{:ok, personality}` o `{:error, reason}`.
  """
  @spec embed_personality(Personality.t() | String.t()) ::
          {:ok, Personality.t()} | {:error, term()}
  def embed_personality(%Personality{} = personality) do
    text = embedding_text(personality)

    case EmbeddingClient.embed(text) do
      {:ok, vector} ->
        pgv = Pgvector.new(vector)

        personality
        |> Personality.changeset(%{embedding: pgv})
        |> Repo.update()

      {:error, reason} ->
        Logger.warning("[PersonalityManager] No se pudo generar embedding para #{personality.name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def embed_personality(name) when is_binary(name) do
    case Repo.get_by(Personality, name: name) do
      nil -> {:error, :not_found}
      personality -> embed_personality(personality)
    end
  end

  @doc """
  Genera y almacena embeddings para TODAS las personalidades existentes.

  Útil tras crear varias personalidades nuevas o tras cambiar sus descripciones.
  Devuelve `{:ok, %{succeeded: count, failed: errors}}`.
  """
  @spec embed_all() :: {:ok, map()}
  def embed_all do
    personalities = Repo.all(Personality)
    results = Enum.reduce(personalities, %{succeeded: 0, failed: []}, fn p, acc ->
      case embed_personality(p) do
        {:ok, _} -> %{acc | succeeded: acc.succeeded + 1}
        {:error, reason} -> %{acc | failed: [{p.name, reason} | acc.failed]}
      end
    end)
    {:ok, %{results | failed: Enum.reverse(results.failed)}}
  end

  @doc """
  Devuelve las personalidades que YA tienen embedding generado (listas para capa 2).
  """
  @spec list_embedded() :: [Personality.t()]
  def list_embedded do
    Personality
    |> where([p], not is_nil(p.embedding))
    |> order_by(desc: :priority)
    |> Repo.all()
  end

  @doc "Número de personalidades con embedding generado."
  @spec embedding_count() :: non_neg_integer()
  def embedding_count do
    Personality
    |> where([p], not is_nil(p.embedding))
    |> Repo.aggregate(:count)
  end

  defp embedding_text(%Personality{} = p) do
    cond do
      not is_nil(p.semantic_description) and p.semantic_description != "" -> p.semantic_description
      not is_nil(p.description) and p.description != "" -> p.description
      true -> p.name
    end
  end
end
