<p align="center">
  <img src="docs/brand/logo.png" alt="Stash" width="560">
</p>

<p align="center">
  <strong>Enregistrez tout en deux touches. Retrouvez-le en une.</strong>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.pt-BR.md">Português</a> · <a href="README.es.md">Español</a> · <b>Français</b>
</p>

<p align="center">
  <a href="https://s4mu3ldemolidor.github.io/stash/fr/">Site web</a> ·
  <a href="https://github.com/S4MU3LDemolidor/stash/releases/latest">Télécharger</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#confidentialité">Confidentialité</a> ·
  <a href="#compiler-depuis-les-sources">Compiler</a>
</p>

<p align="center">
  <a href="https://github.com/S4MU3LDemolidor/stash/actions/workflows/build.yml"><img src="https://github.com/S4MU3LDemolidor/stash/actions/workflows/build.yml/badge.svg" alt="Build"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14+">
  <img src="https://img.shields.io/badge/license-MIT-black" alt="Licence MIT">
</p>

---

Stash est une app de barre des menus pour macOS, gratuite, open source et entièrement locale, pour
garder vos références : la vidéo YouTube que vous regardez (à la seconde près), l’article que vous
lisez, une citation, une capture d’écran, une création publicitaire, un PDF. Un raccourci, un
panneau à la Raycast montre ce que vous avez sous les yeux, Entrée, c’est fait. Le même panneau
sert ensuite à tout rechercher et parcourir.

Chaque référence est un simple fichier Markdown dans un dossier ordinaire. Pas de compte, pas de
serveur, pas de statistiques.

<p align="center">
  <a href="https://s4mu3ldemolidor.github.io/stash/fr/#film"><img src="docs/film.jpg" alt="Voir le film de 43 secondes" width="720"></a>
</p>

| Capture | Bibliothèque | Grille |
|---|---|---|
| ![Capture](docs/screenshots/capture.png) | ![Bibliothèque](docs/screenshots/library.png) | ![Grille](docs/screenshots/grid.png) |

<sub>Les captures montrent des références d’exemple ; toutes les images sont originales.</sub>

## Pourquoi

Garder des références est lent et éparpillé : des favoris jamais rouverts, des captures qui
s’entassent sur le bureau, des idées qu’on s’envoie par message, des listes « à voir plus tard »
qui deviennent des cimetières. Avec Stash, enregistrer prend deux touches et retrouver en prend
une, et tout reste dans des fichiers qui vous appartiennent.

## Fonctionnalités

- **Capture** (`⌥⇧S`) : enregistre l’onglet actuel du navigateur (Safari, Chrome, Arc, Brave,
  Edge), avec le moment de la vidéo YouTube. Pas dans un navigateur ? Stash propose ce que vous
  avez copié dans la dernière minute, ou vous collez, tapez ou déposez n’importe quoi : liens,
  texte, images, fichiers. Une image copiée l’emporte toujours sur l’onglet.
- **Notes et tags** : tapez `super accroche dans les 3 premières secondes #hooks #thumbnails`
  avant d’appuyer sur Entrée. `#` propose les tags que vous utilisez déjà.
- **Déjà enregistré ?** La Capture vous le dit (« Déjà enregistré il y a 3 semaines »), et `↵`
  ajoute la nouvelle note et les tags à cette référence au lieu d’en créer une deuxième. `⌥↵`
  enregistre une copie séparée.
- **Bibliothèque** (`⌥⇧L`, ou `⇥` depuis la Capture) : recherche instantanée à chaque touche dans
  les titres, notes, tags, sites et le texte des PDF, fichiers texte et images enregistrés.
  Filtrez avec `#tag` ou `type:image`, `type:link`, `type:text`, `type:file`. Résultats regroupés
  en Aujourd’hui, Hier, Cette semaine et Plus tôt.
- **Texte dans les images** : captures et créations publicitaires se retrouvent par ce qu’elles
  disent. Stash lit le texte sur votre Mac avec Vision d’Apple et l’affiche dans le panneau de
  détails (`⌘K` le copie).
