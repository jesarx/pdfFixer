#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 jesarx
# Este programa es software libre bajo la GNU GPL v3 o posterior.
# Ver el archivo LICENSE para el texto completo.
#
# ============================================================================
#  cleanpdf.sh — Limpia, endereza, comprime y hace OCR a PDFs escaneados
#  v5
# ============================================================================
#
#  Qué hace, en orden, con cada página del interior:
#    1. Detecta la resolución NATIVA del escaneo y trabaja a esa resolución.
#    2. LIMPIA LOS BORDES: borra los cantos negros del escáner (la franja
#       oscura del borde del libro, la sombra del lomo, la línea del canto).
#    3. ENDEREZA la página midiendo la inclinación real de los renglones
#       (perfil de proyección), no del marco de la imagen.
#    4. Realza los bordes del texto y binariza con el algoritmo de Sauvola.
#    5. Comprime como TIFF G4 / JBIG2.
#  Y con el documento completo:
#    6. Portada y contraportada a color (ver "DÓNDE ESTÁN LAS PORTADAS").
#    7. OCR con tesseract, detectando el idioma automáticamente.
#    8. UNIFICA EL TAMAÑO de todas las páginas y BORRA TODOS LOS METADATOS.
#
#  DÓNDE ESTÁN LAS PORTADAS: hay dos formas típicas de escanear un libro y el
#  script cubre las dos. Elige según cómo esté TU pdf:
#
#    (a) Portada y contraportada JUNTAS AL INICIO  → default, opción -c
#        [portada] [contraportada] [interior...]
#        Es lo que sale al escanear la cubierta completa de una pasada.
#        El script las separa y manda la contraportada al final.
#            ./cleanpdf.sh libro.pdf          (equivale a -c 2)
#
#    (b) Portada 1ª página y contraportada ÚLTIMA  → opción -e
#        [portada] [interior...] [contraportada]
#        Ya están en su sitio: se dejan a color donde están y no se mueve
#        nada. El interior es todo lo de en medio.
#            ./cleanpdf.sh libro.pdf -e
#
#  USO:
#    cleanpdf.sh entrada.pdf [opciones]
#    (las opciones pueden ir antes o después del archivo)
#
#      -o ARCHIVO  Salida                     (default: entrada_limpio.pdf)
#      -c N        Páginas a color al inicio  (default: 2)
#                  Se asume: pág 1 = portada, págs 2..N = contraportada(s)
#                  Con -c 0 se procesa TODO como interior.
#      -d DPI      Resolución de trabajo      (default: auto = nativa)
#      -l IDIOMA   Idioma(s) del OCR. Códigos de 3 letras unidos con "+",
#                  el primero es el principal:  spa  /  spa+fra  /  spa+lat
#                  (default: autodetectar. Lista completa de códigos abajo)
#      -e          EXTREMOS: portada = 1ª página, contraportada = ÚLTIMA
#                  página, las dos ya en su sitio. Se dejan a color tal cual
#                  y no se reordena nada. Implica -c 1 salvo que pases -c.
#      -k          Conservar orden original (NO mover contraportada al final)
#      -N          NO hacer OCR (sólo limpiar, unificar tamaño y comprimir)
#      -w N        Ventana Sauvola en px      (default: auto = DPI/6, impar)
#      -s K        Sensibilidad Sauvola       (default: 0.45)
#      -u N        Fuerza del realce previo   (default: 120; 0 = desactivado)
#      -a GRADOS   Inclinación máx. a corregir (default: 4)
#      -D          Desactivar el enderezado
#      -B          Desactivar la limpieza de bordes
#      -G          MODO GRIS: interior en grises en vez de 1 bit (pesa ~7x)
#      -q N        Calidad JPEG del modo gris (default: 45)
#
#  EJEMPLOS:
#      ./cleanpdf.sh alls.pdf
#      ./cleanpdf.sh alls.pdf -o 45.pdf -s 0.45
#      ./cleanpdf.sh alls.pdf -G -d 250        # máxima nitidez
#      ./cleanpdf.sh alls.pdf -l spa+fra       # español con citas en francés
#      ./cleanpdf.sh alls.pdf -D -B            # sin tocar geometría
#      ./cleanpdf.sh alls.pdf -k               # respetar el orden original
#      ./cleanpdf.sh alls.pdf -e               # portada 1ª y contraportada última
#      ./cleanpdf.sh alls.pdf -c 0 -N -D -B    # sólo unificar tamaño y comprimir
#
#  PDF YA ARMADO AL QUE SÓLO LE FALTA PESO Y TAMAÑO UNIFORME:
#  Si el documento ya está ordenado y no quieres que se le toque nada más,
#  desactiva todo lo demás:
#      ./cleanpdf.sh doc.pdf -c 0 -N -D -B
#        -c 0  no separa portadas: trata todas las páginas igual
#        -N    no hace OCR
#        -D    no endereza
#        -B    no limpia bordes
#  Lo que SÍ sigue haciendo: unifica el tamaño de todas las páginas,
#  comprime y deja el PDF sin metadatos.
#
#  METADATOS: la salida SIEMPRE queda sin metadatos (sin título, autor,
#  productor, fechas ni XMP). No hace falta ninguna opción y no se puede
#  desactivar.
#
#  ¡OJO CON LA SALIDA! El nombre del archivo de salida SIEMPRE va precedido
#  de -o. Esto está MAL y genera "alls_limpio.pdf" ignorando el resto:
#      ./cleanpdf.sh alls.pdf 45.pdf -s 0.45      # ✗
#  Lo correcto es:
#      ./cleanpdf.sh alls.pdf -o 45.pdf -s 0.45   # ✓
#  (desde la v4 el script avisa con un error en vez de ignorarlo en silencio)
#
#  DEPENDENCIAS (Arch):
#    sudo pacman -S poppler imagemagick img2pdf ocrmypdf tesseract \
#                   tesseract-data-spa tesseract-data-eng \
#                   python-scikit-image python-scipy python-pillow \
#                   python-numpy python-pikepdf pngquant
#    yay -S jbig2enc     # opcional pero MUY recomendado: activa JBIG2 y
#                        # reduce ~50% más el peso final
#
#    Para más idiomas de OCR (francés, latín, etc.) ver la sección
#    "IDIOMAS PARA EL OCR" más abajo.
#
# ============================================================================
#  GUÍA DE AJUSTE
# ============================================================================
#
#  ── SI LAS PÁGINAS SALEN CHUECAS ───────────────────────────────────────────
#  El enderezado mide la inclinación de los RENGLONES DE TEXTO, que es lo
#  que realmente se nota al leer (el marco de la hoja puede estar torcido y
#  el texto derecho, o al revés). Funciona así:
#    - se prueban ángulos entre -MAX y +MAX grados
#    - para cada uno se proyectan los píxeles de tinta sobre el eje vertical
#    - el ángulo correcto es el que produce los picos más marcados, porque
#      es cuando los renglones quedan perfectamente alineados en horizontal
#  Precisión medida en pruebas: ±0.05°.
#
#    -a 8   Súbelo si tus páginas vienen MUY torcidas (default 4°). Subirlo
#           de más hace el proceso más lento y puede confundirse en páginas
#           casi vacías.
#    -D     Desactívalo si tu escáner ya endereza o si el resultado empeora.
#
#  IMPORTANTE: el enderezado depende de la limpieza de bordes. Una franja
#  negra del canto del escáner pesa muchísimo en la medición y arruina el
#  cálculo del ángulo. Por eso la limpieza corre ANTES. Si desactivas la
#  limpieza (-B) en un escaneo con cantos sucios, el enderezado va a fallar.
#
#  ── SI QUEDAN MANCHAS O FRANJAS NEGRAS EN LOS BORDES ───────────────────────
#  La limpieza busca manchas oscuras que (a) tocan o casi tocan el borde de
#  la hoja y (b) son grandes: ocupan más del 12% del alto o del ancho. Las
#  borra dejando blanco. Ese doble criterio evita comerse texto legítimo:
#  medido en una página de texto denso, no modifica ni un píxel del cuerpo.
#    BORDE_FRAC   (abajo) Baja a 0.08 si quedan restos; sube a 0.20 si te
#                 está borrando algo que sí querías conservar.
#    BORDE_TOL    Cuánto margen desde el borde cuenta como "pegado al borde"
#                 (2% por defecto). Súbelo si las manchas están más adentro.
#    -B           Desactiva la limpieza por completo.
#
#  ── SI EL TEXTO SE VE POCO NÍTIDO ──────────────────────────────────────────
#  1) Comprueba a qué resolución está escaneado:  pdfimages -list tu.pdf|head
#     Mira la columna "x-ppi". El script ya trabaja a esa resolución sola y
#     NUNCA sube por encima. Forzar -d POR ENCIMA del nativo NO añade
#     nitidez, sólo interpola y engorda el archivo (puede multiplicarlo).
#  2) Realce previo (-u): 160 para escaneos borrosos, 60 si ya son nítidos.
#  3) Sensibilidad (-s): ajusta el GROSOR del trazo. Default 0.45.
#        grueso/embarrado → SUBE k (-s 0.50)
#        roto/incompleto  → BAJA k (-s 0.30)
#     Rango útil 0.15–0.50.
#  4) Ventana (-w): default DPI/6. Súbela si hay manchas de fondo grandes,
#     bájala si se pierde letra muy pequeña.
#  5) Si nada basta: MODO GRIS (-G). El 1 bit nunca tendrá el suavizado del
#     original. Costo medido en página de texto denso a 339 ppi:
#        1 bit (default) ~45 KB/pág  → libro de 80 págs ≈ 3-4 MB
#        gris -G -q 45  ~300 KB/pág  → libro de 80 págs ≈ 20-25 MB
#     Para bajarle peso: -G -d 250 -q 40 (~255 KB/pág).
#
#  ── IDIOMAS PARA EL OCR ────────────────────────────────────────────────────
#
#  QUÉ IDIOMAS TENGO INSTALADOS:
#      tesseract --list-langs
#  (osd y equ que aparecen ahí NO son idiomas: osd detecta la orientación de
#   la página y equ reconoce fórmulas matemáticas.)
#
#  QUÉ IDIOMAS PUEDO INSTALAR:
#      pacman -Ss tesseract-data              # todos los disponibles en Arch
#      pacman -Ss tesseract-data-fra          # buscar uno concreto
#      sudo pacman -S tesseract-data-fra      # instalarlo
#      sudo pacman -S tesseract-data-{fra,lat,por}   # varios de golpe
#  El paquete siempre se llama tesseract-data-<código>. Si alguno no está en
#  los repos, se puede bajar el archivo suelto:
#      sudo curl -L -o /usr/share/tessdata/<código>.traineddata \
#        https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/<código>.traineddata
#
#  CÓDIGOS MÁS ÚTILES (son ISO 639-2, tres letras, no dos):
#      spa       español               ← el que casi siempre vas a usar
#      spa_old   español con ortografía anterior a ~1900 (ss largas, "ç",
#                acentuación vieja). Útil en facsímiles y libros antiguos.
#      eng       inglés
#      fra       francés
#      por       portugués
#      ita       italiano
#      deu       alemán
#      cat       catalán
#      glg       gallego
#      eus       euskera
#      lat       latín                 ← citas en ediciones de ensayo
#      grc       griego antiguo        ← ojo: alfabeto griego, no el moderno
#      ell       griego moderno
#      nld       neerlandés
#      rus       ruso
#      ara       árabe
#      heb       hebreo
#      frm       francés medio (s. XIV-XVI)
#      enm       inglés medio
#      ita_old   italiano antiguo
#      frk       Fraktur (letra gótica alemana)
#
#  CÓMO COMBINARLOS:
#  Se unen con "+" y el PRIMERO es el idioma principal:
#      -l spa           sólo español
#      -l spa+fra       español con citas en francés  ← tu caso en La razón
#      -l spa+lat       español con citas en latín
#      -l spa+eng+fra   tres idiomas (ya empieza a costar)
#  Cada idioma extra hace el OCR más lento y, si ese idioma NO aparece de
#  verdad en el libro, EMPEORA la precisión (tesseract empieza a proponer
#  palabras de un idioma que no está ahí). Añade sólo los que realmente salen.
#
#  AUTODETECCIÓN:
#  Si no pasas -l, el script hace OCR de prueba sobre una página del centro
#  del libro con cada idioma de la lista CANDIDATOS (abajo, en los parámetros)
#  y se queda con el de mayor confianza. Sólo prueba idiomas SUELTOS, nunca
#  combinaciones: si tu libro es bilingüe, la autodetección va a elegir uno
#  solo y conviene que pases -l a mano.
#  Para que considere más idiomas, edita la lista:
#      CANDIDATOS=(spa eng fra lat)
#  Los que no tengas instalados se saltan sin dar error, así que no pasa nada
#  por dejar en la lista alguno que aún no bajaste.
#
#  ── OTROS ──────────────────────────────────────────────────────────────────
#  Portadas pesadas o feas → COVER_MAX_H y COVER_QUALITY (abajo).
#
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# PARÁMETROS EDITABLES
# ----------------------------------------------------------------------------

