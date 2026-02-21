# ~/.zshrc.d/11-kube-ps1.zsh
# Kubernetes context in prompt via kube-ps1
#
# kube-ps1 is installed via Homebrew.
# This module is used primarily when NOT using Starship's k8s module,
# or when you want a standalone kube_ps1 widget for custom prompts.
#
# With Starship active (default), this module loads kube-ps1 but turns
# off its auto-prompt-integration (kubeoff), so it doesn't conflict.

# Homebrew install path (Apple Silicon)
_kube_ps1_script="$(brew --prefix 2>/dev/null)/opt/kube-ps1/share/kube-ps1.sh"

if [[ -f "$_kube_ps1_script" ]]; then
  # shellcheck source=/dev/null
  source "$_kube_ps1_script"

  # Disable kube-ps1 prompt injection by default when using Starship
  # (Starship handles k8s context display via its [kubernetes] module)
  if command -v starship &>/dev/null; then
    kubeoff 2>/dev/null || true
  fi

  # Toggle kube context display in the prompt
  # Usage: kubeon / kubeoff
  # These are provided by the kube-ps1 script itself.
fi

unset _kube_ps1_script
