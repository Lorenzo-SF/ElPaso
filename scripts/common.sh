#!/usr/bin/env bash
# =============================================================================
# common.sh — Funciones compartidas para la automatización de ElPaso
# =============================================================================
# Uso: source este archivo desde los scripts run_vX.Y.sh
#
# Mapeo de modelos:
#   Alias usuario  → llama-server arg → opencode -m arg
#   gemma          → gemma            → llama-cpp-local/gemma
#   thinker        → think            → llama-cpp-local/thinker
#   coder          → coder            → llama-cpp-local/coder
#   r1             → r1               → llama-cpp-local/logic
# =============================================================================

set -euo pipefail

# --- Configuración ---
readonly LLAMA_SCRIPT="$HOME/bin/llama-server"
readonly LLAMA_PORT=8081
readonly LLAMA_HOST="127.0.0.1"
readonly OPENCODE_AGENT="Makeijan"
readonly PROJECT_DIR="$HOME/proyectos/ElPaso"
readonly DOCS_DIR="$PROJECT_DIR/Documentacion"
readonly LOG_DIR="$PROJECT_DIR/scripts/logs"

# Colores
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Estado global
LLAMA_PID=""
CURRENT_MODEL=""
BLOCK_NUM=0
VERSION=""

# --- Mapeo de modelos ---
# Convierte el alias del usuario al argumento de llama-server
llama_arg_for() {
    local model="$1"
    case "$model" in
        gemma)   echo "gemma" ;;
        thinker) echo "think" ;;
        coder)   echo "coder" ;;
        r1)      echo "r1" ;;
        *) echo "ERROR: Modelo desconocido: $model" >&2; return 1 ;;
    esac
}

# Convierte el alias del usuario al argumento de opencode -m
opencode_model_for() {
    local model="$1"
    case "$model" in
        gemma)   echo "llama-cpp-local/gemma" ;;
        thinker) echo "llama-cpp-local/thinker" ;;
        coder)   echo "llama-cpp-local/coder" ;;
        r1)      echo "llama-cpp-local/r1" ;;
        *) echo "ERROR: Modelo desconocido: $model" >&2; return 1 ;;
    esac
}

# --- Gestión de llama-server ---

# Mata cualquier instancia previa de llama-server
kill_llama() {
    if [[ -n "${LLAMA_PID:-}" ]] && kill -0 "$LLAMA_PID" 2>/dev/null; then
        echo -e "${YELLOW}⏹  Parando llama-server (PID: $LLAMA_PID)...${NC}"
        kill "$LLAMA_PID" 2>/dev/null || true
        wait "$LLAMA_PID" 2>/dev/null || true
        LLAMA_PID=""
        sleep 2  # Dar tiempo a liberar VRAM
    fi
    # Por seguridad, matar cualquier otro llama-server que esté corriendo en el puerto
    local pids
    pids=$(lsof -ti :"$LLAMA_PORT" 2>/dev/null || true)
    if [[ -n "$pids" ]]; then
        echo -e "${YELLOW}⏹  Matando procesos en puerto $LLAMA_PORT: $pids${NC}"
        echo "$pids" | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
}

# Arranca llama-server con el modelo indicado
start_llama() {
    local model="$1"
    local llama_arg
    llama_arg=$(llama_arg_for "$model")

    # Si ya está corriendo con el mismo modelo, no hacer nada
    if [[ "$CURRENT_MODEL" == "$model" ]] && [[ -n "${LLAMA_PID:-}" ]] && kill -0 "$LLAMA_PID" 2>/dev/null; then
        echo -e "${GREEN}✓  llama-server ya corriendo con $model (PID: $LLAMA_PID)${NC}"
        return 0
    fi

    kill_llama

    echo -e "${CYAN}🚀 Arrancando llama-server con modelo: ${BOLD}$model${NC} (arg: $llama_arg)"

    mkdir -p "$LOG_DIR"
    local log_file="$LOG_DIR/llama_${model}_$(date +%Y%m%d_%H%M%S).log"

    # Arrancar en background sin el colorize del script original
    # Usamos el binario directamente para evitar el wait del script wrapper
    local LLAMA_BIN="$HOME/llama.cpp/build/bin/llama-server"
    local GGUF_DIR="$HOME/modelos-ia/gguf"
    local MODEL_PATH ALIAS CTX_SIZE EXTRA_OPTS

    case "$llama_arg" in
        gemma)
            MODEL_PATH="$GGUF_DIR/gemma-4-26B-A4B-it-UD-Q3_K_M.gguf"
            ALIAS="gemma"
            CTX_SIZE=128000
            EXTRA_OPTS="--temp 0.3 --min-p 0.1 --keep 16384 --repeat-penalty 1.1"
            ;;
        think)
            MODEL_PATH="$GGUF_DIR/Qwen3-30B-A3B-Thinking-2507-UD-Q3_K_XL.gguf"
            ALIAS="thinker"
            CTX_SIZE=64000
            EXTRA_OPTS="--temp 0.7 --min-p 0.05 --repeat-penalty 1.05"
            ;;
        coder)
            MODEL_PATH="$GGUF_DIR/Qwen3-Coder-30B-A3B-Instruct-UD-Q2_K_XL.gguf"
            ALIAS="coder"
            CTX_SIZE=128000
            EXTRA_OPTS="--temp 0.5 --repeat-penalty 1.05 --keep 16384"
            ;;
        r1)
            MODEL_PATH="$GGUF_DIR/DeepSeek-R1-Distill-Qwen-32B-Q2_K_L.gguf"
            ALIAS="r1"
            CTX_SIZE=32000
            EXTRA_OPTS="--temp 0.6 --min-p 0.05 --repeat-penalty 1.0"
            ;;
    esac

    $LLAMA_BIN \
        -m "$MODEL_PATH" \
        --host 0.0.0.0 \
        --port "$LLAMA_PORT" \
        --alias "$ALIAS" \
        --ctx-size "$CTX_SIZE" \
        --api-key sk-local \
        --parallel 1 --no-mmap --cont-batching --context-shift \
        --min-p 0.05 --jinja --metrics --flash-attn on \
        --n-gpu-layers 999 --threads 12 --threads-http 1 --prio 3 \
        --cache-type-k q4_0 --cache-type-v q4_0 \
        --batch-size 4096 --ubatch-size 1024 \
        $EXTRA_OPTS \
        > "$log_file" 2>&1 &

    LLAMA_PID=$!
    CURRENT_MODEL="$model"

    echo -e "${CYAN}   PID: $LLAMA_PID | Log: $log_file${NC}"

    # Esperar a que esté listo
    wait_for_llama "$model"
}

