#!/usr/bin/env bash
# =============================================================================
# register-wrapper-models.sh
# Lee ~/bin/localllama, extrae los 5 modelos y engines, y los registra en
# ElPaso via CLI. También crea personalidades preconfiguradas.
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
    echo "   O exporta: export ELPASO_BIN=/ruta/al/elpaso" >&2
    exit 1
fi

_cya='\033[1;36m'; _grn='\033[1;32m'; _yel='\033[1;33m'; _red='\033[1;31m'; _rst='\033[0m'
log()  { printf "${_cya}[register]${_rst} %s\n" "$*"; }
ok()   { printf "${_grn}[register]${_rst} %s\n" "$*"; }
warn() { printf "${_yel}[register]${_rst} %s\n" "$*"; }
err()  { printf "${_red}[register]${_rst} %s\n" "$*" >&2; }

if [[ ! -f "$WRAPPER" ]]; then
    err "Wrapper no encontrado: $WRAPPER"
    exit 1
fi

# ---------------------------------------------------------------------------
# Extraer config del wrapper localllama
# ---------------------------------------------------------------------------
PORT=$(grep -E '^readonly PORT=' "$WRAPPER" | head -1 | sed 's/.*="\(.*\)".*/\1/')
API_KEY=$(grep -E '^readonly API_KEY=' "$WRAPPER" | head -1 | sed 's/.*="\(.*\)".*/\1/')

if [[ -z "$PORT" || -z "$API_KEY" ]]; then
    err "No se pudo extraer PORT o API_KEY del wrapper."
    exit 1
fi

log "Wrapper    : $WRAPPER"
log "Puerto     : $PORT"
log "API key    : $API_KEY"
echo ""

cd "$PROJECT_DIR"

# ---------------------------------------------------------------------------
# 1. ENGINE
# ---------------------------------------------------------------------------
log "Registrando engine 'llama-local'..."
"$ELPASO_BIN" engine add llama-local \
    --adapter llama_cpp \
    --base-url "http://localhost:${PORT}/v1" \
    --api-key "$API_KEY" 2>/dev/null || warn "  (ya existía o no se pudo crear — continuando)"

# ---------------------------------------------------------------------------
# 2. MODELOS — los 5 del wrapper localllama
# ---------------------------------------------------------------------------

log "Registrando modelos..."

# ⚡ coder — Qwen3-30B-A3B Q3_K_XL · FULL GPU · código diario
"$ELPASO_BIN" model add coder \
    --engine llama-local \
    --url "http://localhost:${PORT}/v1" \
    --max-tokens 65536 \
    --temp 0.2 \
    --top-k 40 \
    --top-p 0.90 \
    --description "Qwen3-30B-A3B Q3_K_XL — código diario, PRs, refactors. FULL GPU, 64K ctx." \
    2>/dev/null || warn "  coder ya existía"

# 🎯 coder-fim — Qwen3-Coder-30B-A3B Q3_K_XL · código dedicado (FIM)
"$ELPASO_BIN" model add coder-fim \
    --engine llama-local \
    --url "http://localhost:${PORT}/v1" \
    --max-tokens 65536 \
    --temp 0.2 \
    --top-k 40 \
    --top-p 0.90 \
    --description "Qwen3-Coder-30B-A3B Q3_K_XL — código FIM. Mejores benchmarks. 64K ctx." \
    2>/dev/null || warn "  coder-fim ya existía"

# 🧠 thinker — Qwen3.6-35B-A3B Q4_K_XL · razonamiento SSM
"$ELPASO_BIN" model add thinker \
    --engine llama-local \
    --url "http://localhost:${PORT}/v1" \
    --max-tokens 131072 \
    --temp 0.4 \
    --top-p 0.90 \
    --description "Qwen3.6-35B-A3B Q4_K_XL — razonamiento SSM híbrido. 10 capas KV, 128K ctx." \
    2>/dev/null || warn "  thinker ya existía"

# 🧠💫 thinker-opus — Qwen3.6-35B-A3B Q4_K_M · destilado Claude 4.6 Opus
"$ELPASO_BIN" model add thinker-opus \
    --engine llama-local \
    --url "http://localhost:${PORT}/v1" \
    --max-tokens 100000 \
    --temp 0.4 \
    --top-p 0.90 \
    --description "Qwen3.6-35B-A3B Q4_K_M — destilado Claude 4.6 Opus. Razonamiento pro, 100K ctx." \
    2>/dev/null || warn "  thinker-opus ya existía"

# 💬 gemma — gemma-4-E4B-it Q6_K_XL · consultas generales
"$ELPASO_BIN" model add gemma \
    --engine llama-local \
    --url "http://localhost:${PORT}/v1" \
    --max-tokens 32768 \
    --temp 0.7 \
    --top-k 40 \
    --top-p 0.90 \
    --description "gemma-4-E4B-it Q6_K_XL — consultas generales, brainstorming, rápido. 32K ctx." \
    2>/dev/null || warn "  gemma ya existía"

echo ""

# ---------------------------------------------------------------------------
# 3. PERSONALIDADES PRECONFIGURADAS
# ---------------------------------------------------------------------------

log "Registrando personalidades..."

