hl.config({
    dwindle = {
        preserve_split = true,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
    misc = {
        col = {
            splash = CACHYLGREEN,
        },
        middle_click_paste = false,
        -- Pas d'avalement des terminaux : une fenêtre lancée depuis kitty (ou une app lancée depuis kitty)
        -- prenait sa place, ou restait invisible si ce kitty était déjà avalé.
        enable_swallow = false,
        vrr = 3,
    },
    render = {
        direct_scanout = 2,
    },
    xwayland = {
        force_zero_scaling = true
    },
})
