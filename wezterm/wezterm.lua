-- WezTerm設定（install.shで ~/.config/wezterm/wezterm.lua にリンクされる）
local wezterm = require('wezterm')
local config = wezterm.config_builder()

config.use_ime = true -- 日本語入力に必須
config.font_size = 14.0
config.color_scheme = 'nord'
config.hide_tab_bar_if_only_one_tab = true

return config
