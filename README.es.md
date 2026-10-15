<p align="center">
  <img src="docs/brand/logo.png" alt="Stash" width="560">
</p>

<p align="center">
  <strong>Guarda lo que sea con dos teclas. Encuéntralo con una.</strong>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.pt-BR.md">Português</a> · <b>Español</b> · <a href="README.fr.md">Français</a>
</p>

<p align="center">
  <a href="https://s4mu3ldemolidor.github.io/stash/es/">Web</a> ·
  <a href="https://github.com/S4MU3LDemolidor/stash/releases/latest">Descargar</a> ·
  <a href="#instalación">Instalación</a> ·
  <a href="#privacidad">Privacidad</a> ·
  <a href="#compilar-desde-el-código">Compilar</a>
</p>

<p align="center">
  <a href="https://github.com/S4MU3LDemolidor/stash/actions/workflows/build.yml"><img src="https://github.com/S4MU3LDemolidor/stash/actions/workflows/build.yml/badge.svg" alt="Build"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14+">
  <img src="https://img.shields.io/badge/license-MIT-black" alt="Licencia MIT">
</p>

---

Stash es una app de barra de menús para macOS, gratuita, de código abierto y totalmente local,
para guardar referencias: el vídeo de YouTube que estás viendo (en el segundo exacto), el artículo
que estás leyendo, una cita, una captura de pantalla, una creatividad publicitaria, un PDF. Pulsa
un atajo, un panel al estilo de Raycast muestra lo que tienes delante, pulsa Intro y listo. El
mismo panel sirve para buscar y explorar todo después.

Cada referencia es un archivo Markdown normal en una carpeta normal. Sin cuenta, sin servidor,
sin analítica.

<p align="center">
  <a href="https://s4mu3ldemolidor.github.io/stash/es/#film"><img src="docs/film.jpg" alt="Mira la película de 43 segundos" width="720"></a>
</p>

| Captura | Biblioteca | Cuadrícula |
|---|---|---|
| ![Captura](docs/screenshots/capture.png) | ![Biblioteca](docs/screenshots/library.png) | ![Cuadrícula](docs/screenshots/grid.png) |

<sub>Las capturas muestran referencias de ejemplo; todas las imágenes en ellas son originales.</sub>

## Por qué

Guardar referencias es lento y disperso: marcadores que nunca abres, capturas que se amontonan en
el escritorio, ideas que te mandas a ti mismo por chat, listas de "ver más tarde" que acaban
olvidadas. Con Stash, guardar cuesta dos teclas y encontrar cuesta una, y todo queda en archivos
que son tuyos.

## Funciones

- **Captura** (`⌥⇧S`): guarda la pestaña actual del navegador (Safari, Chrome, Arc, Brave, Edge),
  con el momento de YouTube en el que estás. ¿No estás en un navegador? Te ofrece lo que copiaste
  en el último minuto, o pegas, escribes o sueltas lo que sea: enlaces, texto, imágenes, archivos.
  Una imagen copiada siempre gana a la pestaña.
- **Notas y etiquetas**: escribe `buen gancho en los primeros 3s #hooks #thumbnails` antes de
  pulsar Intro. `#` sugiere las etiquetas que ya usas.
- **¿Ya guardado?** La Captura te lo dice ("Ya guardado hace 3 semanas"), y `↵` añade la nota y
  las etiquetas nuevas a esa referencia en lugar de crear otra. `⌥↵` guarda una copia aparte.
- **Biblioteca** (`⌥⇧L`, o `⇥` desde la Captura): búsqueda instantánea con cada tecla en
  títulos, notas, etiquetas, sitios y el texto de los PDF, archivos de texto e imágenes guardados.
  Filtra con `#etiqueta` o `type:image`, `type:link`, `type:text`, `type:file`. Resultados
  agrupados en Hoy, Ayer, Esta semana y Antes.
- **Texto en imágenes**: las capturas y creatividades se encuentran por lo que dicen. Stash lee el
  texto en tu Mac con Vision de Apple y lo muestra en el panel de detalles (`⌘K` lo copia).
