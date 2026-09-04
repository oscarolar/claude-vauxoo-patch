#!/bin/zsh
# Instalador idempotente del parche Vauxoo para Claude Code (VSCode).
# - Aplica el override CSS y los íconos Vakyro (apply.sh)
# - En macOS instala un LaunchAgent que re-aplica el parche cuando la
#   extensión se actualiza (WatchPaths sobre ~/.vscode/extensions)
# Uso:  ./install.sh        (correr de nuevo tras un git pull es seguro)
set -euo pipefail

DIR="${0:a:h}"
LABEL="com.oscarolar.claude-session-panel-patch"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

chmod +x "$DIR/apply.sh"

if [ "$(uname)" = "Darwin" ]; then
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/zsh</string>
		<string>$DIR/apply.sh</string>
	</array>
	<key>WatchPaths</key>
	<array>
		<string>$HOME/.vscode/extensions</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>ThrottleInterval</key>
	<integer>30</integer>
	<key>StandardOutPath</key>
	<string>$DIR/apply.log</string>
	<key>StandardErrorPath</key>
	<string>$DIR/apply.log</string>
</dict>
</plist>
PLISTEOF
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "hook launchd instalado: $LABEL"
else
  echo "AVISO: no es macOS; instala un watcher equivalente (systemd user path unit) que ejecute $DIR/apply.sh"
fi

# Themes de Warp (con Vakyro de fondo) si Warp está instalado
if [ -d "$HOME/.warp" ] && [ -d "$DIR/warp" ]; then
  mkdir -p "$HOME/.warp/themes"
  cp "$DIR"/warp/*.yaml "$DIR"/warp/*.png "$HOME/.warp/themes/" 2>/dev/null || true
  echo "themes de Warp (con Vakyro) instalados en ~/.warp/themes"
fi

# CLI vakyro (animación ANSI) al PATH si hay un bin escribible
if [ -f "$DIR/bin/vakyro" ]; then
  chmod +x "$DIR/bin/vakyro"
  for B in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
    if [ -d "$B" ] && [ -w "$B" ]; then
      ln -sf "$DIR/bin/vakyro" "$B/vakyro"
      echo "comando 'vakyro' enlazado en $B"
      break
    fi
  done
fi

"$DIR/apply.sh"
