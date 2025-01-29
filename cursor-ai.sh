#!/bin/bash

# ====================================================================================
# Script de Instalação, Desinstalação e Manutenção do Cursor IDE
# 
# Este script gerencia o ciclo de vida completo do Cursor IDE no Linux, incluindo:
# - Instalação com verificação de dependências
# - Desinstalação segura
# - Reparo de instalações corrompidas
# - Gerenciamento de múltiplas instalações
# 
# Autor: Truuta
# Versão: 1.0.0
# ====================================================================================

set -euo pipefail

# Configurações globais e constantes
readonly VERSION="1.0.0"
readonly TEMP_DIR="/tmp/cursor_installer"
readonly MAX_RETRIES=3
readonly TIMEOUT=30

# Directory setup
APP_DIR="${HOME}/Applications"
ICON_DIR="${HOME}/.local/share/icons"
DESKTOP_DIR="${HOME}/.local/share/applications"
BIN_DIR="${HOME}/.local/bin"

# File paths
DOWNLOAD_URL="https://downloader.cursor.sh/linux/appImage/x64"
ICON_DOWNLOAD_URL="https://www.cursor.com/assets/images/logo.svg"
APPIMAGE_NAME="cursor.AppImage"
APPIMAGE_PATH="${APP_DIR}/${APPIMAGE_NAME}"
ICON_PATH="${ICON_DIR}/cursor-icon.svg"
DESKTOP_FILE_PATH="${DESKTOP_DIR}/cursor.desktop"
LAUNCHER_SCRIPT="${BIN_DIR}/cursor"

# Configuração de cores e estilos
declare -A COLORS=(
    ["INFO"]="\033[0;34m"     # Azul
    ["SUCCESS"]="\033[0;32m"  # Verde
    ["WARNING"]="\033[0;33m"  # Amarelo
    ["ERROR"]="\033[0;31m"    # Vermelho
    ["RESET"]="\033[0m"       # Reset
    ["BOLD"]="\033[1m"        # Negrito
    ["PROGRESS"]="\033[0;36m" # Ciano
)

# Função para limpar arquivos temporários
cleanup() {
    local exit_code=$?
    log "INFO" "Limpando arquivos temporários..."
    rm -rf "${TEMP_DIR}" 2>/dev/null || true
    exit $exit_code
}

# Registrar função de limpeza
trap cleanup EXIT

# Funções de utilidade melhoradas
log() {
    local level="INFO"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ $# -gt 1 ]]; then
        level=$1
        shift
    fi
    printf "[%s] ${COLORS[$level]}${COLORS[BOLD]}[%s]${COLORS[RESET]} %s\n" "$timestamp" "$level" "$*"
}

error() {
    log "ERROR" "$*" >&2
    exit 1
}

# Função melhorada para perguntar ao usuário com validação
ask() {
    local question=$1
    local default=${2:-""}
    local valid_options=${3:-""}
    local answer
    
    while true; do
        printf "${COLORS[INFO]}${question}${COLORS[RESET]}"
        if [[ -n $default ]]; then
            printf " (padrão: ${COLORS[BOLD]}%s${COLORS[RESET]})" "$default"
        fi
        if [[ -n $valid_options ]]; then
            printf " [%s]" "$valid_options"
        fi
        printf ": "
        read -r answer
        answer=${answer:-$default}
        
        # Validação da resposta
        if [[ -n $valid_options ]]; then
            if [[ $answer =~ ^[$valid_options]$ ]]; then
                break
            else
                log "ERROR" "Opção inválida. Por favor, escolha uma das opções: [$valid_options]"
                continue
            fi
        else
            # Se não houver opções válidas específicas, aceita qualquer resposta não vazia
            if [[ -n $answer ]]; then
                break
            else
                log "ERROR" "Por favor, forneça uma resposta válida."
                continue
            fi
        fi
    done
    
    echo "$answer"
}

