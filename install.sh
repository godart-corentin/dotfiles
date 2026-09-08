#!/usr/bin/env bash

set -euo pipefail

readonly script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
readonly backup_stamp=$(date +%Y%m%d-%H%M%S)

info() {
  printf '[install] %s\n' "$*"
}

warn() {
  printf '[install] WARNING: %s\n' "$*" >&2
}

die() {
  printf '[install] ERROR: %s\n' "$*" >&2
  exit 1
}

check_dependencies() {
  local missing=()
  local command_name

  for command_name in walker elephant noctalia hyprctl git makepkg pacman sudo flock systemctl; do
    command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
  done

  if (( ${#missing[@]} > 0 )); then
    printf '[install] ERROR: dépendances manquantes :' >&2
    printf ' %s' "${missing[@]}" >&2
    printf '\n' >&2
    exit 69
  fi
}

backup_file() {
  local target=$1
  local backup="${target}.bak-dotfiles-${backup_stamp}-$$"

  cp -a -- "$target" "$backup"
  info "sauvegarde : $backup"
}

install_file() {
  local relative=$1
  local mode=$2
  local source="$script_dir/$relative"
  local target="$HOME/$relative"

  [[ -f "$source" ]] || die "source absente : $source"
  mkdir -p -- "$(dirname -- "$target")"

  if [[ -L "$target" ]]; then
    if cmp -s -- "$source" "$target"; then
      info "inchangé : ~/$relative"
      return
    fi
    die "refus d'écraser le lien symbolique divergent : $target"
  fi

  [[ ! -d "$target" ]] || die "la cible est un dossier : $target"

  if [[ -f "$target" ]]; then
    if cmp -s -- "$source" "$target"; then
      chmod "$mode" -- "$target"
      info "inchangé : ~/$relative"
      return
    fi
    backup_file "$target"
  fi

  install -D -m "$mode" -- "$source" "$target"
  info "installé : ~/$relative"
}

ensure_noctalia_registration() {
  local config_dir="$HOME/.config/noctalia"
  local config_file="$config_dir/config.toml"

  mkdir -p -- "$config_dir"
  if [[ -f "$config_file" ]] && grep -Eq '^[[:space:]]*\[theme\.templates\.user\.walker\][[:space:]]*$' "$config_file"; then
    info "template Walker déjà déclaré dans Noctalia"
    return
  fi

  if [[ -L "$config_file" ]]; then
    die "refus de modifier le lien symbolique Noctalia : $config_file"
  fi

  if [[ -f "$config_file" ]]; then
    backup_file "$config_file"
  fi

  {
    printf '\n[theme.templates.user.walker]\n'
    printf 'input_path = "~/.config/noctalia/templates/walker.css"\n'
    printf 'output_path = "$XDG_CONFIG_HOME/walker/themes/noctalia/style.css"\n'
    printf 'post_hook = "pkill walker >/dev/null 2>&1 || true"\n'
  } >> "$config_file"

  info "template Walker déclaré dans Noctalia"
}

apply_runtime_configuration() {
  local failed=0

  if noctalia msg templates-apply; then
    info "template Noctalia appliqué"
  else
    warn "Noctalia indisponible ; relancez l'installateur dans la session graphique"
    failed=1
  fi

  if systemctl --user restart elephant.service; then
    info "Elephant redémarré"
  else
    warn "impossible de redémarrer elephant.service"
    failed=1
  fi

  if hyprctl reload; then
    info "Hyprland rechargé"
  else
    warn "Hyprland indisponible ; relancez l'installateur dans la session graphique"
    failed=1
  fi

  return "$failed"
}

main() {
  local runtime_failed=0

  check_dependencies

  install_file '.config/walker/config.toml' 0644
  install_file '.config/walker/themes/noctalia/layout.xml' 0644
  install_file '.config/walker/themes/noctalia/preview.xml' 0644
  install_file '.config/noctalia/templates/walker.css' 0644
  install_file '.config/elephant/archlinuxpkgs.toml' 0644
  install_file '.config/elephant/desktopapplications.toml' 0644
  install_file '.local/bin/install-arch-package' 0755
  install_file '.config/hypr/hyprland.lua' 0644
  install_file '.config/hypr/config/binds.lua' 0644

  ensure_noctalia_registration
  apply_runtime_configuration || runtime_failed=$?

  if (( runtime_failed != 0 )); then
    die "fichiers installés, mais une ou plusieurs activations runtime ont échoué"
  fi

  info "installation terminée"
}

main "$@"
