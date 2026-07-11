-- WezTerm設定（install.shで ~/.config/wezterm/wezterm.lua にリンクされる）
local wezterm = require('wezterm')
local config = wezterm.config_builder()

config.use_ime = true -- 日本語入力に必須
config.font_size = 13.0
config.color_scheme = 'nord'
config.hide_tab_bar_if_only_one_tab = true
config.initial_rows = 60
config.initial_cols = 200

return config
