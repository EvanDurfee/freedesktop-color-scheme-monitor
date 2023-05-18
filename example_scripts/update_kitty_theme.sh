#!/bin/sh

# Script for updating the kitty terminal emulator's color scheme.
# Updates a symlink to a kitty conf whenever the color-scheme variant changes
# and reloads kitty.

kitty="$(which kitty 2>/dev/null)"
if [ $? -ne 0 ]; then
	printf "Kitty not installed, exiting\n" >&2
	exit 0
fi

variant="$1"

kitty_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"/kitty
mkdir -p "$kitty_config_dir"

case "$variant" in
	0) target_theme="${KITTY_LIGHT_MODE_CONFIG:-light-theme.conf}";;
	1) target_theme="${KITTY_DARK_MODE_CONFIG:-dark-theme.conf}";;
	*) printf "Unrecognized color-scheme variant %s\n" "$variant" >&2; exit 1;;
esac

printf "Setting kitty color scheme to %s\n" "$target_theme" >&2
rm -f "$kitty_config_dir"/system-theme.conf
ln -rs  "$kitty_config_dir"/"$target_theme"  "$kitty_config_dir"/system-theme.conf
printf "Signaling kitty to reload\n" >&2
pkill -USR1 -f "$kitty"
