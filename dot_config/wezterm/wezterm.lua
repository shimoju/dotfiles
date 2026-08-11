local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.font = wezterm.font 'Moralerspace Argon HW'
config.font_size = 14
config.color_scheme = 'Catppuccin Mocha'

config.hide_tab_bar_if_only_one_tab = true
config.initial_cols = 240
config.initial_rows = 80
config.window_decorations = 'RESIZE'

config.use_ime = true

return config
