local mainMod = "SUPER"
local launchPrefix = "uwsm app -- " -- if you are not using UWSM, make this empty (e.g. "")
local outil = "~/.local/bin/qs-outil " -- fenêtres de ~/.config/quickshell/outils

-- Description « Catégorie › Action » lue par l'aide-mémoire (Super+F1) ; les raccourcis
-- qui partagent une description y sont regroupés sur une ligne.
local function d(category, action, options)
    options = options or {}
    options.description = category .. " › " .. action
    return options
end

---------------------------
---- WINDOW MANAGEMENT ----
---------------------------

-- Window manipulation
hl.bind(mainMod .. " + Escape",      hl.dsp.exec_cmd("hyprctl kill"), d("Fenêtres", "Fermer de force (cliquer la fenêtre)"))
hl.bind(mainMod .. " + Q",           hl.dsp.window.close(), d("Fenêtres", "Fermer la fenêtre"))
hl.bind(mainMod .. " + ALT + Space", hl.dsp.window.float({ action = "toggle" }), d("Fenêtres", "Flottante ou en mosaïque"))
hl.bind(mainMod .. " + D",           hl.dsp.window.fullscreen({ mode = 1 }), d("Fenêtres", "Agrandir (garde la barre)"))
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen(), d("Fenêtres", "Plein écran"))
hl.bind(mainMod .. " + J",           hl.dsp.layout("togglesplit"), d("Fenêtres", "Inverser la découpe"))

-- Change focus
hl.bind(mainMod .. " + Left",  hl.dsp.focus({ direction = "left" }), d("Focus", "Fenêtre voisine"))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }), d("Focus", "Fenêtre voisine"))
hl.bind(mainMod .. " + Up",    hl.dsp.focus({ direction = "up" }), d("Focus", "Fenêtre voisine"))
hl.bind(mainMod .. " + Down",  hl.dsp.focus({ direction = "down" }), d("Focus", "Fenêtre voisine"))
hl.bind("ALT + Tab",           hl.dsp.window.cycle_next(), d("Focus", "Fenêtre suivante"))

-- Move active window around workspaces & monitors
hl.bind(mainMod .. " + SHIFT + Up",                   hl.dsp.window.move({ direction = "u" }), d("Déplacer", "Déplacer la fenêtre"))
hl.bind(mainMod .. " + SHIFT + Right",                hl.dsp.window.move({ direction = "r" }), d("Déplacer", "Déplacer la fenêtre"))
hl.bind(mainMod .. " + SHIFT + Left",                 hl.dsp.window.move({ direction = "l" }), d("Déplacer", "Déplacer la fenêtre"))
hl.bind(mainMod .. " + SHIFT + Down",                 hl.dsp.window.move({ direction = "d" }), d("Déplacer", "Déplacer la fenêtre"))
hl.bind(mainMod .. " + SHIFT + 1",                    hl.dsp.window.move({ monitor = MONITOR1 }), d("Déplacer", "Envoyer sur l'écran"))
hl.bind(mainMod .. " + SHIFT + 2",                    hl.dsp.window.move({ monitor = MONITOR2 }), d("Déplacer", "Envoyer sur l'écran"))
hl.bind(mainMod .. " + SHIFT + 3",                    hl.dsp.window.move({ monitor = MONITOR3 }), d("Déplacer", "Envoyer sur l'écran"))
hl.bind(mainMod .. " + SHIFT + mouse_up",             hl.dsp.window.move({ monitor   = "-1" }), d("Déplacer", "Envoyer sur l'écran précédent"))
hl.bind(mainMod .. " + SHIFT + mouse_down",           hl.dsp.window.move({ monitor   = "+1" }), d("Déplacer", "Envoyer sur l'écran suivant"))
hl.bind(mainMod .. " + CONTROL + SHIFT + Right",      hl.dsp.window.move({ workspace = "m+1" }), d("Déplacer", "Envoyer sur l'espace suivant"))
hl.bind(mainMod .. " + CONTROL + SHIFT + Left",       hl.dsp.window.move({ workspace = "m-1" }), d("Déplacer", "Envoyer sur l'espace précédent"))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_up",   hl.dsp.window.move({ workspace = "m-1" }), d("Déplacer", "Envoyer sur l'espace précédent"))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "m+1" }), d("Déplacer", "Envoyer sur l'espace suivant"))
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + SHIFT + CONTROL + " .. key, hl.dsp.window.move({ workspace = "m~" .. i }), d("Déplacer", "Envoyer sur l'espace n°"))
end

