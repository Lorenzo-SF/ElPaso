defmodule ElPaso.Config.Diff do
  @moduledoc """
  Módulo para la gestión de diferencias en configuraciones.
  """

  defstruct changes: [],
            impact: :none,
            hot_reload: false,
            requires_model_restart: false,
            requires_full_restart: false

  @doc """
  Genera una diferencia entre dos configuraciones.
  """
  def diff(_old_config, _new_config) do
    # Implementación temporal
    %ElPaso.Config.Diff{}
  end

  @doc """
  Aplana la configuración para su procesamiento.
  """
  def flatten(_config) do
    # Implementación temporal
    %{}
  end
end
