#!/bin/bash
set -e

# --- Global ---
SCRIPT_VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_DIR="/root/soluschat"
CONFIG_DIR="$APP_DIR/config"
DOCKER_COMPOSE_TEMPLATE_PATH="${SCRIPT_DIR}/docker-compose.template.yml"
CONFIG_TEMPLATE_DIR="${SCRIPT_DIR}/config"

tput_or_empty() { tput "$@" 2>/dev/null || true; }

COLOR_RESET=$(tput_or_empty sgr0)
COLOR_RED=$(tput_or_empty setaf 1)
COLOR_GREEN=$(tput_or_empty setaf 2)
COLOR_YELLOW=$(tput_or_empty setaf 3)
COLOR_BLUE=$(tput_or_empty setaf 4)
COLOR_CYAN=$(tput_or_empty setaf 6)

# --- Logs ---
echo_info() { echo -e "${COLOR_BLUE}ℹ️  INFO:${COLOR_RESET} $1"; }
echo_success() { echo -e "${COLOR_GREEN}✅ SUCESSO:${COLOR_RESET} $1"; }
echo_warning() { echo -e "${COLOR_YELLOW}⚠️  AVISO:${COLOR_RESET} $1"; }
echo_error() {
  echo -e "${COLOR_RED}❌ ERRO:${COLOR_RESET} $1"
  exit 1
}
press_enter_to_continue() { read -r -p "Pressione Enter para continuar..."; }

# Verifica terminal interativo
check_interactive_terminal() {
  if ! [ -t 0 ]; then
    echo_error "Este terminal não suporta entrada interativa (read). Execute este script via SSH ou terminal com suporte à digitação."
  fi
}

generate_secure_password() {
  openssl rand -hex "${1:-16}"
}

generate_long_secure_string() {
  openssl rand -hex "${1:-32}"
}

# --- Checagem de comandos ---
check_command() {
  if ! command -v "$1" &>/dev/null; then
    echo_warning "Comando '$1' não encontrado."
    return 1
  fi
  return 0
}

install_docker() {
  if ! check_command "docker"; then
    echo_info "Instalando Docker..."
    local codename
    if command -v lsb_release >/dev/null 2>&1; then
      codename=$(lsb_release -cs)
    else
      codename="jammy"
    fi

    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg

    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
    fi

    if ! grep -q "download.docker.com" /etc/apt/sources.list.d/docker.list 2>/dev/null; then
      echo_info "Adicionando repositório oficial do Docker..."
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    fi

    sudo apt-get update

    sudo apt-mark unhold docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true

    sudo apt-get install -y \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin
    sudo usermod -aG docker "$USER" || echo_warning "Falha ao adicionar usuário ao grupo docker. Você pode precisar reiniciar sua sessão."
    echo_success "Docker instalado."
    echo_info "Por favor, faça logout e login novamente ou reinicie o sistema para que as alterações no grupo docker tenham efeito, ou execute 'newgrp docker' no terminal atual."
  fi
}

install_docker_compose() {
  if ! docker compose version &>/dev/null; then
    echo_info "Docker Compose (plugin) não encontrado. Tentando instalar..."
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
    if ! docker compose version &>/dev/null; then
      echo_error "Falha ao instalar Docker Compose. Verifique a documentação do Docker para o seu sistema."
    fi
    echo_success "Docker Compose instalado."
  fi
}

install_nodejs() {
  if ! check_command "node"; then
    echo_info "Instalando Node.js (v20.x)..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
    echo_success "Node.js instalado."
  fi
}

optimize_system_performance() {
  echo_info "Aplicando otimizações de performance do sistema..."
  
  local needs_limits_update=false
  local needs_sysctl_update=false
  
  # Verificar se precisa atualizar limits.conf
  if ! grep -q "# OnTicket optimizations" /etc/security/limits.conf 2>/dev/null; then
    needs_limits_update=true
  fi
  
  # Verificar se precisa atualizar sysctl.conf
  if ! grep -q "# OnTicket optimizations" /etc/sysctl.conf 2>/dev/null; then
    needs_sysctl_update=true
  fi
  
  # Backup dos arquivos apenas se for modificá-los
  if [ "$needs_limits_update" = true ]; then
    [ -f /etc/security/limits.conf ] && sudo cp /etc/security/limits.conf "/etc/security/limits.conf.bak.$(date +%Y%m%d-%H%M%S)"
  fi
  
  if [ "$needs_sysctl_update" = true ]; then
    [ -f /etc/sysctl.conf ] && sudo cp /etc/sysctl.conf "/etc/sysctl.conf.bak.$(date +%Y%m%d-%H%M%S)"
  fi
  
  # Configurar limites do sistema (ulimits)
  echo_info "Configurando limites do sistema (ulimits)..."
  if [ "$needs_limits_update" = true ]; then
    sudo tee -a /etc/security/limits.conf >/dev/null <<'EOF'

# OnTicket optimizations
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF
    echo_success "Limites do sistema configurados."
  else
    echo_info "✓ Limites do sistema já configurados (pulando)."
  fi
  
  # Configurar parâmetros do kernel
  echo_info "Configurando parâmetros do kernel..."
  if [ "$needs_sysctl_update" = true ]; then
    sudo tee -a /etc/sysctl.conf >/dev/null <<'EOF'

# OnTicket optimizations

# Network performance
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30

# File descriptors
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512

# Memory
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF
    echo_success "Parâmetros do kernel configurados."
    
    # Aplicar configurações imediatamente
    echo_info "Aplicando configurações do kernel..."
    sudo sysctl -p >/dev/null 2>&1
    echo_success "Configurações do kernel aplicadas."
  else
    echo_info "✓ Parâmetros do kernel já configurados (pulando)."
  fi
  
  if [ "$needs_limits_update" = false ] && [ "$needs_sysctl_update" = false ]; then
    echo_success "✓ Todas as otimizações de sistema já estavam aplicadas!"
  else
    echo_success "Otimizações de sistema aplicadas com sucesso!"
  fi
}

optimize_docker_daemon() {
  echo_info "Aplicando otimizações do Docker daemon..."
  
  local docker_daemon_file="/etc/docker/daemon.json"
  local needs_docker_update=false
  
  # Criar diretório se não existir
  sudo mkdir -p /etc/docker
  
  # Verificar se já existe configuração otimizada
  if [ -f "$docker_daemon_file" ]; then
    if grep -q '"log-driver"' "$docker_daemon_file" 2>/dev/null && \
       grep -q '"default-ulimits"' "$docker_daemon_file" 2>/dev/null; then
      echo_info "✓ Docker daemon já possui configurações otimizadas (pulando)."
      needs_docker_update=false
    else
      echo_info "Docker daemon.json existe, mas faltam otimizações. Atualizando..."
      needs_docker_update=true
    fi
  else
    echo_info "Arquivo daemon.json não existe. Criando com otimizações..."
    needs_docker_update=true
  fi
  
  # Só faz backup se for modificar
  if [ "$needs_docker_update" = true ] && [ -f "$docker_daemon_file" ]; then
    sudo cp "$docker_daemon_file" "${docker_daemon_file}.bak.$(date +%Y%m%d-%H%M%S)"
    echo_info "Backup do daemon.json criado."
  fi
  
  # Criar/atualizar arquivo de configuração apenas se necessário
  if [ "$needs_docker_update" = true ]; then
    echo_info "Criando/atualizando arquivo de configuração do Docker daemon..."
    sudo tee "$docker_daemon_file" >/dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  }
}
EOF
    echo_success "Arquivo daemon.json configurado."
    
    # Reiniciar Docker para aplicar mudanças
    echo_info "Reiniciando Docker daemon para aplicar configurações..."
    if sudo systemctl restart docker; then
      echo_success "Docker daemon reiniciado com sucesso."
      
      # Aguardar Docker estar pronto
      sleep 3
      
      if docker info >/dev/null 2>&1; then
        echo_success "Docker está funcionando corretamente."
      else
        echo_warning "Docker pode estar demorando para iniciar. Aguarde alguns segundos."
      fi
    else
      echo_warning "Falha ao reiniciar Docker. As configurações serão aplicadas na próxima reinicialização."
    fi
    
    echo_success "Otimizações do Docker aplicadas!"
  else
    echo_success "✓ Docker daemon já estava otimizado!"
  fi
}

install_gettext() {
  if check_command envsubst; then
    echo_success "envsubst ja instalado."
    return 0
  fi
  echo_info "Instalando gettext-base (envsubst)..."
  apt-get update -y >/dev/null 2>&1 || true
  if apt-get install -y gettext-base; then
    echo_success "gettext-base instalado."
  else
    echo_error "Falha ao instalar gettext-base. O instalador precisa do envsubst."
  fi
}