# Função para mostrar barra de progresso
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${COLORS[PROGRESS]}["
    printf "%${filled}s" '' | tr ' ' '='
    printf "%${empty}s" '' | tr ' ' ' '
    printf "] %3d%%${COLORS[RESET]}" "$percentage"
    
    if [ "$current" -eq "$total" ]; then
        printf "\n"
    fi
}

# Função melhorada para download com progresso e retry
download_with_progress() {
    local url=$1
    local output=$2
    local description=$3
    local retries=0
    local temp_file="${TEMP_DIR}/$(basename "$output")"
    
    mkdir -p "${TEMP_DIR}"
    
    while [ $retries -lt $MAX_RETRIES ]; do
        log "INFO" "Baixando $description (tentativa $((retries + 1))/$MAX_RETRIES)..."
        
        if curl -L --progress-bar --connect-timeout $TIMEOUT "$url" -o "$temp_file" 2>&1 | \
        stdbuf -o0 tr '\r' '\n' | grep -o "[0-9]*\.[0-9]%" | while read -r percent; do
            percent=${percent%.*}
            show_progress "$percent" 100
        done; then
            # Verificar integridade do download
            if [[ -s "$temp_file" ]]; then
                mv "$temp_file" "$output"
                log "SUCCESS" "Download concluído com sucesso!"
                return 0
            else
                log "ERROR" "Arquivo baixado está vazio ou corrompido."
            fi
        fi
        
        retries=$((retries + 1))
        if [ $retries -lt $MAX_RETRIES ]; then
            local wait_time=$((retries * 5))
            log "WARNING" "Falha no download. Tentando novamente em $wait_time segundos..."
            sleep $wait_time
        fi
    done
    
    error "Falha ao baixar $description após $MAX_RETRIES tentativas."
}

# Função para verificar espaço em disco
check_disk_space() {
    local required_space=$((500 * 1024)) # 500MB em KB
    local available_space
    
    available_space=$(df -k "${APP_DIR}" | awk 'NR==2 {print $4}')
    
    if [[ $available_space -lt $required_space ]]; then
        error "Espaço insuficiente em disco. Necessário: 500MB, Disponível: $((available_space / 1024))MB"
    fi
}

# Função para verificar conexão com a internet
check_internet_connection() {
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        error "Sem conexão com a internet. Por favor, verifique sua conexão e tente novamente."
    fi
}

# Função para remover uma instalação específica
remove_specific_installation() {
    local install_path=$1
    local success=true
    
    log "INFO" "Removendo instalação: $install_path"
    
    # Remover o arquivo principal
    if [[ -f "$install_path" ]]; then
        if rm -f "$install_path"; then
            log "SUCCESS" "✓ Removido: $install_path"
        else
            log "ERROR" "✗ Falha ao remover: $install_path"
            success=false
        fi
    fi
    
    # Remover arquivos associados se for uma instalação completa
    if [[ "$install_path" == *"cursor.AppImage" ]]; then
        local associated_files=(
            "${install_path%/*}/cursor-icon.svg"
            "${HOME}/.local/share/applications/cursor.desktop"
            "${HOME}/.local/bin/cursor"
            "${HOME}/.cursor_log"
        )
        
        for file in "${associated_files[@]}"; do
            if [[ -f "$file" ]]; then
                if rm -f "$file"; then
                    log "SUCCESS" "✓ Removido arquivo associado: $file"
                else
                    log "ERROR" "✗ Falha ao remover arquivo associado: $file"
                    success=false
                fi
            fi
        done
        
        # Atualizar cache do sistema
        update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
        gtk-update-icon-cache -f -t ~/.local/share/icons 2>/dev/null || true
    fi
    
    if [[ "$success" = true ]]; then
        log "SUCCESS" "✨ Instalação removida com sucesso! ✨"
    else
        log "WARNING" "Remoção concluída com alguns erros. Verifique as mensagens acima."
    fi
    
    return $success
}

