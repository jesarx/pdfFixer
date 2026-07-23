# pdfFixer — `escanea-limpia.sh`

Limpia, endereza, comprime y hace OCR a PDFs escaneados de libros, dejándolos
ligeros, derechos y con texto **buscable y seleccionable**.

Pensado para escaneos de libros (con portada y contraportada a color e interior
en blanco y negro), pero funciona con cualquier PDF escaneado.

---

## ¿Qué hace?

Con cada **página del interior**, en orden:

1. **Detecta la resolución nativa** del escaneo y trabaja a esa resolución (ni más, ni menos).
2. **Limpia los bordes:** borra los cantos negros del escáner (la franja oscura del borde del libro, la sombra del lomo, la línea del canto).
3. **Endereza la página** midiendo la inclinación real de los renglones de texto (perfil de proyección), no del marco de la imagen. Precisión medida: **±0.05°**.
4. **Realza los bordes del texto** y **binariza** con el algoritmo de Sauvola (umbral local, resiste iluminación despareja).
5. **Comprime** como TIFF G4 / JBIG2.

Con el **documento completo**:

6. Mantiene **portada y contraportada a color**, moviendo la contraportada al final.
7. Añade una capa de **OCR con Tesseract**, detectando el idioma automáticamente.

El resultado es un PDF mucho más ligero, con las páginas derechas y limpias, y
con texto real por debajo de la imagen (se puede buscar y copiar).

---

## Instalación

### Dependencias (Arch Linux)

```bash
sudo pacman -S poppler imagemagick img2pdf ocrmypdf tesseract \
               tesseract-data-spa tesseract-data-eng \
               python-scikit-image python-scipy python-pillow \
               python-numpy pngquant
```

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
- `python3` con los módulos **scikit-image, scipy, pillow, numpy**
- `jbig2` (**jbig2enc**), opcional

El script comprueba las dependencias al arrancar y te dice exactamente qué falta.

### Poner el script a mano

```bash
chmod +x escanea-limpia.sh
./escanea-limpia.sh -h        # muestra la ayuda incrustada
```

Si lo quieres disponible desde cualquier carpeta:

```bash
cp escanea-limpia.sh ~/.local/bin/escanea-limpia   # o /usr/local/bin
```

---

## Uso

```
escanea-limpia.sh entrada.pdf [opciones]
```

Las opciones pueden ir **antes o después** del nombre del archivo.

### Ejemplos rápidos

```bash
./escanea-limpia.sh alls.pdf                    # todo automático
./escanea-limpia.sh alls.pdf -o 45.pdf -s 0.45  # salida con nombre y trazo más fino
./escanea-limpia.sh alls.pdf -G -d 250          # modo gris, máxima nitidez
./escanea-limpia.sh alls.pdf -l spa+fra         # español con citas en francés
./escanea-limpia.sh alls.pdf -D -B              # sin tocar la geometría
```

> ⚠️ **El archivo de salida SIEMPRE va precedido de `-o`.**
>
> ```bash
> ./escanea-limpia.sh alls.pdf 45.pdf -s 0.45      # ✗ MAL (45.pdf se ignora)
> ./escanea-limpia.sh alls.pdf -o 45.pdf -s 0.45   # ✓ BIEN
> ```
>
> Desde la v4 el script avisa con un error en vez de ignorar el argumento suelto en silencio.

---

## Opciones

| Opción | Descripción | Default |
|--------|-------------|---------|
| `-o ARCHIVO` | Archivo de salida | `entrada_limpio.pdf` |
| `-c N` | Páginas a color al inicio (pág 1 = portada, 2..N = contraportada). `-c 0` procesa todo como interior | `2` |
| `-d DPI` | Resolución de trabajo | `auto` (nativa) |
| `-l IDIOMA` | Idioma(s) del OCR. Códigos de 3 letras unidos con `+`, el primero es el principal (p. ej. `spa`, `spa+fra`, `spa+lat`) | `auto` (detectar) |
| `-k` | Conservar orden original (**no** mover la contraportada al final) | mover al final |
| `-w N` | Ventana Sauvola en px | `auto` (DPI/6, impar) |
| `-s K` | Sensibilidad Sauvola (grosor del trazo) | `0.34` |
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
3. Sensibilidad (`-s`): ajusta el grosor del trazo.
   - grueso/embarrado → **sube** k (`-s 0.45`)
   - roto/incompleto → **baja** k (`-s 0.25`)
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
| `MOVER_CONTRA` | 1 = contraportada al final; 0 = orden original |
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
3. **Detección de idioma** — si no se pasó `-l`, OCR de prueba sobre una página central.
4. **Ensamblado** — `img2pdf` incrusta las imágenes **sin recomprimir**, reordenando la contraportada al final y fijando un tamaño de página uniforme.
5. **OCR + optimización** — `ocrmypdf` añade la capa de texto invisible y con `--optimize 3` recomprime (los TIFF G4 pasan a JBIG2 si `jbig2enc` está instalado; sin él baja a nivel 1).

---

## Licencia

Sin licencia declarada. Ajusta esta sección según prefieras.
