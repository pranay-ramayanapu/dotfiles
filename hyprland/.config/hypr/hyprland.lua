require("monitors")
require("autostart")
require("input")
require("look")
require("animations")
require("misc")
require("keybinds")
require("windowrule")

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- For Noctalia Color templates
require("noctalia").apply_theme()
