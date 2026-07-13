-- WezTerm設定（install.shで ~/.config/wezterm/wezterm.lua にリンクされる）
local wezterm = require('wezterm')
local config = wezterm.config_builder()

config.use_ime = true -- 日本語入力に必須
-- Zedのターミナル（内蔵のZed Plex Mono = IBM Plex Mono派生）と見た目を揃える
-- 実体はBrewfileの cask "font-ibm-plex-mono" で入る。未インストール時は内蔵JetBrains Monoにフォールバック
config.font = wezterm.font('IBM Plex Mono')
config.font_size = 13.0
config.color_scheme = 'nord'
config.hide_tab_bar_if_only_one_tab = true
config.initial_rows = 40
config.initial_cols = 120

return config
