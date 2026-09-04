#!/bin/zsh
# Aplica (o quita) el override CSS del panel de sesiones de Claude Code en VSCode
# y los íconos Vakyro (mascota Vauxoo) sobre los de Claude.
# Uso:  ./apply.sh          -> aplica/actualiza parche CSS + íconos
#       ./apply.sh --remove -> restaura CSS e íconos originales Y desinstala el hook
# Idempotente: si todo está al día no reescribe nada (importante porque el
# LaunchAgent com.oscarolar.claude-session-panel-patch vigila ~/.vscode/extensions
# y ejecuta este script en cada cambio).
set -euo pipefail

PATCH_DIR="${0:a:h}"
OVERRIDE="$PATCH_DIR/override.css"
MODE="${1:-apply}"
LABEL="com.oscarolar.claude-session-panel-patch"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] apply.sh $MODE"

found=0
for f in "$HOME"/.vscode/extensions/anthropic.claude-code-*/webview/index.css(N); do
  found=1
  python3 - "$f" "$MODE" "$OVERRIDE" <<'PY'
import sys, re
target, mode, override = sys.argv[1], sys.argv[2], sys.argv[3]
START = "/*! CC-SESSION-PANEL-PATCH START */"
END = "/*! CC-SESSION-PANEL-PATCH END */"
css = open(target).read()
block = START + "\n" + open(override).read().rstrip("\n") + "\n" + END + "\n"
if mode != "--remove" and css.endswith("\n" + block) and css.count(START) == 1:
    print("al día:    " + target)
    sys.exit(0)
css = re.sub(re.escape(START) + r".*?" + re.escape(END) + r"\n?", "", css, flags=re.S).rstrip("\n") + "\n"
if mode != "--remove":
    css += "\n" + block
open(target, "w").write(css)
print(("parcheado: " if mode != "--remove" else "removido:  ") + target)
PY

  # Themes Monaco de los code snippets → paleta Vauxoo (con respaldo .orig).
  # Los colores de vs/vs-dark son literales hex en index.js; se reescribe
  # SIEMPRE desde el .orig, así es idempotente y --remove solo restaura.
  IJS="${f%.css}.js"
  if [ "$MODE" != "--remove" ]; then
    [ -f "$IJS.orig" ] || cp "$IJS" "$IJS.orig"
    python3 - "$IJS" <<'PY'
import sys
target = sys.argv[1]
js = open(target + ".orig").read()
DARK = {  # Monaco vs-dark -> Vauxoo Dark
 "D4D4D4":"D6DAE0", "1E1E1E":"282C2F", "569CD6":"E11E4D", "C586C0":"9B7BC8",
 "CE9178":"82BCCE", "608B4E":"7A8288", "B5CEA8":"E9BE44", "3DC9B0":"E4A900",
 "9CDCFE":"DCEFFE", "74B0DF":"D6DAE0", "DCDCDC":"95999F", "f44747":"E11E4D",
 "B46695":"9B7BC8",
}
LIGHT = {  # Monaco vs (light) -> Vauxoo Light
 "0000FF":"AC0340", "AF00DB":"67498E", "A31515":"3D7A99", "008000":"95999F",
 "098658":"9E7000", "008080":"B77800", "800000":"AC0340", "0451A5":"3D7A99",
 "001188":"455A64", "dd0000":"AC0340", "cd3131":"AC0340", "863B00":"B77800",
}
total = 0
for a, b in {**DARK, **LIGHT}.items():
    for qa, qb in ((f'"{a}"', f'"{b}"'), (f'"#{a}"', f'"#{b}"')):
        n = js.count(qa)
        if n:
            js = js.replace(qa, qb)
            total += n
open(target, "w").write(js)
print(f"monaco:    {target} ({total} colores reemplazados)")
PY
  elif [ -f "$IJS.orig" ]; then
    mv "$IJS.orig" "$IJS"
    echo "monaco restaurado: $IJS"
  fi

  # Íconos Vakyro sobre los recursos de la extensión (con respaldo .orig)
  RES="${f%/webview/index.css}/resources"
  if [ "$MODE" != "--remove" ]; then
    for pair in \
      "vakyro-mask.svg:claude-logo.svg" \
      "vakyro-pending.svg:claude-logo-pending.svg" \
      "vakyro-done.svg:claude-logo-done.svg" \
      "vakyro.svg:clawd.svg" \
      "vakyro-256.png:claude-logo.png"; do
      srcf="$PATCH_DIR/icons/${pair%%:*}"
      dst="$RES/${pair##*:}"
      [ -f "$srcf" ] && [ -f "$dst" ] || continue
      [ -f "$dst.orig" ] || cp "$dst" "$dst.orig"
      cmp -s "$srcf" "$dst" || { cp "$srcf" "$dst"; echo "icono:     $dst"; }
    done
  else
    for bak in "$RES"/*.orig(N); do
      mv "$bak" "${bak%.orig}"
      echo "icono restaurado: ${bak%.orig}"
    done
  fi
done

if [ "$found" -eq 0 ]; then
  echo "No se encontró ninguna extensión anthropic.claude-code en ~/.vscode/extensions" >&2
  exit 1
fi

if [ "$MODE" = "--remove" ] && [ -f "$PLIST" ]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "hook launchd desinstalado ($LABEL)"
fi

echo "Listo. Recarga VSCode (Cmd+Shift+P → 'Developer: Reload Window') para ver el cambio."
