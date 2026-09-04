# Instrucciones para agentes (Claude Code y similares)

Este repo parcha la extensión `anthropic.claude-code` de VSCode. Léelo completo
antes de tocar nada. Regla de oro: **nunca edites `webview/index.js`** — todo
se logra anexando CSS y reemplazando archivos de `resources/`.

## Anatomía

- `override.css` — todo el CSS del parche. `apply.sh` lo anexa al final de
  `~/.vscode/extensions/anthropic.claude-code-*/webview/index.css` entre los
  marcadores `/*! CC-SESSION-PANEL-PATCH START */` y `END`. Al ir al final
  del archivo gana la cascada sin necesidad de `!important` (salvo contra
  estilos inline o animaciones propias del elemento).
- `apply.sh` — idempotente. Sin argumentos aplica CSS + íconos; `--remove`
  restaura todo (incluye `.orig` de íconos) y desinstala el LaunchAgent.
- `install.sh` — genera el LaunchAgent con rutas absolutas de esta máquina y
  corre `apply.sh`. Seguro de re-correr.
- `icons/` — Vakyro limpio (`vakyro.svg`, derivado del oficial quitando los
  paths con `stroke="#201611"`), variantes monocromas para máscara alfa
  (`-mask`, `-pending`, `-done`), los 4 estados del spinner
  (`-think`, `-write`, `-read`, `-work`) y sus `.b64` (base64 del SVG, es lo
  que va embebido en `override.css` como `data:image/svg+xml;base64,`).

## Hechos del DOM/CSS de la extensión (verificados en 2.1.259–2.1.260)

- Los selectores usan `[class*="prefijo_"]` porque las clases son CSS-modules
  con hash (`sessionItem_OOQiHg`). Los prefijos son estables; el hash no.
- El panel de sesiones: grupos SIN contenedor — `groupHeader_*` y
  `sessionItem_*` son hermanos planos dentro de `sessionsList_*`.
- El indicador "pensando" ("Stewing…") es `icon_hc5dvw`: un span cuyo carácter
  (`· ✢ * ✶ ✻ ✽`) rota por JS. NO es `pendingGlyph_*` (ese es del panel
  "Answering…"). Hay un selector estructural de respaldo:
  `[class*="container_"] > span[class*="icon_"][aria-hidden="true"][style*="font-size"]`.
- Colores de marca Claude: variables en `html{}` del index.css
  (`--app-claude-orange` etc.). Tres usos tienen el hex literal `#d97757`
  (checkbox\_, suggestionBullet\_) y se pisan aparte.
- El webview recibe TODAS las variables `--vscode-*` del theme activo: la
  paleta del parche (`--vxspp-*` en `:root`) hereda de ellas con fallback
  Vauxoo. Si cambias un rol, mantén el patrón
  `var(--vscode-<token>, <hexVauxoo>)` para que Dark/Light/Vakyro (y
  cualquier theme) lo pinten solos.
- El CSP del webview permite `img-src data:` — los data-URIs funcionan.
- Los sparks de headers son SVG inline: se ocultan sus `path` y se pinta
  Vakyro como `background-image` del propio `<svg>`.
- Íconos de activity bar/pestañas: archivos `resources/claude-logo*.svg`
  (VSCode los usa como máscara alfa monocroma — no admiten animación ni color).
- `background-image` no interpola en keyframes: los ciclos usan pares de
  porcentajes (`0%, 24.99%`) para sostener cada cuadro.

## Si un update rompe algo

1. Corre `./apply.sh`; si dice "al día"/"parcheado" el CSS está. El problema
   será entonces un selector muerto.
2. Busca el prefijo en el CSS nuevo:
   `grep -o 'icon_[A-Za-z0-9]*' .../webview/index.css | sort -u`.
   Si el hash cambió (p.ej. `icon_hc5dvw` → `icon_xxxxx`), actualiza el
   selector exacto en `override.css`; el selector estructural suele aguantar.
3. Verifica prefijos del panel: `sessionItem_`, `groupHeader_`, `statusDot*_`,
   `sessionsList_`, `active_`, `selected_`, `checkbox_`, `suggestionBullet_`,
   `spark_`, `sparkIcon_`.
4. Re-aplica, pide Reload Window, y haz commit del fix con tag `[FIX]`.

## Regenerar iconografía de Vakyro

Los `.b64` se generan con `base64 < icons/vakyro-X.svg` (sin saltos). Si
editas un SVG, regenera su `.b64` y re-incrusta el data-URI en la sección
correspondiente de `override.css` (búscalo por el nombre del estado). Los 4
estados del spinner son el `vakyro.svg` base + un overlay dibujado antes de
`</svg>` (foco/lápiz/libro/laptop) con contorno `#1C1B19` grosor 8, estilo
flat de marca.

## Warp y el CLI vakyro

- `warp/*.yaml` son los themes de Warp (paleta ANSI por variante) con
  `background_image` apuntando a `warp/*-bg.png` (Vakyro en la esquina
  inferior derecha, opacidad horneada en el PNG). Warp NO soporta animación
  en themes — no intentes meterla ahí.
- `bin/vakyro` reproduce la animación en ANSI truecolor leyendo
  `bin/frames.json`. Para regenerar frames (p.ej. tras editar un SVG):
  renderiza cada `icons/vakyro-<estado>.svg` sobre un rect croma `#FF00FF`
  a 176×176 con Chrome headless, convierte a BMP con `sips`, y muestrea 1 de
  cada 4 px (SIN resample, para no mezclar el croma) emitiendo half-blocks
  `▀`/`▄`; un pixel es "transparente" si es magenta-ish
  (r>100, b>100, g<150, r-g>40, b-g>40 — calibrado para no comerse los
  morados #6F5198/#7A5FA0 ni el rosa #F3C5D9 del personaje).

## Política de marca

Vakyro es **internal-only**: sus SVG no deben salir de este repo privado ni
publicarse en el theme del Marketplace. El theme público
(github.com/Vauxoo/vauxoo-theme) lleva solo colores.
