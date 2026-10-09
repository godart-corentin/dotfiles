# dotfiles

Configuration personnelle pour CachyOS, Hyprland et Caelestia.

## Contenu

- Caelestia : dossier des fonds d'écran (`~/Images`) et applications thémées par la CLI
- Kitty : couleurs générées par un modèle Caelestia et rechargées à chaque changement de fond d'écran
- Fenêtres au style de Caelestia (`~/.config/quickshell/outils`, ouvertes ou fermées par `qs-outil <nom>`) :
  - `Super+I` : délais d'inactivité (verrouillage, extinction de l'écran, mise en veille), réglés à la volée dans `general.idle.timeouts` de `~/.config/caelestia/shell.json`
  - `Super+Maj+P` : menu de capture (zone, fenêtre, écran ou couleur ; copier, enregistrer ou annoter avec satty ; délai). Les captures vont dans `~/Captures`, hors de `~/Images` où Caelestia cherche les fonds d'écran
  - `Super+V` : historique du presse-papiers (cliphist) avec aperçu du texte et des images, recherche, filtres et épinglage. Les épinglés sont gardés hors de cliphist : `~/.local/state/presse-papiers-epingles.json` et `~/.local/share/presse-papiers`
  - `Super+;` : emojis en français (recherche par nom et mots-clés, récents, couleur de peau). Données dans `emojis.json`, générées depuis emojibase-data (la commande est en tête de `emojis.qml`)
  - `Super+O` : projets de `~/workspace` avec leur état git (branche, modifications, commits à pousser) ; `Entrée` ouvre dans Zed, `Ctrl+Entrée` un terminal, `Ctrl+G` GitHub
  - `Super+Maj+O` : serveurs et ports TCP en écoute, rattachés au projet de `~/workspace` d'où ils ont été lancés ; `Entrée` ouvre `localhost:PORT`, `Ctrl+C` copie l'adresse, `Maj+Suppr` (deux fois) arrête le processus
  - `Super+G` : GitHub via `gh` : tes PR ouvertes (CI, revue), les revues demandées et les issues assignées ; le dernier résultat est gardé dans `~/.cache/github-outil.json` pour s'afficher tout de suite
  - `Super+Tab` : vue d'ensemble des fenêtres par écran et espace de travail ; clic pour y aller, glisser une fenêtre pour la déplacer sans la suivre. Les miniatures sont en direct pour les espaces affichés, les autres montrent l'icône de l'application
  - `Super+F1` : aide-mémoire des raccourcis, lu en direct depuis `hyprctl binds` ; chaque raccourci de `binds.lua` porte une description « Catégorie › Action »
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

L'installateur est idempotent. Il vérifie les dépendances, copie uniquement les fichiers nécessaires et sauvegarde chaque cible différente sous la forme `*.bak-dotfiles-*` avant remplacement. Seule exception : `~/.config/caelestia/shell.json` n'est copié que s'il n'existe pas encore, pour garder les réglages faits depuis Caelestia ou la fenêtre des délais d'inactivité. Il recharge ensuite Hyprland, remplace Noctalia par Caelestia, désactive Elephant, démarre l'historique du presse-papiers et reprend le fond d'écran de Noctalia si Caelestia n'en a pas encore.

Il refuse d'écraser un lien symbolique divergent afin de ne pas interférer silencieusement avec un autre gestionnaire de dotfiles.

N'utilisez pas `caelestia install` ni `caelestia update` : ces commandes installent les dotfiles complets de Caelestia par-dessus cette configuration.

## Diagnostic

```bash
./check.sh
```

Le diagnostic contrôle Caelestia et ses outils, l'arrêt de Noctalia et d'Elephant, l'historique du presse-papiers, le bind `Super+Space` et l'absence de références à Noctalia ou Walker dans la config Hyprland.

## Revenir à Noctalia

```bash
git switch --detach ae81d02 && ./install.sh
caelestia shell -k
setsid -f noctalia
systemctl --user enable --now elephant.service
```

Restaurez ensuite depuis leur sauvegarde `*.bak-dotfiles-*` les fichiers que ce commit ne versionne pas :

- `~/.config/hypr/config/autostart.lua` et `~/.config/hypr/config/windowrules.lua` ;
- `~/.config/kitty/kitty.conf` ;
- `~/.config/gtk-3.0/gtk.css` et `~/.config/gtk-4.0/gtk.css`.
