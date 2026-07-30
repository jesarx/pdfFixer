# pdfFixer — `cleanpdf.sh`

Limpia, endereza, comprime y hace OCR a PDFs escaneados de libros, dejándolos
ligeros, derechos, con todas las páginas del mismo tamaño, sin metadatos y con
texto **buscable y seleccionable**.

Pensado para escaneos de libros (con portada y contraportada a color e interior
en blanco y negro), pero funciona con cualquier PDF escaneado. También sirve
como simple **compresor/uniformador** para PDFs que ya están armados: ver
[Recetas](#recetas).

---

## ¿Qué hace?

Con cada **página del interior**, en orden:

1. **Detecta la resolución nativa** del escaneo y trabaja a esa resolución (ni más, ni menos).
2. **Limpia los bordes:** borra los cantos negros del escáner (la franja oscura del borde del libro, la sombra del lomo, la línea del canto).
3. **Endereza la página** midiendo la inclinación real de los renglones de texto (perfil de proyección), no del marco de la imagen. Precisión medida: **±0.05°**.
4. **Realza los bordes del texto** y **binariza** con el algoritmo de Sauvola (umbral local, resiste iluminación despareja).
5. **Comprime** como TIFF G4 / JBIG2.

Con el **documento completo**:

6. Mantiene **portada y contraportada a color**, moviendo la contraportada al final (desactivable con `-k`).
7. Añade una capa de **OCR con Tesseract**, detectando el idioma automáticamente (desactivable con `-N`).
8. **Unifica el tamaño** de todas las páginas y **borra todos los metadatos**.

El resultado es un PDF mucho más ligero, con las páginas derechas, limpias y
todas del mismo tamaño, sin metadatos y con texto real por debajo de la imagen
(se puede buscar y copiar).

> 🔒 **Metadatos:** la salida **siempre** queda sin título, autor, asunto,
> palabras clave, productor, creador, fechas ni XMP — ni del original ni de las
> herramientas que intervienen. No hace falta ninguna opción y no se puede
> desactivar.

---

## Instalación

### Dependencias (Arch Linux)

```bash
sudo pacman -S poppler imagemagick img2pdf ocrmypdf tesseract \
               tesseract-data-spa tesseract-data-eng \
               python-scikit-image python-scipy python-pillow \
               python-numpy python-pikepdf pngquant
```

(`python-pikepdf` se usa para borrar los metadatos; normalmente ya viene
instalado porque `ocrmypdf` depende de él.)

Opcional pero **muy recomendado** (reduce ~50 % más el peso final activando JBIG2):

```bash
yay -S jbig2enc     # desde el AUR
```

### En otras distros

Los programas son los mismos, sólo cambian los nombres de los paquetes. Necesitas
que estén en el `PATH`:

- `pdftoppm`, `pdfinfo`, `pdfimages` (del paquete **poppler / poppler-utils**)
- `img2pdf`
- `ocrmypdf`
- `tesseract` (+ los datos de idioma que uses)
- `magick` o `convert` (**ImageMagick** 7 o 6)
- `python3` con los módulos **scikit-image, scipy, pillow, numpy, pikepdf**
- `jbig2` (**jbig2enc**), opcional

El script comprueba las dependencias al arrancar y te dice exactamente qué falta.

### Poner el script a mano

```bash
chmod +x cleanpdf.sh
./cleanpdf.sh -h        # muestra la ayuda incrustada
```

Si lo quieres disponible desde cualquier carpeta:

```bash
cp cleanpdf.sh ~/.local/bin/cleanpdf   # o /usr/local/bin
```

---

## Uso

```
cleanpdf.sh entrada.pdf [opciones]
```

Las opciones pueden ir **antes o después** del nombre del archivo.

### Ejemplos rápidos

```bash
./cleanpdf.sh alls.pdf                    # todo automático
./cleanpdf.sh alls.pdf -o 45.pdf -s 0.50  # salida con nombre y trazo más fino
./cleanpdf.sh alls.pdf -G -d 250          # modo gris, máxima nitidez
./cleanpdf.sh alls.pdf -l spa+fra         # español con citas en francés
./cleanpdf.sh alls.pdf -D -B              # sin tocar la geometría
./cleanpdf.sh alls.pdf -k                 # respetar el orden original
./cleanpdf.sh alls.pdf -N                 # sin OCR
```

> ⚠️ **El archivo de salida SIEMPRE va precedido de `-o`.**
>
> ```bash
> ./cleanpdf.sh alls.pdf 45.pdf -s 0.50      # ✗ MAL (45.pdf se ignora)
> ./cleanpdf.sh alls.pdf -o 45.pdf -s 0.50   # ✓ BIEN
> ```
>
> Desde la v4 el script avisa con un error en vez de ignorar el argumento suelto en silencio.

---

## Recetas

### PDF ya armado: sólo unificar tamaño de página y bajar peso

Si el documento **ya está ordenado y procesado** y lo único que necesitas es que
todas las hojas midan lo mismo y que pese menos, desactiva todo lo demás:

```bash
./cleanpdf.sh doc.pdf -c 0 -N -D -B
```

| Opción | Qué desactiva |
|--------|---------------|
| `-c 0` | No separa portadas: trata todas las páginas por igual |
| `-N` | No hace OCR |
| `-D` | No endereza |
| `-B` | No limpia bordes |

Lo que **sí** sigue haciendo: unifica el tamaño de todas las páginas, binariza
y comprime el interior, y deja el PDF **sin metadatos**.

Si el documento ya trae una capa de texto que quieres conservar, usa `-N`: sin
OCR el script no la toca.

### Conservar el orden original de las páginas

Por defecto la contraportada se mueve al final. Con `-k` se respeta el orden tal
cual venía en el escaneo:

```bash
./cleanpdf.sh alls.pdf -k
```

---

## Opciones

| Opción | Descripción | Default |
|--------|-------------|---------|
| `-o ARCHIVO` | Archivo de salida | `entrada_limpio.pdf` |
| `-c N` | Páginas a color al inicio (pág 1 = portada, 2..N = contraportada). `-c 0` procesa todo como interior | `2` |
| `-d DPI` | Resolución de trabajo | `auto` (nativa) |
| `-l IDIOMA` | Idioma(s) del OCR. Códigos de 3 letras unidos con `+`, el primero es el principal (p. ej. `spa`, `spa+fra`, `spa+lat`) | `auto` (detectar) |
| `-k` | Conservar orden original (**no** mover la contraportada al final) | mover al final |
| `-N` | **No hacer OCR.** Sólo limpia, unifica el tamaño y comprime | OCR activado |
| `-w N` | Ventana Sauvola en px | `auto` (DPI/6, impar) |
| `-s K` | Sensibilidad Sauvola (grosor del trazo) | `0.45` |
| `-u N` | Fuerza del realce previo (0 = desactivado) | `120` |
| `-a GRADOS` | Inclinación máxima a corregir | `4` |
| `-D` | Desactivar el enderezado | activado |
| `-B` | Desactivar la limpieza de bordes | activada |
| `-G` | **Modo gris:** interior en grises en vez de 1 bit (pesa ~7×) | 1 bit |
| `-q N` | Calidad JPEG del modo gris | `45` |
| `-h`, `--help` | Mostrar la ayuda incrustada | — |

---

## Guía de ajuste

### Si las páginas salen chuecas

El enderezado mide la inclinación de los **renglones de texto**, que es lo que
se nota al leer. Prueba ángulos entre `-MAX` y `+MAX` grados, proyecta los
píxeles de tinta y elige el ángulo que produce los picos más marcados (renglones
perfectamente horizontales).

- `-a 8` — súbelo si tus páginas vienen **muy** torcidas (default 4°). Subirlo de más lo hace más lento y puede confundirse en páginas casi vacías.
- `-D` — desactívalo si tu escáner ya endereza o si el resultado empeora.

> **Importante:** el enderezado depende de la limpieza de bordes. Una franja
> negra del canto pesa muchísimo en la medición y arruina el cálculo del ángulo.
> Por eso la limpieza corre **antes**. Si desactivas la limpieza (`-B`) en un
> escaneo con cantos sucios, el enderezado va a fallar.

### Si quedan manchas o franjas negras en los bordes

La limpieza borra manchas oscuras que (a) tocan o casi tocan el borde de la hoja
y (b) son grandes (más del 12 % del alto o del ancho). El doble criterio evita
comerse texto legítimo.

- `BORDE_FRAC` (editable en el script) — baja a `0.08` si quedan restos; sube a `0.20` si borra algo que querías conservar.
- `BORDE_TOL` — cuánto margen desde el borde cuenta como "pegado al borde" (2 % por defecto). Súbelo si las manchas están más adentro.
- `-B` — desactiva la limpieza por completo.

### Si el texto se ve poco nítido

1. Comprueba a qué resolución está escaneado: `pdfimages -list tu.pdf | head` (columna `x-ppi`). El script ya trabaja a esa resolución. Forzar `-d` **por encima** del nativo no añade nitidez, sólo interpola y engorda el archivo.
2. Realce previo (`-u`): `160` para escaneos borrosos, `60` si ya son nítidos.
3. Sensibilidad (`-s`): ajusta el grosor del trazo. El default es `0.45`.
   - grueso/embarrado → **sube** k (`-s 0.50`)
   - roto/incompleto → **baja** k (`-s 0.30`)
   - rango útil `0.15`–`0.50`.
4. Ventana (`-w`): default DPI/6. Súbela si hay manchas de fondo grandes; bájala si se pierde letra muy pequeña.
5. Si nada basta: **modo gris** (`-G`). El 1 bit nunca tendrá el suavizado del original.

| Modo | Peso aprox. | Libro de 80 págs |
|------|-------------|------------------|
| 1 bit (default) a 339 ppi | ~45 KB/pág | ≈ 3–4 MB |
| gris `-G -q 45` | ~300 KB/pág | ≈ 20–25 MB |
| gris `-G -d 250 -q 40` | ~255 KB/pág | más ligero |

---

## Idiomas para el OCR

> Si usas `-N` (sin OCR) esta sección no te aplica: el script no toca idiomas
> ni necesita tener instalado ningún paquete de Tesseract.

Los códigos son **ISO 639-2** (tres letras, no dos).

### Qué idiomas tengo instalados

```bash
tesseract --list-langs
```

(`osd` y `equ` que aparecen ahí **no** son idiomas: `osd` detecta la orientación
de la página y `equ` reconoce fórmulas matemáticas.)

### Cómo instalar más

```bash
pacman -Ss tesseract-data              # todos los disponibles en Arch
sudo pacman -S tesseract-data-fra      # instalar uno
sudo pacman -S tesseract-data-{fra,lat,por}   # varios de golpe
```

El paquete siempre se llama `tesseract-data-<código>`. Si alguno no está en los
repos, se puede bajar suelto:

```bash
sudo curl -L -o /usr/share/tessdata/<código>.traineddata \
  https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/<código>.traineddata
```

### Códigos más útiles

| Código | Idioma |
|--------|--------|
| `spa` | español ← el que casi siempre vas a usar |
| `spa_old` | español con ortografía anterior a ~1900 (útil en facsímiles y libros antiguos) |
| `eng` | inglés |
| `fra` | francés |
| `por` | portugués |
| `ita` | italiano |
| `deu` | alemán |
| `cat` | catalán |
| `glg` | gallego |
| `eus` | euskera |
| `lat` | latín ← citas en ediciones de ensayo |
| `grc` | griego antiguo (alfabeto griego, no el moderno) |
| `ell` | griego moderno |
| `nld` | neerlandés |
| `rus` | ruso |
| `ara` | árabe |
| `heb` | hebreo |
| `frm` | francés medio (s. XIV–XVI) |
| `enm` | inglés medio |
| `ita_old` | italiano antiguo |
| `frk` | Fraktur (letra gótica alemana) |

### Cómo combinarlos

Se unen con `+` y el **primero** es el idioma principal:

```bash
-l spa           # sólo español
-l spa+fra       # español con citas en francés
-l spa+lat       # español con citas en latín
-l spa+eng+fra   # tres idiomas (ya empieza a costar)
```

Cada idioma extra hace el OCR más lento y, si ese idioma **no** aparece de verdad
en el libro, **empeora** la precisión. Añade sólo los que realmente salen.

### Autodetección

Si no pasas `-l`, el script hace OCR de prueba sobre una página del centro del
libro con cada idioma de la lista `CANDIDATOS` y se queda con el de mayor
confianza. Sólo prueba idiomas **sueltos**, nunca combinaciones: si tu libro es
bilingüe, conviene pasar `-l` a mano.

Para que considere más idiomas, edita la lista dentro del script:

```bash
CANDIDATOS=(spa eng fra lat)
```

Los que no tengas instalados se saltan sin dar error.

---

## Parámetros editables

Al principio del script (sección **PARÁMETROS EDITABLES**) puedes cambiar los
valores por defecto sin tener que pasar opciones cada vez:

| Parámetro | Qué controla |
|-----------|--------------|
| `COVER_PAGES` | Páginas a color al inicio |
| `DPI` | Resolución (vacío = nativa) |
| `LANGS` | Idiomas del OCR (vacío = autodetectar) |
| `CANDIDATOS` | Idiomas sueltos que prueba la autodetección |
| `MOVER_CONTRA` | 1 = contraportada al final; 0 (`-k`) = orden original |
| `HACER_OCR` | 1 = añadir capa de texto; 0 (`-N`) = sin OCR |
| `DESKEW`, `DESKEW_MAX` | Enderezado y su ángulo máximo |
| `LIMPIAR_BORDES`, `BORDE_FRAC`, `BORDE_TOL` | Limpieza de cantos negros |
| `SAUVOLA_W`, `SAUVOLA_K`, `UNSHARP` | Binarización del interior |
| `MODO_GRIS`, `GRIS_QUALITY`, `GRIS_LO`, `GRIS_HI` | Modo gris |
| `COVER_MAX_H`, `COVER_QUALITY` | Portadas a color (alto máx. y calidad JPEG) |

---

## Cómo funciona por dentro

El script trabaja en un directorio temporal (`mktemp -d`, se borra solo al
terminar) y sigue estos pasos:

1. **Portadas a color** — `pdftoppm` renderiza las primeras `N` páginas, se reescalan y se comprimen en JPEG.
2. **Interior** — `pdftoppm -gray` renderiza el resto; un script de Python (incrustado) procesa **cada página en paralelo** (`xargs -P $(nproc)`): limpieza de bordes → enderezado → realce + binarizado Sauvola (o ajuste de niveles en modo gris).
3. **Detección de idioma** — si no se pasó `-l` (y el OCR está activo), OCR de prueba sobre una página central.
4. **Ensamblado** — `img2pdf` incrusta las imágenes **sin recomprimir**, reordenando la contraportada al final y fijando un **tamaño de página uniforme** para todo el documento (con `--nodate`, para no incrustar fechas).
5. **OCR + optimización** — `ocrmypdf` añade la capa de texto invisible y con `--optimize 3` recomprime (los TIFF G4 pasan a JBIG2 si `jbig2enc` está instalado; sin él baja a nivel 1). Con `-N` se sigue pasando por `ocrmypdf` porque es quien optimiza, pero con `--tesseract-timeout 0` para que no ejecute el OCR.
6. **Borrado de metadatos** — `pikepdf` elimina el diccionario `/Info`, el XMP del documento y los restos por página (`/Metadata`, `/PieceInfo`), y reescribe el archivo linearizado para que nada quede arrastrado en actualizaciones incrementales.

---

## Licencia

Este proyecto se distribuye bajo la **GNU General Public License v3.0**
(GPL-3.0). Ver el archivo [`LICENSE`](LICENSE) para el texto completo.

En resumen: puedes usar, estudiar, modificar y redistribuir el programa
libremente, siempre que las versiones modificadas que distribuyas se liberen
también bajo GPL-3.0 y conserven este aviso.

```
Copyright (C) 2026 jesarx

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
```
