#!/usr/bin/env bash
# =============================================================================
# register-wrapper-models.sh — Configuración inicial de ElPaso
#
# Registra 1 engine (llama-local), 5 modelos y 5 personalidades con triggers
# de activación para el router MoE manual.
#
# Uso:
#   ./scripts/register-wrapper-models.sh
#
# Idempotente: ejecutar N veces produce el mismo resultado.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ELPASO="${ELPASO_BIN:-$HOME/.elpaso/elpaso}"
if [[ ! -x "$ELPASO" ]]; then
    ELPASO="$(command -v elpaso 2>/dev/null || true)"
fi
if [[ -z "$ELPASO" ]]; then
    echo "❌ Binario 'elpaso' no encontrado." >&2
    echo "   Compila: MIX_ENV=prod mix gen" >&2
    exit 1
fi

# ─── Configuración (editable) ────────────────────────────────────────────────
PORT="${ELPASO_PORT:-8081}"
API_KEY="${ELPASO_API_KEY:-sk-local}"
BASE_URL="http://localhost:${PORT}/v1"

CYA='\033[1;36m'; GRN='\033[1;32m'; RST='\033[0m'
log()    { printf "${CYA}%s${RST}\n" "$*"; }
success(){ printf "  ${GRN}✓${RST} %s\n" "$*"; }

echo ""
log "╔══════════════════════════════════════════╗"
log "║   ElPaso — Registro inicial              ║"
log "╚══════════════════════════════════════════╝"
echo ""

cd "$PROJECT_DIR"

# ═══════════════════════════════════════════════════════════════════════════════
# 1. ENGINE — llama.cpp local
# ═══════════════════════════════════════════════════════════════════════════════
log "Engine"
$ELPASO engine add \
    --name=llama-local \
    --adapter=llama_cpp \
    --base-url="$BASE_URL" \
    --api-key="$API_KEY" \
    >/dev/null 2>&1 && success "llama-local (llama_cpp → $BASE_URL)" || true

# ═══════════════════════════════════════════════════════════════════════════════
# 2. MODELOS — los 5 del sistema local
# ═══════════════════════════════════════════════════════════════════════════════
log "Modelos"

declare -A MODELS
MODELS=(
    ["coder"]="65536|0.2|0.90|Qwen3-30B-A3B — código diario, FULL GPU, 64K ctx"
    ["coder-fim"]="65536|0.2|0.90|Qwen3-Coder-30B-A3B — código FIM dedicado, 64K ctx"
    ["thinker"]="131072|0.4|0.90|Qwen3.6-35B-A3B — razonamiento SSM, 128K ctx"
    ["thinker-opus"]="100000|0.4|0.90|Qwen3.6-35B-A3B — destilado Claude Opus, 100K ctx"
    ["gemma"]="32768|0.7|0.90|gemma-4-E4B-it — consultas generales, 32K ctx"
)

for name in "${!MODELS[@]}"; do
    IFS='|' read -r max_tokens temp top_p desc <<< "${MODELS[$name]}"
    $ELPASO model add \
        --name="$name" \
        --engine=llama-local \
        --url="$BASE_URL" \
        --max-tokens="$max_tokens" \
        --temp="$temp" \
        --top-p="$top_p" \
        --description="$desc" \
        >/dev/null 2>&1 && success "$name" || true
done

# ═══════════════════════════════════════════════════════════════════════════════
# 3. PERSONALIDADES — con triggers para el router MoE
# ═══════════════════════════════════════════════════════════════════════════════
log "Personalidades"

# ── coder (priority 10) — desarrollo de software ──────────────────────────
$ELPASO personality add \
    --name=coder \
    --model=coder-fim --engine=llama-local \
    --system-prompt="Eres un ingeniero de software senior. Escribes código limpio, idiomático y bien documentado. Explicas tus decisiones técnicas. Prefieres soluciones simples y mantenibles. Cuando refactorizas, mantienes todas las validaciones originales." \
    --keywords="refactoriza,implementa,test,PR,bug,fix,debug,compila,migra,migration,endpoint,api,módulo,función,typespec,pattern match,gen_server,supervisor,ecto,schema" \
    --task-types="code,debug,refactor,testing" \
    --priority=10 \
    >/dev/null 2>&1 && success "coder (prio=10 → coder-fim)" || true