# Espera a que llama-server responda al health check
wait_for_llama() {
    local model="$1"
    local max_wait=120  # segundos máximos de espera
    local elapsed=0

    echo -ne "${YELLOW}⏳ Esperando a que $model esté listo"

    while [[ $elapsed -lt $max_wait ]]; do
        if curl -sf "http://$LLAMA_HOST:$LLAMA_PORT/health" > /dev/null 2>&1; then
            echo -e "${NC}"
            echo -e "${GREEN}✓  $model listo en ${elapsed}s${NC}"
            return 0
        fi

        # Verificar que el proceso sigue vivo
        if ! kill -0 "$LLAMA_PID" 2>/dev/null; then
            echo -e "${NC}"
            echo -e "${RED}✗  llama-server murió durante el arranque de $model${NC}"
            return 1
        fi

        echo -n "."
        sleep 2
        elapsed=$((elapsed + 2))
    done

    echo -e "${NC}"
    echo -e "${RED}✗  Timeout esperando a $model después de ${max_wait}s${NC}"
    return 1
}

# --- Ejecución de bloques ---

# Ejecuta un bloque: arranca modelo, ejecuta opencode, para modelo
run_block() {
    local model="$1"
    local block_name="$2"
    local prompt="$3"

    BLOCK_NUM=$((BLOCK_NUM + 1))
    local oc_model
    oc_model=$(opencode_model_for "$model")

    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  BLOQUE $BLOCK_NUM: ${BOLD}$block_name${NC}"
    echo -e "${MAGENTA}  Modelo: $model | Version: $VERSION${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # 1. Arrancar llama-server con el modelo
    if ! start_llama "$model"; then
        echo -e "${RED}✗  Fallo arrancando $model para bloque '$block_name'${NC}"
        return 1
    fi

    # 2. Ejecutar opencode
    echo -e "${CYAN}🤖 Ejecutando opencode con $oc_model...${NC}"
    echo -e "${CYAN}   Prompt (primeros 200 chars): ${prompt:0:200}...${NC}"
    echo ""

    local start_time
    start_time=$(date +%s)

    # Ejecutar opencode desde el directorio del proyecto
    if ! (cd "$PROJECT_DIR" && opencode -m "$oc_model" --agent "$OPENCODE_AGENT" "$prompt"); then
        echo -e "${RED}⚠  opencode terminó con error en bloque '$block_name'${NC}"
        echo -e "${YELLOW}   Continuando con el siguiente bloque...${NC}"
    fi

    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    echo ""
    echo -e "${GREEN}✓  Bloque '$block_name' completado en ${duration}s${NC}"

    # 3. Matar llama-server (se re-arranca en el siguiente bloque si cambia el modelo)
    # Solo matar si el siguiente bloque usa otro modelo
    # (la optimización se maneja en start_llama)

    return 0
}

# --- Utilidades ---

# Cabecera de inicio de versión
version_header() {
    VERSION="$1"
    local desc="$2"
    BLOCK_NUM=0

    echo ""
    echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║  ElPaso — Automatización $VERSION${NC}"
    echo -e "${BOLD}${GREEN}║  $desc${NC}"
    echo -e "${BOLD}${GREEN}║  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Commit de git tras completar una versión o bloque importante
git_commit() {
    local msg="$1"
    (
        cd "$PROJECT_DIR"
        git add -A
        git commit -m "$msg" || echo -e "${YELLOW}⚠  Nada que commitear${NC}"
    )
}

# Tag de git para marcar una versión completada
git_tag() {
    local tag="$1"
    (
        cd "$PROJECT_DIR"
        git tag -a "$tag" -m "Versión $tag completada" || echo -e "${YELLOW}⚠  Tag $tag ya existe${NC}"
    )
}

# Limpieza al salir
cleanup_on_exit() {
    echo ""
    echo -e "${YELLOW}🧹 Limpiando...${NC}"
    kill_llama
    echo -e "${GREEN}✓  Limpieza completada${NC}"
}

trap cleanup_on_exit EXIT INT TERM
