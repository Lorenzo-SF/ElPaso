defmodule ElPaso.Config.Migrator do
  @moduledoc """
  Migrador de configuración entre versiones.

  Implementa la migración de V1.0 a V1.1.
  """

  @doc """
  Migra la configuración de una versión a otra.
  """
  def migrate(config, from_version, to_version) do
    # Esta implementación es simplificada para prototipo

    case find_migration_path(from_version, to_version) do
      [] ->
        {:error, :no_migration_path}

      path ->
        Enum.reduce_while(path, {:ok, config}, fn {from, to}, {:ok, acc} ->
          case apply_migration(acc, from, to) do
            {:ok, migrated} -> {:cont, {:ok, migrated}}
            {:error, _} = err -> {:halt, err}
          end
        end)
    end
  end

  @doc """
  Verifica si se puede migrar de una versión a otra.
  """
  def can_migrate?(from, to) do
    find_migration_path(from, to) != []
  end

  # Funciones auxiliares
  defp find_migration_path(from, to) do
    # Simplificación - en producción se usaría un mapa de rutas

    case {from, to} do
      {"1.0", "1.1"} -> [{"1.0", "1.1"}]
      _ -> []
    end
  end

  defp apply_migration(config, from, to) do
    case {from, to} do
      {"1.0", "1.1"} ->
        {:ok, migrate_1_0_to_1_1(config)}

      _ ->
        {:error, :unknown_migration}
    end
  end

  defp migrate_1_0_to_1_1(config) do
    # Migración de V1.0 a V1.1

    # Añadir sección embeddings
    migrated_config =
      config
      |> Map.put_new("embeddings", default_embeddings_config())

    # Añadir tokenizer a cada modelo
    models = Map.get(migrated_config, "models", %{})

    updated_models =
      Enum.reduce(models, %{}, fn {model_id, model}, acc ->
        updated_model =
          model
          |> Map.put_new("context_spec", %{})
          |> Map.update!("context_spec", fn spec ->
            spec
            |> Map.put_new("tokenizer", "estimate")
            |> Map.put_new("supports_vision", false)
          end)

        Map.put(acc, model_id, updated_model)
      end)

    migrated_config
    |> Map.put("models", updated_models)
    |> Map.put("meta", Map.put_new(%{}, "version", "1.1"))
  end

  defp default_embeddings_config do
    %{
      "enabled" => false,
      "model_id" => nil,
      "dimensions" => 768,
      "embedding_timeout_ms" => 5000,
      "batch_size" => 50,
      "semantic_retrieval_k" => 5,
      "min_similarity_threshold" => 0.75,
      "ivfflat_build_threshold" => 100
    }
  end
end
