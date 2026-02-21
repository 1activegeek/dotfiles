# ~/.zshrc.d/10-kubectl.zsh
# Kubernetes (kubectl) aliases and completion

if command -v kubectl &>/dev/null; then
  # ============================================
  # Aliases
  # ============================================
  alias k='kubectl'
  alias kg='kubectl get'
  alias kga='kubectl get all'
  alias kgp='kubectl get pods'
  alias kgpo='kubectl get pods -o wide'
  alias kgs='kubectl get svc'
  alias kgn='kubectl get nodes'
  alias kgno='kubectl get nodes -o wide'
  alias kgd='kubectl get deployments'
  alias kgcm='kubectl get configmaps'
  alias kgsec='kubectl get secrets'
  alias kgns='kubectl get namespaces'

  alias kd='kubectl describe'
  alias kdp='kubectl describe pod'
  alias kds='kubectl describe svc'
  alias kdn='kubectl describe node'

  alias kl='kubectl logs'
  alias klf='kubectl logs -f'
  alias klt='kubectl logs -f --tail=100'

  alias kex='kubectl exec -it'
  alias kaf='kubectl apply -f'
  alias kdf='kubectl delete -f'
  alias kdr='kubectl delete'

  alias krr='kubectl rollout restart'
  alias krs='kubectl rollout status'

  # Set current namespace
  alias kns='kubectl config set-context --current --namespace'
  # Switch context
  alias kcx='kubectl config use-context'
  # List contexts
  alias kctxl='kubectl config get-contexts'

  # ============================================
  # Shell completion
  # ============================================
  # Load kubectl completion and alias it to 'k'
  source <(kubectl completion zsh)
  compdef k=kubectl

  # ============================================
  # Helper functions
  # ============================================

  # Watch pods in a namespace
  kwatch() {
    local ns="${1:-default}"
    watch -n2 kubectl get pods -n "$ns"
  }

  # Get a shell in a pod
  kshell() {
    local pod="${1:?Usage: kshell <pod-name> [namespace]}"
    local ns="${2:-default}"
    kubectl exec -it "$pod" -n "$ns" -- /bin/sh
  }
fi
