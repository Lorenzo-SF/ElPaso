#!/usr/bin/env bash
# =============================================================================
# register-wrapper-models.sh
# Lee ~/bin/localllama y registra engines, modelos y personalidades en ElPaso.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WRAPPER="${1:-$HOME/bin/localllama}"

ELPASO_BIN="${ELPASO_BIN:-$(command -v elpaso 2>/dev/null || true)}"
if [[ -z "$ELPASO_BIN" && -f "$HOME/.elpaso/elpaso" ]]; then
    ELPASO_BIN="$HOME/.elpaso/elpaso"
fi
if [[ -z "$ELPASO_BIN" ]]; then
    echo "❌ Binario 'elpaso' no encontrado." >&2
    echo "   Compila: MIX_ENV=prod mix gen" >&2
    exit 1
fi

_cya='\033[1;36m'; _grn='\033[1;32m'; _yel='\033[1;33m'; _rst='\033[0m'
log()  { printf "${_cya}[register]${_rst} %s\n" "$*"; }

PORT=$(grep -E '^readonly PORT=' "$WRAPPER" | head -1 | sed 's/.*="\(.*\)".*/\1/')
API_KEY=$(grep -E '^readonly API_KEY=' "$WRAPPER" | head -1 | sed 's/.*="\(.*\)".*/\1/')
[[ -z "$PORT" || -z "$API_KEY" ]] && { echo "❌ No se pudo extraer PORT/API_KEY"; exit 1; }

log "Wrapper: $WRAPPER  |  Puerto: $PORT"
echo ""
cd "$PROJECT_DIR"

BASE_URL="http://localhost:${PORT}/v1"

# ─── ENGINE ──────────────────────────────────────────────────────────────────
log "Engine: llama-local"
"$ELPASO_BIN" engine add \
    --name=llama-local \
    --adapter=llama_cpp \
    --base-url="$BASE_URL" \
    --api-key="$API_KEY" 2>/dev/null || true

# ─── MODELOS ─────────────────────────────────────────────────────────────────
log "Modelos..."
for m in \
  "coder:65536:0.2:0.90:Qwen3-30B-A3B Q3_K_XL — código diario, PRs, refactors. FULL GPU, 64K ctx." \
  "coder-fim:65536:0.2:0.90:Qwen3-Coder-30B-A3B Q3_K_XL — código FIM dedicado. Mejores benchmarks, 64K ctx." \
  "thinker:131072:0.4:0.90:Qwen3.6-35B-A3B Q4_K_XL — razonamiento SSM híbrido. 10 capas KV, 128K ctx." \
  "thinker-opus:100000:0.4:0.90:Qwen3.6-35B-A3B Q4_K_M — destilado Claude 4.6 Opus. Razonamiento pro." \
  "gemma:32768:0.7:0.90:gemma-4-E4B-it Q6_K_XL — consultas generales, brainstorming, rápido."; do
  IFS=':' read -r name max_tokens temp top_p desc <<< "$m"
  "$ELPASO_BIN" model add \
      --name="$name" \
      --engine=llama-local \
      --url="$BASE_URL" \
      --max-tokens="$max_tokens" \
      --temp="$temp" \
      --top-p="$top_p" \
      --description="$desc" 2>/dev/null || true
done

# ─── PERSONALIDADES (con triggers para el router MoE) ────────────────────────
log "Personalidades (con triggers de activación)..."

"$ELPASO_BIN" personality add \
    --name=coder \
    --model=coder-fim --engine=llama-local \
    --system-prompt="Eres un ingeniero de software senior experto. Escribes código limpio, idiomático y bien documentado. Explicas tus decisiones técnicas. Usas patrones de diseño. Prefieres soluciones simples y mantenibles. Cuando refactorizas, mantienes todas las validaciones originales." \
    --keywords="refactoriza,implementa,test,PR,bug,fix,debug,compila,migra,migration,endpoint,api,módulo,función,typespec,pattern match,gen_server,supervisor,ecto,schema" \
    --task-types="code,debug,refactor,testing" \
    --priority=10 2>/dev/null || true

"$ELPASO_BIN" personality add \
    --name=architect \
    --model=thinker-opus --engine=llama-local \
    --system-prompt="Eres un arquitecto de software con 20 años de experiencia. Analizas requisitos, diseñas sistemas escalables, evalúas trade-offs entre rendimiento, mantenibilidad y coste. Piensas en el largo plazo. Documentas tus decisiones de arquitectura con ADRs. Conoces patrones: microservicios, event-driven, CQRS, hexagonal, etc." \
    --keywords="arquitectura,diseña,escalable,sistema,ADR,trade-off,tradeoff,event-driven,microservicio,monolito,hexagonal,cqrs,pipeline,infraestructura,cluster,distribuido" \
    --task-types="architecture,reasoning,planning,code" \
    --priority=20 2>/dev/null || true

"$ELPASO_BIN" personality add \
    --name=legal-es \
    --model=thinker --engine=llama-local \
    --system-prompt="Eres un asistente jurídico especializado en legislación española. Respondes BASÁNDOTE EXCLUSIVAMENTE en los documentos y legislación proporcionados. Citas artículos y disposiciones concretas indicando la fuente. Si no encuentras la información, dices: 'No consta en los documentos analizados'. NO inventas legislación." \
    --keywords="ley,BOE,pensión,jubilación,IRPF,seguridad social,excedencia,contrato,legal,jurídico,artículo,disposición,normativa,real decreto,estatuto,trabajadores,constitución,sentencia,tribunal" \
    --task-types="legal,question_answer,summarization" \
    --priority=30 2>/dev/null || true

"$ELPASO_BIN" personality add \
    --name=tutor \
    --model=thinker --engine=llama-local \
    --system-prompt="Eres un tutor paciente y didáctico. Explicas conceptos desde lo más básico, paso a paso, asegurándote de que el alumno entiende cada paso antes de avanzar. Usas analogías, ejemplos concretos y diagramas conceptuales cuando ayudan. Adaptas tu ritmo al nivel del alumno. Nunca asumes conocimiento previo." \
    --keywords="explica,explicar,explicación,por qué,cómo funciona,qué es,define,definición,significa,diferencia entre,comparar,tutorial,paso a paso,aprender,guía" \
    --task-types="question_answer,explanation" \
    --priority=5 2>/dev/null || true

"$ELPASO_BIN" personality add \
    --name=general \
    --model=gemma --engine=llama-local \
    --system-prompt="Eres un asistente útil, conversacional y directo. Respondes preguntas de todo tipo con precisión y sin rodeos. Si no sabes algo, lo dices claramente. Eres amable pero no empalagoso. Adaptas tu tono al contexto de la conversación." \
    --priority=1 --default 2>/dev/null || true

echo ""
log "Registro completo."
echo "  1 engine, 5 modelos, 5 personalidades (con triggers de activación)"
echo "  Personalidad por defecto: general (gemma)"
log "Arranca:  localllama <modelo>  +  $ELPASO_BIN server start"
