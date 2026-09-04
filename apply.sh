#!/bin/zsh
# Aplica (o quita) el skin Vauxoo a la extensión de Claude Code en VSCode:
# CSS del webview, colores Monaco de los snippets, e íconos según el theme
# activo de VSCode (flavor "vauxoo" = isotipo con Vauxoo Dark/Light; flavor
# "vakyro" = mascota con el theme Vauxoo Vakyro o cualquier otro theme).
# Uso:  ./apply.sh          -> aplica/actualiza todo
#       ./apply.sh --remove -> restaura CSS, index.js e íconos originales y
#                              desinstala el hook de launchd
# Idempotente. El LaunchAgent lo corre al cambiar ~/.vscode/extensions o el
# settings.json de VSCode (cambio de theme => swap de íconos automático).
set -euo pipefail

PATCH_DIR="${0:a:h}"
OVERRIDE="$PATCH_DIR/override.css"
MODE="${1:-apply}"
LABEL="com.oscarolar.claude-session-panel-patch"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

# Flavor según el theme activo de VSCode
VSETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
THEME=$(grep -o '"workbench.colorTheme"[^,}]*' "$VSETTINGS" 2>/dev/null | head -1 || true)
FLAVOR="vakyro"
case "$THEME" in
  (*"Vauxoo Vakyro"*) FLAVOR="vakyro" ;;
  (*Vauxoo*)          FLAVOR="vauxoo" ;;
esac

echo "[$(date '+%Y-%m-%d %H:%M:%S')] apply.sh $MODE (flavor: $FLAVOR)"

found=0
for f in "$HOME"/.vscode/extensions/anthropic.claude-code-*/webview/index.css(N); do
  found=1
  python3 - "$f" "$MODE" "$OVERRIDE" "$FLAVOR" "$PATCH_DIR" <<'PY'
import sys
target, mode, override, flavor, patch_dir = sys.argv[1:6]
import re
START = "/*! CC-SESSION-PANEL-PATCH START */"
END = "/*! CC-SESSION-PANEL-PATCH END */"
css = open(target).read()
body = open(override).read().rstrip("\n")
if mode != "--remove" and flavor == "vauxoo":
    # el spark de headers usa el b64 de la mascota; con flavor vauxoo va el isotipo
    vak = open(f"{patch_dir}/icons/vakyro.b64").read().strip()
    iso = open(f"{patch_dir}/icons/isotipo.b64").read().strip()
    body = body.replace(
        "/* ══ Spark de Claude en headers del webview → Vakyro ══",
        "/* ══ Spark de Claude en headers del webview → isotipo (flavor vauxoo) ══",
    ).replace(vak, iso, 1)
    # vakyro.b64 completo aparece solo en la sección spark; el spinner usa los
    # b64 de los 4 estados y no se toca: la animación es siempre Vakyro.
block = START + "\n" + body + "\n" + END + "\n"
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

  # Íconos según flavor sobre los recursos de la extensión (respaldo .orig)
  RES="${f%/webview/index.css}/resources"
  if [ "$MODE" != "--remove" ]; then
    if [ "$FLAVOR" = "vauxoo" ]; then
      PAIRS=("isotipo-mask.svg:claude-logo.svg" \
             "isotipo-pending.svg:claude-logo-pending.svg" \
             "isotipo-done.svg:claude-logo-done.svg" \
             "isotipo.svg:clawd.svg" \
             "isotipo-256.png:claude-logo.png")
    else
      PAIRS=("vakyro-mask.svg:claude-logo.svg" \
             "vakyro-pending.svg:claude-logo-pending.svg" \
             "vakyro-done.svg:claude-logo-done.svg" \
             "vakyro.svg:clawd.svg" \
             "vakyro-256.png:claude-logo.png")
    fi
    for pair in "${PAIRS[@]}"; do
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

echo "Listo. Recarga la ventana; para cambios de íconos reinicia VSCode (Cmd+Q)."
