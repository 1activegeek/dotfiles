# ~/.zshrc.d/06-docker.zsh
# Docker and Docker Compose aliases

# Only define these if docker is available
if command -v docker &>/dev/null; then
  # ============================================
  # Docker
  # ============================================
  alias d='docker'
  alias dps='docker ps'
  alias dpsa='docker ps -a'
  alias di='docker images'
  alias dex='docker exec -it'
  alias dlogs='docker logs -f'
  alias dprune='docker system prune -af --volumes'
  alias dstop='docker stop $(docker ps -q)'
  alias drm='docker rm $(docker ps -aq)'
  alias drmi='docker rmi $(docker images -q)'

  # ============================================
  # Docker Compose
  # ============================================
  alias dc='docker compose'
  alias dcu='docker compose up -d'
  alias dcd='docker compose down'
  alias dcl='docker compose logs -f'
  alias dcr='docker compose restart'
  alias dcb='docker compose build'
  alias dcp='docker compose pull'

  # Show running container IDs and names
  dnames() {
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
  }

  # Shell into a running container
  dsh() {
    local container="${1:?Usage: dsh <container-name>}"
    docker exec -it "$container" /bin/sh
  }

  # Bash into a running container
  dbash() {
    local container="${1:?Usage: dbash <container-name>}"
    docker exec -it "$container" /bin/bash
  }
fi