# ── architect (priority 20) — arquitectura de sistemas ────────────────────
$ELPASO personality add \
    --name=architect \
    --model=thinker-opus --engine=llama-local \
    --system-prompt="Eres un arquitecto de software con 20 años de experiencia. Analizas requisitos, diseñas sistemas escalables, evalúas trade-offs entre rendimiento, mantenibilidad y coste. Piensas en el largo plazo. Documentas tus decisiones de arquitectura con ADRs." \
    --keywords="arquitectura,diseña,escalable,sistema,ADR,trade-off,tradeoff,event-driven,microservicio,monolito,hexagonal,cqrs,pipeline,infraestructura,cluster,distribuido" \
    --task-types="architecture,reasoning,planning,code" \
    --priority=20 \
    >/dev/null 2>&1 && success "architect (prio=20 → thinker-opus)" || true

# ── legal-es (priority 30) — consultas jurídicas españolas ─────────────────
$ELPASO personality add \
    --name=legal-es \
    --model=thinker --engine=llama-local \
    --system-prompt="Eres un asistente jurídico especializado en legislación española. Respondes basándote exclusivamente en los documentos y legislación proporcionados. Citas artículos y disposiciones concretas. Si no encuentras la información, dices claramente que no consta en los documentos." \
    --keywords="ley,BOE,pensión,jubilación,IRPF,seguridad social,excedencia,contrato,legal,jurídico,artículo,disposición,normativa,real decreto,estatuto,trabajadores,constitución,sentencia,tribunal" \
    --task-types="legal,question_answer,summarization" \
    --priority=30 \
    >/dev/null 2>&1 && success "legal-es (prio=30 → thinker)" || true

# ── tutor (priority 5) — explicaciones didácticas ─────────────────────────
$ELPASO personality add \
    --name=tutor \
    --model=thinker --engine=llama-local \
    --system-prompt="Eres un tutor paciente y didáctico. Explicas conceptos desde lo más básico, paso a paso, asegurándote de que el alumno entiende cada paso antes de avanzar. Usas analogías, ejemplos concretos y diagramas conceptuales cuando ayudan." \
    --keywords="explica,explicar,explicación,por qué,cómo funciona,qué es,define,definición,significa,diferencia entre,comparar,tutorial,paso a paso,aprender,guía" \
    --task-types="question_answer,explanation" \
    --priority=5 \
    >/dev/null 2>&1 && success "tutor (prio=5 → thinker)" || true

# ── general (priority 1, DEFAULT) — fallback para cualquier consulta ───────
$ELPASO personality add \
    --name=general \
    --model=gemma --engine=llama-local \
    --system-prompt="Eres un asistente útil, conversacional y directo. Respondes preguntas de todo tipo con precisión y sin rodeos. Si no sabes algo, lo dices claramente." \
    --priority=1 --default \
    >/dev/null 2>&1 && success "general (prio=1, ★ DEFAULT → gemma)" || true

# ═══════════════════════════════════════════════════════════════════════════════
# 4. CONFIGURACIÓN RECOMENDADA
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
log "╔══════════════════════════════════════════╗"
log "║   Registro completo                      ║"
log "╠══════════════════════════════════════════╣"
log "║   1 engine · 5 modelos · 5 personalidades║"
log "║   Default: general (gemma)               ║"
log "╚══════════════════════════════════════════╝"
echo ""

cat << 'CFG'
  Configuración recomendada (añadir a ~/.zshrc o exportar antes de arrancar):

    export ELPASO_PORT=4000
    export ELPASO_API_KEYS=sk-local
    export ELPASO_JWT_SECRET=$(openssl rand -hex 32)

  Arrancar el proxy:

    elpaso server start

  Usar la API (OpenAI-compatible):

    curl -s http://localhost:4000/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer sk-local" \
      -d '{"messages":[{"role":"user","content":"refactoriza esta función"}]}'

CFG
echo ""
log "Listo."