COVER_PAGES=2        # Páginas a color al inicio (1=portada, 2..N=contraportada)
DPI=""               # Vacío = detectar resolución nativa del escaneo
LANGS=""             # Vacío = autodetectar entre CANDIDATOS
CANDIDATOS=(spa eng) # Idiomas SUELTOS que se prueban en la autodetección.
                     # Añade los que uses seguido, p.ej. (spa eng fra lat).
                     # Los que no tengas instalados se saltan sin error.
                     # Ver "IDIOMAS PARA EL OCR" en la cabecera.
MOVER_CONTRA=1       # 1 = contraportada al final; 0 (-k) = orden original
HACER_OCR=1          # 1 = añadir capa de texto; 0 (-N) = sin OCR
EXTREMOS=0           # 1 (-e) = portada 1ª pág y contraportada ÚLTIMA pág, ya
                     # en su sitio: se dejan a color y NO se reordena nada.

# --- Geometría de la página ---
DESKEW=1             # 1 = enderezar renglones; 0 (-D) = no tocar
DESKEW_MAX=4         # Inclinación máxima a corregir, en grados
LIMPIAR_BORDES=1     # 1 = borrar cantos negros; 0 (-B) = no tocar
BORDE_FRAC=0.12      # Una mancha de borde se borra si ocupa >12% del alto
                     # o del ancho de la página. ↓ borra más, ↑ borra menos.