-- Move & Resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), d("Déplacer", "Déplacer à la souris"))
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), d("Déplacer", "Redimensionner à la souris"))

-- Zoom
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 3.0 then
        hl.config({ cursor = { zoom_factor = 3.0 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
hl.bind(mainMod .. " + Minus", function() zoomfunction(-0.3) end, d("Zoom", "Dézoomer", { repeating = true}))
hl.bind(mainMod .. " + Plus", function() zoomfunction(0.3) end, d("Zoom", "Zoomer", { repeating = true }))

--# Zoom with keypad
hl.bind(mainMod .. " + code:82", function() zoomfunction(-0.3) end, d("Zoom", "Dézoomer", { repeating = true }))
hl.bind(mainMod .. " + code:86", function() zoomfunction(0.3) end, d("Zoom", "Zoomer", { repeating = true }))


------------------
---- LAUNCHER ----
------------------

hl.bind(mainMod .. " + Return",     hl.dsp.exec_cmd(launchPrefix .. TERMINAL), d("Applications", "Terminal"))
hl.bind(mainMod .. " + E",          hl.dsp.exec_cmd(launchPrefix .. FILE_MANAGER), d("Applications", "Fichiers"))
hl.bind(mainMod .. " + T",          hl.dsp.exec_cmd(launchPrefix .. EDITOR), d("Applications", "Éditeur"))
hl.bind(mainMod .. " + C",          hl.dsp.exec_cmd(launchPrefix .. CALCULATOR), d("Applications", "Calculatrice"))
hl.bind("XF86Calculator",           hl.dsp.exec_cmd(launchPrefix .. CALCULATOR), d("Applications", "Calculatrice"))
hl.bind(mainMod .. " + W",          hl.dsp.exec_cmd(launchPrefix .. BROWSER), d("Applications", "Navigateur"))
hl.bind("CONTROL + SHIFT + Escape", hl.dsp.exec_cmd(launchPrefix .. TERMINAL .. " -e btop"), d("Applications", "Moniteur système (btop)"))
hl.bind(mainMod .. " + Z",          hl.dsp.global("caelestia:nexus"), d("Caelestia", "Réglages (Nexus)"))
hl.bind(mainMod .. " + X",          hl.dsp.global("caelestia:utilities"), d("Caelestia", "Utilitaires"))
hl.bind(mainMod .. " + Space",      hl.dsp.global("caelestia:launcher"), d("Caelestia", "Lanceur d'applications"))
hl.bind(mainMod .. " + semicolon",  hl.dsp.exec_cmd(outil .. "emojis"), d("Caelestia", "Emojis")) -- AZERTY: same key as "."
hl.bind(mainMod .. " + L",          hl.dsp.global("caelestia:lock"), d("Caelestia", "Verrouiller"))
hl.bind(mainMod .. " + ALT + C",    hl.dsp.global("caelestia:session"), d("Caelestia", "Session (éteindre, redémarrer…)"))
hl.bind(mainMod .. " + I",          hl.dsp.exec_cmd(outil .. "inactivite"), d("Caelestia", "Délais d'inactivité"))
hl.bind(mainMod .. " + F1",         hl.dsp.exec_cmd(outil .. "raccourcis"), d("Caelestia", "Aide-mémoire des raccourcis"))

---------------------------
---- HARDWARE CONTROLS ----
---------------------------

-- Audio
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), d("Médias et matériel", "Monter le volume", { locked = true, repeating = true }))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      d("Médias et matériel", "Baisser le volume", { locked = true, repeating = true }))
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   d("Médias et matériel", "Couper le son", { locked = true }))
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), d("Médias et matériel", "Couper le micro", { locked = true }))