- **Lista y cuadrícula**: una lista con panel de vista previa, o una cuadrícula (`⌘G`) para
  explorar visualmente.
- **Acciones** (`⌘K`): abrir, abrir en el momento guardado, copiar, editar nota y etiquetas,
  mostrar en Finder, eliminar (a la Papelera).
- **Títulos, miniaturas e iconos de sitios** se obtienen para los enlaces guardados y se quedan
  con tu biblioteca.
- **Archivos simples**: Markdown con front matter YAML, legible en cualquier editor u Obsidian;
  los cambios hechos fuera aparecen al instante.
- **Tu carpeta, donde quieras**: guarda la biblioteca en iCloud Drive, Dropbox o Syncthing para
  usarla en varios Mac.
- **Repisa**: mientras arrastras cualquier cosa (archivos, carpetas, imágenes, texto, enlaces),
  agita el ratón y aparece una repisa bajo el cursor. Suéltalo ahí, ve adonde necesites y sácalo
  después. También puedes soltar cosas en el icono de la barra de menús.
- **En tu idioma**: English, Português (Brasil), Español y Français. Stash sigue el idioma de tu
  Mac; para elegir otro solo para Stash, ve a **Ajustes del Sistema › General › Idioma y región ›
  Aplicaciones**.
- **Nativa**: modo claro y oscuro, VoiceOver, Reducir movimiento y Reducir transparencia.

## Instalación