# Função para atualizar o Cursor AppImage
update_cursor_appimage() {
    local install_path=$1
    local success=true
    local backup_path="${install_path}.backup"
    
    log "INFO" "Iniciando atualização do Cursor..."
    
    # Criar backup do AppImage atual
    if [[ -f "$install_path" ]]; then
        log "INFO" "Criando backup da versão atual..."
        if mv "$install_path" "$backup_path"; then
            log "SUCCESS" "✓ Backup criado: $backup_path"
        else
            log "ERROR" "✗ Falha ao criar backup"
            return 1
        fi
    fi
    
    # Baixar nova versão
    log "INFO" "Baixando nova versão do Cursor..."
    if download_with_progress "${DOWNLOAD_URL}" "$install_path" "nova versão do Cursor"; then
        chmod +x "$install_path"
        log "SUCCESS" "✓ Nova versão baixada e configurada"
        
        # Testar se o novo arquivo é válido
        if [[ -x "$install_path" ]] && [[ -s "$install_path" ]]; then
            log "SUCCESS" "✨ Atualização concluída com sucesso! ✨"
            rm -f "$backup_path"  # Remover backup se tudo deu certo
            return 0
        else
            log "ERROR" "Nova versão parece estar corrompida"
            success=false
        fi
    else
        log "ERROR" "Falha ao baixar nova versão"
        success=false
    fi
    
    # Restaurar backup em caso de falha
    if [[ "$success" = false ]] && [[ -f "$backup_path" ]]; then
        log "WARNING" "Restaurando versão anterior..."
        if mv "$backup_path" "$install_path"; then
            log "SUCCESS" "✓ Versão anterior restaurada"
        else
            log "ERROR" "✗ Falha ao restaurar versão anterior"
        fi
        return 1
    fi
}

