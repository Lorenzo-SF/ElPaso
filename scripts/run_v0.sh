#!/usr/bin/env bash
# =============================================================================
# run_v0.sh — Automatización ElPaso V0: Proyecto Base Elixir
# =============================================================================
source "$(dirname "$0")/common.sh"

version_header "V0" "Proyecto Base Elixir — Scaffolding"

# ---------------------------------------------------------------------------
# BLOQUE 1: Scaffolding completo (coder)
# ---------------------------------------------------------------------------
PROMPT_B1=$(cat <<'PROMPT'
Eres un desarrollador Elixir experto. Estás creando el proyecto ElPaso desde cero. El proyecto es un proxy de inferencia multi-modelo.

CONTEXTO IMPORTANTE:
- Zaguan es una dependencia local en ~/proyectos/zaguan (framework TUI/CLI para Elixir). Úsala como {:zaguan, path: "~/proyectos/zaguan"} en mix.exs.
- Runtime: Elixir 1.19.5 / OTP 28.

PASO 1: Si no existe el proyecto, ejecuta `mix new elpaso --sup`. Si ya existe, adapta lo que haga falta.

PASO 2: Edita mix.exs para que tenga estas dependencias EXACTAS:
  {:plug_cowboy, "~> 2.7"}, {:finch, "~> 0.19"}, {:jason, "~> 1.4"},
  {:ecto_sql, "~> 3.11"}, {:postgrex, "~> 0.17"}, {:pgvector, "~> 0.2"},
  {:nimble_options, "~> 1.1"}, {:telemetry, "~> 1.2"},
  {:zaguan, path: Path.expand("~/proyectos/zaguan")},
  {:jose, "~> 1.11"}, {:libcluster, "~> 3.4"},
  {:ex_aws, "~> 2.5"}, {:ex_aws_s3, "~> 2.5"},
  {:ex_doc, "~> 0.31", only: :dev, runtime: false},
  {:mox, "~> 1.1", only: :test}, {:bypass, "~> 2.1", only: :test}
Configura elixir: "~> 1.19", app: :elpaso.

PASO 3: Crea módulos placeholder (defmodule con @moduledoc breve) en:
- lib/elpaso/context/{prefix_manager,builder,manager,storage,token_counter,embedding_client,semantic_retriever,tokenizer,summarization_worker}.ex
- lib/elpaso/context/schemas/{session,message,conversation_summary,routing_decision}.ex
- lib/elpaso/domain/{router,model_manager,model_worker,model_supervisor,model_registry,model_pool,output_cache,router_stats,router_tuner}.ex
- lib/elpaso/engine/{base,llama_server,openai,anthropic,ollama,vllm,dispatcher,chat_template,registry}.ex
- lib/elpaso/config/{loader,schema,validator,merger,environment_detector,condition_evaluator,migrator,diff}.ex
- lib/elpaso/http/{router,dashboard,auth_plug,request_parser,anthropic_proxy,websocket_handler}.ex
- lib/elpaso/security/{auth,rate_limiter}.ex
- lib/elpaso/telemetry/{supervisor,store,prometheus_exporter}.ex
- lib/elpaso/cluster/node_registry.ex
- lib/elpaso/plugin/loader.ex
- lib/elpaso/model_downloader.ex
- lib/elpaso/cost_manager.ex
- lib/elpaso/repo.ex

PASO 4: Crea lib/elpaso/types.ex con structs (defstruct con campos y defaults nil):
- FeatureVector: token_estimate, task_type, complexity_score, language, has_structured_output_request, is_continuation, prompt_length_chars, has_image_input, image_count
- RoutingDecision: request_id, session_id, selected_model, runner_up, features, scores, reason, decided_at, decision_latency_us
- ModelState: model_id, status, pid, port, current_queue_depth, avg_latency_ms, p95_latency_ms, last_error_at, last_error_reason, consecutive_errors, restart_count, ram_mb, vram_mb, started_at, last_call_at, node
- PrefixBlock: session_id, content, hash, token_estimate, built_at, version
- BuiltPrompt: messages, system, token_estimate, budget_used, model_id, session_id, built_at
- SessionState: session_id, context_mode, window, window_token_count, last_summary_id, last_summary_tokens, last_model_id, summarization_in_progress, created_at, last_active_at
- ContextSpec: model_id, max_tokens, reserved_for_output, usable_tokens
- SessionOverrides: session_id, context_mode, window_size, force_model, latency_tolerance_ms, summarize_with_model
- ConversationSummary: session_id, content, covers_until_message_id, token_estimate, generated_at, generated_by_model

PASO 5: Crea configs:
- config/config.exs: Logger config, Ecto repos [ElPaso.Repo], Jason
- config/dev.exs: log level :debug, Repo database elpaso_dev
- config/test.exs: log level :warning, Repo pool Ecto.Adapters.SQL.Sandbox
- config/runtime.exs: lee DATABASE_URL del entorno

PASO 6: lib/elpaso/repo.ex: use Ecto.Repo, otp_app: :elpaso, adapter: Ecto.Adapters.Postgres

PASO 7: Application children: [ElPaso.Repo, {Finch, name: ElPasoFinch}]

PASO 8: Ejecuta mix deps.get && mix compile para verificar.
PROMPT
)

if ! run_block "coder" "Scaffolding proyecto Elixir" "$PROMPT_B1"; then
    echo -e "${RED}✗  Error crítico en V0. Deteniendo ejecución.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Commit y tag
# ---------------------------------------------------------------------------
git_commit "feat(v0): proyecto base Elixir con estructura y dependencias"
git_tag "v0"

echo ""
echo -e "${GREEN}${BOLD}✓ V0 completada${NC}"
