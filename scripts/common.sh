#!/usr/bin/env bash
# =============================================================================
# common.sh — Funciones compartidas para la automatización de ElPaso
# =============================================================================
# Uso: source este archivo desde los scripts run_vX.Y.sh

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

# Convierte el alias del usuario al argumento de llama-server (para el wrapper)
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

kill_llama() {
    if [[ -n "${LLAMA_PID:-}" ]] && kill -0 "$LLAMA_PID" 2>/dev/null; then
        echo -e "${YELLOW}⏹  Parando llama-server (PID: $LLAMA_PID)...${NC}"
        kill "$LLAMA_PID" 2>/dev/null || true
        wait "$LLAMA_PID" 2>/dev/null || true
        LLAMA_PID=""
        sleep 2
    fi
    local pids
    pids=$(lsof -ti :"$LLAMA_PORT" 2>/dev/null || true)
    if [[ -n "$pids" ]]; then
        echo -e "${YELLOW}⏹  Matando procesos en puerto $LLAMA_PORT: $pids${NC}"
        echo "$pids" | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
}

start_llama() {
    local model="$1"
    local llama_arg
    llama_arg=$(llama_arg_for "$model")

    if [[ "$CURRENT_MODEL" == "$model" ]] && [[ -n "${LLAMA_PID:-}" ]] && kill -0 "$LLAMA_PID" 2>/dev/null; then
        echo -e "${GREEN}✓  llama-server ya corriendo con $model (PID: $LLAMA_PID)${NC}"
        return 0
    fi

    kill_llama

    echo -e "${CYAN}🚀 Arrancando llama-server mediante wrapper con modelo: ${BOLD}$model${NC}"
    mkdir -p "$LOG_DIR"
    local log_file="$LOG_DIR/llama_${model}_$(date +%Y%m%d_%H%M%S).log"

    # Usamos el wrapper directamente. El wrapper se encarga de los argumentos y el binario.
    # Lo lanzamos en background para capturar su PID.
    "$LLAMA_SCRIPT" "$llama_arg" > "$log_file" 2>&1 &
    LLAMA_PID=$!
    CURRENT_MODEL="$model"

    echo -e "${CYAN}   PID: $LLAMA_PID | Log: $log_file${NC}"

    wait_for_llama "$model"
}

wait_for_llama() {
    local model="$1"
    local max_wait=300  # Aumentado a 5 min para modelos grandes en carga
    local elapsed=0

    echo -ne "${YELLOW}⏳ Esperando a que $model esté listo (Health Check)..."

    while [[ $elapsed -lt $max_wait ]]; do
        if curl -sf "http://$LLAMA_HOST:$LLAMA_PORT/health" > /dev/null 2>&1; then
            echo -e "${NC}"
            echo -e "${GREEN}✓  $model listo en ${elapsed}s${NC}"
            return 0
        fi

        if ! kill -0 "$LLAMA_PID" 2>/dev/null; then
            echo -e "${NC}"
            echo -e "${RED}✗  llama-server murió durante el arranque de $model. Revisa: $LOG_DIR${NC}"
            return 1
        fi

        echo -n "."
        sleep 5
        elapsed=$((elapsed + 5))
    done

    echo -e "${NC}"
    echo -e "${RED}✗  Timeout esperando a $model después de ${max_wait}s${NC}"
    return 1
}

# --- Ejecución de bloques ---

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

    if ! start_llama "$model"; then
        echo -e "${RED}✗  Fallo crítico arrancando $model para bloque '$block_name'${NC}"
        return 1
    fi

    echo -e "${CYAN}🤖 Ejecutando opencode con $oc_model...${NC}"
    echo ""

    local start_time=$(date +%s)

    if ! (cd "$PROJECT_DIR" && opencode -m "$oc_model" --agent "$OPENCODE_AGENT" "$prompt"); then
        echo -e "${RED}✗  opencode falló en bloque '$block_name'${NC}"
        return 1
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo -e "${GREEN}✓  Bloque '$block_name' completado en ${duration}s${NC}"
    return 0
}

# --- Utilidades ---

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

git_commit() {
    local msg="$1"
    (cd "$PROJECT_DIR" && git add -A && git commit -m "$msg" || echo -e "${YELLOW}⚠  Nada que commitear${NC}")
}

git_tag() {
    local tag="$1"
    (cd "$PROJECT_DIR" && git tag -a "$tag" -m "Versión $tag completada" || echo -e "${YELLOW}⚠  Tag $tag ya existe${NC}")
}

cleanup_on_exit() {
    echo ""
    echo -e "${YELLOW}🧹 Limpiando...${NC}"
    kill_llama
    echo -e "${GREEN}✓  Limpieza completada${NC}"
}

trap cleanup_on_exit EXIT INT TERM