-- Media
hl.bind("XF86AudioPlay",  hl.dsp.global("caelestia:mediaToggle"), d("Médias et matériel", "Lecture / pause", { locked = true }))
hl.bind("XF86AudioPause", hl.dsp.global("caelestia:mediaToggle"), d("Médias et matériel", "Lecture / pause", { locked = true }))
hl.bind("XF86AudioNext",  hl.dsp.global("caelestia:mediaNext"),   d("Médias et matériel", "Piste suivante", { locked = true }))
hl.bind("XF86AudioPrev",  hl.dsp.global("caelestia:mediaPrev"),   d("Médias et matériel", "Piste précédente", { locked = true }))

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.global("caelestia:brightnessUp"),   d("Médias et matériel", "Augmenter la luminosité", { locked = true, repeating = true }))
hl.bind("XF86MonBrightnessDown", hl.dsp.global("caelestia:brightnessDown"), d("Médias et matériel", "Baisser la luminosité", { locked = true, repeating = true }))

-------------------
---- UTILITIES ----
-------------------

-- Screen Capture
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(outil .. "capture"), d("Captures", "Menu de capture"))
hl.bind(mainMod .. " + P",     hl.dsp.exec_cmd("hyprpicker -a -n"), d("Captures", "Pipette de couleur"))
hl.bind(mainMod .. " + SHIFT + ALT + S",   hl.dsp.global("caelestia:screenshot"), d("Captures", "Zone (sélecteur Caelestia)"))
hl.bind(mainMod .. " + CONTROL + ALT + S", hl.dsp.exec_cmd("caelestia screenshot"), d("Captures", "Écran entier"))

-- Wallpaper: type ">wallpaper" in the launcher

-- Clipboard
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(outil .. "presse-papiers"), d("Caelestia", "Historique du presse-papiers"))

-- Notifications
hl.bind(mainMod .. " + A", hl.dsp.global("caelestia:sidebar"), d("Caelestia", "Notifications"))

-------------------------------
---- WORKSPACES & MONITORS ----
-------------------------------

-- Focus on monitors
hl.bind(mainMod .. " + 1", hl.dsp.focus({ monitor = MONITOR1 }), d("Espaces de travail", "Focus sur l'écran"))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ monitor = MONITOR2 }), d("Espaces de travail", "Focus sur l'écran"))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ monitor = MONITOR3 }), d("Espaces de travail", "Focus sur l'écran"))

-- Focus on workspace number
-- Absolute
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.focus({ workspace = i }), d("Espaces de travail", "Aller à l'espace n°"))
end
-- Relative
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + CONTROL + " .. key, hl.dsp.focus({ workspace = "m~" .. i }), d("Espaces de travail", "Aller à l'espace n° de l'écran"))
end

-- Move to adjacent workspaces and next empty on a given monitor
hl.bind(mainMod .. " + CONTROL + Right",       hl.dsp.focus({ workspace = "m+1" }), d("Espaces de travail", "Espace suivant"))
hl.bind(mainMod .. " + CONTROL + Left",        hl.dsp.focus({ workspace = "m-1" }), d("Espaces de travail", "Espace précédent"))
hl.bind(mainMod .. " + CONTROL + Down",        hl.dsp.focus({ workspace = "emptym" }), d("Espaces de travail", "Premier espace vide"))

-- Scroll through existing workspaces & monitors
hl.bind(mainMod .. " + mouse_down",           hl.dsp.focus({ workspace = "m-1" }), d("Espaces de travail", "Espace précédent"))
hl.bind(mainMod .. " + mouse_up",             hl.dsp.focus({ workspace = "m+1" }), d("Espaces de travail", "Espace suivant"))
hl.bind(mainMod .. " + CONTROL + mouse_up",   hl.dsp.focus({ workspace = "m-1" }), d("Espaces de travail", "Espace précédent"))
hl.bind(mainMod .. " + CONTROL + mouse_down", hl.dsp.focus({ workspace = "m+1" }), d("Espaces de travail", "Espace suivant"))

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special" }), d("Espaces de travail", "Envoyer dans l'espace spécial"))
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special(), d("Espaces de travail", "Afficher l'espace spécial"))

-------------------
----- CUSTOM ------
-------------------

-- Screenshots
hl.bind(
    "SUPER + ALT + S",
    hl.dsp.exec_cmd([[grim -g "$(slurp)" /tmp/screenshot.png && satty --filename /tmp/screenshot.png]]),
    d("Captures", "Zone à annoter (satty)")
)
