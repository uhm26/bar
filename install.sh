#!/bin/sh
# bar installer (Arch Linux + Hyprland): downloads the prebuilt bar from GitHub releases,
# checks its SHA-256, puts the shell in ~/.config/quickshell/bar and its two helper
# programs in ~/.local/bin, then offers to add it to your Hyprland config. No root needed.
# Re-run it to update.
#
#   curl -fsSL https://raw.githubusercontent.com/uhm26/bar/main/install.sh | sh
#   sh install.sh [--version X.Y.Z] [--no-hypr] [--uninstall]
#
# Everything runs inside main(), called on the last line: if the download is cut off,
# nothing runs.

set -eu

REPO="uhm26/bar"
ASSET="bar-x86_64-linux"
HELPERS="bar-sys bar-launcher"
MARK=".installed-by-bar" # in the shell folder: only a folder with it gets replaced

say() { printf 'bar: %s\n' "$*"; }
die() { printf 'bar: error: %s\n' "$*" >&2; exit 1; }
has() { command -v "$1" >/dev/null 2>&1; }

usage() {
    cat <<EOF
bar installer (Arch Linux + Hyprland)

usage: install.sh [options]

options:
  --version X.Y.Z  install this version instead of the latest
  --no-hypr        don't touch the Hyprland config (print what to add instead)
  --uninstall      remove the bar, its helpers and its Hyprland lines
  -h, --help       show this
EOF
}

# Download $1 to file $2. BAR_MIRROR (a local folder laid out like the release downloads:
# <tag>/<file>) is for testing without the network.
fetch() {
    if [ -n "${BAR_MIRROR:-}" ]; then
        cp "$BAR_MIRROR/${1#*/releases/download/}" "$2" 2>/dev/null \
            || die "not in mirror: ${1#*/releases/download/}"
    elif has curl; then
        curl --proto '=https' --tlsv1.2 -fsSL "$1" -o "$2" || die "download failed: $1"
    elif has wget; then
        wget -q --https-only "$1" -O "$2" || die "download failed: $1"
    else
        die "needs curl or wget"
    fi
}

# Arch Linux and distros based on it (ID or ID_LIKE "arch"), x86_64.
check_system() {
    ids=$(grep -E '^(ID|ID_LIKE)=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' | tr '\n' ' ')
    case " $ids " in
        *" arch "*) ;;
        *) die "the bar supports Arch Linux (and Arch-based distros) only" ;;
    esac
    [ "$(uname -m)" = x86_64 ] || die "no prebuilt bar for $(uname -m)"
    has Hyprland || has hyprctl || die "Hyprland is not installed (sudo pacman -S hyprland)"
    v=$(Hyprland --version 2>/dev/null | head -n 1 | cut -d' ' -f2 || true)
    case "$v" in
        0.[0-9].* | 0.[1-4][0-9].* | 0.5[0-6].*)
            say "note: Hyprland $v is old; the bar is made for 0.57 and newer (update: sudo pacman -Syu)" ;;
    esac
}

latest_tag() {
    [ -n "${BAR_MIRROR:-}" ] && die "with BAR_MIRROR, pass --version"
    list="$tmp/releases.json"
    fetch "https://api.github.com/repos/$REPO/releases?per_page=20" "$list"
    tag=$(grep -o '"tag_name": *"v[^"]*"' "$list" | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/')
    [ -n "$tag" ] || die "no release found"
    printf '%s' "$tag"
}

download() {
    if [ -n "$version" ]; then tag="v$version"; else tag=$(latest_tag); fi
    base="https://github.com/$REPO/releases/download/$tag"
    say "downloading $tag"
    fetch "$base/$ASSET.tar.gz" "$tmp/$ASSET.tar.gz"
    fetch "$base/$ASSET.tar.gz.sha256" "$tmp/$ASSET.tar.gz.sha256"
    want=$(cut -d' ' -f1 "$tmp/$ASSET.tar.gz.sha256")
    got=$(sha256sum "$tmp/$ASSET.tar.gz" | cut -d' ' -f1)
    [ "$want" = "$got" ] || die "checksum mismatch (corrupt or tampered download)"
    tar -xzf "$tmp/$ASSET.tar.gz" -C "$tmp"
}

install_helpers() {
    mkdir -p "$bin"
    for h in $HELPERS; do
        # Copy then rename: replacing a running helper's file is safe this way.
        cp "$tmp/$ASSET/$h" "$bin/.$h.new"
        chmod 755 "$bin/.$h.new"
        mv -f "$bin/.$h.new" "$bin/$h"
    done
    say "installed $HELPERS to $bin"
}

install_shell() {
    if [ -e "$shell_dir" ] && [ ! -e "$shell_dir/$MARK" ]; then
        old="$shell_dir.backup-$(date +%Y%m%d-%H%M%S)"
        mv "$shell_dir" "$old"
        say "a different $shell_dir was there: moved it to $old"
    fi
    rm -rf "$shell_dir.new"
    mkdir -p "${shell_dir%/*}"
    cp -r "$tmp/$ASSET/shell" "$shell_dir.new"
    set_icon_theme "$shell_dir.new/shell.qml"
    : > "$shell_dir.new/$MARK"
    rm -rf "$shell_dir"
    mv "$shell_dir.new" "$shell_dir"
    say "installed the shell to $shell_dir"
}

# The bar draws app icons from an icon theme: use the desktop's own (GTK setting), else a
# common one that is installed, else the bare fallback every system has.
set_icon_theme() {
    theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'" || true)
    [ -n "$theme" ] && [ -n "$(icon_dir "$theme")" ] || theme=""
    if [ -z "$theme" ]; then
        for t in Papirus-Dark Papirus breeze-dark Adwaita; do
            if [ -n "$(icon_dir "$t")" ]; then theme=$t; break; fi
        done
    fi
    [ -n "$theme" ] || theme=hicolor
    sed -i "1s|^//@ pragma IconTheme .*|//@ pragma IconTheme $theme|" "$1"
    say "icon theme: $theme"
}

icon_dir() {
    for d in "${XDG_DATA_HOME:-$HOME/.local/share}/icons" "$HOME/.icons" /usr/share/icons; do
        if [ -f "$d/$1/index.theme" ]; then echo "$d/$1"; return; fi
    done
}

# One pacman line for what is still missing.
missing_packages() {
    need=""
    has qs || need="$need quickshell"
    fc-list : family 2>/dev/null | grep -q "RobotoMono Nerd Font" || need="$need ttf-roboto-mono-nerd"
    has pipewire || need="$need pipewire wireplumber"
    if [ -n "$need" ]; then
        say "still needed, run this once:"
        say "    sudo pacman -S --needed$need"
    fi
}

# Only one program can show notifications and one can host the tray icons.
warn_conflicts() {
    for p in mako dunst swaync fnott waybar; do
        if pgrep -x "$p" >/dev/null 2>&1; then
            say "note: $p is running. Stop it (and remove it from your autostart): the bar"
            say "      shows notifications and tray icons itself, and only one program can."
        fi
    done
}

# --- Hyprland config ---------------------------------------------------------------------
# Hyprland 0.57 and newer read only hyprland.lua (an old hyprland.conf is ignored), so the
# bar's lines are Lua. They live in their own file, bar.lua, loaded by one line at the end
# of hyprland.lua.

hypr_dir() { echo "${XDG_CONFIG_HOME:-$HOME/.config}/hypr"; }
INCLUDE='require("bar") -- the bar (added by its installer)'

snippet() {
    cat <<'LUA'
-- Added by the bar's installer (remove with: install.sh --uninstall).
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c bar")
end)
-- App launcher: SUPER + R (replaces whatever SUPER + R did before, e.g. the default app menu).
hl.unbind("SUPER + R")
hl.bind("SUPER + R", hl.dsp.global("quickshell:launcher"))
-- Blur behind the bar, its notifications and the launcher (seen in glass mode).
hl.layer_rule({ name = "bar-glass", match = { namespace = "^bar$" }, blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ name = "bar-toast-glass", match = { namespace = "^bar-toast$" }, blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ name = "launcher-glass", match = { namespace = "^launcher$" }, blur = true, ignore_alpha = 0.2 })
LUA
}

