#!/usr/bin/env bash
# =============================================================================
# setup-llama-elpaso.sh
# Orquesta el arranque de los modelos locales y su registro en ElPaso.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

_cya='\033[1;36m'; _grn='\033[1;32m'; _yel='\033[1;33m'
_red='\033[1;31m'; _rst='\033[0m'

log()  { printf "${_cya}[setup]${_rst} %s\n" "$*"; }
ok()   { printf "${_grn}[setup]${_rst} %s\n" "$*"; }
warn() { printf "${_yel}[setup]${_rst} %s\n" "$*"; }
err()  { printf "${_red}[setup]${_rst} %s\n" "$*" >&2; }

# --- Verificar PostgreSQL ---
verify_postgres() {
    log "Verificando PostgreSQL..."
    if ! pg_isready -q 2>/dev/null; then
        err "PostgreSQL no responde. Asegúrate de que está corriendo:"
        err "  sudo systemctl start postgresql"
        exit 1
    fi
    ok "PostgreSQL activo"
}

# --- Verificar binario llama-server ---
verify_llama() {
    local bin="${LLAMA_BIN:-$HOME/llama.cpp/build/bin/llama-server}"
    if [[ ! -x "$bin" ]]; then
        err "llama-server no encontrado: $bin"
        err "Compila llama.cpp primero o exporta LLAMA_BIN"
        exit 1
    fi
    ok "llama-server encontrado: $bin"
}

# --- Verificar modelos ---
verify_models() {
    local gguf="${GGUF_DIR:-$HOME/modelos-ia/gguf}"
    local thinker="$gguf/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf"
    local coder="$gguf/Qwen3-Coder-30B-A3B-Instruct-UD-Q3_K_XL.gguf"

    if [[ ! -f "$thinker" ]]; then
        err "Modelo thinker no encontrado: $thinker"
        exit 1
    fi
    if [[ ! -f "$coder" ]]; then
        err "Modelo coder no encontrado: $coder"
        exit 1
    fi
    ok "Modelos GGUF verificados"
}

# --- Arrancar servidores llama.cpp ---
start_servers() {
    log "Arrancando servidores llama.cpp..."
    "$SCRIPT_DIR/llama-dual-server.sh" &
    local dual_pid=$!
    ok "llama-dual-server.sh arrancado (PID=$dual_pid)"
    echo "$dual_pid" > /tmp/elpaso-llama-dual.pid
}

# --- Ejecutar setup de ElPaso ---
setup_elpaso() {
    log "Registrando engines y modelos en ElPaso..."
    cd "$PROJECT_DIR"
    mix elpaso.setup_local
}

# --- Banner ---
cat <<'BANNER'
╔══════════════════════════════════════════════════════════════════════╗
║  ElPaso + llama.cpp Local Setup                                      ║
║  RTX 5080 dual-model (thinker:8081 + coder:8082)                   ║
╚══════════════════════════════════════════════════════════════════════╝
BANNER
echo ""

# --- Flujo principal ---
verify_postgres
verify_llama
verify_models
start_servers
setup_elpaso

echo ""
ok "Setup completo."
echo ""
log "Próximos pasos:"
echo "  1. Arranca ElPaso:       cd $PROJECT_DIR && iex -S mix"
echo "  2. Genera el escript:    cd $PROJECT_DIR && MIX_ENV=prod mix gen"
echo "  3. Usa la API:           curl http://localhost:8080/infer"
echo ""
log "Para detener los servidores llama.cpp:"
echo "  kill \$(cat /tmp/elpaso-llama-dual.pid)"
