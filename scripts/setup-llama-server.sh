#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# ELPASO SETUP SCRIPT
# Configura ElPaso con los modelos de llama-server
# ============================================================

readonly ELPASO_HOST="localhost"
readonly ELPASO_PORT="8080"
readonly LLAMA_SERVER_HOST="localhost"
readonly LLAMA_SERVER_PORT="8081"

echo -e "\x1b[1;36m===============================================\x1b[0m"
echo -e "\x1b[1;36m  🚀 ELPASO SETUP - Modelos llama-server\x1b[0m"
echo -e "\x1b[1;36m===============================================\x1b[0m"

# Verificar que llama-server esté corriendo
check_llama_server() {
    echo -e "\n🔍 Verificando llama-server en puerto $LLAMA_SERVER_PORT..."
    if curl -s -o /dev/null -w "%{http_code}" "http://$LLAMA_SERVER_HOST:$LLAMA_SERVER_PORT/v1/models" 2>/dev/null | grep -q "200"; then
        echo -e "   ✅ llama-server corriendo"
        return 0
    else
        echo -e "   ❌ llama-server NO está corriendo!"
        echo -e "   💡 Inicia un modelo primero:"
        echo -e "      ~/bin/llama-server gemma   # o think, coder"
        return 1
    fi
}

# Registrar los 3 motores en ElPaso
register_engines() {
    echo -e "\n📝 Registrando motores en ElPaso..."

    # gemma - modelo de skills
    elpaso engine add \
        --name gemma \
        --adapter llama \
        --base-url "http://$LLAMA_SERVER_HOST:$LLAMA_SERVER_PORT/v1" \
        --description " Gemma 4 26B - Skills: code-reviewer, stack-migrator"

    # think - modelo de razonamiento
    elpaso engine add \
        --name think \
        --adapter llama \
        --base-url "http://$LLAMA_SERVER_HOST:$LLAMA_SERVER_PORT/v1" \
        --description "Qwen3 Thinking - Skills: architect, project-planning"

    # coder - modelo de código
    elpaso engine add \
        --name coder \
        --adapter llama \
        --base-url "http://$LLAMA_SERVER_HOST:$LLAMA_SERVER_PORT/v1" \
        --description "Qwen3 Coder - Skills: jira-manager, coding"
}

# Registrar los 3 modelos en ElPaso
register_models() {
    echo -e "\n📝 Registrando modelos en ElPaso..."

    # gemma - código/review
    elpaso model add \
        --name gemma \
        --engine gemma \
        --url "http://$LLAMA_SERVER_HOST:$LLAMA_SERVER_PORT/v1" \
        --api-key sk-local \
        --description " Gemma 4 26B - Skills: code-reviewer, stack-migrator" \
        --max-tokens 8192

    # think - razonamiento
    elpaso model add \
        --name think \
        --engine think \
        --url "http://$LLAMA_SERVER_HOST:$LLAMA_SERVER_PORT/v1" \
        --api-key sk-local \
        --description "Qwen3 Thinking - Skills: monolith-weaver, project-architect" \
        --max-tokens 16384 \
        --temperature 0.7

    # coder - código
    elpaso model add \
        --name coder \
        --engine coder \
        --url "http://$LLAMA_SERVER_HOST:$LLAMA_SERVER_PORT/v1" \
        --api-key sk-local \
        --description "Qwen3 Coder - Skills: jira-manager, coding" \
        --max-tokens 8192
}

# Probar routing entre modelos
test_routing() {
    echo -e "\n🧪 Probando routing entre modelos..."

    # Test 1: gemma (revisión de código)
    echo -e "\n   📝 Test 1: Revisión de código → gemma"
    curl -s -X POST "http://$ELPASO_HOST:$ELPASO_PORT/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gemma",
            "messages": [{"role": "user", "content": "Revisa este código: fn foo(x) { return x + 1 }"}]
        }' | jq -r '.choices[0].message.content' 2>/dev/null || echo "(respuesta)"

    # Test 2: think (arquitectura)
    echo -e "\n   📝 Test 2: Proyecto nuevo → think"
    curl -s -X POST "http://$ELPASO_HOST:$ELPASO_PORT/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "think",
            "messages": [{"role": "user", "content": "Diseña una API REST con Elixir y Plug"}]
        }' | jq -r '.choices[0].message.content' 2>/dev/null || echo "(respuesta)"

    # Test 3: coder (código)
    echo -e "\n   📝 Test 3: Generar código → coder"
    curl -s -X POST "http://$ELPASO_HOST:$ELPASO_PORT/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "coder",
            "messages": [{"role": "user", "content": "Crea un módulo Elixir que calcule fibonacci"}]
        }' | jq -r '.choices[0].message.content' 2>/dev/null || echo "(respuesta)"

    # Test 4: auto (routing automático)
    echo -e "\n   📝 Test 4: Routing automático → auto"
    curl -s -X POST "http://$ELPASO_HOST:$ELPASO_PORT/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "auto",
            "messages": [{"role": "user", "content": "Explícame closures en JavaScript"}]
        }' | jq -r '.choices[0].message.content' 2>/dev/null || echo "(respuesta)"
}

# Mostrar ayuda de uso
show_help() {
    echo -e "\x1b[1;33mUSO:\x1b[0m"
    echo -e "  $0 setup          # Configurar motores y modelos"
    echo -e "  $0 test         # Probar routing"
    echo -e "  $0 help         # Mostrar esta ayuda"
    echo -e ""
    echo -e "\x1b[1;33mREQUISITOS:\x1b[0m"
    echo -e "  1. Instalar PostgreSQL y crear DB"
    echo -e "  2. Iniciar ElPaso: mix run --no-halt"
    echo -e "  3. Iniciar modelo llama-server: ~/bin/llama-server gemma"
    echo -e ""
    echo -e "\x1b[1;33mFLUJO DE PRUEBA:\x1b[0m"
    echo -e "  Terminal 1: ~/bin/llama-server gemma"
    echo -e "  Terminal 2: mix run --no-halt"
    echo -e "  Terminal 3: $0 setup && $0 test"
}

# MAIN
case "${1:-help}" in
    setup)
        check_llama_server || exit 1
        register_engines
        register_models
        echo -e "\n✅ ✓ Configuración completa!"
        echo -e "   💡 Ahora prueba: curl http://localhost:8080/v1/models"
        ;;
    test)
        test_routing
        ;;
    -h|--help|help)
        show_help
        ;;
    *)
        echo -e "❌ Comando desconocido: $1"
        show_help
        exit 1
        ;;
esac