# Ask on the terminal even when this script comes through a pipe (curl | sh).
ask_yes() {
    [ -r /dev/tty ] || return 1
    printf 'bar: %s [Y/n] ' "$1" > /dev/tty
    read -r answer < /dev/tty || return 1
    case "$answer" in [nN]*) return 1 ;; *) return 0 ;; esac
}

setup_hypr() {
    d=$(hypr_dir)
    main="$d/hyprland.lua"
    if [ ! -f "$main" ]; then
        say "no $main yet (Hyprland 0.57+ makes it on its first start): log in to Hyprland once,"
        say "then run this installer again to add the bar to it"
        return 0
    fi
    if grep -qF "$INCLUDE" "$main"; then
        snippet > "$d/bar.lua"
        say "your Hyprland config already loads the bar (updated $d/bar.lua)"
        return 0
    fi
    if [ "$hypr" = 1 ] && ask_yes "add the bar to your Hyprland config ($main)? A backup is kept."; then
        snippet > "$d/bar.lua"
        cp "$main" "$main.before-bar"
        # Only our one line, so uninstalling leaves the file exactly as it was.
        if [ -n "$(tail -c 1 "$main")" ]; then echo >> "$main"; fi
        printf '%s\n' "$INCLUDE" >> "$main"
        say "added. Backup of your old config: $main.before-bar"
        say "start it now with: qs -c bar   (from the next login it starts by itself)"
    else
        say "to start the bar with Hyprland, save this as $d/bar.lua:"
        snippet | sed 's/^/    /'
        say "and add this line at the end of $main:"
        say "    $INCLUDE"
    fi
}

remove_hypr() {
    main="$(hypr_dir)/hyprland.lua"
    if [ -f "$main" ] && grep -qF "$INCLUDE" "$main"; then
        grep -vF "$INCLUDE" "$main" > "$main.tmp" && mv "$main.tmp" "$main"
        say "removed the bar's line from $main"
    fi
    rm -f "$(hypr_dir)/bar.lua"
}

# -----------------------------------------------------------------------------------------

uninstall() {
    pkill -f '^qs -c bar$' 2>/dev/null || true
    for h in $HELPERS; do rm -f "$bin/$h"; done
    if [ -e "$shell_dir/$MARK" ]; then rm -rf "$shell_dir"; fi
    remove_hypr
    say "removed. Saved settings stay in ~/.local/state/quickshell (delete it if you like)."
}

main() {
    bin="$HOME/.local/bin"
    shell_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/bar"
    version=""
    hypr=1
    remove=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --version) [ $# -ge 2 ] || die "--version needs a version"; version=${2#v}; shift ;;
            --no-hypr) hypr=0 ;;
            --uninstall) remove=1 ;;
            -h | --help) usage; return 0 ;;
            *) die "unknown option $1 (see --help)" ;;
        esac
        shift
    done

    if [ $remove = 1 ]; then uninstall; return 0; fi

    check_system
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT INT TERM
    download
    install_helpers
    install_shell
    setup_hypr
    missing_packages
    warn_conflicts
    say "done. Restart the bar any time with: qs -c bar kill; qs -c bar"
}

main "$@"
