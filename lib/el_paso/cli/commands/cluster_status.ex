defmodule ElPaso.CLI.Commands.ClusterStatus do
  @moduledoc """
  Muestra el estado del cluster: nodos, roles y modelos disponibles.
  
  Uso: mix elpaso cluster status
  """

  def run(_opts) do
    IO.puts("=== ElPaso Cluster Status ===\n")

    if ElPaso.Config.cluster_enabled?() do
      IO.puts("Cluster: HABILITADO\n")
      IO.puts("Node name: #{ElPaso.Config.node_name() || "no configurado"}")
      IO.puts("Role: #{ElPaso.Config.node_role()}")
      IO.puts("Discovery: #{ElPaso.Config.cluster_discovery()}\n")

      # Mostrar nodos conectados
      nodes = ElPaso.Cluster.NodeRegistry.all_nodes()
      
      IO.puts("Nodos conectados (#{length(nodes)}):")
      
      if Enum.empty?(nodes) do
        IO.puts("  (ninguno)\n")
      else
        Enum.each(nodes, fn node_info ->
          IO.puts("  - #{node_info.node}")
          IO.puts("    Role: #{node_info.role}")
          IO.puts("    Status: #{node_info.status}\n")
        end)
      end

      # Mostrar modelos disponibles en cada nodo
      IO.puts("Modelos disponibles por nodo:")
      
      model_states = ElPaso.Cluster.NodeRegistry.all_model_states()
      
      if Enum.empty?(model_states) do
        IO.puts("  (ninguno)")
      else
        Enum.each(model_states, fn {node, states} ->
          IO.puts("  #{node}:")
          
          if Enum.empty?(states) do
            IO.puts("    (sin modelos)")
          else
            Enum.each(states, fn state ->
              IO.puts("    - #{state.model_id}: #{state.status}")
            end)
          end
        end)
      end
    else
      IO.puts("Cluster: DESHABILITADO\n")
      IO.puts("Para habilitar, configura cluster.enabled = true en la config.")
    end

    :ok
  end
end