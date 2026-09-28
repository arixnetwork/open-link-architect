#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# OpenLinkArchitect - Automatic Installer
# ============================================================
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/open-link-architect/main/install.sh | bash
#   ./install.sh
#   ./install.sh --yes
#   ./install.sh --local
# ============================================================

REPO_URL="https://github.com/YOUR_ORG/open-link-architect.git"
PROJECT_NAME="open-link-architect"
DEFAULT_PORT=3000
COMPOSE_FILE="docker-compose.yml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NON_INTERACTIVE=false
FORCE_LOCAL=false

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

print_banner() {
  echo -e "${BLUE}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║           OpenLinkArchitect Installer                ║"
  echo "║     AI-powered safe link outreach (Open Source)      ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-n}"
  if $NON_INTERACTIVE; then
    [[ "$default" =~ ^[Yy]$ ]] && return 0 || return 1
  fi
  local reply
  read -r -p "$prompt [y/N]: " reply
  reply=${reply:-$default}
  [[ "$reply" =~ ^[Yy]$ ]]
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--yes) NON_INTERACTIVE=true; shift ;;
    --local) FORCE_LOCAL=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--yes] [--local]"
      exit 0
      ;;
    *) log_error "Unknown option: $1" ;;
  esac
done

print_banner

OS="$(uname -s)"
ARCH="$(uname -m)"
log_info "Detected OS: $OS ($ARCH)"

for cmd in curl git; do
  if ! command_exists "$cmd"; then
    log_error "$cmd is required but not installed."
  fi
done

USE_DOCKER=false
if ! $FORCE_LOCAL && command_exists docker && docker compose version >/dev/null 2>&1; then
  USE_DOCKER=true
  log_info "Docker + Docker Compose detected → using Docker mode"
elif ! $FORCE_LOCAL; then
  log_warn "Docker not found."
  if ask_yes_no "Continue with local (non-Docker) installation?"; then
    USE_DOCKER=false
  else
    log_error "Docker is recommended. Install Docker and re-run, or use --local."
  fi
else
  log_info "Forcing local mode (--local)"
fi

if [[ ! -f "$COMPOSE_FILE" && ! -f "package.json" ]]; then
  log_info "Cloning repository..."
  if [[ -d "$PROJECT_NAME" ]]; then
    log_warn "Directory $PROJECT_NAME already exists."
    if ask_yes_no "Enter existing directory and continue?"; then
      cd "$PROJECT_NAME"
    else
      log_error "Aborted."
    fi
  else
    git clone "$REPO_URL" "$PROJECT_NAME"
    cd "$PROJECT_NAME"
  fi
else
  log_info "Already inside project directory."
fi

if [[ ! -f .env ]]; then
  log_info "Creating .env from .env.example..."
  if [[ -f .env.example ]]; then
    cp .env.example .env
  else
    cat > .env << 'EOF'
DATABASE_URL="postgresql://openlink:openlink@db:5432/openlink"
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
NEXTAUTH_SECRET=change-me-to-a-long-random-string
NEXTAUTH_URL=http://localhost:3000
RESEND_API_KEY=
EOF
  fi
fi

if ! $NON_INTERACTIVE; then
  echo
  log_info "Configuring environment variables (press Enter to keep current value)..."
  set_env_var() {
    local key="$1"
    local prompt="$2"
    local current
    current=$(grep -E "^${key}=" .env 2>/dev/null | cut -d'=' -f2- || true)
    local value
    read -r -p "$prompt [$current]: " value
    value=${value:-$current}
    if grep -qE "^${key}=" .env 2>/dev/null; then
      sed -i.bak "s|^${key}=.*|${key}=${value}|" .env && rm -f .env.bak
    else
      echo "${key}=${value}" >> .env
    fi
  }
  set_env_var "OPENAI_API_KEY" "OpenAI API Key"
  set_env_var "ANTHROPIC_API_KEY" "Anthropic API Key"
  set_env_var "NEXTAUTH_SECRET" "NextAuth Secret"
fi

if grep -q "change-me-to-a-long-random-string" .env 2>/dev/null; then
  RANDOM_SECRET=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p | tr -d '\n')
  sed -i.bak "s|change-me-to-a-long-random-string|${RANDOM_SECRET}|" .env && rm -f .env.bak
  log_info "Generated random NEXTAUTH_SECRET"
fi

if $USE_DOCKER; then
  log_info "Building and starting containers..."
  docker compose pull || true
  docker compose up -d --build

  log_info "Waiting for services to become healthy..."
  MAX_WAIT=90
  WAITED=0
  until curl -sf "http://localhost:${DEFAULT_PORT}/api/health" >/dev/null 2>&1 || [[ $WAITED -ge $MAX_WAIT ]]; do
    sleep 3
    WAITED=$((WAITED + 3))
    echo -n "."
  done
  echo

  if [[ $WAITED -ge $MAX_WAIT ]]; then
    log_warn "Health check timed out. Showing recent logs:"
    docker compose logs --tail=40
    log_error "Services did not become healthy in time."
  fi

  log_info "Running database migrations..."
  docker compose exec -T web npx prisma migrate deploy 2>/dev/null || \
  docker compose exec -T web npx prisma db push 2>/dev/null || \
  log_warn "Could not run migrations automatically. Run them manually later."
else
  log_info "Installing dependencies (local mode)..."
  if command_exists pnpm; then
    pnpm install
  elif command_exists npm; then
    npm install
  else
    log_error "Neither pnpm nor npm found."
  fi
  log_warn "Local mode is limited. Prefer Docker for full features."
fi

echo
log_success "Installation complete!"
echo
echo -e "  ${GREEN}→ Open the dashboard:${NC}  http://localhost:${DEFAULT_PORT}"
echo
echo "Useful commands:"
if $USE_DOCKER; then
  echo "  docker compose logs -f"
  echo "  docker compose down"
  echo "  docker compose up -d"
else
  echo "  npm run dev"
fi
echo
echo "Next steps:"
echo "  1. Open http://localhost:${DEFAULT_PORT}"
echo "  2. Add API keys in Settings if needed"
echo "  3. Create your first campaign"
echo
log_info "Docs: https://github.com/YOUR_ORG/open-link-architect"
echo
