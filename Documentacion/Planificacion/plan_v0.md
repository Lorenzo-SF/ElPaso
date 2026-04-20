# Plan V0 — Proyecto Base Elixir

> **Spec**: [v0.md](../v0.md) | **Prerequisito**: Ninguno

## Objetivo
Crear proyecto Elixir 1.19.5-otp-28 desde cero: mix.exs, estructura de directorios, tipos compartidos, configs.

---

## BLOQUE 1 — Scaffolding completo (coder)

**Modelo**: `coder` | **Estimación**: ~20 min

### Tareas
1. `mix new elpaso --sup` (o adaptar si existe)
2. mix.exs con TODAS las dependencias (plug_cowboy, finch, jason, ecto_sql, postgrex, pgvector, nimble_options, telemetry, zaguan, jose, libcluster, ex_aws, ex_aws_s3, ex_doc, mox, bypass)
3. Estructura de directorios con módulos placeholder (defmodule + @moduledoc):
   - `lib/elpaso/{context,domain,engine,config,http,security,cli/commands,telemetry}/`
   - Schemas en `context/schemas/`
4. `lib/elpaso/types.ex` con todos los structs: FeatureVector, RoutingDecision, ModelState, PrefixBlock, BuiltPrompt, SessionState, ContextSpec, SessionOverrides, ConversationSummary
5. `config/{config,dev,test,runtime}.exs` para Ecto/Logger
6. `lib/elpaso/repo.ex` y Application con children básicos
7. `mix deps.get && mix compile`

### Prompt opencode

> Eres un desarrollador Elixir experto. Crea el proyecto ElPaso desde cero.
>
> 1. Ejecuta `mix new elpaso --sup` si no existe. Configura mix.exs con elixir: "~> 1.19" y estas deps: {:plug_cowboy, "~> 2.7"}, {:finch, "~> 0.19"}, {:jason, "~> 1.4"}, {:ecto_sql, "~> 3.11"}, {:postgrex, "~> 0.17"}, {:pgvector, "~> 0.2"}, {:nimble_options, "~> 1.1"}, {:telemetry, "~> 1.2"}, {:zaguan, "~> 1.0"}, {:jose, "~> 1.11"}, {:libcluster, "~> 3.4"}, {:ex_aws, "~> 2.5"}, {:ex_aws_s3, "~> 2.5"}, {:ex_doc, "~> 0.31", only: :dev, runtime: false}, {:mox, "~> 1.1", only: :test}, {:bypass, "~> 2.1", only: :test}
>
> 2. Crea módulos placeholder (defmodule vacío con @moduledoc) en: lib/elpaso/context/{prefix_manager,builder,manager,storage,token_counter}.ex, lib/elpaso/context/schemas/{session,message,conversation_summary,routing_decision}.ex, lib/elpaso/domain/{router,model_manager,model_worker,model_supervisor,model_registry,model_pool,output_cache}.ex, lib/elpaso/engine/{base,llama_server,openai,anthropic,ollama,vllm,dispatcher,chat_template}.ex, lib/elpaso/config/{loader,schema,validator,wizard,merger,environment_detector,condition_evaluator,migrator}.ex, lib/elpaso/http/{router,dashboard}.ex, lib/elpaso/security/auth.ex, lib/elpaso/telemetry/supervisor.ex, lib/elpaso/repo.ex
>
> 3. Crea lib/elpaso/types.ex con structs defstruct y typespecs para: FeatureVector(token_estimate,task_type,complexity_score,language,has_structured_output_request,is_continuation,prompt_length_chars,has_image_input,image_count), RoutingDecision(request_id,session_id,selected_model,runner_up,features,scores,reason,decided_at,decision_latency_us), ModelState(model_id,status,pid,port,current_queue_depth,avg_latency_ms,p95_latency_ms,last_error_at,last_error_reason,consecutive_errors,restart_count,ram_mb,vram_mb,started_at,last_call_at,node), PrefixBlock(session_id,content,hash,token_estimate,built_at,version), BuiltPrompt(messages,system,token_estimate,budget_used,model_id,session_id,built_at), SessionState(session_id,context_mode,window,window_token_count,last_summary_id,last_summary_tokens,last_model_id,summarization_in_progress,created_at,last_active_at), ContextSpec(model_id,max_tokens,reserved_for_output,usable_tokens), SessionOverrides(session_id,context_mode,window_size,force_model,latency_tolerance_ms,summarize_with_model), ConversationSummary(session_id,content,covers_until_message_id,token_estimate,generated_at,generated_by_model)
>
> 4. Crea config/config.exs (Ecto Repo, Logger, Jason), config/dev.exs (log debug), config/test.exs (sandbox, log warn), config/runtime.exs (DATABASE_URL). Repo: use Ecto.Repo, otp_app: :elpaso, adapter: Ecto.Adapters.Postgres. Application children: [ElPaso.Repo, {Finch, name: ElPasoFinch}]
>
> 5. Ejecuta mix deps.get y mix compile para verificar.

### Criterio de completitud
- `mix compile` sin errores
- Estructura de directorios completa
- Tipos en types.ex

---

## Resumen

| Bloque | Modelo | Descripción          |
|--------|--------|----------------------|
| 1      | coder  | Scaffolding completo |

**Cambios de modelo**: 0
