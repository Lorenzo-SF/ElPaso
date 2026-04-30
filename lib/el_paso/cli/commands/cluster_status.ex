defmodule ElPaso.CLI.Commands.ClusterStatus do
  @moduledoc """
  Muestra el estado del cluster: nodos, roles y modelos disponibles.

  Uso: mix elpaso cluster status
  """

  alias ElPaso.CLI.Output

  def run(_opts) do
    Output.section("ElPaso Cluster Status")

    if ElPaso.Config.cluster_enabled?() do
      Output.info("Cluster: HABILITADO")
      Output.divider("Configuración del nodo")

      Output.data_table(
        ["Campo", "Valor"],
        [
          ["Node name", ElPaso.Config.node_name() || "no configurado"],
          ["Role", ElPaso.Config.node_role()],
          ["Discovery", ElPaso.Config.cluster_discovery()]
        ]
      )

      nodes = ElPaso.Cluster.NodeRegistry.all_nodes()

      Output.divider("Nodos conectados (#{length(nodes)})")

      if Enum.empty?(nodes) do
        Output.info("(ninguno)")
      else
        rows =
          Enum.map(nodes, fn node_info ->
            [to_string(node_info.node), node_info.role, to_string(node_info.status)]
          end)

        Output.data_table(["Nodo", "Rol", "Estado"], rows)
      end

      model_states = ElPaso.Cluster.NodeRegistry.all_model_states()

      Output.divider("Modelos disponibles por nodo")

      if Enum.empty?(model_states) do
        Output.info("(ninguno)")
      else
        rows =
          Enum.flat_map(model_states, fn {node, states} ->
            if Enum.empty?(states) do
              [[to_string(node), "(sin modelos)", ""]]
            else
              Enum.map(states, fn state ->
                [to_string(node), state.model_id, to_string(state.status)]
              end)
            end
          end)

        Output.data_table(["Nodo", "Modelo", "Estado"], rows)
      end
    else
      Output.warning("Cluster: DESHABILITADO")
      Output.info("Para habilitar, configura cluster.enabled = true en la config.")
    end

    :ok
  end
end
