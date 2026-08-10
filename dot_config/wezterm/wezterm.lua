local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.font = wezterm.font 'Moralerspace Argon HW'
config.font_size = 14
config.color_scheme = 'Catppuccin Mocha'

config.use_ime = true

return config
