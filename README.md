# dotfiles

Configuration personnelle pour CachyOS, Hyprland, Noctalia, Walker et Elephant.

## Contenu

- Walker : configuration, layout compact et preview compacte
- Noctalia : template de couleurs Walker
- Elephant : ranking des applications et installation Arch/AUR sans helper
- Hyprland : bind `Super+Space` vers Walker et règle de blur du namespace `walker`

Le fichier `~/.config/walker/themes/noctalia/style.css` n'est pas versionné : il est généré par Noctalia depuis `walker.css`.

## Installation

Depuis la racine du dépôt :

```bash
cp -a .config .local "$HOME/"
chmod 0755 "$HOME/.local/bin/install-arch-package"
```

Le template Walker doit être déclaré dans `~/.config/noctalia/config.toml` :

```toml
[theme.templates.user.walker]
input_path = "~/.config/noctalia/templates/walker.css"
output_path = "$XDG_CONFIG_HOME/walker/themes/noctalia/style.css"
post_hook = "pkill walker >/dev/null 2>&1 || true"
```

Appliquer ensuite la configuration :

```bash
noctalia msg templates-apply
systemctl --user restart elephant.service
hyprctl reload
```

## Dépendances

`walker`, `elephant`, `elephant-desktopapplications`, `elephant-archlinuxpkgs`, `git`, `pacman`, `makepkg`, `sudo` et `flock`.

Les paquets AUR sont construits directement avec `makepkg -si`. Aucun helper AUR n'est utilisé.