- **Liste et grille** : une liste avec un aperçu, ou une grille (`⌘G`) pour parcourir visuellement.
- **Actions** (`⌘K`) : ouvrir, ouvrir au moment enregistré, copier, modifier la note et les tags,
  afficher dans le Finder, supprimer (vers la Corbeille).
- **Titres, vignettes et icônes des sites** sont récupérés pour les liens enregistrés et gardés
  avec votre bibliothèque.
- **Des fichiers simples** : Markdown avec un en-tête YAML, lisible dans n’importe quel éditeur ou
  dans Obsidian ; les modifications faites ailleurs apparaissent aussitôt.
- **Votre dossier, où vous voulez** : gardez la bibliothèque dans iCloud Drive, Dropbox ou
  Syncthing pour l’utiliser sur plusieurs Mac.
- **Étagère** : pendant que vous faites glisser quelque chose (fichiers, dossiers, images, texte,
  liens), secouez la souris et une étagère apparaît sous le curseur. Déposez-y l’élément, allez où
  vous voulez, et reprenez-le plus tard. Vous pouvez aussi déposer des choses sur l’icône de la
  barre des menus.
- **Dans votre langue** : English, Português (Brasil), Español et Français. Stash suit la langue
  de votre Mac ; pour en choisir une autre rien que pour Stash, allez dans **Réglages Système ›
  Général › Langue et région › Applications**.
- **Natif** : modes clair et sombre, VoiceOver, Réduire les animations et Réduire la transparence.

## Installation