check_and_install_dependencies() {
  echo_info "Verificando dependências..."
  install_docker
  install_docker_compose
  install_nodejs
  install_gettext
  
  # Aplicar otimizações do sistema após instalar dependências
  echo ""
  echo_info "Aplicando otimizações de performance..."
  optimize_system_performance
  optimize_docker_daemon
  
  echo_success "Todas as dependências necessárias estão presentes ou foram instaladas."
}

# --- Coleta de dados ---
get_environment_tag() {
  echo_info "Selecione o ambiente para as imagens Docker (para operações GHCR):"
  options=("Produção (tag: latest)" "Staging (tag: beta)")
  select opt in "${options[@]}"; do
    case $opt in
    "Produção (tag: latest)")
      DOCKER_TAG="latest"
      NODE_ENV="production"
      break
      ;;
    "Staging (tag: beta)")
      DOCKER_TAG="beta"
      NODE_ENV="production"
      break
      ;;
    *) echo_warning "Opção inválida: $REPLY. Tente novamente." ;;
    esac
  done
  echo_info "Ambiente selecionado para GHCR: $DOCKER_TAG"
}

collect_ghcr_image_details() {
  echo_info "Configuração das Imagens Docker do GHCR:"
  prompt_for_variable "GHCR_IMAGE_USER" "  Usuário/Organização do GitHub para as imagens" "${GHCR_IMAGE_USER_CURRENT}" "BuddySoftware" "BuddySoftware"
  prompt_for_variable "GHCR_IMAGE_REPO" "  Nome do Repositório no GitHub para as imagens" "${GHCR_IMAGE_REPO_CURRENT}" "soluschat-V2" "soluschat-V2"
}

collect_traefik_email() {
  echo_info "Configuração do Traefik:"
  prompt_for_variable "EMAIL" "  E-mail para certificados SSL (Traefik)" "${EMAIL_CURRENT}" "" "seu@email.com" validate_email
}

