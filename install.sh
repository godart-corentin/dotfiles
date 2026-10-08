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

  for command_name in caelestia qs hyprctl wpctl wl-paste cliphist fuzzel git makepkg pacman sudo flock systemctl; do
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

# Caelestia réécrit gtk.css à chaque changement de couleurs : on garde la version Noctalia.
backup_noctalia_gtk() {
  local gtk_css

  for gtk_css in "$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"; do
    if [[ -f "$gtk_css" ]] && grep -Fq 'noctalia' "$gtk_css"; then
      backup_file "$gtk_css"
    fi
  done
}

disable_legacy_services() {
  if systemctl --user is-enabled --quiet elephant.service 2>/dev/null; then
    if systemctl --user disable --now elephant.service; then
      info "elephant.service désactivé"
    else
      warn "impossible de désactiver elephant.service"
    fi
  fi
}

start_clipboard_watchers() {
  local type

  for type in text image; do
    if ! pgrep -f "wl-paste --type $type --watch cliphist store" >/dev/null; then
      setsid -f wl-paste --type "$type" --watch cliphist store >/dev/null 2>&1
      info "historique du presse-papiers ($type) démarré"
    fi
  done
}

# Reprend le fond d'écran de Noctalia, avec des couleurs calculées à partir de lui.
import_noctalia_wallpaper() {
  local state_file="$HOME/.local/state/noctalia/settings.toml"
  local wallpaper

  [[ "$(caelestia wallpaper)" == "No wallpaper set" ]] || return 0
  [[ -f "$state_file" ]] || return 0

  wallpaper=$(sed -n '/^\[wallpaper\.last\]/,/^\[/s/^path = "\(.*\)"$/\1/p' "$state_file" | head -n 1)
  [[ -n "$wallpaper" && -f "$wallpaper" ]] || return 0

  # Le schéma dynamique exige un fond d'écran déjà défini.
  if ! caelestia wallpaper -f "$wallpaper"; then
    warn "impossible d'appliquer le fond d'écran $wallpaper"
    return 0
  fi
  info "fond d'écran repris de Noctalia : $wallpaper"
  caelestia scheme set -n dynamic || warn "impossible de passer au schéma de couleurs dynamique"
}

# Kitty inclut le thème généré par le modèle Caelestia, régénéré à chaque changement de couleurs.
link_kitty_theme() {
  local generated="$HOME/.local/state/caelestia/theme/kitty.conf"
  local link="$HOME/.config/kitty/themes/caelestia.conf"

  if [[ ! -f "$generated" ]]; then
    caelestia scheme set -n "$(caelestia scheme get -n)" ||
      warn "impossible de générer le thème kitty"
  fi

  mkdir -p -- "$(dirname -- "$link")"
  if [[ -e "$link" && ! -L "$link" ]]; then
    die "refus d'écraser le fichier existant : $link"
  fi
  ln -sfn -- "$generated" "$link"
  info "thème kitty relié : $link"

  pkill -USR1 -x kitty || true
}

apply_runtime_configuration() {
  local failed=0

  if hyprctl reload; then
    info "Hyprland rechargé"
  else
    warn "Hyprland indisponible ; relancez l'installateur dans la session graphique"
    return 1
  fi

  if pkill -x noctalia; then
    info "Noctalia arrêté"
  fi

  # Avant le démarrage du shell : sans fond d'écran enregistré, il applique son fond par défaut.
  import_noctalia_wallpaper
  link_kitty_theme

  if caelestia shell -d; then
    info "Caelestia démarré"
  else
    warn "impossible de démarrer Caelestia"
    failed=1
  fi

  disable_legacy_services
  start_clipboard_watchers

  return "$failed"
}

main() {
  local runtime_failed=0

  check_dependencies

  install_file '.config/caelestia/shell.json' 0644
  install_file '.config/caelestia/cli.json' 0644
  install_file '.config/caelestia/templates/kitty.conf' 0644
  install_file '.config/kitty/kitty.conf' 0644
  install_file '.local/bin/install-arch-package' 0755
  install_file '.config/hypr/hyprland.lua' 0644
  install_file '.config/hypr/config/autostart.lua' 0644
  install_file '.config/hypr/config/binds.lua' 0644
  install_file '.config/hypr/config/windowrules.lua' 0644

  backup_noctalia_gtk
  apply_runtime_configuration || runtime_failed=$?

  if (( runtime_failed != 0 )); then
    die "fichiers installés, mais une ou plusieurs activations runtime ont échoué"
  fi

  info "installation terminée"
}

main "$@"
