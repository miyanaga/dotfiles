-- WezTerm設定（install.shで ~/.config/wezterm/wezterm.lua にリンクされる）
-- 方針: フォントサイズと初期ウィンドウサイズ以外はデフォルトのまま
local wezterm = require('wezterm')
local config = wezterm.config_builder()

config.font_size = 13.0
config.initial_rows = 60
config.initial_cols = 200

return config