validate_domain() {
  local domain="$1"
  if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    return 1
  fi
  return 0
}
validate_port() {
  local port="$1"
  if [[ "$port" =~ ^[0-9]{1,5}$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
    return 0
  fi
  return 1
}
validate_secret() {
  local value="$1"
  if [[ "$value" =~ [\"\\\$\`[:space:]] ]]; then
    echo_warning "  Use apenas caracteres sem aspas, barra invertida, cifrão, crase ou espaço."
    return 1
  fi
  return 0
}

validate_email() {
  local email="$1"
  if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    return 0
  fi
  return 1
}

prompt_for_variable() {
  local var_name="$1"
  local prompt_text="$2"
  local current_value="$3"
  local default_value="$4"
  local example="$5"
  local validator="$6"
  local new_value
  while true; do
    if [ -n "$current_value" ]; then
      read -r -p "$prompt_text [$current_value]${example:+ | Ex: $example}: " new_value
      new_value="${new_value:-$current_value}"
    elif [ -n "$default_value" ]; then
      read -r -p "$prompt_text (Padrão: $default_value)${example:+ | Ex: $example}: " new_value
      new_value="${new_value:-$default_value}"
    else
      read -r -p "$prompt_text${example:+ | Ex: $example}: " new_value
    fi
    if [ -z "$validator" ] || [ -z "$new_value" ] || $validator "$new_value"; then
      printf -v "$var_name" "%s" "$new_value"
      break
    else
      echo_warning "Valor inválido. Tente novamente."
    fi
  done
}

collect_domains() {
  echo_info "Configuração de Domínios:"
  prompt_for_variable "FRONTEND_DOMAIN" "  URL do FRONTEND" "${FRONTEND_DOMAIN_CURRENT}" "" "app.seudominio.com" validate_domain
  prompt_for_variable "BACKEND_DOMAIN" "  URL do BACKEND" "${BACKEND_DOMAIN_CURRENT}" "" "api.seudominio.com" validate_domain
}

collect_facebook_credentials() {
  echo_info "Configuração do Facebook e Instagram (Opcional - deixe em branco se não for usar):"
  prompt_for_variable "FACEBOOK_APP_ID" "  FACEBOOK_APP_ID" "${FACEBOOK_APP_ID_CURRENT}"
  prompt_for_variable "FACEBOOK_APP_SECRET" "  FACEBOOK_APP_SECRET" "${FACEBOOK_APP_SECRET_CURRENT}"
  prompt_for_variable "VERIFY_TOKEN" "  VERIFY_TOKEN (Webhook do Facebook)" "${VERIFY_TOKEN_CURRENT:-$(generate_secure_password 16)}"
  prompt_for_variable "REQUIRE_BUSINESS_MANAGEMENT" "  REQUIRE_BUSINESS_MANAGEMENT (true/false, para frontend)" "${REQUIRE_BUSINESS_MANAGEMENT_CURRENT:-true}"
}

collect_gerencianet_credentials() {
  echo_info "Configuração da Gerencianet:"
  local setup_gerencianet_prompt="Deseja configurar a integração com Gerencianet agora? (s/N)"
  local current_choice="N"

  if [ -n "$GERENCIANET_CLIENT_ID_CURRENT" ] || [ -n "$GERENCIANET_CLIENT_SECRET_CURRENT" ]; then
    current_choice="s"
  fi

  read -r -p "$setup_gerencianet_prompt (Padrão: $current_choice): " choice
  SETUP_GERENCIANET="${choice:-$current_choice}"

  if [[ "$SETUP_GERENCIANET" == "s" || "$SETUP_GERENCIANET" == "S" ]]; then
    prompt_for_variable "GERENCIANET_SANDBOX" "  GERENCIANET_SANDBOX (true/false)" "${GERENCIANET_SANDBOX_CURRENT:-true}"
    prompt_for_variable "GERENCIANET_CLIENT_ID" "  GERENCIANET_CLIENT_ID" "${GERENCIANET_CLIENT_ID_CURRENT}"
    prompt_for_variable "GERENCIANET_CLIENT_SECRET" "  GERENCIANET_CLIENT_SECRET" "${GERENCIANET_CLIENT_SECRET_CURRENT}"
    prompt_for_variable "GERENCIANET_CHAVEPIX" "  CHAVE PIX da Gerencianet" "${GERENCIANET_CHAVEPIX_CURRENT}"
    prompt_for_variable "GERENCIANET_PIX_CERT" "  Caminho do certificado PIX (.p12)" "${GERENCIANET_PIX_CERT_CURRENT}"
    echo_info "Gerencianet será configurado."
  else
    GERENCIANET_SANDBOX=""
    GERENCIANET_CLIENT_ID=""
    GERENCIANET_CLIENT_SECRET=""
    GERENCIANET_CHAVEPIX=""
    GERENCIANET_PIX_CERT=""
    echo_info "Gerencianet não será configurado."
  fi
}

collect_other_configs() {
  echo_info "Outras Configurações:"
  prompt_for_variable "MASTER_KEY" "  MASTER_KEY (Chave mestra para criptografia interna, essencial e única por instalação)" "${MASTER_KEY_CURRENT}" validate_secret
  if [ -z "$MASTER_KEY" ]; then
    echo_warning "MASTER_KEY não foi definida. É altamente recomendável definir uma."
    read -r -p "Pressione Enter para gerar uma MASTER_KEY automaticamente ou digite uma agora: " user_master_key_input
    if [ -z "$user_master_key_input" ]; then
      MASTER_KEY=$(generate_long_secure_string 32)
      echo_info "MASTER_KEY gerada automaticamente: $MASTER_KEY"
    else
      MASTER_KEY=$user_master_key_input
    fi
  fi
  prompt_for_variable "NUMBER_SUPPORT" "  Número de Suporte (para frontend)" "${NUMBER_SUPPORT_CURRENT}"
  local detected_ip
  detected_ip=$(curl -s --max-time 8 https://api.ipify.org)
  [[ "$detected_ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || detected_ip=""
  prompt_for_variable "WACALLS_PUBLIC_IP" "  IP publico para midia WebRTC" \
    "${WACALLS_PUBLIC_IP_CURRENT}" "$detected_ip" "203.0.113.10"
  prompt_for_variable "WACALLS_WEBRTC_UDP_PORT" "  Porta UDP fixa para midia WebRTC" \
    "${WACALLS_WEBRTC_UDP_PORT_CURRENT}" "7881" "7881"
}

# --- Geração de credenciais ---
set_credentials_mode() {
  echo_info "Como deseja definir as credenciais para Banco de Dados, RabbitMQ e Redis?"
  options=("Gerar automaticamente (Recomendado)" "Digitar manualmente")
  select opt in "${options[@]}"; do
    case $opt in
    "Gerar automaticamente (Recomendado)")
      CREDENTIAL_MODE="auto"
      break
      ;;
    "Digitar manualmente")
      CREDENTIAL_MODE="manual"
      break
      ;;
    *) echo_warning "Opção inválida: $REPLY. Tente novamente." ;;
    esac
  done
}

set_database_credentials() {
  echo_info "Configurando Credenciais do Banco de Dados (PostgreSQL):"
  if [ "$CREDENTIAL_MODE" == "auto" ]; then
    DB_NAME="soluschat_$(generate_secure_password 8)"
    DB_USER="soluschat_$(generate_secure_password 8)"
    DB_PASS="$(generate_secure_password 24)"
    echo_info "  Credenciais do Banco de Dados geradas automaticamente."
  else
    prompt_for_variable "DB_NAME" "  Nome do Banco de Dados (DB_NAME)" "${DB_NAME_CURRENT:-soluschat}"
    prompt_for_variable "DB_USER" "  Usuário do Banco de Dados (DB_USER)" "${DB_USER_CURRENT:-soluschat}"
    prompt_for_variable "DB_PASS" "  Senha do Banco de Dados (DB_PASS)" "" "" "" validate_secret
  fi
}

set_rabbitmq_credentials() {
  echo_info "Configurando Credenciais do RabbitMQ:"
  if [ "$CREDENTIAL_MODE" == "auto" ]; then
    RABBIT_USER="rabbit_$(generate_secure_password 8)"
    RABBIT_PASS="$(generate_secure_password 24)"
    echo_info "  Credenciais do RabbitMQ geradas automaticamente."
  else
    prompt_for_variable "RABBIT_USER" "  Usuário do RabbitMQ (RABBIT_USER)" "${RABBIT_USER_CURRENT:-soluschat}"
    prompt_for_variable "RABBIT_PASS" "  Senha do RabbitMQ (RABBIT_PASS)" "" "" "" validate_secret
  fi
}

set_redis_credentials() {
  echo_info "Configurando Credenciais do Redis:"
  if [ "$CREDENTIAL_MODE" == "auto" ]; then
    REDIS_PASSWORD="$(generate_secure_password 24)"
    echo_info "  Senha do Redis gerada automaticamente."
  else
    while true; do
      prompt_for_variable "REDIS_PASSWORD" "  Senha do Redis (REDIS_PASSWORD)" "${REDIS_PASSWORD_CURRENT}" "" "" validate_secret
      if [ -n "$REDIS_PASSWORD" ]; then
        break
      fi
      echo_warning "Senha do Redis não pode ficar vazia."
    done
  fi
}


generate_internal_secrets() {
  echo_info "Gerando/Verificando chaves e tokens internos..."
  JWT_SECRET="${JWT_SECRET_CURRENT:-$(openssl rand -base64 44)}"
  JWT_REFRESH_SECRET="${JWT_REFRESH_SECRET_CURRENT:-$(openssl rand -base64 44)}"
  COMPANY_TOKEN="${COMPANY_TOKEN_CURRENT:-$(generate_long_secure_string 16)}"
  REDIS_PASSWORD="${REDIS_PASSWORD:-${REDIS_PASSWORD_CURRENT:-$(generate_secure_password 24)}}"
  MASTER_KEY="${MASTER_KEY:-${MASTER_KEY_CURRENT:-$(generate_long_secure_string 32)}}"
  VERIFY_TOKEN="${VERIFY_TOKEN:-${VERIFY_TOKEN_CURRENT:-$(generate_long_secure_string 32)}}"
  ENV_TOKEN="${ENV_TOKEN_CURRENT:-$(generate_long_secure_string 32)}"
  WACALLS_SERVICE_TOKEN="${WACALLS_SERVICE_TOKEN_CURRENT:-$(generate_long_secure_string 64)}"
  MASTER_SETTINGS_ENCRYPTION_KEY="${MASTER_SETTINGS_ENCRYPTION_KEY_CURRENT:-$(openssl rand -base64 32)}"
}

compose_env_value() {
  grep -oP "(?<=^      - \"$1=)[^\"]*" "$APP_DIR/docker-compose.yml" | head -1 || true
}

read_current_values() {
  local compose="$APP_DIR/docker-compose.yml"

  if [ ! -f "$compose" ]; then
    echo_warning "Nenhum compose em '$compose'. Assumindo nova instalação."
    return 1
  fi
  echo_info "Carregando configurações existentes de '$compose'..."

  EMAIL_CURRENT=$(grep -oP '(?<=acme\.email=)[^"]+' "$compose" | head -1 || true)
  FRONTEND_DOMAIN_CURRENT=$(compose_env_value FRONTEND_URL | sed 's|^https://||')
  BACKEND_DOMAIN_CURRENT=$(compose_env_value BACKEND_URL | sed 's|^https://||')

  local backend_image
  backend_image=$(grep -oP '(?<=^    image: )ghcr\.io/\S+/backend:\S+' "$compose" | head -1 || true)
  if [ -n "$backend_image" ]; then
    GHCR_IMAGE_USER_CURRENT=$(echo "$backend_image" | cut -d/ -f2)
    GHCR_IMAGE_REPO_CURRENT=$(echo "$backend_image" | cut -d/ -f3)
    DOCKER_TAG_CURRENT=${backend_image##*:}
  fi

  NODE_ENV_CURRENT=$(compose_env_value NODE_ENV)
  DB_NAME_CURRENT=$(compose_env_value DB_NAME)
  DB_USER_CURRENT=$(compose_env_value DB_USER)
  DB_PASS_CURRENT=$(compose_env_value DB_PASS)
  JWT_SECRET_CURRENT=$(compose_env_value JWT_SECRET)
  JWT_REFRESH_SECRET_CURRENT=$(compose_env_value JWT_REFRESH_SECRET)
  COMPANY_TOKEN_CURRENT=$(compose_env_value COMPANY_TOKEN)
  ENV_TOKEN_CURRENT=$(compose_env_value ENV_TOKEN)
  MASTER_KEY_CURRENT=$(compose_env_value MASTER_KEY)
  MASTER_SETTINGS_ENCRYPTION_KEY_CURRENT=$(compose_env_value MASTER_SETTINGS_ENCRYPTION_KEY)
  VERIFY_TOKEN_CURRENT=$(compose_env_value VERIFY_TOKEN)
  FACEBOOK_APP_ID_CURRENT=$(compose_env_value FACEBOOK_APP_ID)
  FACEBOOK_APP_SECRET_CURRENT=$(compose_env_value FACEBOOK_APP_SECRET)
  UAZAPI_BASE_URL_CURRENT=$(compose_env_value UAZAPI_BASE_URL)
  UAZAPI_ADMIN_TOKEN_CURRENT=$(compose_env_value UAZAPI_ADMIN_TOKEN)
  GERENCIANET_SANDBOX_CURRENT=$(compose_env_value GERENCIANET_SANDBOX)
  GERENCIANET_CLIENT_ID_CURRENT=$(compose_env_value GERENCIANET_CLIENT_ID)
  GERENCIANET_CLIENT_SECRET_CURRENT=$(compose_env_value GERENCIANET_CLIENT_SECRET)
  GERENCIANET_CHAVEPIX_CURRENT=$(compose_env_value GERENCIANET_CHAVEPIX)
  GERENCIANET_PIX_CERT_CURRENT=$(compose_env_value GERENCIANET_PIX_CERT)
  REDIS_PASSWORD_CURRENT=$(compose_env_value REDIS_PASSWORD)
  RABBIT_USER_CURRENT=$(compose_env_value RABBITMQ_DEFAULT_USER)
  RABBIT_PASS_CURRENT=$(compose_env_value RABBITMQ_DEFAULT_PASS)
  NUMBER_SUPPORT_CURRENT=$(compose_env_value REACT_APP_NUMBER_SUPPORT)
  REQUIRE_BUSINESS_MANAGEMENT_CURRENT=$(compose_env_value REACT_APP_REQUIRE_BUSINESS_MANAGEMENT)
  WACALLS_SERVICE_TOKEN_CURRENT=$(compose_env_value WACALLS_SERVICE_TOKEN)
  WACALLS_PUBLIC_IP_CURRENT=$(compose_env_value WACALLS_PUBLIC_IP)
  WACALLS_WEBRTC_UDP_PORT_CURRENT=$(compose_env_value WACALLS_WEBRTC_UDP_PORT)

  echo_success "Configurações carregadas de '$compose'."
  return 0
}

apply_current_values() {
  if [ -z "${EMAIL+definida}" ]; then EMAIL="${EMAIL_CURRENT:-}"; fi
  if [ -z "${NODE_ENV+definida}" ]; then NODE_ENV="${NODE_ENV_CURRENT:-}"; fi
  if [ -z "${DOCKER_TAG+definida}" ]; then DOCKER_TAG="${DOCKER_TAG_CURRENT:-}"; fi
  if [ -z "${GHCR_IMAGE_USER+definida}" ]; then GHCR_IMAGE_USER="${GHCR_IMAGE_USER_CURRENT:-}"; fi
  if [ -z "${GHCR_IMAGE_REPO+definida}" ]; then GHCR_IMAGE_REPO="${GHCR_IMAGE_REPO_CURRENT:-}"; fi
  if [ -z "${FRONTEND_DOMAIN+definida}" ]; then FRONTEND_DOMAIN="${FRONTEND_DOMAIN_CURRENT:-}"; fi
  if [ -z "${BACKEND_DOMAIN+definida}" ]; then BACKEND_DOMAIN="${BACKEND_DOMAIN_CURRENT:-}"; fi
  if [ -z "${DB_NAME+definida}" ]; then DB_NAME="${DB_NAME_CURRENT:-}"; fi
  if [ -z "${DB_USER+definida}" ]; then DB_USER="${DB_USER_CURRENT:-}"; fi
  if [ -z "${DB_PASS+definida}" ]; then DB_PASS="${DB_PASS_CURRENT:-}"; fi
  if [ -z "${RABBIT_USER+definida}" ]; then RABBIT_USER="${RABBIT_USER_CURRENT:-}"; fi
  if [ -z "${RABBIT_PASS+definida}" ]; then RABBIT_PASS="${RABBIT_PASS_CURRENT:-}"; fi
  if [ -z "${REDIS_PASSWORD+definida}" ]; then REDIS_PASSWORD="${REDIS_PASSWORD_CURRENT:-}"; fi
  if [ -z "${JWT_SECRET+definida}" ]; then JWT_SECRET="${JWT_SECRET_CURRENT:-}"; fi
  if [ -z "${JWT_REFRESH_SECRET+definida}" ]; then JWT_REFRESH_SECRET="${JWT_REFRESH_SECRET_CURRENT:-}"; fi
  if [ -z "${VERIFY_TOKEN+definida}" ]; then VERIFY_TOKEN="${VERIFY_TOKEN_CURRENT:-}"; fi
  if [ -z "${ENV_TOKEN+definida}" ]; then ENV_TOKEN="${ENV_TOKEN_CURRENT:-}"; fi
  if [ -z "${COMPANY_TOKEN+definida}" ]; then COMPANY_TOKEN="${COMPANY_TOKEN_CURRENT:-}"; fi
  if [ -z "${MASTER_KEY+definida}" ]; then MASTER_KEY="${MASTER_KEY_CURRENT:-}"; fi
  if [ -z "${MASTER_SETTINGS_ENCRYPTION_KEY+definida}" ]; then MASTER_SETTINGS_ENCRYPTION_KEY="${MASTER_SETTINGS_ENCRYPTION_KEY_CURRENT:-}"; fi
  if [ -z "${WACALLS_SERVICE_TOKEN+definida}" ]; then WACALLS_SERVICE_TOKEN="${WACALLS_SERVICE_TOKEN_CURRENT:-}"; fi
  if [ -z "${WACALLS_PUBLIC_IP+definida}" ]; then WACALLS_PUBLIC_IP="${WACALLS_PUBLIC_IP_CURRENT:-}"; fi
  if [ -z "${WACALLS_WEBRTC_UDP_PORT+definida}" ]; then WACALLS_WEBRTC_UDP_PORT="${WACALLS_WEBRTC_UDP_PORT_CURRENT:-}"; fi
  if [ -z "${NUMBER_SUPPORT+definida}" ]; then NUMBER_SUPPORT="${NUMBER_SUPPORT_CURRENT:-}"; fi
  if [ -z "${REQUIRE_BUSINESS_MANAGEMENT+definida}" ]; then REQUIRE_BUSINESS_MANAGEMENT="${REQUIRE_BUSINESS_MANAGEMENT_CURRENT:-}"; fi
  if [ -z "${FACEBOOK_APP_ID+definida}" ]; then FACEBOOK_APP_ID="${FACEBOOK_APP_ID_CURRENT:-}"; fi
  if [ -z "${FACEBOOK_APP_SECRET+definida}" ]; then FACEBOOK_APP_SECRET="${FACEBOOK_APP_SECRET_CURRENT:-}"; fi
  if [ -z "${UAZAPI_BASE_URL+definida}" ]; then UAZAPI_BASE_URL="${UAZAPI_BASE_URL_CURRENT:-}"; fi
  if [ -z "${UAZAPI_ADMIN_TOKEN+definida}" ]; then UAZAPI_ADMIN_TOKEN="${UAZAPI_ADMIN_TOKEN_CURRENT:-}"; fi
  if [ -z "${GERENCIANET_SANDBOX+definida}" ]; then GERENCIANET_SANDBOX="${GERENCIANET_SANDBOX_CURRENT:-}"; fi
  if [ -z "${GERENCIANET_CLIENT_ID+definida}" ]; then GERENCIANET_CLIENT_ID="${GERENCIANET_CLIENT_ID_CURRENT:-}"; fi
  if [ -z "${GERENCIANET_CLIENT_SECRET+definida}" ]; then GERENCIANET_CLIENT_SECRET="${GERENCIANET_CLIENT_SECRET_CURRENT:-}"; fi
  if [ -z "${GERENCIANET_CHAVEPIX+definida}" ]; then GERENCIANET_CHAVEPIX="${GERENCIANET_CHAVEPIX_CURRENT:-}"; fi
  if [ -z "${GERENCIANET_PIX_CERT+definida}" ]; then GERENCIANET_PIX_CERT="${GERENCIANET_PIX_CERT_CURRENT:-}"; fi
}

render_compose() {
  mkdir -p "$APP_DIR"

  GHCR_IMAGE_USER="${GHCR_IMAGE_USER,,}"
  GHCR_IMAGE_REPO="${GHCR_IMAGE_REPO,,}"

  FRONTEND_URL="https://${FRONTEND_DOMAIN}"
  BACKEND_URL="https://${BACKEND_DOMAIN}"
  RABBITMQ_URI="amqp://${RABBIT_USER}:${RABBIT_PASS}@soluschat-rabbitmq:5672/"
  REDIS_URI="redis://:${REDIS_PASSWORD}@soluschat-redis:6379"
  WACALLS_DSN="postgres://${DB_USER}:${DB_PASS}@soluschat-postgres:5432/${DB_NAME}?sslmode=disable&search_path=wacalls"

  export APP_DIR DOCKER_TAG NODE_ENV EMAIL \
    GHCR_IMAGE_USER GHCR_IMAGE_REPO FRONTEND_DOMAIN BACKEND_DOMAIN \
    FRONTEND_URL BACKEND_URL DB_NAME DB_USER DB_PASS \
    RABBIT_USER RABBIT_PASS RABBITMQ_URI REDIS_PASSWORD REDIS_URI \
    JWT_SECRET JWT_REFRESH_SECRET VERIFY_TOKEN ENV_TOKEN COMPANY_TOKEN \
    MASTER_KEY MASTER_SETTINGS_ENCRYPTION_KEY \
    WACALLS_SERVICE_TOKEN WACALLS_DSN WACALLS_PUBLIC_IP WACALLS_WEBRTC_UDP_PORT \
    NUMBER_SUPPORT REQUIRE_BUSINESS_MANAGEMENT \
    FACEBOOK_APP_ID FACEBOOK_APP_SECRET \
    GERENCIANET_SANDBOX GERENCIANET_CLIENT_ID GERENCIANET_CLIENT_SECRET \
    GERENCIANET_CHAVEPIX GERENCIANET_PIX_CERT \
    UAZAPI_BASE_URL UAZAPI_ADMIN_TOKEN

  local out="$APP_DIR/docker-compose.yml"
  local tmp="$out.novo"
  : >"$tmp"
  chmod 600 "$tmp"
  envsubst <"$DOCKER_COMPOSE_TEMPLATE_PATH" >"$tmp"

  if [ "$OPERATION_TYPE" = "local_build" ]; then
    sed -i -E \
      -e "s|^(    image: )ghcr\.io/[^/]+/[^/]+/([a-z]+):.*|\1soluschat/\2:${DOCKER_TAG}|" \
      -e "s|^(    pull_policy: )always$|\1never|" \
      "$tmp"
  fi

  [ -f "$out" ] && cp -p "$out" "$out.bak"
  mv "$tmp" "$out"

  echo_success "Compose renderizado em $out"
}

docker_login() {
  if grep -q '"ghcr.io"' ~/.docker/config.json 2>/dev/null; then
    echo_success "Login no GitHub Container Registry já existe, pulando etapa de login."
    return 0
  fi

  local ghcr_user_login
  local ghcr_token
  echo_info "Login no GitHub Container Registry (GHCR)"
  while true; do
    read -r -p "  Digite o seu usuário do GitHub para LOGIN no GHCR: " ghcr_user_login
    read -s -r -p "  Digite o seu Token de Acesso Pessoal (PAT) do GitHub (escopo: read:packages ou write:packages): " ghcr_token
    echo
    if [ -n "$ghcr_user_login" ] && [ -n "$ghcr_token" ]; then
      break
    else
      echo_warning "Usuário e token do GitHub para login não podem ser vazios. Tente novamente."
    fi
  done

  echo_info "Tentando login no GHCR com o usuário '$ghcr_user_login'..."
  if echo "$ghcr_token" | docker login ghcr.io -u "$ghcr_user_login" --password-stdin; then
    echo_success "Login no GitHub Container Registry realizado com sucesso."
  else
    echo_error "Falha no login do GHCR. Verifique o usuário, token e sua conexão com a internet."
  fi
}

sync_config_templates() {
  echo_info "Sincronizando arquivos de configuração auxiliares..."

  if [ ! -d "$CONFIG_TEMPLATE_DIR" ]; then
    echo_warning "Diretório de templates de configuração '$CONFIG_TEMPLATE_DIR' não encontrado. Pulando sincronização."
    return
  fi

  local config_dir="$APP_DIR/config"
  mkdir -p "$config_dir"
  
  local files=()

  if [ ${#files[@]} -eq 0 ]; then
    echo_info "Nenhum arquivo de configuração estático para sincronizar. Arquivos são gerados dinamicamente."
    return
  fi

  for rel_path in "${files[@]}"; do
    local source_file="$CONFIG_TEMPLATE_DIR/$rel_path"
    local target_file="$config_dir/$rel_path"
    local target_parent
    target_parent=$(dirname "$target_file")

    if [ ! -f "$source_file" ]; then
      echo_warning "Arquivo de template '$source_file' não encontrado."
      continue
    fi

    mkdir -p "$target_parent"

    if [ -d "$target_file" ]; then
      echo_warning "Corrigindo caminho '$target_file' que era um diretório. Removendo antes de substituir por arquivo."
      rm -rf "$target_file"
    fi

    cp -f "$source_file" "$target_file"
  done

  echo_success "Configurações auxiliares atualizadas em '$config_dir'."
}

generate_pgbouncer_config() {
  echo_info "Gerando arquivos de configuração do PgBouncer..."
  
  local pgbouncer_dir="$APP_DIR/config/pgbouncer"
  mkdir -p "$pgbouncer_dir"

  # Gera pgbouncer.ini
  cat >"$pgbouncer_dir/pgbouncer.ini" <<'PGBOUNCER_INI'
[databases]
;; Aliases for your databases
* = host=soluschat-postgres port=5432

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt

;; Pool settings optimized for OnTicket
pool_mode = transaction
default_pool_size = 25
min_pool_size = 5
reserve_pool_size = 10
reserve_pool_timeout = 5.0
max_client_conn = 400
max_db_connections = 100

;; Connection management
server_reset_query = DISCARD ALL
server_lifetime = 3600
server_idle_timeout = 600
client_login_timeout = 60

;; Logging
log_connections = 1
log_disconnections = 1
log_pooler_errors = 1

server_reset_query = DISCARD ALL
ignore_startup_parameters = extra_float_digits

;; Admin settings
admin_users = ${DB_USER}
stats_users = ${DB_USER}
PGBOUNCER_INI

  sed -i "s/\${DB_USER}/${DB_USER}/g" "$pgbouncer_dir/pgbouncer.ini"
  cat >"$pgbouncer_dir/userlist.txt" <<EOF
"${DB_USER}" "${DB_PASS}"
EOF
  chown 70:70 "$pgbouncer_dir/userlist.txt" 2>/dev/null || true
  chmod 600 "$pgbouncer_dir/userlist.txt"

  echo_success "Arquivos de configuração do PgBouncer gerados:"
  echo_info "  - $pgbouncer_dir/pgbouncer.ini"
  echo_info "  - $pgbouncer_dir/userlist.txt"
}

docker_compose_pull() {
  echo_info "Atualizando imagens Docker (docker compose pull)..."
  cd "$APP_DIR" || echo_error "Não foi possível acessar o diretório $APP_DIR"

  # Verifica se o arquivo docker-compose.yml existe
  if [ ! -f "docker-compose.yml" ]; then
    echo_error "Arquivo docker-compose.yml não encontrado em $APP_DIR"
  fi

  if docker compose pull; then
    echo_success "Imagens Docker atualizadas."
  else
    echo_error "Falha ao atualizar imagens Docker. Verifique se você está logado no GHCR se estiver usando imagens de lá."
  fi
}

ensure_wacalls_schema() {
  local pg="soluschat-postgres"
  echo_info "Garantindo o schema 'wacalls' no banco..."
  docker compose up -d "$pg"

  local attempt
  for attempt in $(seq 1 30); do
    if docker compose exec -T "$pg" pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
      break
    fi
    if [ "$attempt" -eq 30 ]; then
      echo_error "PostgreSQL não respondeu em 60s. Não foi possível criar o schema 'wacalls'."
    fi
    sleep 2
  done

  if docker compose exec -T "$pg" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" \
    -c "CREATE SCHEMA IF NOT EXISTS wacalls AUTHORIZATION \"$DB_USER\"" >/dev/null; then
    echo_success "Schema 'wacalls' disponível."
  else
    echo_error "Falha ao criar o schema 'wacalls'. O serviço de voz não sobe sem ele."
  fi
}

docker_compose_up() {
  echo_info "Iniciando/Reiniciando serviços com Docker Compose..."
  cd "$APP_DIR" || echo_error "Não foi possível acessar o diretório $APP_DIR"

  # Verifica se o arquivo docker-compose.yml existe
  if [ ! -f "docker-compose.yml" ]; then
    echo_error "Arquivo docker-compose.yml não encontrado em $APP_DIR"
  fi

  echo_info "Executando docker compose a partir de: $(pwd)"

  ensure_wacalls_schema

  if docker compose up -d --remove-orphans; then
    echo_success "Serviços Docker iniciados/reiniciados com sucesso."
    echo_info "Aguarde alguns instantes para que todos os serviços estejam operacionais."
    echo ""
    echo_info "Para verificar os logs, use:"
    echo "  ${COLOR_GREEN}cd $APP_DIR && docker compose logs -f${COLOR_RESET}"
    echo ""
    echo_info "Para verificar o status dos serviços:"
    echo "  ${COLOR_GREEN}cd $APP_DIR && docker compose ps${COLOR_RESET}"
  else
    echo_error "Falha ao iniciar/reiniciar serviços Docker. Verifique os logs com 'cd $APP_DIR && docker compose logs'."
  fi
}

show_summary_and_confirm() {
  echo "${COLOR_CYAN}================ Resumo das Configurações ================${COLOR_RESET}"
  echo "  E-mail Traefik:         ${COLOR_YELLOW}${EMAIL}${COLOR_RESET}"
  echo "  URL Frontend:           ${COLOR_YELLOW}https://${FRONTEND_DOMAIN}${COLOR_RESET}"
  echo "  URL Backend:            ${COLOR_YELLOW}https://${BACKEND_DOMAIN}${COLOR_RESET}"
  echo ""
  echo "  Ambiente (NODE_ENV):    ${COLOR_YELLOW}${NODE_ENV}${COLOR_RESET}"
  if [ "$OPERATION_TYPE" == "ghcr" ]; then
    echo "  Docker Tag (GHCR):      ${COLOR_YELLOW}${DOCKER_TAG}${COLOR_RESET}"
    echo "  Usuário Imagem GHCR:    ${COLOR_YELLOW}${GHCR_IMAGE_USER}${COLOR_RESET}"
    echo "  Repositório Imagem GHCR:${COLOR_YELLOW}${GHCR_IMAGE_REPO}${COLOR_RESET}"
    if [ -n "$ghcr_user_login" ]; then
      echo "  Usuário Login GHCR:     ${COLOR_YELLOW}${ghcr_user_login}${COLOR_RESET}"
    fi
  else
    echo "  Build Local:            ${COLOR_YELLOW}Sim${COLOR_RESET}"
    echo "  Repositório Git:        ${COLOR_YELLOW}${REPO_URL}${COLOR_RESET}"
  fi
  echo ""
  echo "  Banco de Dados (Nome):  ${COLOR_YELLOW}${DB_NAME}${COLOR_RESET}"
  echo "  Banco de Dados (User):  ${COLOR_YELLOW}${DB_USER}${COLOR_RESET}"
  echo "  RabbitMQ (User):        ${COLOR_YELLOW}${RABBIT_USER}${COLOR_RESET}"
  echo "  Redis Password:        ${COLOR_YELLOW}${REDIS_PASSWORD}${COLOR_RESET}"
  echo ""
  echo "  MASTER_KEY:             ${COLOR_YELLOW}${MASTER_KEY:0:8}... (oculto)${COLOR_RESET}"
  echo "${COLOR_CYAN}========================================================${COLOR_RESET}"
  echo ""
  read -r -p "As configurações acima estão corretas? Deseja prosseguir? (s/N): " confirmation
  if [[ "$confirmation" != "s" && "$confirmation" != "S" ]]; then
    echo_error "Operação cancelada pelo usuário."
  fi
}

collect_all_data_new_install() {
  collect_traefik_email
  if [ "$OPERATION_TYPE" == "ghcr" ]; then
    get_environment_tag
    collect_ghcr_image_details
  else
    prompt_for_variable "NODE_ENV" "  Ambiente de execução (NODE_ENV para build local)" "${NODE_ENV_CURRENT:-production}" "production" "production ou development"
    DOCKER_TAG="local"
  fi
  collect_domains
  collect_facebook_credentials
  collect_gerencianet_credentials
  collect_other_configs
  set_credentials_mode
  set_database_credentials
  set_rabbitmq_credentials
  set_redis_credentials
  generate_internal_secrets
}

collect_data_update_simplified() {
  echo_info "Carregando configurações existentes para atualização..."
  if ! read_current_values; then
    echo_warning "Nenhum compose em '$APP_DIR/docker-compose.yml'. Não é possível atualizar."
    read -r -p "Deseja prosseguir com uma Nova Instalação? (s/N): " choice
    if [[ "$choice" == "s" || "$choice" == "S" ]]; then
      if [ "$OPERATION_TYPE" == "ghcr" ]; then
        run_new_ghcr_installation
      else
        run_new_local_build_installation
      fi
      exit 0
    else
      echo_error "Atualização cancelada. Arquivo de configuração não encontrado."
    fi
  fi

  echo ""
  echo_info "${COLOR_CYAN}=== Atualização Simplificada ===${COLOR_RESET}"
  echo_info "Apenas as informações essenciais serão solicitadas."
  echo ""

  # Perguntas específicas para cada tipo de operação
  if [ "$OPERATION_TYPE" == "ghcr" ]; then
    echo_info "Configuração do GHCR (GitHub Container Registry):"
    
    # Tag do Docker
    DOCKER_TAG_OLD="$DOCKER_TAG_CURRENT"
    get_environment_tag
    if [ "$DOCKER_TAG" != "$DOCKER_TAG_OLD" ]; then
      echo_info "Tag Docker (GHCR) alterada de '$DOCKER_TAG_OLD' para '$DOCKER_TAG'."
    fi
    
    # Owner/Organização e Repositório
    prompt_for_variable "GHCR_IMAGE_USER" "  Usuário/Organização do GitHub para as imagens" "${GHCR_IMAGE_USER_CURRENT}" "BuddySoftware" "BuddySoftware"
    prompt_for_variable "GHCR_IMAGE_REPO" "  Nome do Repositório no GitHub para as imagens" "${GHCR_IMAGE_REPO_CURRENT}" "soluschat-V2" "soluschat-V2"
    
  else
    echo_info "Configuração do Repositório Git para Build Local:"
    prompt_for_variable "NODE_ENV" "  Ambiente de execução (NODE_ENV)" "${NODE_ENV_CURRENT:-production}" "production" "production ou development"
    DOCKER_TAG="local"
  fi

  echo ""
  # Pergunta se quer alterar outras configurações
  read -r -p "Deseja alterar outras configurações (domínios, Facebook, Gerencianet, etc.)? (s/N): " change_other_configs
  
  if [[ "$change_other_configs" == "s" || "$change_other_configs" == "S" ]]; then
    echo_info "Você pode revisar e alterar as configurações. Pressione Enter para manter o valor atual."
    collect_traefik_email
    collect_domains
    collect_facebook_credentials
    collect_gerencianet_credentials
    collect_other_configs
    
    echo ""
    echo_info "Credenciais de Banco de Dados, RabbitMQ e Redis:"
    DB_NAME="$DB_NAME_CURRENT"
    DB_USER="$DB_USER_CURRENT"
    prompt_for_variable "DB_PASS" "  Senha do Banco de Dados (DB_PASS)" "" "" "Deixe em branco para NÃO alterar" validate_secret
    DB_PASS=${DB_PASS:-$DB_PASS_CURRENT}

    RABBIT_USER="$RABBIT_USER_CURRENT"
    prompt_for_variable "RABBIT_PASS" "  Senha do RabbitMQ (RABBIT_PASS)" "" "" "Deixe em branco para NÃO alterar" validate_secret
    RABBIT_PASS=${RABBIT_PASS:-$RABBIT_PASS_CURRENT}

    prompt_for_variable "REDIS_PASSWORD" "  Senha do Redis" "${REDIS_PASSWORD_CURRENT}" "" "Deixe em branco para NÃO alterar" validate_secret
    REDIS_PASSWORD=${REDIS_PASSWORD:-$REDIS_PASSWORD_CURRENT}
  else
    # Carrega todas as configurações existentes sem perguntar
    echo_info "Mantendo todas as configurações existentes..."
    
    EMAIL="$EMAIL_CURRENT"
    FRONTEND_DOMAIN="$FRONTEND_DOMAIN_CURRENT"
    BACKEND_DOMAIN="$BACKEND_DOMAIN_CURRENT"
    
    FACEBOOK_APP_ID="$FACEBOOK_APP_ID_CURRENT"
    FACEBOOK_APP_SECRET="$FACEBOOK_APP_SECRET_CURRENT"
    VERIFY_TOKEN="$VERIFY_TOKEN_CURRENT"
    REQUIRE_BUSINESS_MANAGEMENT="$REQUIRE_BUSINESS_MANAGEMENT_CURRENT"
    
    GERENCIANET_SANDBOX="$GERENCIANET_SANDBOX_CURRENT"
    GERENCIANET_CLIENT_ID="$GERENCIANET_CLIENT_ID_CURRENT"
    GERENCIANET_CLIENT_SECRET="$GERENCIANET_CLIENT_SECRET_CURRENT"
    GERENCIANET_CHAVEPIX="$GERENCIANET_CHAVEPIX_CURRENT"
    GERENCIANET_PIX_CERT="$GERENCIANET_PIX_CERT_CURRENT"
    
    MASTER_KEY="$MASTER_KEY_CURRENT"
    NUMBER_SUPPORT="$NUMBER_SUPPORT_CURRENT"
    
    DB_NAME="$DB_NAME_CURRENT"
    DB_USER="$DB_USER_CURRENT"
    DB_PASS="$DB_PASS_CURRENT"
    
    RABBIT_USER="$RABBIT_USER_CURRENT"
    RABBIT_PASS="$RABBIT_PASS_CURRENT"
    
    REDIS_PASSWORD="$REDIS_PASSWORD_CURRENT"
    WACALLS_PUBLIC_IP="$WACALLS_PUBLIC_IP_CURRENT"
    WACALLS_WEBRTC_UDP_PORT="$WACALLS_WEBRTC_UDP_PORT_CURRENT"
  fi

  generate_internal_secrets
  apply_current_values
}

collect_data_update() {
  echo_info "Carregando configurações existentes para atualização..."
  if ! read_current_values; then
    echo_warning "Nenhum compose em '$APP_DIR/docker-compose.yml'. Não é possível atualizar."
    read -r -p "Deseja prosseguir com uma Nova Instalação? (s/N): " choice
    if [[ "$choice" == "s" || "$choice" == "S" ]]; then
      if [ "$OPERATION_TYPE" == "ghcr" ]; then
        run_new_ghcr_installation
      else
        run_new_local_build_installation
      fi
      exit 0
    else
      echo_error "Atualização cancelada. Arquivo de configuração não encontrado."
    fi
  fi

  echo_info "Você pode revisar e alterar as configurações. Pressione Enter para manter o valor atual."
  collect_traefik_email

  if [ "$OPERATION_TYPE" == "ghcr" ]; then
    DOCKER_TAG_OLD="$DOCKER_TAG_CURRENT"
    get_environment_tag
    if [ "$DOCKER_TAG" != "$DOCKER_TAG_OLD" ]; then
      echo_info "Tag Docker (GHCR) alterada de '$DOCKER_TAG_OLD' para '$DOCKER_TAG'."
    fi
    collect_ghcr_image_details
  else
    prompt_for_variable "NODE_ENV" "  Ambiente de execução (NODE_ENV para build local)" "${NODE_ENV_CURRENT:-production}"
    DOCKER_TAG="local"
  fi

  collect_domains
  collect_facebook_credentials
  collect_gerencianet_credentials
  collect_other_configs

  echo_info "Credenciais de Banco de Dados, RabbitMQ e Redis: Para alterá-las, edite '$APP_DIR/docker-compose.yml' manualmente ANTES de rodar a atualização, ou use a opção de Resetar Instalação."
  DB_NAME="$DB_NAME_CURRENT"
  DB_USER="$DB_USER_CURRENT"
  prompt_for_variable "DB_PASS" "  Senha do Banco de Dados (DB_PASS)" "" "" "Deixe em branco para NÃO alterar se já existir" validate_secret
  DB_PASS=${DB_PASS:-$DB_PASS_CURRENT}

  RABBIT_USER="$RABBIT_USER_CURRENT"
  prompt_for_variable "RABBIT_PASS" "  Senha do RabbitMQ (RABBIT_PASS)" "" "" "Deixe em branco para NÃO alterar" validate_secret
  RABBIT_PASS=${RABBIT_PASS:-$RABBIT_PASS_CURRENT}

  prompt_for_variable "REDIS_PASSWORD" "  Senha do Redis" "${REDIS_PASSWORD_CURRENT}" "" "Deixe em branco para NÃO alterar" validate_secret
  REDIS_PASSWORD=${REDIS_PASSWORD:-$REDIS_PASSWORD_CURRENT}

  generate_internal_secrets
  apply_current_values
}

run_new_ghcr_installation() {
  OPERATION_TYPE="ghcr"
  echo_info "Iniciando Nova Instalação (Imagens Remotas GHCR)..."
  collect_all_data_new_install
  show_summary_and_confirm
  render_compose
  sync_config_templates
  generate_pgbouncer_config
  docker_login
  docker_compose_pull
  docker_compose_up
  echo_success "Nova Instalação (GHCR) concluída!"
  show_post_install_info
}

run_update_ghcr_installation() {
  OPERATION_TYPE="ghcr"
  echo_info "Iniciando Atualização da Instalação (Imagens Remotas GHCR)..."
  collect_data_update_simplified
  show_summary_and_confirm
  render_compose
  sync_config_templates
  generate_pgbouncer_config
  docker_login
  docker_compose_pull
  docker_compose_up
  echo_success "Atualização da Instalação (GHCR) concluída!"
  show_post_install_info
}

setup_local_repo() {
  prompt_for_variable "REPO_URL" "  URL do repositório Git (HTTPS)" "${REPO_URL_CURRENT}" "https://github.com/seu-usuario/seu-repositorio.git" "https://github.com/seu-usuario/seu-repositorio.git"
  prompt_for_variable "REPO_BRANCH" "  Branch do repositório Git" "${REPO_BRANCH_CURRENT:-main}" "main" "main ou develop"
  read -r -p "  O repositório é privado e requer um token de acesso? (s/N): " private_repo_choice
  if [[ "$private_repo_choice" == "s" || "$private_repo_choice" == "S" ]]; then
    prompt_for_variable "REPO_TOKEN" "  Token de acesso ao repositório (PAT)" "" "" "ghp_xxx..."
  else
    REPO_TOKEN=""
  fi

  REPO_URL_CURRENT="$REPO_URL"
  REPO_BRANCH_CURRENT="$REPO_BRANCH"

  local repo_source_dir="$APP_DIR/source_code"
  mkdir -p "$repo_source_dir"

  if [ ! -d "$repo_source_dir/.git" ]; then
    echo_info "Clonando repositório de $REPO_URL (branch: $REPO_BRANCH) em $repo_source_dir..."
    local clone_url="$REPO_URL"
    if [ -n "$REPO_TOKEN" ]; then
      clone_url="https://${REPO_TOKEN}@${REPO_URL#https://}"
    fi
    if git clone --branch "$REPO_BRANCH" "$clone_url" "$repo_source_dir"; then
      echo_success "Repositório clonado com sucesso."
    else
      echo_error "Falha ao clonar o repositório. Verifique a URL, branch, token e permissões."
    fi
  else
    echo_info "Repositório local encontrado em $repo_source_dir. Atualizando (git pull)..."
    cd "$repo_source_dir"
    git stash push -u
    if git checkout "$REPO_BRANCH" && git pull origin "$REPO_BRANCH"; then
      echo_success "Repositório atualizado com sucesso."
      git stash pop || echo_info "Nenhum stash para aplicar."
    else
      git stash pop || true
      echo_error "Falha ao atualizar o repositório. Verifique o status do git em $repo_source_dir."
    fi
    cd "$APP_DIR"
  fi
}

build_local_images() {
  local repo_source_dir="$APP_DIR/source_code"
  if [ ! -d "$repo_source_dir" ]; then
    echo_error "Diretório de código fonte $repo_source_dir não encontrado. Execute o setup do repositório primeiro."
  fi

  echo_info "Iniciando build das imagens Docker locais..."
  for svc in backend frontend wacalls; do
    local dockerfile_path="$repo_source_dir/$svc/Dockerfile"
    local context_path="$repo_source_dir/$svc"
    local image_name="soluschat/${svc}:${DOCKER_TAG}"

    if [ -f "$dockerfile_path" ]; then
      echo_info "Buildando imagem $image_name a partir de $context_path..."
      if docker build -t "$image_name" --build-arg NODE_ENV="$NODE_ENV" "$context_path"; then
        echo_success "Imagem $image_name buildada com sucesso."
      else
        echo_error "Falha ao buildar a imagem $image_name."
      fi
    else
      echo_warning "Dockerfile para o serviço '$svc' não encontrado em '$dockerfile_path'. Pulando build."
    fi
  done
}

run_new_local_build_installation() {
  OPERATION_TYPE="local_build"
  echo_info "Iniciando Nova Instalação (Build Local das Imagens)..."
  setup_local_repo
  collect_all_data_new_install
  show_summary_and_confirm
  render_compose
  build_local_images
  sync_config_templates
  generate_pgbouncer_config
  docker_compose_up
  echo_success "Nova Instalação (Build Local) concluída!"
  show_post_install_info
}

run_update_local_build_installation() {
  OPERATION_TYPE="local_build"
  echo_info "Iniciando Atualização da Instalação (Build Local das Imagens)..."
  setup_local_repo
  collect_data_update_simplified
  show_summary_and_confirm
  render_compose
  build_local_images
  sync_config_templates
  generate_pgbouncer_config
  docker_compose_up
  echo_success "Atualização da Instalação (Build Local) concluída!"
  show_post_install_info
}

run_reset_installation() {
  echo_warning "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo_warning "!!! ATENÇÃO: ESTA OPERAÇÃO É DESTRUTIVA E IRREVERSÍVEL !!!"
  echo_warning "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo_info "Esta operação irá:"
  echo_info "  1. Parar e remover todos os contêineres da aplicação (definidos em docker-compose.yml)."
  echo_info "  2. Remover os volumes Docker associados (PERDA DE DADOS: postgres_data, redis_data, etc.)."
  echo_info "  3. Apagar o docker-compose.yml renderizado em '$APP_DIR'."
  echo_info "  4. Apagar o diretório de código fonte baixado ($APP_DIR/source_code) se existir."
  echo_info "  5. Limpar o sistema Docker de imagens e volumes órfãos."
  echo ""
  read -r -p "Você tem certeza absoluta que deseja resetar a instalação? (Digite 'SIM' para confirmar): " confirmation
  if [ "$confirmation" != "SIM" ]; then
    echo_info "Reset cancelado pelo usuário."
    exit 0
  fi

  echo_info "Iniciando reset da instalação..."

  if [ -f "$APP_DIR/docker-compose.yml" ]; then
    echo_info "Parando e removendo contêineres e volumes Docker..."
    cd "$APP_DIR" || echo_warning "Não foi possível acessar $APP_DIR"
    if docker compose down --volumes --remove-orphans; then
      echo_success "Contêineres Docker e volumes associados parados e removidos."
    else
      echo_warning "Falha ao parar/remover contêineres com Docker Compose."
    fi
  else
    echo_warning "Arquivo docker-compose.yml não encontrado em $APP_DIR. Pulando 'docker compose down'."
  fi

  echo_info "Limpando sistema Docker (docker system prune)..."
  if docker system prune -af --volumes; then
    echo_success "Sistema Docker limpo."
  else
    echo_warning "Falha ao limpar o sistema Docker."
  fi

  if [ -d "$APP_DIR/source_code" ]; then
    echo_info "Removendo diretório de código fonte '$APP_DIR/source_code'..."
    rm -rf "$APP_DIR/source_code"
    echo_success "Diretório de código fonte removido."
  fi

  if [ -f "$APP_DIR/docker-compose.yml" ]; then
    echo_info "Removendo arquivo docker-compose.yml da aplicação..."
    rm -f "$APP_DIR/docker-compose.yml" "$APP_DIR/docker-compose.yml.bak" 2>/dev/null
    echo_success "Arquivo docker-compose.yml removido."
  fi

  if [ -d "$CONFIG_DIR" ]; then
    echo_info "Removendo diretório de configurações auxiliares '$CONFIG_DIR'..."
    rm -rf "$CONFIG_DIR"
    echo_success "Diretório de configurações removido."
  fi

  # Volta para o diretório do instalador
  cd "$INSTALLER_DIR" || true

  echo_success "Reset da instalação concluído!"
  echo_info "Você pode agora executar uma nova instalação se desejar."
}

show_post_install_info() {
  echo ""
  echo "${COLOR_CYAN}=====================================================${COLOR_RESET}"
  echo "${COLOR_GREEN}🎉 Instalação/Atualização Concluída com Sucesso! 🎉${COLOR_RESET}"
  echo "${COLOR_CYAN}=====================================================${COLOR_RESET}"
  echo ""
  echo "${COLOR_YELLOW}📋 Informações Importantes:${COLOR_RESET}"
  echo ""
  echo "  🌐 URLs da Aplicação:"
  echo "     Frontend: ${COLOR_GREEN}https://${FRONTEND_DOMAIN}${COLOR_RESET}"
  echo "     Backend:  ${COLOR_GREEN}https://${BACKEND_DOMAIN}${COLOR_RESET}"
  echo ""
  echo "  🔐 Redis:"
  echo "     Senha:   ${COLOR_YELLOW}${REDIS_PASSWORD}${COLOR_RESET}"
  echo ""
  echo "  📦 Banco de Dados PostgreSQL:"
  echo "     Nome:    ${COLOR_YELLOW}${DB_NAME}${COLOR_RESET}"
  echo "     Usuário: ${COLOR_YELLOW}${DB_USER}${COLOR_RESET}"
  echo ""
  echo "${COLOR_CYAN}📝 Comandos Úteis:${COLOR_RESET}"
  echo "  Ver logs de todos os serviços:"
  echo "    ${COLOR_GREEN}cd $APP_DIR && docker compose logs -f${COLOR_RESET}"
  echo ""
  echo "  Ver logs de um serviço específico:"
  echo "    ${COLOR_GREEN}cd $APP_DIR && docker compose logs -f backend${COLOR_RESET}"
  echo "    ${COLOR_GREEN}cd $APP_DIR && docker compose logs -f frontend${COLOR_RESET}"
  echo "    ${COLOR_GREEN}cd $APP_DIR && docker compose logs -f wacalls${COLOR_RESET}"
  echo ""
  echo "  Verificar status dos serviços:"
  echo "    ${COLOR_GREEN}cd $APP_DIR && docker compose ps${COLOR_RESET}"
  echo ""
  echo "  Reiniciar um serviço:"
  echo "    ${COLOR_GREEN}cd $APP_DIR && docker compose restart backend${COLOR_RESET}"
  echo ""
  echo "${COLOR_YELLOW}⚠️  Importante:${COLOR_RESET}"
  echo "  - Aguarde alguns minutos para todos os serviços iniciarem completamente"
  echo "  - O certificado SSL pode levar alguns minutos para ser gerado na primeira vez"
  echo "  - Suas configurações foram salvas em: ${COLOR_YELLOW}$APP_DIR/docker-compose.yml${COLOR_RESET}"
  echo "  - ${COLOR_RED}MANTENHA ESTE ARQUIVO SEGURO!${COLOR_RESET} Ele contém todas as senhas e chaves"
  echo ""
  echo "${COLOR_CYAN}=====================================================${COLOR_RESET}"
}

main_menu_header() {
  clear
  echo "${COLOR_CYAN}=====================================================${COLOR_RESET}"
  echo "${COLOR_CYAN}  🚀 Instalador SolusChat - Versão $SCRIPT_VERSION ${COLOR_RESET}"
  echo "${COLOR_CYAN}  📦 Atendimento e voz no WhatsApp ${COLOR_RESET}"
  echo "${COLOR_CYAN}  👨‍💻 Autor: Joseph Fernandes ${COLOR_RESET}"
  echo "${COLOR_CYAN}=====================================================${COLOR_RESET}"
  echo ""
}

select_operation_mode() {
  main_menu_header
  echo "Escolha a operação desejada:"
  echo ""
  echo "${COLOR_GREEN}🐳 Imagens Remotas (GHCR) - Recomendado${COLOR_RESET}"
  echo "  1) Nova Instalação (usando imagens do GHCR)"
  echo "  2) Atualizar Instalação (usando imagens do GHCR)"
  echo ""
  echo "${COLOR_YELLOW}🔨 Build Local de Imagens (Avançado)${COLOR_RESET}"
  echo "  3) Nova Instalação (buildando imagens localmente a partir do Git)"
  echo "  4) Atualizar Instalação (re-buildando imagens localmente a partir do Git)"
  echo ""
  echo "${COLOR_RED}🔧 Manutenção${COLOR_RESET}"
  echo "  5) Resetar Instalação Completa (⚠️  PERDA DE DADOS)"
  echo ""
  echo "  6) Sair"
  echo ""
  while true; do
    read -rp "Digite o número da opção desejada: " opt
    case $opt in
    1)
      OPERATION_MODE="new_ghcr"
      break
      ;;
    2)
      OPERATION_MODE="update_ghcr"
      break
      ;;
    3)
      OPERATION_MODE="new_local"
      break
      ;;
    4)
      OPERATION_MODE="update_local"
      break
      ;;
    5)
      OPERATION_MODE="reset"
      break
      ;;
    6)
      echo_info "Saindo..."
      exit 0
      ;;
    *) echo_warning "Opção inválida: $opt. Tente novamente." ;;
    esac
  done
}

# --- Início da Execução ---
check_interactive_terminal
check_and_install_dependencies

# Cria o diretório da aplicação se não existir
mkdir -p "$APP_DIR"

# Salva o diretório atual do instalador
INSTALLER_DIR="$(pwd)"
echo_info "Diretório do instalador: $INSTALLER_DIR"
echo_info "Diretório da aplicação: $APP_DIR"

if [ ! -f "$DOCKER_COMPOSE_TEMPLATE_PATH" ]; then
  echo_error "Template não encontrado em $DOCKER_COMPOSE_TEMPLATE_PATH."
fi

if [ ! -d "$CONFIG_TEMPLATE_DIR" ]; then
  if [ -d "$INSTALLER_DIR/config" ]; then
    CONFIG_TEMPLATE_DIR="$INSTALLER_DIR/config"
    echo_info "Templates de configuração encontrados em: $CONFIG_TEMPLATE_DIR"
  else
    echo_warning "Diretório de templates de configuração '$CONFIG_TEMPLATE_DIR' não encontrado."
  fi
fi

select_operation_mode

case "$OPERATION_MODE" in
"new_ghcr")
  run_new_ghcr_installation
  ;;
"update_ghcr")
  run_update_ghcr_installation
  ;;
"new_local")
  run_new_local_build_installation
  ;;
"update_local")
  run_update_local_build_installation
  ;;
"reset")
  run_reset_installation
  ;;
*)
  echo_error "Modo de operação desconhecido: $OPERATION_MODE"
  ;;
esac

exit 0
