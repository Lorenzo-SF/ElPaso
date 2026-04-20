# Plan V2.1 — Clustering Multi-nodo

> **Spec**: [v2.1.md](../v2.1.md) | **Prerequisito**: V2.0 completo

## Objetivo
Varias instancias ElPaso en red local comparten sesiones y distribuyen inferencia.

---

## BLOQUE 1 — NodeRegistry + Router distribuido + libcluster (thinker)

**Modelo**: `thinker` | **Estimación**: ~35 min

**Tareas**:
1. `ElPaso.Cluster.NodeRegistry` (GenServer): init con net_kernel.start, connect_to_configured_nodes, all_nodes/0, all_model_states/0, remote_model_states/2 con RPC timeout 500ms
2. Config sección cluster: enabled, node_name, role (coordinator/worker/both), coordinator_nodes, worker_nodes, discovery (static/gossip)
3. Descubrimiento: modo static (Node.connect al arrancar), modo gossip con libcluster (Cluster.Supervisor con Strategy.Gossip)
4. `ElPaso.Domain.Router.Cluster`: all_model_states_global/0 agregando local + remotos via Task.async_stream con timeout 600ms, ModelState con campo node
5. Forward a nodo remoto: forward_to_remote_node/4 con :rpc.call a Engine.Dispatcher.infer
6. mix elpaso cluster status — muestra nodos, roles, modelos

**Ref**: Secciones 2.1.1-2.1.3 de v2.1.md

---

## BLOQUE 2 — Context.Manager modo cluster (coder)

**Modelo**: `coder` | **Estimación**: ~20 min

**Tareas**:
1. Context.Manager con TTL 30s en ETS para modo cluster: get_session_state verifica timestamp, recarga desde PostgreSQL si expirado
2. cluster_mode?/0 condicional basado en Config.cluster_enabled?
3. SessionState en ETS con timestamp inserted_at para TTL
4. Tests de integración (aceptables manuales): dos nodos comparten sesión, coordinator ejecuta en worker via RPC

**Ref**: Sección 2.1.4 de v2.1.md

---

## Resumen

| Bloque | Modelo  | Descripción                    | Dep  |
|--------|---------|--------------------------------|------|
| 1      | thinker | NodeRegistry + Router cluster  | V2.0 |
| 2      | coder   | Context.Manager cluster        | B1   |

**Cambios de modelo**: 1 (thinker→coder)
