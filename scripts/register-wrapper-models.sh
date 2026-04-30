#!/usr/bin/env bash
# =============================================================================
# register-wrapper-models.sh
# Lee ~/bin/llama-server y registra sus modelos en ElPaso via CLI.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WRAPPER="${1:-$HOME/bin/llama-server}"

# Buscar binario elpaso (PATH → ~/.elpaso/elpaso)
ELPASO_BIN="${ELPASO_BIN:-$(command -v elpaso 2>/dev/null || true)}"
if [[ -z "$ELPASO_BIN" && -f "$HOME/.elpaso/elpaso" ]]; then
    ELPASO_BIN="$HOME/.elpaso/elpaso"
fi
if [[ -z "$ELPASO_BIN" ]]; then
    err "Binario 'elpaso' no encontrado."
    err "  Compila e instala:  mix escript.build && mix deploy"
    err "  O exporta la ruta:  export ELPASO_BIN=/ruta/al/elpaso"
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
# Extraer config del wrapper
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
# Registrar engine
# ---------------------------------------------------------------------------
log "Registrando engine 'llama-local'..."
"$ELPASO_BIN" engine add llama-local \
    --adapter llama_cpp \
    --base-url "http://localhost:${PORT}/v1" \
    --api-key "$API_KEY"

# ---------------------------------------------------------------------------
# Registrar modelos (hardcodeados según el wrapper conocido)
# ---------------------------------------------------------------------------
log "Registrando modelo 'local-thinker'..."
"$ELPASO_BIN" model add local-thinker \
    --engine llama-local \
    --url "http://localhost:${PORT}/v1" \
    --max-tokens 128000 \
    --temp 0.4 \
    --description "Qwen3.6-35B-A3B Q4_K_M — arquitectura, planificación, razonamiento"

log "Registrando modelo 'local-coder'..."
"$ELPASO_BIN" model add local-coder \
    --engine llama-local \
    --url "http://localhost:${PORT}/v1" \
    --max-tokens 4800 \
    --temp 0.3 \
    --description "Qwen3-Coder-30B-A3B Q3_K_XL — código, debugging, completado"

echo ""
ok "Registro completo. Modelos disponibles:"
echo "   • local-thinker  → arquitectura / razonamiento"
echo "   • local-coder    → código / debugging"
echo ""
log "Arranca el servidor:  llama-server <thinker|coder>"
log "Arranca ElPaso:       $ELPASO_BIN server start"