# Função para verificar instalação existente
check_existing_installation() {
    local possible_paths=(
        "${HOME}/Applications/cursor.AppImage"
        "${HOME}/.local/bin/cursor"
        "/usr/local/bin/cursor"
        "/opt/cursor/cursor.AppImage"
    )
    
    local found=false
    local installations=()
    local valid_paths=()
    
    log "INFO" "Verificando instalações existentes do Cursor..."
    
    # Encontrar todas as instalações existentes
    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" ]]; then
            found=true
            installations+=("$path")
            valid_paths+=("$path")
        fi
    done
    
    if [[ "$found" = true ]]; then
        local num_installations=${#installations[@]}
        
        log "WARNING" "Instalações existentes do Cursor encontradas:"
        for ((i=0; i<num_installations; i++)); do
            log "WARNING" "  $((i+1)). ${installations[$i]}"
        done
        
        # Mostrar opções ao usuário
        cat << EOF

${COLORS[INFO]}Opções disponíveis:${COLORS[RESET]}
${COLORS[WARNING]}U${COLORS[RESET]} - Atualizar instalação existente
${COLORS[WARNING]}R${COLORS[RESET]} - Remover instalação específica
${COLORS[WARNING]}A${COLORS[RESET]} - Remover todas as instalações
${COLORS[WARNING]}S${COLORS[RESET]} - Substituir mantendo as existentes
${COLORS[WARNING]}C${COLORS[RESET]} - Cancelar instalação

EOF
        
        local action=$(ask "O que você deseja fazer?" "C" "UuRrAaSsCc")
        case "${action,,}" in
            u)
                if [[ $num_installations -gt 1 ]]; then
                    while true; do
                        log "INFO" "Digite o número da instalação que deseja atualizar (1-$num_installations):"
                        local choice
                        read -r choice
                        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$num_installations" ]; then
                            local target_path="${installations[$((choice-1))]}"
                            if [[ "$target_path" == *"cursor.AppImage" ]]; then
                                if update_cursor_appimage "$target_path"; then
                                    log "INFO" "Atualização concluída. Não é necessário continuar com a instalação."
                                    exit 0
                                else
                                    error "Falha na atualização. Por favor, tente novamente ou escolha outra opção."
                                fi
                            else
                                log "ERROR" "Só é possível atualizar instalações do tipo AppImage."
                                local try_again=$(ask "Deseja escolher outra instalação? (s/n)" "s" "sn")
                                if [[ "${try_again,,}" != "s" ]]; then
                                    break
                                fi
                            fi
                        else
                            log "ERROR" "Escolha inválida. Por favor, digite um número entre 1 e $num_installations."
                        fi
                    done
                else
                    if [[ "${installations[0]}" == *"cursor.AppImage" ]]; then
                        if update_cursor_appimage "${installations[0]}"; then
                            log "INFO" "Atualização concluída. Não é necessário continuar com a instalação."
                            exit 0
                        else
                            error "Falha na atualização. Por favor, tente novamente ou escolha outra opção."
                        fi
                    else
                        log "ERROR" "Só é possível atualizar instalações do tipo AppImage."
                    fi
                fi
                ;;
            r)
                if [[ $num_installations -gt 1 ]]; then
                    while true; do
                        log "INFO" "Digite o número da instalação que deseja remover (1-$num_installations):"
                        local choice
                        read -r choice
                        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$num_installations" ]; then
                            remove_specific_installation "${installations[$((choice-1))]}"
                            break
                        else
                            log "ERROR" "Escolha inválida. Por favor, digite um número entre 1 e $num_installations."
                        fi
                    done
                else
                    remove_specific_installation "${installations[0]}"
                fi
                
                local continue_install=$(ask "Deseja continuar com a instalação do Cursor? (s/n)" "s" "sn")
                if [[ "${continue_install,,}" = "s" ]]; then
                    log "INFO" "Continuando com a instalação..."
                    return 0
                else
                    log "INFO" "Instalação cancelada pelo usuário."
                    exit 0
                fi
                ;;
            a)
                log "WARNING" "Removendo todas as instalações existentes..."
                local all_success=true
                for install in "${installations[@]}"; do
                    if ! remove_specific_installation "$install"; then
                        all_success=false
                    fi
                done
                
                if [[ "$all_success" = true ]]; then
                    local continue_install=$(ask "Todas as instalações foram removidas. Deseja continuar com a nova instalação? (s/n)" "s" "sn")
                    if [[ "${continue_install,,}" = "s" ]]; then
                        log "INFO" "Continuando com a instalação..."
                        return 0
                    else
                        log "INFO" "Instalação cancelada pelo usuário."
                        exit 0
                    fi
                else
                    error "Houve erros durante a remoção das instalações. Por favor, verifique e tente novamente."
                fi
                ;;
            s)
                log "INFO" "Mantendo instalações existentes e continuando com a nova instalação..."
                return 0
                ;;
            *)
                log "INFO" "Instalação cancelada pelo usuário."
                exit 0
                ;;
        esac
    fi
}

# Função para reparar instalação
repair_installation() {
    log "INFO" "Iniciando reparo da instalação do Cursor..."
    
    # Verificar integridade dos arquivos
    local files_to_check=(
        "${APPIMAGE_PATH}"
        "${ICON_PATH}"
        "${DESKTOP_FILE_PATH}"
        "${LAUNCHER_SCRIPT}"
    )
    
    local needs_repair=false
    
    for file in "${files_to_check[@]}"; do
        if [[ ! -f "$file" ]]; then
            log "WARNING" "Arquivo ausente: $file"
            needs_repair=true
        elif [[ ! -x "$file" && "${file##*.}" != "svg" ]]; then
            log "WARNING" "Permissões incorretas: $file"
            needs_repair=true
        fi
    done
    
    if [[ "$needs_repair" = true ]]; then
        log "INFO" "Iniciando processo de reparo..."
        
        # Baixar arquivos ausentes
        if [[ ! -f "${APPIMAGE_PATH}" ]]; then
            download_with_progress "${DOWNLOAD_URL}" "${APPIMAGE_PATH}" "Cursor AppImage"
            chmod +x "${APPIMAGE_PATH}"
        fi
        
        if [[ ! -f "${ICON_PATH}" ]]; then
            download_with_progress "${ICON_DOWNLOAD_URL}" "${ICON_PATH}" "ícone do Cursor"
        fi
        
        # Recriar arquivos de configuração
        create_desktop_file
        create_launcher_script
        
        # Atualizar cache do sistema
        update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
        gtk-update-icon-cache -f -t ~/.local/share/icons 2>/dev/null || true
        
        log "SUCCESS" "✨ Reparo concluído com sucesso! ✨"
    else
        log "SUCCESS" "Todos os arquivos estão íntegros, não é necessário reparo."
    fi
}