BORDE_TOL=0.02       # Margen (2%) dentro del cual una mancha cuenta como
                     # "pegada al borde".

# --- Binarización del interior ---
SAUVOLA_W=""         # Vacío = auto (DPI/6, redondeado a impar)
SAUVOLA_K=0.45       # ↑k = trazo fino, ↓k = trazo grueso
UNSHARP=120          # Realce de bordes previo (0 = desactivado)

# --- Modo gris (-G) ---
MODO_GRIS=0
GRIS_QUALITY=45      # Calidad JPEG del interior en modo gris
GRIS_LO=45           # Niveles: todo lo más claro que esto pasa a blanco.
GRIS_HI=88           # Si el fondo queda sucio, sube GRIS_LO.
                     # Si el texto se ve lavado, baja GRIS_HI.

# --- Portadas a color ---
COVER_MAX_H=1800     # Alto máximo en px (sólo reduce, nunca agranda)
COVER_QUALITY=70     # Calidad JPEG de las portadas (1-100)

# ----------------------------------------------------------------------------
# LECTURA DE ARGUMENTOS
# ----------------------------------------------------------------------------
# Parseo manual (en vez de getopts) para que las opciones puedan ir antes o
# después del nombre del archivo, y para poder AVISAR si sobra un argumento
# suelto en vez de ignorarlo en silencio.

