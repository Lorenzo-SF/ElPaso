defmodule ElPaso.CostManager do
  @moduledoc """
  Gestor de costes para APIs remotas.

  Registra el uso de tokens, calcula costes y gestiona budgets de usuario.
  """

  require Logger

  alias ElPaso.Config
  alias ElPaso.Context.Storage

  @doc """
  Registra el uso de tokens de un request.
  Llamado por el pipeline tras cada inferencia remota.
  """
  @spec record_usage(String.t(), String.t(), non_neg_integer(), non_neg_integer()) :: :ok
  def record_usage(user_id, model_id, input_tokens, output_tokens) do
    price = get_price(model_id)

    cost_usd = calculate_cost(input_tokens, output_tokens, price)

    # Upsert en api_usage
    Storage.upsert_api_usage(%{
      user_id: user_id,
      model_id: model_id,
      date: Date.utc_today(),
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      cost_usd: cost_usd
    })

    # Verificar budget después de registrar uso
    _budget_status = check_budget(user_id)

    :ok
  end

  @doc """
  Calcula el coste en USD para los tokens dados.
  """
  @spec calculate_cost(non_neg_integer(), non_neg_integer(), map()) :: Decimal.t()
  def calculate_cost(input_tokens, output_tokens, price) do
    input_cost = input_tokens * Decimal.to_float(price.input_price_per_1k) / 1000
    output_cost = output_tokens * Decimal.to_float(price.output_price_per_1k) / 1000

    Decimal.from_float(input_cost + output_cost)
  end

  @doc """
  Obtiene el precio para un modelo desde la BD o config.
  """
  @spec get_price(String.t()) :: map()
  def get_price(model_id) do
    # Primero buscar en BD (si hay implementación real)
    # Por ahora siempre usamos default pricing
    # case Storage.get_model_pricing(model_id) do
    #   {:ok, pricing} -> ...
    #   {:error, _} -> ...
    # end

    # Fallback a configuración por defecto directamente
    default_pricing(model_id)
  end

  @doc """
  Verifica el budget diario del usuario.
  Devuelve:
  - :budget_exceeded si supera el budget
  - :approaching_budget si está cerca (por threshold)
  - :ok si está dentro del budget
  """
  @spec check_budget(String.t()) :: :ok | :approaching_budget | :budget_exceeded
  def check_budget(user_id) do
    config = Config.Loader.get()
    cost_config = Map.get(config, :cost_management, %{})

    # Si no está habilitado, retornar ok
    unless Map.get(cost_config, :enabled, false) do
      :ok
    end

    daily_limit = Map.get(cost_config, :daily_usd, 100.0)
    alert_pct = Map.get(cost_config, :alert_at_pct, 80)

    daily_spend = Storage.daily_spend(user_id)

    cond do
      daily_spend >= daily_limit ->
        Logger.warning("Usuario #{user_id} superó el budget diario ($#{daily_spend})")
        :budget_exceeded

      daily_spend >= daily_limit * alert_pct / 100 ->
        Logger.info("Usuario #{user_id} acercándose al budget ($#{daily_spend}/$#{daily_limit})")
        :approaching_budget

      true ->
        :ok
    end
  end

  @doc """
  Devuelve la penalización de score para modelos remotos basada en el estado del budget.

  - :budget_exceeded -> 999.0 (excluye modelos remotos)
  - :approaching_budget -> 0.3 (penalización significativa)
  - :ok -> 0.0 (sin penalización)
  """
  @spec remote_model_penalty(String.t()) :: float()
  def remote_model_penalty(user_id) do
    case check_budget(user_id) do
      :budget_exceeded -> 999.0
      :approaching_budget -> 0.3
      :ok -> 0.0
    end
  end

  # Default pricing si no hay en BD
  defp default_pricing(model_id) do
    # Precios por defecto (aproximados)
    cond do
      String.contains?(model_id, "opus") ->
        %{
          input_price_per_1k: Decimal.from_float(15.0),
          output_price_per_1k: Decimal.from_float(75.0)
        }

      String.contains?(model_id, "sonnet") ->
        %{
          input_price_per_1k: Decimal.from_float(3.0),
          output_price_per_1k: Decimal.from_float(15.0)
        }

      String.contains?(model_id, "haiku") ->
        %{
          input_price_per_1k: Decimal.from_float(0.25),
          output_price_per_1k: Decimal.from_float(1.25)
        }

      true ->
        %{
          input_price_per_1k: Decimal.from_float(1.0),
          output_price_per_1k: Decimal.from_float(5.0)
        }
    end
  end
end