# Função para criar arquivo .desktop
create_desktop_file() {
    log "INFO" "Criando arquivo .desktop..."
    cat > "${DESKTOP_FILE_PATH}" << EOF
[Desktop Entry]
Name=Cursor
Exec=${LAUNCHER_SCRIPT} %F
Terminal=false
Type=Application
Icon=${ICON_PATH}
StartupWMClass=Cursor
X-AppImage-Version=latest
Comment=Cursor is an AI-first coding environment.
MimeType=x-scheme-handler/cursor;
Categories=Utility;Development
EOF
    chmod +x "${DESKTOP_FILE_PATH}"
    log "SUCCESS" "Arquivo .desktop criado em: ${DESKTOP_FILE_PATH}"
}

# Função para criar script launcher
create_launcher_script() {
    log "INFO" "Criando script launcher..."
    cat > "${LAUNCHER_SCRIPT}" << EOF
#!/bin/bash

# Configurações
CURSOR_APP="${APPIMAGE_PATH}"
LOG_FILE="\${HOME}/.cursor_log"
SANDBOX_FLAG="$([ "$SANDBOX_MODE" = "s" ] && echo "--no-sandbox" || echo "")"

# Função para logging
log_msg() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" >> "\$LOG_FILE"
}

# Função principal do Cursor
run_cursor() {
    local target="\$1"
    
    if [ "\$target" = "." ] || [ -z "\$target" ]; then
        log_msg "Iniciando Cursor no diretório atual: \$(pwd)"
        nohup "\$CURSOR_APP" \$SANDBOX_FLAG "\$(pwd)" > "\$LOG_FILE" 2>&1 &
    else
        log_msg "Iniciando Cursor com argumentos: \$*"
        nohup "\$CURSOR_APP" \$SANDBOX_FLAG "\$@" > "\$LOG_FILE" 2>&1 &
    fi
}

run_cursor "\$@"
EOF
    chmod +x "${LAUNCHER_SCRIPT}"
    log "SUCCESS" "Script launcher criado em: ${LAUNCHER_SCRIPT}"
}

# Função de instalação
install_cursor() {
    log "INFO" "Iniciando instalação do Cursor IDE v${VERSION}..."
    
    # Verificações preliminares
    check_disk_space
    check_internet_connection
    check_existing_installation
    
    # Perguntar ao usuário sobre diretórios de instalação
    APP_DIR=$(ask "Digite o diretório de instalação do aplicativo" "${HOME}/Applications")
    SANDBOX_MODE=$(ask "Deseja executar o Cursor sem sandbox?" "s" "sn")
    
    # Criar diretórios necessários
    mkdir -p "${APP_DIR}" "${ICON_DIR}" "${DESKTOP_DIR}" "${BIN_DIR}" || error "Falha ao criar diretórios"
    
    # Downloads com retry e verificação
    download_with_progress "${DOWNLOAD_URL}" "${APPIMAGE_PATH}" "Cursor AppImage"
    chmod +x "${APPIMAGE_PATH}"
    
    if [ ! -f "${ICON_PATH}" ]; then
        download_with_progress "${ICON_DOWNLOAD_URL}" "${ICON_PATH}" "ícone do Cursor"
    fi
    
    create_desktop_file
    create_launcher_script
    
    # Verificar instalação
    verify_installation
    
    log "SUCCESS" "✨ Cursor foi instalado com sucesso! ✨"
    show_post_install_message
}