Avec [Homebrew](https://brew.sh) :

```sh
brew install --cask s4mu3ldemolidor/tap/stash-references
```

Ou à la main :

1. Téléchargez **`Stash-x.y.z.dmg`** depuis la [dernière version](https://github.com/S4MU3LDemolidor/stash/releases/latest).
2. Ouvrez-le et faites glisser **Stash** dans **Applications**.
3. Ouvrez Stash depuis Applications. Il n’est pas encore notarié par Apple, donc la première fois
   macOS le bloque : ouvrez **Réglages Système › Confidentialité et sécurité**, faites défiler et
   cliquez sur **Ouvrir quand même** (sur macOS 14, vous pouvez aussi faire un clic droit sur
   l’app › **Ouvrir**). Ou, dans le Terminal :
   ```sh
   xattr -dr com.apple.quarantine /Applications/Stash.app
   ```
4. Stash vit dans la **barre des menus** (l’icône de bac) ; il n’a pas d’icône dans le Dock. La
   première fois, une bulle montre le raccourci. Appuyez sur `⌥⇧S` pour capturer.

Comme Stash n’est pas encore notarié, avec Homebrew aussi la première ouverture demande **Ouvrir
quand même** (étape 3). Homebrew le met à jour avec `brew upgrade`.

Nécessite macOS 14 Sonoma ou ultérieur. Pour lancer Stash automatiquement, activez **Réglages ›
Ouvrir à la connexion**.

## Utilisation

### Capture

1. Appuyez sur `⌥⇧S` n’importe où.
2. Le panneau montre ce qui va être enregistré : l’onglet actuel du navigateur, ce que vous venez
   de copier, ou une carte vide où coller, taper ou déposer quelque chose.
3. Si vous voulez, tapez une note avec des `#tags`.
4. Appuyez sur `↵`. Le panneau se ferme et **Enregistré dans Stash** le confirme. (`⌘↵` enregistre
   et garde le panneau ouvert pour la suite.)

Si c’est déjà dans votre bibliothèque (la même page, même partagée avec des paramètres de suivi ;
le même moment d’une vidéo ; le même texte, la même image ou le même fichier), la carte affiche
**Déjà enregistré** et `↵` ajoute votre note et vos tags à cette référence. `⌥↵` enregistre quand
même une copie séparée.

### Bibliothèque

Appuyez sur `⌥⇧L`, tapez pour chercher, `↑ ↓` pour vous déplacer, `↵` pour ouvrir. `#tag` et
`type:` deviennent des filtres (`⌫` dans un champ vide retire le dernier). Aucun résultat ? `↵`
enregistre votre recherche comme note.

### Étagère

1. Commencez à faire glisser quelque chose : un fichier dans le Finder, une image ou un lien dans
   le navigateur, du texte.
2. Secouez la souris de gauche à droite. Une étagère apparaît sous le curseur ; lâchez dessus.
3. Plus tard, faites glisser la pile pour tout prendre, ou cliquez dessus et faites glisser un
   élément à la fois.

Sortir un élément de l’étagère revient à terminer le glisser d’origine : le Finder déplace un
fichier sur le même disque et le copie vers un autre. Maintenez `⌥` pour copier et le garder aussi
sur l’étagère. L’étagère reste à l’écran tant qu’elle contient quelque chose (même après un
redémarrage), et `×` la vide. Les fichiers sur l’étagère sont des références aux originaux, jamais
des copies : les grosses vidéos ne coûtent rien. Déposer des choses sur l’icône de la barre des
menus les met aussi sur l’étagère. Désactivez la secousse dans **Réglages › Étagère**.

### Clavier

| Touche | Capture | Bibliothèque |
|---|---|---|
| `↵` | Enregistrer | Ouvrir |
| `⌘↵` | Enregistrer et garder le panneau ouvert | Ouvrir au moment enregistré |
| `⌥↵` | Enregistrer une copie de ce qui est déjà enregistré | |
| `⇥` | Aller à la Bibliothèque | Aller à la Capture |
| `↑ ↓ ← →` | Choisir un tag proposé | Déplacer la sélection (← → dans la grille) |
| `⌘K` | | Actions |
| `⌘G` | | Grille / liste |
| `⌘E` | | Modifier la note et les tags |
| `⌘C` | | Copier le lien, le texte, l’image ou le fichier |
| `⌘⇧F` | | Afficher dans le Finder |
| `⌘⌫` | Vider la capture | Supprimer (demande d’abord) |
| `⌘V` | Remplacer la capture par le presse-papiers | Coller dans la recherche |
| `⌘,` | Réglages | Réglages |
| `Esc` | Fermer | Effacer la recherche, puis fermer |

Les deux raccourcis globaux se changent dans **Réglages › Raccourcis**.

### Réglages

Raccourcis · dossier de la bibliothèque (choisir, afficher, reconstruire l’index) · récupérer
titres et vignettes · ancienneté maximale de ce qui a été copié pour être proposé (30 s, 1 min,
5 min, désactivé) · secouer pour ouvrir l’étagère · ouvrir à la connexion · afficher l’icône dans
la barre des menus. Si vous masquez l’icône, rouvrez Stash depuis le Finder ou Spotlight pour
revenir aux réglages.

## Autorisations

Stash demande le moins possible, et seulement quand c’est nécessaire :

- **Automatisation (contrôler le navigateur)** : la première fois que vous capturez depuis un
  navigateur, macOS demande si Stash peut le contrôler. Stash lit seulement l’adresse et le titre
  de l’onglet actuel (et, sur YouTube, la position de lecture). Modifiez-le quand vous voulez dans
  **Réglages Système › Confidentialité et sécurité › Automatisation**.
- **Les moments YouTube** nécessitent que le navigateur autorise JavaScript depuis les Apple
  Events. C’est désactivé par défaut ; Stash affiche une astuce une seule fois s’il ne peut pas
  lire la position :
  - Chrome, Brave, Edge, Arc : **Présentation › Développeur › Autoriser JavaScript depuis les
    Apple Events**.
  - Safari : **Réglages › Avancées › Afficher les fonctionnalités pour les développeurs web**, puis
    **Réglages › Développeur › Autoriser JavaScript depuis les Apple Events**.

  Sans cela, Stash garde le `t=` déjà présent dans le lien.
- **Ouvrir à la connexion** (facultatif) utilise les éléments d’ouverture standard.

Stash n’a besoin ni de l’Accessibilité, ni de l’Enregistrement de l’écran, ni de l’Accès complet
au disque, ni d’aucune autre autorisation.

## Confidentialité

- **Vos données ne quittent jamais votre Mac.** Pas de compte, pas de serveur, pas de
  statistiques, pas de télémétrie, pas de rapports de plantage.
- **Les seules requêtes réseau** récupèrent le titre, l’image d’aperçu et l’icône des liens que
  vous enregistrez, auprès du site lui-même (pour YouTube : son point d’accès oEmbed public et ses
  vignettes). Aucun cookie n’est envoyé ni conservé. Désactivez-les dans **Réglages › Capturer ›
  Récupérer titres et vignettes** et Stash ne fait plus aucune requête réseau.
- **Le texte dans les images** est lu sur votre Mac par le framework Vision d’Apple et gardé
  uniquement dans l’index de recherche ; vos fichiers ne changent pas.
- **L’étagère** reste aussi sur votre Mac : les fichiers y sont des références aux originaux, et
  les images, textes et liens glissés de petites copies privées dans
  `~/Library/Application Support/Stash/Shelf/`. Elle ne touche jamais à votre bibliothèque ni au
  réseau, et Stash ne déplace ni ne supprime jamais un original de lui-même.
- **Le presse-papiers** n’est lu que lorsque vous ouvrez la Capture, et seulement si vous avez
  copié quelque chose récemment. Ce qu’un gestionnaire de mots de passe marque comme secret n’est
  jamais capturé, et ce que vous copiez depuis Stash ne vous est pas reproposé.

## Où sont vos données

```
~/Stash/                      ← la bibliothèque (changez-la dans les réglages, par ex. vers iCloud Drive)
  items/
    2026-10-14-great-hook-in-the-first-3s.md
  assets/
    01JA8K3Q7Z2M4X5C6V7B8N9P0Q.jpg     ← vignettes, images et fichiers, nommés par ID de référence
    icons/youtube.com.png              ← une icône par site

~/Library/Application Support/Stash/
  index.sqlite                ← index de recherche (et texte lu dans les images) ; un cache, reconstruit depuis les fichiers à tout moment
  Shelf/                      ← le contenu de l’étagère (shelf.json + copies privées dans Items/)
```

Chaque référence est un fichier Markdown avec un petit en-tête :

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

Les références texte gardent le texte enregistré dans le corps et la note dans un champ `note:`.
Stash conserve les champs d’en-tête qu’il ne connaît pas : vous pouvez ajouter les vôtres (dans
Obsidian, par exemple).

**Plusieurs Mac :** dans **Réglages › Bibliothèque › Choisir…**, déplacez la bibliothèque dans
iCloud Drive, Dropbox ou un dossier Syncthing. Sur l’autre Mac, choisissez le même dossier : Stash
voit qu’il contient déjà une bibliothèque et l’utilise. Supprimer une référence envoie ses fichiers
à la Corbeille.

**Si Stash disparaît demain**, votre bibliothèque reste un dossier de fichiers Markdown et
d’images.

## Compiler depuis les sources

Nécessite macOS 14+ et un **Xcode** récent (testé avec Xcode 27 ; les Command Line Tools seules ne
suffisent pas, une dépendance a besoin des macros de Xcode).

```sh
git clone https://github.com/S4MU3LDemolidor/stash.git
cd stash
scripts/run.sh
```

`scripts/run.sh` compile `build/Stash.app`, quitte toute copie ouverte et lance la nouvelle.

| Commande | Ce qu’elle fait |
|---|---|
| `scripts/run.sh` | Compile et lance l’app |
| `scripts/build-app.sh` | Compile `build/Stash.app` (release, signature ad hoc) |
| `scripts/make-dmg.sh` | Compile l’app et `build/Stash-<version>.dmg` |
| `swift test` | Lance les tests |
| `scripts/check-strings.sh` | Vérifie les textes de chaque langue par rapport au code |
| `swift scripts/make-icon.swift` | Régénère `Support/AppIcon.icns` depuis le dessin de l’icône |

Définissez `STASH_VERSION` (et éventuellement `STASH_BUILD`) pour des builds versionnés, par
exemple `STASH_VERSION=0.3.0 scripts/make-dmg.sh`.

**Traductions :** `Support/Localization/<langue>.lproj/Localizable.strings`, une table par langue,
dont chaque clé est le texte anglais. Après avoir modifié des textes de l’interface, lancez
`scripts/check-strings.sh sync-en` pour mettre à jour la table anglaise, puis traduisez les
nouvelles clés (`scripts/check-strings.sh missing fr` les liste). La CI échoue s’il manque un
texte dans une langue.

**Site web :** `site/` est publié sur GitHub Pages à chaque push sur `main` qui le modifie (voir
[`.github/workflows/pages.yml`](.github/workflows/pages.yml)). `site/index.html` est la page
anglaise ; `python3 site/i18n/build.py` génère les autres langues depuis `site/i18n/*.json`. Pour
le voir en local : `python3 site/i18n/build.py && python3 -m http.server 8080 --directory site`.

**Homebrew :** le cask est dans [S4MU3LDemolidor/homebrew-tap](https://github.com/S4MU3LDemolidor/homebrew-tap)
(sa source est dans [`packaging/homebrew-tap`](packaging/homebrew-tap)) et se met à jour chaque
jour à partir de la dernière version.

**Versions :** pousser un tag comme `v0.1.0` fait compiler, tester et publier `Stash-0.1.0.dmg` et
`Stash-0.1.0.zip` par GitHub Actions (voir [`.github/workflows/build.yml`](.github/workflows/build.yml)).

**Aides au développement :**

- Maintenez `⌥` en ouvrant le menu de la barre des menus pour les commandes de débogage (générer ou
  retirer 200 références d’exemple, avec le tag `#sample`).
- `open build/Stash.app --args -libraryPath /tmp/stash-test` utilise une autre bibliothèque le
  temps d’un lancement.
- `open build/Stash.app --args -StashShowPanel library` ouvre le panneau au lancement.
- `open build/Stash.app --args -AppleLanguages "(fr)"` lance Stash dans une autre langue.
- Les builds de débogage (`.build/debug/Stash`) se pilotent par script : voir
  [`Sources/Stash/App/DebugHooks.swift`](Sources/Stash/App/DebugHooks.swift).

### Organisation du projet

```
Sources/Stash/
  App/          point d’entrée, barre des menus, commandes de débogage
  Panel/        le panneau flottant et ses raccourcis
  Capture/      onglet du navigateur, presse-papiers, coller et déposer, enregistrement, doublons
  Library/      recherche, liste, panneau de détails, grille, actions ⌘K
  Components/   barre de recherche, barre d’actions, touches, filtres, HUD
  Model/        références, tags, slugs, ID
  Storage/      fichiers Markdown, synchro du dossier, index de recherche (GRDB + FTS5), texte dans les images
  Enrichment/   YouTube, titres et vignettes
  Settings/     préférences et la fenêtre de réglages
  Shelf/        l’étagère qui s’ouvre en secouant
  Design/       jetons de design et la marque Stash
Support/        Info.plist, entitlements, icône de l’app, traductions (Localization/)
docs/           éléments de marque et captures d’écran
site/           le site web (HTML, CSS et JS simples ; publié sur GitHub Pages)
packaging/      la source du tap Homebrew
```

Conçu avec Swift, SwiftUI et AppKit, plus deux bibliothèques :
[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (raccourcis globaux) et
[GRDB.swift](https://github.com/groue/GRDB.swift) (recherche plein texte SQLite).

Voir [CONTRIBUTING.md](CONTRIBUTING.md) (en anglais) pour les principes et conventions.

## Marque

Le logo et l’icône de l’app sont dans [`docs/brand`](docs/brand). L’icône de la barre des menus est
la même marque, dessinée en vectoriel dans [`StashMark.swift`](Sources/Stash/Design/StashMark.swift)
pour rester nette et suivre l’apparence claire ou sombre de la barre des menus.

## Licence

MIT. Voir [LICENSE](LICENSE).