Con [Homebrew](https://brew.sh):

```sh
brew install --cask s4mu3ldemolidor/tap/stash-references
```

O a mano:

1. Descarga **`Stash-x.y.z.dmg`** de la [última versión](https://github.com/S4MU3LDemolidor/stash/releases/latest).
2. Ábrelo y arrastra **Stash** a **Aplicaciones**.
3. Abre Stash desde Aplicaciones. Todavía no está notarizada por Apple, así que la primera vez
   macOS la bloquea: abre **Ajustes del Sistema › Privacidad y seguridad**, baja hasta el final y
   haz clic en **Abrir igualmente** (en macOS 14 también puedes hacer clic derecho en la app ›
   **Abrir**). O, en Terminal:
   ```sh
   xattr -dr com.apple.quarantine /Applications/Stash.app
   ```
4. Stash vive en la **barra de menús** (el icono de bandeja); no tiene icono en el Dock. La
   primera vez, un aviso muestra el atajo. Pulsa `⌥⇧S` para capturar.

Como Stash aún no está notarizada, con Homebrew la primera apertura también necesita **Abrir
igualmente** (paso 3). Homebrew la actualiza con `brew upgrade`.

Requiere macOS 14 Sonoma o posterior. Para abrir Stash automáticamente, activa **Ajustes › Abrir al
iniciar sesión**.

## Cómo se usa

### Captura

1. Pulsa `⌥⇧S` en cualquier sitio.
2. El panel muestra lo que se va a guardar: la pestaña actual del navegador, algo que acabas de
   copiar, o una tarjeta vacía para pegar, escribir o soltar algo.
3. Si quieres, escribe una nota con `#etiquetas`.
4. Pulsa `↵`. El panel se cierra y **Guardado en Stash** lo confirma. (`⌘↵` guarda y deja el
   panel abierto para la siguiente.)

Si ya está en tu biblioteca (la misma página, aunque se haya compartido con parámetros de
seguimiento; el mismo momento de un vídeo; el mismo texto, imagen o archivo), la tarjeta dice
**Ya guardado** y `↵` añade tu nota y tus etiquetas a esa referencia. `⌥↵` guarda una copia aparte
de todos modos.

### Biblioteca

Pulsa `⌥⇧L`, escribe para buscar, `↑ ↓` para moverte, `↵` para abrir. `#etiqueta` y `type:` se
convierten en filtros (`⌫` con el campo vacío quita el último). ¿Sin resultados? `↵` guarda tu
búsqueda como nota.

### Repisa

1. Empieza a arrastrar algo: un archivo en Finder, una imagen o un enlace en el navegador, un
   texto.
2. Agita el ratón a los lados. Aparece una repisa bajo el cursor; suéltalo encima.
3. Después, arrastra la pila para llevarte todo, o haz clic en ella y arrastra ítems sueltos.

Sacar algo de la repisa funciona como terminar el arrastre original: Finder mueve un archivo
dentro del mismo disco y lo copia a otro. Mantén `⌥` para copiarlo y dejarlo también en la repisa.
La repisa se queda en pantalla mientras tenga algo (también después de reiniciar), y `×` la vacía.
Los archivos en la repisa son referencias a los originales, nunca copias, así que los vídeos
grandes no ocupan nada. Soltar cosas en el icono de la barra de menús también las pone en la
repisa. Desactiva el gesto de agitar en **Ajustes › Repisa**.

### Teclado

| Tecla | Captura | Biblioteca |
|---|---|---|
| `↵` | Guardar | Abrir |
| `⌘↵` | Guardar y dejar el panel abierto | Abrir en el momento guardado |
| `⌥↵` | Guardar una copia de algo ya guardado | |
| `⇥` | Ir a la Biblioteca | Ir a la Captura |
| `↑ ↓ ← →` | Elegir una etiqueta sugerida | Mover la selección (← → en la cuadrícula) |
| `⌘K` | | Acciones |
| `⌘G` | | Cuadrícula / lista |
| `⌘E` | | Editar nota y etiquetas |
| `⌘C` | | Copiar enlace, texto, imagen o archivo |
| `⌘⇧F` | | Mostrar en Finder |
| `⌘⌫` | Vaciar lo capturado | Eliminar (pregunta antes) |
| `⌘V` | Reemplazar la captura por lo copiado | Pegar en la búsqueda |
| `⌘,` | Ajustes | Ajustes |
| `Esc` | Cerrar | Borrar la búsqueda, luego cerrar |

Los dos atajos globales se pueden cambiar en **Ajustes › Atajos**.

### Ajustes

Atajos · carpeta de la biblioteca (elegir, mostrar, reconstruir el índice) · obtener títulos y
miniaturas · hace cuánto puede ser lo copiado para ofrecerlo (30 s, 1 min, 5 min, desactivado) ·
agitar para abrir la repisa · abrir al iniciar sesión · mostrar el icono en la barra de menús. Si
ocultas el icono, vuelve a abrir Stash desde Finder o Spotlight para volver a los Ajustes.

## Permisos

Stash pide lo mínimo posible, y solo cuando hace falta:

- **Automatización (controlar el navegador)**: la primera vez que capturas desde un navegador,
  macOS pregunta si Stash puede controlarlo. Stash solo lee la dirección y el título de la
  pestaña actual (y, en YouTube, la posición del vídeo). Cámbialo cuando quieras en **Ajustes del
  Sistema › Privacidad y seguridad › Automatización**.
- **Los momentos de YouTube** necesitan que el navegador permita JavaScript desde Apple Events.
  Viene desactivado; Stash muestra un consejo una vez si no puede leer la posición:
  - Chrome, Brave, Edge, Arc: **Ver › Desarrollador › Permitir JavaScript desde Apple Events**.
  - Safari: **Ajustes › Avanzado › Mostrar funciones para desarrolladores web**, luego **Ajustes ›
    Desarrollador › Permitir JavaScript desde Apple Events**.

  Sin eso, Stash conserva el `t=` que ya tenga el enlace.
- **Abrir al iniciar sesión** (opcional) usa los Ítems de inicio estándar.

Stash no necesita Accesibilidad, Grabación de pantalla, Acceso total al disco ni ningún otro
permiso.

## Privacidad

- **Tus datos nunca salen de tu Mac.** Sin cuenta, sin servidor, sin analítica, sin telemetría,
  sin informes de fallos.
- **Las únicas conexiones a la red** obtienen el título, la imagen de vista previa y el icono de
  los enlaces que guardas, del propio sitio (en YouTube: su endpoint público de oEmbed y las
  miniaturas). No se envían ni se guardan cookies. Desactívalo en **Ajustes › Capturar › Obtener
  títulos y miniaturas** y Stash no hace ninguna conexión a la red.
- **El texto en imágenes** se lee en tu Mac con el framework Vision de Apple y se guarda solo en
  el índice de búsqueda; tus archivos no cambian.
- **La repisa** también se queda en tu Mac: los archivos se guardan como referencias a los
  originales, y las imágenes, textos y enlaces arrastrados como pequeñas copias privadas en
  `~/Library/Application Support/Stash/Shelf/`. Nunca toca tu biblioteca ni la red, y Stash nunca
  mueve ni elimina un original por su cuenta.
- **El portapapeles** solo se lee cuando abres la Captura, y solo si copiaste algo hace poco. Nada
  que un gestor de contraseñas marque como secreto se captura nunca, y lo que copias desde Stash no
  se te vuelve a ofrecer.

## Dónde están tus datos

```
~/Stash/                      ← la biblioteca (cámbiala en Ajustes, por ejemplo a iCloud Drive)
  items/
    2026-10-14-great-hook-in-the-first-3s.md
  assets/
    01JA8K3Q7Z2M4X5C6V7B8N9P0Q.jpg     ← miniaturas, imágenes y archivos, con el ID de la referencia
    icons/youtube.com.png              ← un icono por sitio

~/Library/Application Support/Stash/
  index.sqlite                ← índice de búsqueda (y texto leído de las imágenes); una caché, reconstruible desde los archivos
  Shelf/                      ← lo que hay en la repisa (shelf.json + copias privadas en Items/)
```

Cada referencia es un archivo Markdown con una pequeña cabecera:

```markdown
---
id: 01JA8K3Q7Z2M4X5C6V7B8N9P0Q
type: link
url: https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=272s
title: How I Write Hooks That Stop the Scroll
site: youtube.com
timestamp: 272
tags: [hooks, thumbnails]
thumbnail: assets/01JA8K3Q7Z2M4X5C6V7B8N9P0Q.jpg
created: 2026-10-14T10:20:00-03:00
---
great hook in the first 3s
```

Las referencias de texto guardan el texto en el cuerpo y la nota en un campo `note:`. Stash
conserva los campos de la cabecera que no conoce, así que puedes añadir los tuyos (en Obsidian, por
ejemplo).

**Varios Mac:** en **Ajustes › Biblioteca › Elegir…**, mueve la biblioteca a iCloud Drive, Dropbox o
una carpeta de Syncthing. En el otro Mac, elige la misma carpeta: Stash ve que ya contiene una
biblioteca y la usa. Eliminar una referencia mueve sus archivos a la Papelera.

**Si Stash desaparece mañana**, tu biblioteca sigue siendo una carpeta de archivos Markdown e
imágenes.

## Compilar desde el código

Requiere macOS 14+ y un **Xcode** reciente (probado con Xcode 27; las Command Line Tools solas no
bastan, una dependencia necesita las macros de Xcode).

```sh
git clone https://github.com/S4MU3LDemolidor/stash.git
cd stash
scripts/run.sh
```

`scripts/run.sh` compila `build/Stash.app`, cierra cualquier copia abierta y abre la nueva.

| Comando | Qué hace |
|---|---|
| `scripts/run.sh` | Compila y abre la app |
| `scripts/build-app.sh` | Compila `build/Stash.app` (release, firma ad-hoc) |
| `scripts/make-dmg.sh` | Compila la app y `build/Stash-<versión>.dmg` |
| `swift test` | Ejecuta las pruebas |
| `scripts/check-strings.sh` | Compara los textos de cada idioma con el código |
| `swift scripts/make-icon.swift` | Regenera `Support/AppIcon.icns` desde el diseño del icono |

Define `STASH_VERSION` (y, si quieres, `STASH_BUILD`) para compilaciones con versión, por ejemplo
`STASH_VERSION=0.3.0 scripts/make-dmg.sh`.

**Traducciones:** `Support/Localization/<idioma>.lproj/Localizable.strings`, una tabla por
idioma, donde cada clave es el texto en inglés. Después de cambiar textos de la interfaz, ejecuta
`scripts/check-strings.sh sync-en` para actualizar la tabla en inglés y traduce las claves nuevas
(`scripts/check-strings.sh missing es` las lista). El CI falla si a un idioma le falta un texto.

**Web:** `site/` se publica en GitHub Pages con cada push a `main` que lo cambia (ver
[`.github/workflows/pages.yml`](.github/workflows/pages.yml)). `site/index.html` es la página en
inglés; `python3 site/i18n/build.py` genera los demás idiomas a partir de `site/i18n/*.json`. Para
verla en local: `python3 site/i18n/build.py && python3 -m http.server 8080 --directory site`.

**Homebrew:** el cask está en [S4MU3LDemolidor/homebrew-tap](https://github.com/S4MU3LDemolidor/homebrew-tap)
(su código fuente está en [`packaging/homebrew-tap`](packaging/homebrew-tap)) y se actualiza solo
cada día con la última versión.

**Versiones:** enviar una etiqueta como `v0.1.0` hace que GitHub Actions compile, pruebe y publique
`Stash-0.1.0.dmg` y `Stash-0.1.0.zip` (ver [`.github/workflows/build.yml`](.github/workflows/build.yml)).

**Ayudas para desarrollar:**

- Mantén `⌥` al abrir el menú de la barra de menús para ver comandos de depuración (generar o
  eliminar 200 referencias de ejemplo, con la etiqueta `#sample`).
- `open build/Stash.app --args -libraryPath /tmp/stash-test` usa otra biblioteca durante una
  ejecución.
- `open build/Stash.app --args -StashShowPanel library` abre el panel al arrancar.
- `open build/Stash.app --args -AppleLanguages "(es)"` abre Stash en otro idioma.
- Las compilaciones de depuración (`.build/debug/Stash`) se pueden controlar con scripts: ver
  [`Sources/Stash/App/DebugHooks.swift`](Sources/Stash/App/DebugHooks.swift).

### Estructura del proyecto

```
Sources/Stash/
  App/          punto de entrada, barra de menús, comandos de depuración
  Panel/        el panel flotante y su mapa de teclas
  Capture/      pestaña del navegador, portapapeles, pegar y soltar, guardar, duplicados
  Library/      búsqueda, lista, panel de detalles, cuadrícula, acciones de ⌘K
  Components/   barra de búsqueda, barra de acciones, teclas, filtros, HUD
  Model/        referencias, etiquetas, slugs, ID
  Storage/      archivos Markdown, sincronización de la carpeta, índice de búsqueda (GRDB + FTS5), texto en imágenes
  Enrichment/   YouTube, títulos y miniaturas
  Settings/     preferencias y la ventana de Ajustes
  Shelf/        la repisa que se abre agitando
  Design/       tokens de diseño y la marca de Stash
Support/        Info.plist, entitlements, icono de la app, traducciones (Localization/)
docs/           recursos de marca y capturas
site/           la web (HTML, CSS y JS sencillos; publicada en GitHub Pages)
packaging/      el código fuente del tap de Homebrew
```

Hecha con Swift, SwiftUI y AppKit, más dos bibliotecas:
[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (atajos globales) y
[GRDB.swift](https://github.com/groue/GRDB.swift) (búsqueda de texto completo en SQLite).

Consulta [CONTRIBUTING.md](CONTRIBUTING.md) (en inglés) para principios y convenciones.

## Marca

El logo y el icono de la app están en [`docs/brand`](docs/brand). El icono de la barra de menús es
la misma marca, dibujada con vectores en [`StashMark.swift`](Sources/Stash/Design/StashMark.swift)
para que se vea nítida y siga la apariencia clara u oscura de la barra de menús.

## Licencia

MIT. Ver [LICENSE](LICENSE).
