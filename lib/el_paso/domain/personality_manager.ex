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

  alias ElPaso.Repo
  alias ElPaso.Models.Personality

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
end
