#!/bin/sh

_fail () {
	exit_status="$1"
	if [ -z "$exit_status" ]; then exit_status=1; fi
	printf "Exiting...\n" >&2
	if [ -n "$monitor_pid" ]; then kill -TERM "$monitor_pid" 2>/dev/null; fi
	if [ -n "$updater_pid" ]; then kill -TERM "$updater_pid" 2>/dev/null; fi
	if [ -n "$fifo_name" ]; then rm -f "$fifo_name"; fi
	exit "$exit_status"
}

trap "_fail 0" INT TERM

i=0
while true; do
	# Wait for color-scheme info to become available
	i=$(( i + 1 ))
	dbus-send --session --print-reply=literal --reply-timeout=1000 \
			--dest=org.freedesktop.portal.Desktop \
			/org/freedesktop/portal/desktop \
			org.freedesktop.portal.Settings.Read \
			string:'org.freedesktop.appearance' string:'color-scheme' >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		break;
	elif [ $i -ge 10 ]; then
		printf "Timeout waiting for color-scheme reads on dbus\n" >&2
		_fail
	else
		sleep 1
	fi
done


color_scheme_dir="${XDG_STATE_HOME:-"$HOME"/.local/state}"/color-scheme
mkdir -p "$color_scheme_dir"
data_dir="${XDG_DATA_HOME:-"$HOME"/.local/share}"/color-scheme

invoke_callback_scripts() {
	variant="$1"
	if ! [ -d "$data_dir/scripts" ]; then
		printf "No callback scripts to invoke" >&2
		return 0
	fi
	# Not parallelized, so keep it quick.
	find "$data_dir/scripts" -maxdepth 1 -type f -exec sh -c '
		printf "Invoking %s\n" "$1" >&2
		"$1" "'"$variant"'"
	' sh {} \;
}


fifo_name="$(mktemp --dry-run -t color-scheme-monitor-XXXXXX.fifo)"
mkfifo -m 0600 "$fifo_name"
printf "Created pipe %s\n" "$fifo_name" >&2

# Process to monitor the dbus session; Must use named pipe and manually monitor
# subprocesses, since sh has no pipefail or wait -n builtins
{
	type="signal"
	interface="org.freedesktop.portal.Settings"
	member="SettingChanged"
	printf "Monitoring session dbus\n" >&2
	dbus-monitor --session "type='$type',interface='$interface',member='$member'" --profile
} >"$fifo_name" &
monitor_pid="$!"

# Process to check for and trigger updates
{
	variant="$(cat "$color_scheme_dir"/variant 2>/dev/null)" || variant=""
	while read -r line; do
		color_scheme="$(dbus-send --session --print-reply=literal --reply-timeout=1000 \
				--dest=org.freedesktop.portal.Desktop \
				/org/freedesktop/portal/desktop \
				org.freedesktop.portal.Settings.Read \
				string:'org.freedesktop.appearance' string:'color-scheme')"
		if [ $? -ne 0 ] || [ "$color_scheme" = "" ]; then
			printf "Unable to get color scheme info from dbus\n" >&2
			_fail
		fi
		new_variant="$(printf "%s" "$color_scheme" \
				| grep -E "variant +uint32 [0-9]+" --only-matching \
				| sed -E 's/variant[ ]+uint32 ([0-9]+)/\1/')"
		if [ "$new_variant" != "$variant" ]; then
			printf "System color scheme variant updated to %s\n" "$new_variant" >&2
			variant="$new_variant"
			printf "%s" "$variant" >"$color_scheme_dir"/variant
			invoke_callback_scripts "$variant"
		fi
	done
} <"$fifo_name" &
updater_pid="$!"

# Short sleep before checking process health in case they die quickly
sleep 1
while true; do
	if ! kill -0 $monitor_pid 2>/dev/null; then
		printf "Monitor died unexpectedly\n" >&2
		_fail 3
	elif ! kill -0 $updater_pid 2>/dev/null; then
		printf "Updater died unexpectedly\n" >&2
		_fail 3
	else
		sleep 60
	fi
done
printf "Exiting unexpectedly\n" &2
_fail
