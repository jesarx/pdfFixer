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

6. Mantiene **portada y contraportada a color** (ver [¿Dónde están las portadas?](#dónde-están-las-portadas)).
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

## ¿Dónde están las portadas?

Hay dos formas típicas de escanear un libro y el script cubre las dos. **Elige
según cómo esté tu PDF**, porque es lo único que cambia entre un caso y otro.

### (a) Portada y contraportada juntas al inicio → default, opción `-c`

```
[portada] [contraportada] [interior ...]
```

Es lo que sale al escanear la cubierta completa de una pasada: las dos caras
quedan al principio. El script las separa y **manda la contraportada al final**.

```bash
./cleanpdf.sh libro.pdf          # equivale a -c 2
```

### (b) Portada 1ª página y contraportada última → opción `-e`

```
[portada] [interior ...] [contraportada]
```

Las cubiertas **ya están en su sitio**. Con `-e` el script las deja a color donde
están, **no mueve nada**, y procesa como interior todo lo de en medio.

```bash
./cleanpdf.sh libro.pdf -e
```

`-e` implica `-c 1` (sólo la primera página a color al inicio) salvo que pases
`-c` a mano. Si tu PDF tiene además una guarda a color después de la portada,
combínalos:

```bash
./cleanpdf.sh libro.pdf -e -c 2   # págs 1 y 2 a color + la última a color
```

Con `-e` la opción `-k` no hace nada, porque no hay ningún reordenamiento que
desactivar.

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
./cleanpdf.sh alls.pdf -e                 # portada 1ª y contraportada última
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

### PDF terminado al que sólo le falta que las hojas midan igual → `-U`

```bash
./cleanpdf.sh libro.pdf -U
```

Para un PDF que **ya está bien** (escaneado, limpio, comprimido y con OCR) y
cuyo único defecto es que las páginas tienen tamaños distintos. Es un camino
completamente aparte del resto del script:

| | |
|---|---|
| **Qué hace** | Reescribe el tamaño de cada página y encaja el contenido centrado |
| **Qué NO hace** | No rasteriza, no recomprime, no vuelve a hacer OCR |
| **Qué conserva** | Las imágenes **byte a byte**, la capa de texto del OCR, la calidad |
| **Peso** | Prácticamente idéntico al original |
| **Metadatos** | Se borran, igual que en el modo normal |

El **tamaño destino es el más frecuente** del documento, así que la mayoría de
páginas no se tocan y sólo se ajustan las que se salen (normalmente las
cubiertas). El script te enseña qué tamaños encontró y cuál eligió:

```
>> Tamaños encontrados: 2
>>   328.45 x 551.44 pts  (12 pág)  <- destino
>>   359.58 x 553.76 pts  (2 pág)
>> Páginas ajustadas: 2 de 14
```

**No hace falta rehacer el OCR.** La capa de texto vive dentro del contenido de
la página, así que se transforma junto con la imagen y sigue estando alineada y
seleccionable. Lo verificamos: mismo número de palabras antes y después, texto
idéntico, y las coordenadas del texto escaladas exactamente por el factor
esperado.

`-U` ignora las demás opciones de procesado (`-s`, `-D`, `-G`…), porque en este
modo no hay nada que procesar. Maneja correctamente páginas rotadas
(`/Rotate`) y PDFs recortados (`CropBox`).

> **¿Por qué no usar el modo normal para esto?** Porque rasteriza y comprime
> desde cero. Si el PDF ya venía bien comprimido —sobre todo si su interior ya
> era JBIG2— el resultado pesa **más** que el original. Medido: un interior de
> 3.8 KB/pág pasó a 31 KB/pág al reprocesarlo. Con `-U` se queda en 3.8 KB.

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

### Libro con portada 1ª y contraportada última, ya en su sitio

```bash
./cleanpdf.sh libro.pdf -e
```

La primera y la última página se quedan **a color y tal cual están**; todo lo de
en medio se limpia, endereza, binariza y comprime. No se reordena nada. Ver
[¿Dónde están las portadas?](#dónde-están-las-portadas).

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
| `-U` | **Uniformar y nada más:** iguala el tamaño de las páginas sin rasterizar ni recomprimir. Conserva imágenes y OCR. Ignora el resto de opciones | desactivado |
| `-e` | **Extremos:** portada = 1ª página y contraportada = **última**, ya en su sitio. Las deja a color y no reordena nada. Implica `-c 1` | desactivado |
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

### Si el PDF de salida pesa MÁS que el original

El peso de la salida **no depende del peso de la entrada**: lo fija la
resolución de trabajo. Si el original ya venía bien comprimido, es posible que
la salida acabe pesando más. Qué mirar, en orden:

1. **¿Se está ampliando la página?** Es la causa más habitual y la más cara.
   Compara las dimensiones en píxeles del original y de la salida:

   ```bash
   pdfimages -list original.pdf | head -4
   pdfimages -list salida.pdf   | head -4
   ```

   Si las de la salida son **mayores**, se está interpolando: más píxeles, cero
   detalle nuevo y un archivo mucho más pesado. El script ya no hace esto por
   su cuenta (nunca renderiza por encima de la resolución nativa), pero sí
   ocurre si fuerzas `-d` por encima del nativo. Quita el `-d` o bájalo.

2. **¿Tienes `jbig2enc`?** Sin él, el interior se queda en TIFF G4 en vez de
   JBIG2. El script lo avisa al correr. Es el factor más grande con diferencia:
   en un libro de prueba de 14 páginas a 340 ppi medimos **56.9 KB/pág con G4
   frente a 31.3 KB/pág con JBIG2** (−45 % en el interior, −41 % en el total).

   ```bash
   yay -S jbig2enc          # AUR
   ```

   Necesita además `pngquant`, porque activa `--optimize 3`. Si falta alguno de
   los dos, el script baja a `--optimize 1` y te lo dice.

3. **¿El original YA venía en JBIG2?** Míralo en la columna `enc`:

   ```bash
   pdfimages -list original.pdf | head -4
   ```

   Si dice `jbig2` con un tamaño por página minúsculo (cientos de bytes), ese
   PDF ya está comprimido con un diccionario de símbolos compartido entre
   páginas, que es prácticamente lo mejor que existe para texto en 1 bit.
   **Volver a procesarlo no puede igualar eso**: al rasterizar y re-binarizar,
   cada instancia de cada letra queda con píxeles ligeramente distintos, el
   diccionario de símbolos crece y el resultado pesa varias veces más — pasar
   por el script es, en compresión, un viaje de ida.

   Para estos PDFs el script no tiene nada que aportar salvo que necesites
   OCR o uniformar el tamaño de página. (`--jbig2-lossy` de ocrmypdf **no**
   ayuda aquí: lo medimos y no cambió nada.)

   👉 **Si sólo necesitabas que las hojas midieran igual, usa
   [`-U`](#pdf-terminado-al-que-sólo-le-falta-que-las-hojas-midan-igual---u):**
   iguala el tamaño sin tocar las imágenes, así que el peso no sube.

4. **¿Estás en modo gris?** `-G` pesa ~7× más que 1 bit. Quítalo, o baja la
   calidad con `-q`.

5. **La capa de OCR ocupa.** En un libro de 14 páginas medimos ~50 KB. Con `-N`
   te la ahorras, pero pierdes el texto buscable.

Desde v5 el script **compara los tamaños al terminar** y te avisa si la salida
creció, con estas mismas sugerencias.

> Si el original ya estaba limpio, derecho y comprimido, puede que sencillamente
> no necesitara pasar por aquí. Este script está pensado para escaneos crudos:
> en un escaneo sin procesar la reducción típica que medimos fue del **76 %**.

### Si el texto se ve poco nítido

1. Comprueba a qué resolución está escaneado: `pdfimages -list tu.pdf | head` (columna `x-ppi`). El script ya trabaja a esa resolución y **nunca sube por encima**: forzar `-d` por encima del nativo no añade nitidez, sólo interpola y engorda el archivo. Si el nativo es muy bajo (<150 ppi) el script te avisa; ahí `-d 300` sí puede ayudar al OCR, a costa de peso.
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
| `EXTREMOS` | 1 (`-e`) = portada 1ª y contraportada última, sin reordenar |
| `DESKEW`, `DESKEW_MAX` | Enderezado y su ángulo máximo |
| `LIMPIAR_BORDES`, `BORDE_FRAC`, `BORDE_TOL` | Limpieza de cantos negros |
| `SAUVOLA_W`, `SAUVOLA_K`, `UNSHARP` | Binarización del interior |
| `MODO_GRIS`, `GRIS_QUALITY`, `GRIS_LO`, `GRIS_HI` | Modo gris |
| `COVER_MAX_H`, `COVER_QUALITY` | Portadas a color (alto máx. y calidad JPEG) |

---

## Cómo funciona por dentro

El script trabaja en un directorio temporal (`mktemp -d`, se borra solo al
terminar) y sigue estos pasos:

1. **Portadas a color** — `pdftoppm` renderiza las primeras `N` páginas (y con `-e` también la última), se reescalan y se comprimen en JPEG con `-strip`, que ya les quita los metadatos.
2. **Interior** — `pdftoppm -gray` renderiza el resto (con `-e`, hasta la penúltima); un script de Python (incrustado) procesa **cada página en paralelo** (`xargs -P $(nproc)`): limpieza de bordes → enderezado → realce + binarizado Sauvola (o ajuste de niveles en modo gris).
3. **Detección de idioma** — si no se pasó `-l` (y el OCR está activo), OCR de prueba sobre una página central.
4. **Ensamblado** — `img2pdf` incrusta las imágenes **sin recomprimir** y fija un **tamaño de página uniforme** para todo el documento (con `--nodate`, para no incrustar fechas). El orden depende del modo: con `-e` se respeta tal cual, y si no, la contraportada se mueve al final salvo `-k`.
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
