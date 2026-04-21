defmodule ElPaso.Engine.Registry do
  @moduledoc """
  Registro central de engines disponibles.

  Permite registro dinámico de engines (plugins) además de los internos.
  """
  use GenServer

  @table :engine_registry

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    table = :ets.new(@table, [:named_table, :protected, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @doc """
  Registra un engine dinámicamente.
  """
  def register(name, module) when is_atom(name) do
    :ets.insert(@table, {name, module})
    :telemetry.execute([:elpaso, :engine, :registered], %{}, %{name: name})
    :ok
  end

  @doc """
  Obtiene el módulo de un engine por nombre.
  """
  def get(name) do
    case :ets.lookup(@table, name) do
      [{^name, module}] -> {:ok, module}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lista todos los engines registrados.
  """
  def list_all do
    :ets.tab2list(@table)
  end

  @doc """
  Desregistra un engine.
  """
  def unregister(name) do
    :ets.delete(@table, name)
    :ok
  end
end
