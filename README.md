# Freedesktop Color Scheme Monitor

Script and systemd service for monitoring updates to the user's graphical session color scheme,
storing the current state in `XDG_STATE_HOME`, and invoking callback scripts whenever the color
scheme changes.

## Installation

Install the script and systemd service

```shell
mkdir -p "${XDG_DATA_HOME:-/.local/share}"/color-scheme
cp ./color-scheme/color-scheme-monitor.sh "${XDG_DATA_HOME:-/.local/share}"/color-scheme/
cp ./systemd/color-scheme-monitor.service "${XDG_CONFIG_HOME:-/.config}"/systemd/user/
# OR
ln -s ./color-scheme/color-scheme-monitor.sh "${XDG_DATA_HOME:-/.local/share}"/color-scheme/
ln -s ./systemd/color-scheme-monitor.service "${XDG_CONFIG_HOME:-/.config}"/systemd/user/
```

Enable the systemd service

```shell
systemctl --user daemon-reload
systemctl --user enable --now color-scheme-monitor.service
```

If you wish to install the monitor script elsewhere, you will need to update the path in the
systemd unit.

## Usage

Upon startup, the color scheme monitor will load the previous state data (if available) from
`$XDG_STATE_HOME/color-scheme` (`$XDG_STATE_HOME` defaults to `~/.local/state`). Then, it will start
monitoring dbus for status updates to the system color scheme. If the color scheme changes (or there
was no prior state data), the new color scheme information will be written to `XDG_STATE_HOME` and
the monitor will invoke all scripts in `$XDG_DATA_HOME/color-scheme/scripts` (`$XDG_DATA_HOME`
defaults to `~/.local/share`), passing the latest color scheme info as arguments to each script.

Currently, the only color scheme info available is `variant`, which is a 32 bit unsigned integer (0
represents default / light mode and 1 represents dark mode on most systems). This is passed as
argument 1 in callback scripts, and stored in `$XDG_STATE_HOME/color-scheme/variant`.

### Example script

```shell
# Create the callback script dir if it doesn't exist
mkdir -p ~/.local/share/color-scheme/scripts
# Create a simple script that prints the color-scheme variant
cat <<'EOF' >~/.local/share/color-scheme/scripts/myscript.sh
#!/bin/sh
echo "Variant is $1"
EOF
# set execute permissions
chmod 744 ~/.local/share/color-scheme/scripts/myscript.sh
```

Now, once the color scheme has been changed, check the monitor output

```shell
systemctl --user status color-scheme-monitor.service
```

```text
May 18 14:04:10 myhost bash[454988]: Monitoring session dbus
May 18 14:04:18 myhost bash[454989]: System color scheme variant updated to 0
May 18 14:04:18 myhost bash[455106]: Invoking /home/myuser/.local/share/color-scheme/scripts/test.sh
May 18 14:04:18 myhost bash[455108]: Variant is 0
```

More examples can be found in the `example_scripts` dir.