"$ELPASO_BIN" personality add coder \
    --description "Asistente experto en programación. Responde con código limpio, explicaciones técnicas precisas y mejores prácticas." \
    --system-prompt "Eres un ingeniero de software senior experto. Escribes código limpio, idiomático y bien documentado. Explicas tus decisiones técnicas. Usas patrones de diseño cuando aplican. Prefieres soluciones simples y mantenibles." \
    2>/dev/null || warn "  personality 'coder' ya existía"

"$ELPASO_BIN" personality add architect \
    --description "Arquitecto de software. Diseña sistemas, evalúa trade-offs, planifica." \
    --system-prompt "Eres un arquitecto de software con 20 años de experiencia. Analizas requisitos, diseñas sistemas escalables, evalúas trade-offs entre rendimiento, mantenibilidad y coste. Piensas en el largo plazo. Documentas tus decisiones de arquitectura con ADRs." \
    2>/dev/null || warn "  personality 'architect' ya existía"

"$ELPASO_BIN" personality add legal-es \
    --description "Asistente jurídico español. Responde basándose en legislación. NO inventa." \
    --system-prompt "Eres un asistente jurídico especializado en legislación española. Respondes BASÁNDOTE EXCLUSIVAMENTE en los documentos y legislación proporcionados. Citas artículos y disposiciones concretas. Si no encuentras la información, dices claramente 'No consta en los documentos analizados'. NO inventas legislación." \
    2>/dev/null || warn "  personality 'legal-es' ya existía"

"$ELPASO_BIN" personality add tutor \
    --description "Tutor paciente. Explica conceptos paso a paso, desde lo básico." \
    --system-prompt "Eres un tutor paciente y didáctico. Explicas conceptos desde lo más básico, paso a paso, asegurándote de que el alumno entiende cada paso antes de avanzar. Usas analogías, ejemplos concretos y diagramas conceptuales." \
    2>/dev/null || warn "  personality 'tutor' ya existía"

"$ELPASO_BIN" personality add general \
    --description "Asistente general. Conversacional, útil, directo." \
    --system-prompt "Eres un asistente útil, conversacional y directo. Respondes preguntas de todo tipo con precisión y sin rodeos. Si no sabes algo, lo dices claramente. Eres amable pero no empalagoso." \
    2>/dev/null || warn "  personality 'general' ya existía"

echo ""

# ---------------------------------------------------------------------------
# 4. PROFILES — vincular modelos + personalidades
# ---------------------------------------------------------------------------

log "Creando profiles (modelo + personalidad)..."

"$ELPASO_BIN" profile add coder-default \
    --model coder \
    --engine llama-local \
    --personality coder \
    2>/dev/null || warn "  profile 'coder-default' ya existía"

"$ELPASO_BIN" profile add coder-fim-default \
    --model coder-fim \
    --engine llama-local \
    --personality coder \
    2>/dev/null || warn "  profile 'coder-fim-default' ya existía"

"$ELPASO_BIN" profile add thinker-default \
    --model thinker \
    --engine llama-local \
    --personality architect \
    2>/dev/null || warn "  profile 'thinker-default' ya existía"

"$ELPASO_BIN" profile add thinker-opus-default \
    --model thinker-opus \
    --engine llama-local \
    --personality architect \
    2>/dev/null || warn "  profile 'thinker-opus-default' ya existía"

"$ELPASO_BIN" profile add gemma-default \
    --model gemma \
    --engine llama-local \
    --personality general \
    2>/dev/null || warn "  profile 'gemma-default' ya existía"

# ---------------------------------------------------------------------------
# 5. USUARIO ADMIN POR DEFECTO
# ---------------------------------------------------------------------------

log "Creando usuario admin por defecto..."
"$ELPASO_BIN" user add admin \
    --role admin \
    --api-key "sk-local" \
    2>/dev/null || warn "  user 'admin' ya existía"

echo ""
ok "Registro completo."
echo ""
echo "  Engines:"
echo "    • llama-local  (llama_cpp → localhost:$PORT)"
echo ""
echo "  Modelos:"
echo "    • coder         → código diario, FULL GPU, 64K ctx"
echo "    • coder-fim     → código FIM dedicado, 64K ctx"
echo "    • thinker       → razonamiento SSM, 128K ctx"
echo "    • thinker-opus  → razonamiento Claude-distilled, 100K ctx"
echo "    • gemma         → consultas generales, 32K ctx"
echo ""
echo "  Personalidades:"
echo "    • coder      → ingeniero de software senior"
echo "    • architect  → arquitectura y diseño de sistemas"
echo "    • legal-es   → asistente jurídico español"
echo "    • tutor      → explicaciones didácticas paso a paso"
echo "    • general    → asistente conversacional"
echo ""
echo "  Profiles (modelo + personalidad):"
echo "    • coder-default        → coder + coder"
echo "    • coder-fim-default    → coder-fim + coder"
echo "    • thinker-default      → thinker + architect"
echo "    • thinker-opus-default → thinker-opus + architect"
echo "    • gemma-default        → gemma + general"
echo ""
echo "  Usuario:"
echo "    • admin (api-key: sk-local)"
echo ""
log "Arranca el servidor:  localllama <modelo>"
log "Arranca ElPaso:       $ELPASO_BIN server start"