INPUT=""
OUT=""
COVER_SET=0          # ¿el usuario pasó -c explícitamente? (ver -e más abajo)
while (( $# )); do
    case "$1" in
        -o) OUT="$2"; shift 2 ;;
        -c) COVER_PAGES="$2"; COVER_SET=1; shift 2 ;;
        -d) DPI="$2"; shift 2 ;;
        -l) LANGS="$2"; shift 2 ;;
        -w) SAUVOLA_W="$2"; shift 2 ;;
        -s) SAUVOLA_K="$2"; shift 2 ;;
        -u) UNSHARP="$2"; shift 2 ;;
        -a) DESKEW_MAX="$2"; shift 2 ;;
        -q) GRIS_QUALITY="$2"; shift 2 ;;
        -k) MOVER_CONTRA=0; shift ;;
        -N) HACER_OCR=0; shift ;;
        -e) EXTREMOS=1; shift ;;
        -D) DESKEW=0; shift ;;
        -B) LIMPIAR_BORDES=0; shift ;;
        -G) MODO_GRIS=1; shift ;;
        -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
        -*) echo "Opción desconocida: $1" >&2; exit 1 ;;
        *)
            if [[ -z "$INPUT" ]]; then
                INPUT="$1"; shift
            else
                echo "Error: argumento suelto '$1'." >&2
                echo "       ¿Querías decir '-o $1'? El archivo de salida va con -o." >&2
                exit 1
            fi
            ;;
    esac
done

[[ -n "$INPUT" ]] || { echo "Uso: $0 entrada.pdf [-o salida.pdf] [opciones]  ($0 -h para ayuda)" >&2; exit 1; }
[[ -f "$INPUT" ]] || { echo "No existe: $INPUT" >&2; exit 1; }
[[ -n "$OUT" ]] || OUT="${INPUT%.pdf}_limpio.pdf"

# Con -e la portada es la 1ª página y la contraportada la ÚLTIMA. En ese caso
# el default de 2 páginas de color al inicio no aplica: sólo la primera. Si el
# usuario pasó -c a mano se respeta lo que haya pedido.
if (( EXTREMOS )) && (( ! COVER_SET )); then
    COVER_PAGES=1
fi

# ----------------------------------------------------------------------------
# VERIFICACIÓN DE DEPENDENCIAS
# ----------------------------------------------------------------------------

# ImageMagick 7 usa `magick`; el 6 usa `convert`.
if command -v magick >/dev/null; then IM=magick; else IM=convert; fi

for dep in pdftoppm pdfinfo pdfimages img2pdf ocrmypdf tesseract python3 "$IM"; do
    command -v "$dep" >/dev/null || { echo "Falta dependencia: $dep" >&2; exit 1; }
done
python3 -c "import skimage, scipy, PIL, numpy" 2>/dev/null || {
    echo "Faltan módulos Python: python-scikit-image python-scipy python-pillow python-numpy" >&2
    exit 1
}
# pikepdf se usa para borrar los metadatos del PDF final. Viene instalado con
# ocrmypdf (es dependencia suya), así que normalmente ya está.
python3 -c "import pikepdf" 2>/dev/null || {
    echo "Falta el módulo Python pikepdf (se usa para borrar los metadatos)." >&2
    echo "  Instala con: sudo pacman -S python-pikepdf" >&2
    exit 1
}
JOBS=$(nproc)

