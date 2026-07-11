# ユーティリティ関数集（install.shで ~/.zsh_functions にリンクされ、zshrcから読み込まれる）

# scode - リモートディレクトリをVSCodeで開く（SSH経由）
# 使い方: scode [-p port] host[:path]
function scode() {
  local port destination host dir
  local -A opthash
  zparseopts -D -E -A opthash -- p:
  port=${opthash[-p]}
  if [ $# -eq 0 ]; then
    echo "usage: $0 [-p port] host[:path]"
    return -1
  fi
  destination="$1"
  host="${destination%%:*}" # before ':'
  dir="${destination##*:}" # after ':'
  # fix dir if ':' does not exist
  [ "$host" = "$dir" ] && dir=""
  # find abs path if $dir does not start with '/'
  [ "${dir:0:1}" != "/" ] && dir="$(ssh ${port:+-p $port} $host pwd)/$dir"
  code --folder-uri "vscode-remote://ssh-remote+$host${port:+:$port}$dir"
}

# scursor - リモートディレクトリをCursorで開く（SSH経由）
function scursor() {
  local port destination host dir
  local -A opthash
  zparseopts -D -E -A opthash -- p:
  port=${opthash[-p]}
  if [ $# -eq 0 ]; then
    echo "usage: $0 [-p port] host[:path]"
    return -1
  fi
  destination="$1"
  host="${destination%%:*}"
  dir="${destination##*:}"
  [ "$host" = "$dir" ] && dir=""
  [ "${dir:0:1}" != "/" ] && dir="$(ssh ${port:+-p $port} $host pwd)/$dir"
  cursor --folder-uri "vscode-remote://ssh-remote+$host${port:+:$port}$dir"
}

# szed - リモートディレクトリをZedで開く（SSH経由）
function szed() {
  local port destination host dir
  local -A opthash
  zparseopts -D -E -A opthash -- p:
  port=${opthash[-p]}
  if [ $# -eq 0 ]; then
    echo "usage: $0 [-p port] host[:path]"
    return 1
  fi
  destination="$1"
  host="${destination%%:*}"
  dir="${destination##*:}"
  [ "$host" = "$dir" ] && dir=""
  # build ssh:// URL
  if [ -z "$dir" ]; then
    zed "ssh://$host${port:+:$port}/~"        # パス省略時はホーム
  elif [ "${dir:0:1}" = "/" ]; then
    zed "ssh://$host${port:+:$port}$dir"      # 絶対パス
  else
    zed "ssh://$host${port:+:$port}/~/$dir"   # 相対パスは ~/ 起点
  fi
}

# scode/scursor/szed 共通の補完（ssh_configのホスト名 + リモートパス）
# ref: /usr/share/zsh/functions/Completion/Unix/_ssh
function _scode_completion () {
  local expl suf ret=1
  typeset -A opt_args
  if compset -P 1 '[^./][^/]#:'; then
    _remote_files -- ssh ${(kv)~opt_args[(I)-[FP1246]]/-P/-p} && ret=0
  elif compset -P 1 '*@'; then
    suf=( -S '' )
    compset -S ':*' || suf=( -r: -S: )
    _wanted hosts expl 'remote host name' _ssh_hosts $suf && ret=0
  else
    _alternative 'hosts:remote host name:_ssh_hosts -r: -S:'
  fi
  return ret
}

if (( $+functions[compdef] )); then
  compdef _scode_completion scode
  compdef _scode_completion scursor
  compdef _scode_completion szed
fi
