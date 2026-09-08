# dotfiles

Configuration personnelle pour CachyOS, Hyprland, Noctalia, Walker et Elephant.

## Contenu

- Walker : configuration, layout compact et preview compacte
- Noctalia : template de couleurs Walker
- Elephant : ranking des applications et installation Arch/AUR sans helper
- Hyprland : bind `Super+Space` vers Walker et règle de blur du namespace `walker`

Le fichier `~/.config/walker/themes/noctalia/style.css` n'est pas versionné : il est généré par Noctalia depuis `walker.css`.

## Installation

Installation en une commande avec GitHub CLI :

```bash
mkdir -p "$HOME/workspace" && gh repo clone godart-corentin/dotfiles "$HOME/workspace/dotfiles" && "$HOME/workspace/dotfiles/install.sh"
```

Depuis un clone existant :

```bash
./install.sh
```

L'installateur est idempotent. Il vérifie les dépendances, copie uniquement les fichiers nécessaires et sauvegarde chaque cible différente sous la forme `*.bak-dotfiles-*` avant remplacement. Il déclare ensuite le template Walker dans Noctalia si nécessaire, applique la palette, redémarre Elephant et recharge Hyprland.

Il refuse d'écraser un lien symbolique divergent afin de ne pas interférer silencieusement avec un autre gestionnaire de dotfiles.

## Diagnostic

```bash
./check.sh
```

Le diagnostic contrôle Walker, Elephant et ses providers, le CSS généré, le script d'installation des paquets, le bind `Super+Space` et la règle de blur Walker.

## Dépendances

`walker`, `elephant`, `elephant-desktopapplications`, `elephant-archlinuxpkgs`, `noctalia`, `hyprland`, `git`, `pacman`, `makepkg`, `sudo` et `flock`.

Les paquets AUR sont construits directement avec `makepkg -si`. Aucun helper AUR n'est utilisé.
