#!/usr/bin/env bash
# =============================================================================
# run_v2.1.sh — Automatización ElPaso V2.1: Clustering Multi-nodo
# =============================================================================
source "$(dirname "$0")/common.sh"

version_header "V2.1" "Clustering Multi-nodo"

# --- BLOQUE 1: NodeRegistry + Router distribuido (thinker) ---
PROMPT_B1=$(cat <<'PROMPT'
Implementa clustering para ElPaso. Lee Documentacion/v2.1.md completa.

1. ElPaso.Cluster.NodeRegistry (GenServer): init con net_kernel.start si cluster enabled, connect_to_configured_nodes. all_nodes/0, remote_model_states/2 con :rpc.call timeout 500ms.
2. Config cluster: enabled, node_name, role, discovery (static/gossip). Static: Node.connect. Gossip: Cluster.Supervisor con libcluster Strategy.Gossip.
3. ElPaso.Domain.Router.Cluster: all_model_states_global/0 agrega local+remotos via Task.async_stream (timeout 600ms). forward_to_remote_node/4 con :rpc.call a Dispatcher.infer.
4. mix elpaso cluster status. Integrar en Router: cluster_mode? → usar all_model_states_global.
PROMPT
)

if ! run_block "thinker" "NodeRegistry + Router distribuido" "$PROMPT_B1"; then
    echo -e "${RED}✗  Error crítico en V2.1 Bloque 1. Deteniendo.${NC}"
    exit 1
fi

# --- BLOQUE 2: Context.Manager modo cluster (coder) ---
PROMPT_B2=$(cat <<'PROMPT'
Implementa Context.Manager cluster para ElPaso. Lee Documentacion/v2.1.md sección 2.1.4.

Context.Manager: TTL 30s en ETS para cluster. get_session_state verifica timestamp, recarga desde PostgreSQL si expirado. cluster_mode?() condicional. ETS entry: {session_id, state, monotonic_time}.
PROMPT
)

if ! run_block "coder" "Context.Manager cluster" "$PROMPT_B2"; then
    echo -e "${RED}✗  Error crítico en V2.1 Bloque 2. Deteniendo.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Commit y tag
# ---------------------------------------------------------------------------
git_commit "feat(v2.1): clustering multi-nodo"
git_tag "v2.1"
echo -e "${GREEN}${BOLD}✓ V2.1 completada${NC}"