# Função para verificar a instalação
verify_installation() {
    local verification_failed=false
    
    log "INFO" "Verificando instalação..."
    
    # Verificar arquivos essenciais
    for file in "${APPIMAGE_PATH}" "${ICON_PATH}" "${DESKTOP_FILE_PATH}" "${LAUNCHER_SCRIPT}"; do
        if [[ ! -f "$file" ]]; then
            log "ERROR" "Arquivo ausente: $file"
            verification_failed=true
        elif [[ ! -x "$file" && "${file##*.}" != "svg" ]]; then
            log "ERROR" "Permissões incorretas: $file"
            verification_failed=true
        fi
    done
    
    if [[ "$verification_failed" = true ]]; then
        error "Verificação da instalação falhou. Por favor, execute o reparo."
    fi
}

# Função para mostrar mensagem pós-instalação
show_post_install_message() {
    cat << EOF

${COLORS[SUCCESS]}${COLORS[BOLD]}Instalação Concluída!${COLORS[RESET]}

${COLORS[INFO]}Para executar o Cursor, você pode:${COLORS[RESET]}
1. Procurar por 'Cursor' no seu launcher de aplicativos
2. Executar no terminal: cursor
3. Executar diretamente: ${APPIMAGE_PATH}
4. Abrir arquivos/diretórios: cursor <arquivo_ou_diretório>

${COLORS[WARNING]}Notas:${COLORS[RESET]}
- Você pode precisar fazer logout e login novamente para que todas as alterações tenham efeito
- Logs de execução são salvos em ~/.cursor_log
- Para reparar a instalação: $0 --repair
- Para desinstalar: $0 --uninstall

${COLORS[INFO]}Versão instalada: ${VERSION}${COLORS[RESET]}
EOF
}

# Função para desinstalar o Cursor
uninstall_cursor() {
    log "WARNING" "Iniciando processo de desinstalação do Cursor..."
    
    # Confirmar desinstalação
    local confirm=$(ask "Tem certeza que deseja desinstalar o Cursor? (s/n)" "n")
    if [[ $confirm != "s" ]]; then
        log "INFO" "Desinstalação cancelada pelo usuário."
        exit 0
    fi
    
    local files_to_remove=(
        "${APPIMAGE_PATH}"
        "${ICON_PATH}"
        "${DESKTOP_FILE_PATH}"
        "${LAUNCHER_SCRIPT}"
        "${HOME}/.cursor_log"
    )
    
    local success=true
    
    for file in "${files_to_remove[@]}"; do
        if [[ -f "$file" ]]; then
            log "INFO" "Removendo: $file"
            if rm -f "$file"; then
                log "SUCCESS" "✓ Removido: $file"
            else
                log "ERROR" "✗ Falha ao remover: $file"
                success=false
            fi
        fi
    done
    
    # Atualizar cache do sistema
    update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
    gtk-update-icon-cache -f -t ~/.local/share/icons 2>/dev/null || true
    
    if [[ "$success" = true ]]; then
        log "SUCCESS" "✨ Cursor foi desinstalado com sucesso! ✨"
    else
        log "WARNING" "Desinstalação concluída com alguns erros. Verifique as mensagens acima."
    fi
}

# Função de ajuda
show_help() {
    cat << EOF
${COLORS[BOLD]}Uso: $0 [OPÇÃO]${COLORS[RESET]}

Opções:
  ${COLORS[INFO]}-i, --install${COLORS[RESET]}     Instalar o Cursor (padrão)
  ${COLORS[WARNING]}-u, --uninstall${COLORS[RESET]}   Desinstalar o Cursor
  ${COLORS[INFO]}-r, --repair${COLORS[RESET]}      Reparar instalação existente
  ${COLORS[INFO]}-h, --help${COLORS[RESET]}        Mostrar esta mensagem de ajuda

EOF
}

# Função principal
main() {
    local action="install"
    
    # Processar argumentos da linha de comando
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--install)
                action="install"
                shift
                ;;
            -u|--uninstall)
                action="uninstall"
                shift
                ;;
            -r|--repair)
                action="repair"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log "ERROR" "Opção desconhecida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    case $action in
        "install")
            install_cursor
            ;;
        "uninstall")
            uninstall_cursor
            ;;
        "repair")
            repair_installation
            ;;
    esac
}

# Executar o script
main "$@"
