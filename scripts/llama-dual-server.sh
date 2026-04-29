#!/usr/bin/env bash
# =============================================================================
# llama-dual-server.sh
# Arranca ambos modelos locales (thinker + coder) en paralelo.
# Thinker → localhost:8081  |  Coder → localhost:8082
# =============================================================================
set -euo pipefail

readonly LLAMA_BIN="${LLAMA_BIN:-$HOME/llama.cpp/build/bin/llama-server}"
readonly GGUF_DIR="${GGUF_DIR:-$HOME/modelos-ia/gguf}"
readonly API_KEY="sk-local"

# Colores
_red='\033[1;31m'; _grn='\033[1;32m'; _yel='\033[1;33m'
_cya='\033[1;36m'; _dim='\033[90m'; _rst='\033[0m'

log()  { printf "${_cya}[dual-server]${_rst} %s\n" "$*"; }
warn() { printf "${_yel}[dual-server]${_rst} %s\n" "$*"; }
err()  { printf "${_red}[dual-server]${_rst} %s\n" "$*" >&2; }
ok()   { printf "${_grn}[dual-server]${_rst} %s\n" "$*"; }

# --- Verificaciones ---
if [[ ! -x "$LLAMA_BIN" ]]; then
    err "llama-server no encontrado: $LLAMA_BIN"
    err "  Exporta LLAMA_BIN o compila llama.cpp"
    exit 1
fi

# Array de PIDs para cleanup
declare -a PIDS=()

cleanup() {
    log "Recibida señal de terminación. Parando servidores..."
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
        fi
    done
    ok "Servidores detenidos."
}
trap cleanup EXIT INT TERM

# =============================================================================
# Thinker — Puerto 8081
# =============================================================================
start_thinker() {
    local port=8081
    local model="$GGUF_DIR/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf"

    if [[ ! -f "$model" ]]; then
        err "Modelo thinker no encontrado: $model"
        return 1
    fi

    log "Arrancando thinker en :$port ..."
    "$LLAMA_BIN" \
        -m "$model" \
        --host 0.0.0.0 --port "$port" \
        --alias thinker \
        --ctx-size 128000 \
        --api-key "$API_KEY" \
        --no-mmap --cont-batching --jinja --metrics \
        --flash-attn on --prio 3 \
        --cache-type-k q4_0 --cache-type-v q4_0 \
        --batch-size 4096 --ubatch-size 2048 \
        --temp 0.4 --min-p 0.05 --repeat-penalty 1.05 --keep 16384 \
        --n-gpu-layers 22 --threads 8 --parallel 1 \
        > >(sed -u 's/^/[thinker] /') 2>&1 &

    PIDS+=("$!")
    ok "thinker PID=${PIDS[-1]}"
}

# =============================================================================
# Coder — Puerto 8082
# =============================================================================
start_coder() {
    local port=8082
    local model="$GGUF_DIR/Qwen3-Coder-30B-A3B-Instruct-UD-Q3_K_XL.gguf"

    if [[ ! -f "$model" ]]; then
        err "Modelo coder no encontrado: $model"
        return 1
    fi

    log "Arrancando coder en :$port ..."
    "$LLAMA_BIN" \
        -m "$model" \
        --host 0.0.0.0 --port "$port" \
        --alias coder \
        --ctx-size 48000 \
        --api-key "$API_KEY" \
        --no-mmap --cont-batching --jinja --metrics \
        --flash-attn on --prio 3 \
        --cache-type-k q4_0 --cache-type-v q4_0 \
        --batch-size 4096 --ubatch-size 2048 --context-shift \
        --temp 0.3 --top-k 20 --repeat-penalty 1.05 --keep 8192 \
        --n-gpu-layers 49 --parallel 2 --threads 4 --threads-http 2 \
        > >(sed -u 's/^/[coder]   /') 2>&1 &

    PIDS+=("$!")
    ok "coder   PID=${PIDS[-1]}"
}

# =============================================================================
# Health-check rápido
# =============================================================================
wait_for_server() {
    local port=$1
    local name=$2
    local max_wait=${3:-60}
    local waited=0

    log "Esperando health de $name en :$port ..."
    while ! curl -sf "http://localhost:$port/health" >/dev/null 2>&1; do
        if (( waited >= max_wait )); then
            err "$name no respondió tras ${max_wait}s"
            return 1
        fi
        sleep 1
        ((waited++))
    done
    ok "$name listo en :$port"
}

# =============================================================================
# Main
# =============================================================================
main() {
    log "Iniciando servidores llama.cpp duales"
    log "Binario: $LLAMA_BIN"
    log "Modelos: $GGUF_DIR"
    echo ""

    start_thinker
    start_coder
    echo ""

    # Esperar a que respondan
    wait_for_server 8081 thinker 60
    wait_for_server 8082 coder   60

    ok "Ambos servidores están activos."
    echo ""
    ok "Thinker → http://localhost:8081/v1  (API key: $API_KEY)"
    ok "Coder   → http://localhost:8082/v1  (API key: $API_KEY)"
    echo ""
    log "Presiona Ctrl+C para detener ambos servidores."

    # Esperar a que ambos procesos terminen
    wait
}

main "$@"
