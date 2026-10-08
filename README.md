# dotfiles

Configuration personnelle pour CachyOS, Hyprland et Caelestia.

## Contenu

- Caelestia : dossier des fonds d'écran (`~/Images`) et applications thémées par la CLI
- Hyprland : raccourcis vers Caelestia, démarrage du shell et de l'historique du presse-papiers, règle de fenêtre pour Nexus (les réglages de Caelestia)
- `install-arch-package` : installation Arch/AUR sans helper, à lancer à la main

## Dépendances

Caelestia est construit depuis l'AUR sans helper. Installez les paquets AUR dans cet ordre, chacun avec `install-arch-package`, dans un vrai terminal :

```bash
install-arch-package python-materialyoucolor
install-arch-package caelestia-cli
install-arch-package libcava
install-arch-package qt6-m3shapes-git
install-arch-package quickshell-git
install-arch-package ttf-rubik-vf
install-arch-package caelestia-shell
```

Les autres dépendances viennent des dépôts officiels et sont installées automatiquement par `makepkg -si`.

## Installation

Installation en une commande avec GitHub CLI :

```bash
mkdir -p "$HOME/workspace" && gh repo clone godart-corentin/dotfiles "$HOME/workspace/dotfiles" && "$HOME/workspace/dotfiles/install.sh"
```

Depuis un clone existant :

```bash
./install.sh
```

L'installateur est idempotent. Il vérifie les dépendances, copie uniquement les fichiers nécessaires et sauvegarde chaque cible différente sous la forme `*.bak-dotfiles-*` avant remplacement. Il recharge ensuite Hyprland, remplace Noctalia par Caelestia, désactive Elephant, démarre l'historique du presse-papiers et reprend le fond d'écran de Noctalia si Caelestia n'en a pas encore.

Il refuse d'écraser un lien symbolique divergent afin de ne pas interférer silencieusement avec un autre gestionnaire de dotfiles.

N'utilisez pas `caelestia install` ni `caelestia update` : ces commandes installent les dotfiles complets de Caelestia par-dessus cette configuration.

## Diagnostic

```bash
./check.sh
```

Le diagnostic contrôle Caelestia et ses outils, l'arrêt de Noctalia et d'Elephant, l'historique du presse-papiers, le bind `Super+Space` et l'absence de références à Noctalia ou Walker dans la config Hyprland.

## Revenir à Noctalia

```bash
git switch main && ./install.sh
caelestia shell -k
setsid -f noctalia
systemctl --user enable --now elephant.service
```

Restaurez ensuite depuis leur sauvegarde `*.bak-dotfiles-*` les fichiers que la branche `main` ne versionne pas :

- `~/.config/hypr/config/autostart.lua` et `~/.config/hypr/config/windowrules.lua` ;
- `~/.config/gtk-3.0/gtk.css` et `~/.config/gtk-4.0/gtk.css`.