# Si se pidieron idiomas con -l, comprobarlos AHORA y no después de haber
# procesado todo el libro (ocrmypdf falla al final y se pierde el trabajo).
if (( HACER_OCR )) && [[ -n "$LANGS" ]]; then
    INSTALADOS=$(tesseract --list-langs 2>/dev/null | tail -n +2)
    FALTAN=""
    for l in ${LANGS//+/ }; do
        grep -qx "$l" <<< "$INSTALADOS" || FALTAN+=" $l"
    done
    if [[ -n "$FALTAN" ]]; then
        echo "No tienes instalado(s) el/los idioma(s):$FALTAN" >&2
        echo "  Instalados: $(tr '\n' ' ' <<< "$INSTALADOS")" >&2
        for l in $FALTAN; do
            echo "  Instala con: sudo pacman -S tesseract-data-$l" >&2
        done
        exit 1
    fi
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

TOTAL=$(pdfinfo "$INPUT" | awk '/^Pages:/{print $2}')

# Última página del INTERIOR. Con -e la última página es la contraportada a
# color, así que el interior termina una antes.
if (( EXTREMOS )); then
    INT_FIN=$(( TOTAL - 1 ))
else
    INT_FIN=$TOTAL
fi

# El interior va de COVER_PAGES+1 a INT_FIN: tiene que quedar al menos una
# página. Si no, avisamos aquí en vez de fallar más adelante de mala manera.
if (( COVER_PAGES + 1 > INT_FIN )); then
    echo "Error: no queda ninguna página de interior que procesar." >&2
    echo "       El PDF tiene $TOTAL página(s), con -c $COVER_PAGES al inicio$( (( EXTREMOS )) && echo " y -e (última a color)")." >&2
    exit 1
fi

# ----------------------------------------------------------------------------
# DETECCIÓN DE LA RESOLUCIÓN NATIVA DEL ESCANEO
# ----------------------------------------------------------------------------
# `pdfimages -list` reporta el ppi real de cada imagen embebida (columna
# x-ppi). Tomamos la mediana. Trabajar ahí evita los dos errores opuestos:
#   - renderizar POR DEBAJO del nativo → se pierde detalle, letras "comidas"
#   - renderizar POR ENCIMA           → sólo interpola, engorda sin ganar nada

# OJO: NUNCA se sube por encima del nativo. Antes había un mínimo de 200 ppi
# que, en PDFs cuya resolución nativa es más baja, AMPLIABA las páginas: el
# archivo salía varias veces más pesado que el original sin ganar un solo
# detalle. Si el nativo es bajo y quieres más, pídelo a mano con -d.

if [[ -z "$DPI" ]]; then
    NATIVO=$(pdfimages -list "$INPUT" \
             | awk 'NR>2 && $13+0>0 {print $13}' | sort -n \
             | awk '{v[n++]=$1} END{print (n? v[int(n/2)] : 0)}')
    if (( NATIVO > 0 )); then
        DPI=$NATIVO
        (( DPI > 800 )) && DPI=800     # techo: por encima se dispara el peso
        echo ">> Resolución nativa detectada: ${DPI} ppi"
        if (( DPI < 150 )); then
            echo ">> (resolución nativa baja. Si el texto sale pobre, prueba -d 300," >&2
            echo ">>  pero el archivo pesará bastante más.)" >&2
        fi
    else
        DPI=300
        echo ">> No se pudo detectar la resolución nativa; usando ${DPI} ppi"
    fi
fi

# Ventana de Sauvola proporcional al DPI (≈ el alto de una línea). IMPAR.
if [[ -z "$SAUVOLA_W" ]]; then
    SAUVOLA_W=$(( DPI / 6 ))
    (( SAUVOLA_W % 2 == 0 )) && SAUVOLA_W=$(( SAUVOLA_W + 1 ))
fi

MODO=$( (( MODO_GRIS )) && echo "GRIS q=$GRIS_QUALITY" || echo "1bit w=$SAUVOLA_W k=$SAUVOLA_K u=$UNSHARP" )
COLOR_INFO="1-$COVER_PAGES"
(( COVER_PAGES == 0 )) && COLOR_INFO="ninguna"
(( EXTREMOS )) && COLOR_INFO="$COLOR_INFO + $TOTAL (última)"
echo ">> $TOTAL págs | color: $COLOR_INFO | interior: $((COVER_PAGES+1))-$INT_FIN | ${DPI} dpi | $MODO | deskew=$DESKEW bordes=$LIMPIAR_BORDES ocr=$HACER_OCR | $JOBS hilos"

# ----------------------------------------------------------------------------
# TAMAÑO DE PÁGINA DESTINO
# ----------------------------------------------------------------------------
# Se toma el tamaño (en puntos PDF) de la primera página interior como tamaño
# canónico. Las portadas se encajan centradas ahí (img2pdf --fit into).

read -r PW PH < <(pdfinfo -f $((COVER_PAGES+1)) -l $((COVER_PAGES+1)) "$INPUT" \
                  | awk '/^Page.*size:/{print $4, $6}')
echo ">> Tamaño de página destino: ${PW}x${PH} pts"

# ----------------------------------------------------------------------------
# PASO 1: PORTADAS A COLOR
# ----------------------------------------------------------------------------

# Reduce y comprime en JPEG todos los PNG de un prefijo dado.
# -strip quita de paso los metadatos de la imagen.
comprime_color() {
    local f
    for f in "$1"-*.png; do
        [[ -e "$f" ]] || continue
        $IM "$f" -resize "x${COVER_MAX_H}>" \
            -strip -interlace none -sampling-factor 4:2:0 \
            -quality "$COVER_QUALITY" "${f%.png}.jpg"
        rm "$f"
    done
}

# Con -c 0 se procesa todo el documento como interior (libro sin portadas
# a color, o PDF que ya viene recortado).
if (( COVER_PAGES > 0 )); then
    echo ">> Procesando portadas (color)..."
    pdftoppm -png -r "$DPI" -f 1 -l "$COVER_PAGES" "$INPUT" "$WORK/cov"
    comprime_color "$WORK/cov"
else
    echo ">> Sin portadas a color (-c 0)"
fi

# Con -e la ÚLTIMA página es la contraportada: se saca a color y se queda
# donde está, sin reordenar nada.
if (( EXTREMOS )); then
    echo ">> Procesando contraportada (última página, color)..."
    pdftoppm -png -r "$DPI" -f "$TOTAL" -l "$TOTAL" "$INPUT" "$WORK/contra"
    comprime_color "$WORK/contra"
fi

# ----------------------------------------------------------------------------
# PASO 2: INTERIOR (limpieza de bordes + deskew + binarizado/gris)
# ----------------------------------------------------------------------------

cat > "$WORK/procesa.py" <<'PYEOF'
"""Procesa UNA página del interior. Se invoca en paralelo, una vez por página."""
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import rotate as ndrotate
from skimage.filters import threshold_sauvola, threshold_otsu
from skimage.measure import label, regionprops


def limpiar_bordes(a, tol, frac):
    """Blanquea manchas oscuras GRANDES que tocan (o casi) el borde de la hoja.

    Son los cantos negros del escáner y la sombra del lomo. El doble criterio
    (pegada al borde + grande) evita borrar texto legítimo: una palabra que
    llegue al margen no supera el umbral de tamaño.
    """
    H, W = a.shape
    ty, tx = int(H * tol), int(W * tol)
    try:
        umbral = threshold_otsu(a)
    except ValueError:          # página en blanco
        return a
    etiquetas = label(a < umbral)
    salida = a.copy()
    for r in regionprops(etiquetas):
        minr, minc, maxr, maxc = r.bbox
        pegada = minr <= ty or minc <= tx or maxr >= H - ty or maxc >= W - tx
        if not pegada:
            continue
        if (maxr - minr) / H > frac or (maxc - minc) / W > frac:
            salida[etiquetas == r.label] = 255
    return salida


def angulo_deskew(a, maximo):
    """Inclinación de los RENGLONES, por varianza del perfil de proyección.

    Para cada ángulo candidato se rota la imagen y se suman los píxeles de
    tinta por fila. Cuando los renglones quedan horizontales, el perfil tiene
    picos muy marcados (líneas) y valles profundos (interlineado), así que su
    varianza es máxima. Búsqueda en dos pasadas: gruesa de 0.5° y fina de
    0.05°. Precisión medida: ±0.05°.
    """
    f = 800.0 / max(a.shape)
    if f < 1:
        chico = np.asarray(Image.fromarray(a).resize(
            (max(1, int(a.shape[1] * f)), max(1, int(a.shape[0] * f))), Image.BILINEAR))
    else:
        chico = a
    tinta = 255.0 - chico.astype(np.float32)
    tinta[tinta < 40] = 0            # ignora el fondo casi blanco
    if tinta.sum() < 1:              # página vacía: nada que enderezar
        return 0.0

    def puntaje(ang):
        r = ndrotate(tinta, ang, reshape=False, order=1, mode='constant', cval=0)
        return np.var(np.diff(r.sum(axis=1)))

    grueso = max(np.arange(-maximo, maximo + 1e-9, 0.5), key=puntaje)
    return float(max(np.arange(grueso - 0.5, grueso + 0.5 + 1e-9, 0.05), key=puntaje))


def main():
    (src, dst, modo, dpi, sw, sk, unsharp,
     hacer_deskew, deskew_max, hacer_bordes, borde_tol, borde_frac,
     gris_lo, gris_hi, gris_q) = sys.argv[1:16]

    a = np.asarray(Image.open(src).convert('L'))

    # 1) Cantos negros del escáner. VA PRIMERO: si no, su masa oscura
    #    desvía por completo el cálculo del ángulo de inclinación.
    if int(hacer_bordes):
        a = limpiar_bordes(a, float(borde_tol), float(borde_frac))

    # 2) Enderezado
    if int(hacer_deskew):
        ang = angulo_deskew(a, float(deskew_max))
        if abs(ang) > 0.05:          # por debajo de esto no vale la pena
            a = np.clip(ndrotate(a, ang, reshape=False, order=3,
                                 mode='constant', cval=255), 0, 255).astype(np.uint8)

    if modo == 'gris':
        # Ajuste de niveles: lleva el fondo a blanco puro (comprime mucho
        # mejor en JPEG) y oscurece el texto SIN destruir el suavizado.
        lo, hi = float(gris_lo) * 2.55, float(gris_hi) * 2.55
        x = (a.astype(np.float32) - lo) * (255.0 / max(hi - lo, 1))
        Image.fromarray(np.clip(x, 0, 255).astype(np.uint8)).save(
            dst, quality=int(gris_q), optimize=True)
    else:
        im = Image.fromarray(a)
        # Realce previo: radio 1 px afila el filo de cada letra sin engordar
        # el trazo, así el umbral cae más limpio.
        if int(unsharp) > 0:
            im = im.filter(ImageFilter.UnsharpMask(
                radius=1, percent=int(unsharp), threshold=2))
        arr = np.asarray(im)
        # Sauvola: umbral LOCAL por píxel (media y desviación de su ventana).
        # Mantiene trazos finos y fondo blanco aunque la iluminación del
        # escaneo sea despareja.
        th = threshold_sauvola(arr, window_size=int(sw), k=float(sk))
        Image.fromarray(arr > th).save(dst, compression='group4',
                                       dpi=(int(dpi), int(dpi)))


if __name__ == '__main__':
    main()
PYEOF

echo ">> Procesando interior..."
pdftoppm -gray -r "$DPI" -f $((COVER_PAGES+1)) -l "$INT_FIN" "$INPUT" "$WORK/pag"

if (( MODO_GRIS )); then MODO_PY=gris; EXT=jpg; else MODO_PY=bin; EXT=tif; fi

export WORK MODO_PY EXT DPI SAUVOLA_W SAUVOLA_K UNSHARP \
       DESKEW DESKEW_MAX LIMPIAR_BORDES BORDE_TOL BORDE_FRAC \
       GRIS_LO GRIS_HI GRIS_QUALITY

find "$WORK" -name 'pag-*.p*m' -print0 | xargs -0 -P "$JOBS" -I{} bash -c '
    f="{}"
    python3 "$WORK/procesa.py" "$f" "${f%.*}.$EXT" "$MODO_PY" "$DPI" \
        "$SAUVOLA_W" "$SAUVOLA_K" "$UNSHARP" \
        "$DESKEW" "$DESKEW_MAX" "$LIMPIAR_BORDES" "$BORDE_TOL" "$BORDE_FRAC" \
        "$GRIS_LO" "$GRIS_HI" "$GRIS_QUALITY"
    rm -f "$f"
'

# ----------------------------------------------------------------------------
# PASO 3: DETECCIÓN AUTOMÁTICA DE IDIOMA (si no se pasó -l)
# ----------------------------------------------------------------------------
# tesseract no detecta idioma solo. Truco práctico: se toma una página de en
# medio del libro (donde seguro hay texto corrido), se le hace OCR de prueba
# con cada candidato y gana el de mayor confianza media. Cuesta ~2 s.

if (( HACER_OCR )); then
    if [[ -z "$LANGS" ]]; then
        MUESTRA=$(find "$WORK" -name "pag-*.$EXT" | sort | awk '{l[NR]=$0} END{print l[int(NR/2)+1]}')
        best="" ; best_conf=0
        for l in "${CANDIDATOS[@]}"; do
            tesseract --list-langs 2>/dev/null | grep -qx "$l" || continue
            conf=$(tesseract "$MUESTRA" - -l "$l" tsv 2>/dev/null \
                   | awk -F'\t' '$12!="" && $11>=0 {s+=$11; n++} END{printf "%d", (n? s/n : 0)}')
            echo "   idioma $l: confianza media $conf"
            (( conf > best_conf )) && { best_conf=$conf; best="$l"; }
        done
        LANGS="${best:-spa}"
    fi
    echo ">> OCR con idioma: $LANGS"
else
    echo ">> OCR desactivado (-N)"
fi

# ----------------------------------------------------------------------------
# PASO 4: ENSAMBLADO CON REORDENAMIENTO DE LA CONTRAPORTADA
# ----------------------------------------------------------------------------
# Orden final (default): [portada] [interior] [contraportada(s)]
# Con -k se conserva el orden del escaneo original.
# img2pdf incrusta las imágenes SIN recomprimir y fija el mismo tamaño de
# página en pts para todo el documento.

mapfile -t COVS < <(ls "$WORK"/cov-*.jpg 2>/dev/null | sort)
mapfile -t CONTRAS < <(ls "$WORK"/contra-*.jpg 2>/dev/null | sort)
mapfile -t PAGS < <(ls "$WORK"/pag-*."$EXT" | sort)

if (( EXTREMOS )); then
    # La contraportada ya venía al final: se respeta el orden tal cual.
    echo ">> Ensamblando PDF (portada y contraportada en su sitio)..."
    ORDEN=( "${COVS[@]}" "${PAGS[@]}" "${CONTRAS[@]}" )
elif (( MOVER_CONTRA )) && (( ${#COVS[@]} > 1 )); then
    # Las contraportadas venían al inicio: se mandan al final.
    echo ">> Ensamblando PDF (contraportada al final)..."
    ORDEN=( "${COVS[0]}" "${PAGS[@]}" "${COVS[@]:1}" )
else
    echo ">> Ensamblando PDF (orden original)..."
    ORDEN=( "${COVS[@]}" "${PAGS[@]}" )
fi

# --nodate: no incrustar fechas de creación/modificación (parte de dejar el
# PDF sin metadatos; el resto se limpia al final con pikepdf).
img2pdf --pagesize "${PW}ptx${PH}pt" --fit into --nodate \
        "${ORDEN[@]}" -o "$WORK/ensamblado.pdf"

# ----------------------------------------------------------------------------
# PASO 5: OCR + OPTIMIZACIÓN FINAL
# ----------------------------------------------------------------------------
# ocrmypdf añade la capa de texto invisible (seleccionable y buscable) y con
# --optimize 3 recomprime: los TIFF G4 pasan a JBIG2 (si jbig2enc está
# instalado). Sin jbig2enc bajamos a nivel 1 para no perder tiempo.
#
# Con -N (sin OCR) se sigue pasando por ocrmypdf porque es quien hace la
# optimización, pero con --tesseract-timeout 0 no se ejecuta el OCR.

# --optimize 3 necesita jbig2enc (para el 1 bit) Y pngquant (para el color).
# Si falta cualquiera de los dos bajamos a 1: ocrmypdf abortaría al final,
# después de haber procesado el libro entero.
OPT=3
if ! command -v jbig2 >/dev/null; then
    OPT=1
    echo ">> (jbig2enc no instalado: instala 'jbig2enc' del AUR para ~45% menos de peso)"
elif ! command -v pngquant >/dev/null; then
    OPT=1
    echo ">> (pngquant no instalado: hace falta para --optimize 3." >&2
    echo ">>  Instala con: sudo pacman -S pngquant)" >&2
fi

OCR_ARGS=(--optimize "$OPT" --jobs "$JOBS" --output-type pdf)
if (( HACER_OCR )); then
    OCR_ARGS+=(-l "$LANGS")
else
    # --tesseract-timeout 0 desactiva el OCR conservando la optimización.
    # --skip-text evita que falle si alguna página ya traía texto.
    OCR_ARGS+=(--tesseract-timeout 0 --skip-text)
    # Aunque no se vaya a hacer OCR, ocrmypdf valida el idioma al arrancar y
    # por defecto pide "eng". Si no está instalado abortaría sin necesidad, así
    # que le pasamos el primero que haya disponible.
    SIN_OCR_L=$(tesseract --list-langs 2>/dev/null | tail -n +2 \
                | grep -vx -e osd -e equ | head -1)
    if [[ -n "$SIN_OCR_L" ]]; then
        OCR_ARGS+=(-l "$SIN_OCR_L")
    fi
fi

echo ">> Optimizando$( (( HACER_OCR )) && echo " y aplicando OCR")..."
ocrmypdf "${OCR_ARGS[@]}" "$WORK/ensamblado.pdf" "$WORK/final.pdf"

# ----------------------------------------------------------------------------
# PASO 6: BORRADO DE METADATOS
# ----------------------------------------------------------------------------
# ocrmypdf escribe su propia identificación (Producer, Creator, fechas) y
# arrastra el XMP del original. Esto deja el PDF completamente limpio.
# pikepdf viene instalado con ocrmypdf, así que no añade dependencias.

echo ">> Borrando metadatos..."
python3 - "$WORK/final.pdf" "$OUT" <<'PYEOF'
"""Elimina TODOS los metadatos del PDF: docinfo, XMP y restos por página."""
import sys
import pikepdf

origen, destino = sys.argv[1], sys.argv[2]

with pikepdf.open(origen) as pdf:
    # 1) Diccionario /Info: título, autor, asunto, palabras clave, productor,
    #    creador y fechas de creación/modificación. Se borra entero, no se
    #    deja vacío (leer pdf.docinfo lo recrearía, así que no se toca).
    if pikepdf.Name.Info in pdf.trailer:
        del pdf.trailer[pikepdf.Name.Info]

    # 2) XMP del documento (el que leen Acrobat, exiftool, etc.).
    if pikepdf.Name.Metadata in pdf.Root:
        del pdf.Root[pikepdf.Name.Metadata]

    # 3) Restos por página: XMP propio y /PieceInfo, donde algunas
    #    herramientas guardan datos privados de la aplicación.
    for pagina in pdf.pages:
        for clave in (pikepdf.Name.Metadata, pikepdf.Name.PieceInfo):
            if clave in pagina.obj:
                del pagina.obj[clave]

    # linearize=True reescribe el archivo entero, así nada queda arrastrado
    # en actualizaciones incrementales del PDF.
    pdf.save(destino, linearize=True)
PYEOF

# Comparación de peso. Si la salida creció, casi siempre es que el PDF de
# origen ya venía bien comprimido: avisamos en vez de dejarlo pasar callando.
BYTES_IN=$(stat -c%s "$INPUT")
BYTES_OUT=$(stat -c%s "$OUT")
echo ">> Listo: $OUT ($(du -h "$OUT" | cut -f1), origen $(du -h "$INPUT" | cut -f1))"
if (( BYTES_OUT > BYTES_IN )); then
    echo ">> AVISO: la salida pesa más que el original ($(( 100 * BYTES_OUT / BYTES_IN ))%)."
    echo ">>   El PDF de origen ya venía bien comprimido. Cosas que ayudan:"
    echo ">>     - instalar jbig2enc (del AUR): suele quitar ~50% del interior"
    (( MODO_GRIS )) && echo ">>     - quitar -G: el modo gris pesa ~7x más que 1 bit"
    echo ">>     - bajar la resolución con -d (p.ej. -d 200)"
    echo ">>   Si el original ya te servía, quizá este PDF no necesitaba limpieza."
fi
