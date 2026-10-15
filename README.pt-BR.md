<p align="center">
  <img src="docs/brand/logo.png" alt="Stash" width="560">
</p>

<p align="center">
  <strong>Salve qualquer coisa com dois toques no teclado. Encontre de novo com um.</strong>
</p>

<p align="center">
  <a href="README.md">English</a> · <b>Português</b> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a>
</p>

<p align="center">
  <a href="https://s4mu3ldemolidor.github.io/stash/pt-br/">Site</a> ·
  <a href="https://github.com/S4MU3LDemolidor/stash/releases/latest">Download</a> ·
  <a href="#instalação">Instalação</a> ·
  <a href="#privacidade">Privacidade</a> ·
  <a href="#compilar-a-partir-do-código">Compilar</a>
</p>

<p align="center">
  <a href="https://github.com/S4MU3LDemolidor/stash/actions/workflows/build.yml"><img src="https://github.com/S4MU3LDemolidor/stash/actions/workflows/build.yml/badge.svg" alt="Build"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14+">
  <img src="https://img.shields.io/badge/license-MIT-black" alt="Licença MIT">
</p>

---

O Stash é um app de barra de menus para macOS, gratuito, de código aberto e totalmente local,
para guardar referências: o vídeo do YouTube que você está vendo (no segundo exato), o artigo
que está lendo, uma frase, um print, um criativo de anúncio, um PDF. Aperte um atalho, um painel
no estilo do Raycast mostra o que está na sua frente, aperte Enter e pronto. O mesmo painel
serve para buscar e navegar por tudo depois.

Cada referência é um arquivo Markdown comum numa pasta normal. Sem conta, sem servidor, sem
analytics.

<p align="center">
  <a href="https://s4mu3ldemolidor.github.io/stash/pt-br/#film"><img src="docs/film.jpg" alt="Assista ao filme de 43 segundos" width="720"></a>
</p>

| Captura | Biblioteca | Grade |
|---|---|---|
| ![Captura](docs/screenshots/capture.png) | ![Biblioteca](docs/screenshots/library.png) | ![Grade](docs/screenshots/grid.png) |

<sub>As capturas de tela mostram referências de exemplo; todas as artes nelas são originais.</sub>

## Por quê

Guardar referências é lento e espalhado: favoritos que você nunca abre, prints se acumulando na
mesa, ideias mandadas para você mesmo no chat, listas de "ver depois" que viram cemitério. Com o
Stash, salvar leva dois toques e encontrar leva um, e tudo fica em arquivos que são seus.

## Recursos

- **Captura** (`⌥⇧S`): salva a aba atual do navegador (Safari, Chrome, Arc, Brave, Edge), com o
  momento do YouTube em que você está. Fora do navegador? Ele oferece o que você copiou no último
  minuto, ou você cola, digita ou solta qualquer coisa: links, textos, imagens, arquivos. Uma
  imagem copiada sempre ganha da aba.
- **Notas e tags**: digite `gancho ótimo nos primeiros 3s #hooks #thumbnails` antes de apertar
  Enter. O `#` sugere as tags que você já usa.
- **Já salvo?** A Captura avisa ("Já salvo há 3 semanas"), e `↵` adiciona a nota e as tags novas
  àquela referência em vez de criar uma segunda. `⌥↵` salva uma cópia separada.
- **Biblioteca** (`⌥⇧L`, ou `⇥` a partir da Captura): busca instantânea a cada tecla em títulos,
  notas, tags, sites e no texto de PDFs, arquivos de texto e imagens salvos. Filtre com `#tag` ou
  `type:image`, `type:link`, `type:text`, `type:file`. Resultados agrupados em Hoje, Ontem, Esta
  semana e Antes.
- **Texto nas imagens**: prints e criativos de anúncio podem ser encontrados pelo que está escrito
  neles. O Stash lê o texto no seu Mac com o Vision da Apple e o mostra no painel de detalhes
  (`⌘K` copia).
- **Lista e grade**: uma lista com painel de pré-visualização, ou uma grade (`⌘G`) para navegar
  visualmente.
- **Ações** (`⌘K`): abrir, abrir no momento salvo, copiar, editar nota e tags, mostrar no Finder,
  apagar (vai para o Lixo).
- **Títulos, miniaturas e ícones de sites** são buscados para os links salvos e ficam com a sua
  biblioteca.
- **Arquivos simples**: Markdown com front matter YAML, legível em qualquer editor ou no
  Obsidian; edições feitas fora aparecem na hora.
- **Sua pasta, onde quiser**: deixe a biblioteca no iCloud Drive, Dropbox ou Syncthing para usá-la
  em vários Macs.
- **Prateleira**: enquanto arrasta qualquer coisa (arquivos, pastas, imagens, textos, links),
  sacuda o mouse e uma prateleira aparece sob o cursor. Solte ali, vá aonde precisar e arraste de
  volta depois. Você também pode soltar coisas no ícone da barra de menus.
- **No seu idioma**: English, Português (Brasil), Español e Français. O Stash segue o idioma do
  seu Mac; para escolher outro só para ele, use **Ajustes do Sistema › Geral › Idioma e Região ›
  Aplicativos**.
- **Nativo**: modo claro e escuro, VoiceOver, Reduzir Movimento e Reduzir Transparência.

## Instalação

Com o [Homebrew](https://brew.sh):

```sh
brew install --cask s4mu3ldemolidor/tap/stash-references
```

Ou manualmente:

1. Baixe o **`Stash-x.y.z.dmg`** da [versão mais recente](https://github.com/S4MU3LDemolidor/stash/releases/latest).
2. Abra e arraste o **Stash** para **Aplicativos**.
3. Abra o Stash em Aplicativos. Ele ainda não é notarizado pela Apple, então na primeira vez o
   macOS o bloqueia: abra **Ajustes do Sistema › Privacidade e Segurança**, role até o fim e
   clique em **Abrir Mesmo Assim** (no macOS 14 você também pode clicar com o botão direito no app
   › **Abrir**). Ou, no Terminal:
   ```sh
   xattr -dr com.apple.quarantine /Applications/Stash.app
   ```
4. O Stash fica na **barra de menus** (o ícone de bandeja); ele não tem ícone no Dock. Na primeira
   vez, um aviso mostra o atalho. Aperte `⌥⇧S` para capturar.

Como o Stash ainda não é notarizado, com o Homebrew a primeira abertura também precisa do
**Abrir Mesmo Assim** (passo 3). O Homebrew o atualiza com `brew upgrade`.

Requer macOS 14 Sonoma ou posterior. Para abrir o Stash automaticamente, ative **Ajustes › Abrir ao
iniciar sessão**.

## Como usar

### Captura

1. Aperte `⌥⇧S` em qualquer lugar.
2. O painel mostra o que vai ser salvo: a aba atual do navegador, algo que você acabou de copiar,
   ou um cartão vazio para colar, digitar ou soltar algo.
3. Se quiser, digite uma nota com `#tags`.
4. Aperte `↵`. O painel fecha e **Salvo no Stash** confirma. (`⌘↵` salva e mantém o painel aberto
   para a próxima.)

Se já estiver na sua biblioteca (a mesma página, mesmo compartilhada com parâmetros de
rastreamento; o mesmo momento de um vídeo; o mesmo texto, imagem ou arquivo), o cartão diz
**Já salvo** e `↵` adiciona sua nota e suas tags àquela referência. `⌥↵` salva uma cópia separada
mesmo assim.

### Biblioteca

Aperte `⌥⇧L`, digite para buscar, `↑ ↓` para mover, `↵` para abrir. `#tag` e `type:` viram
filtros (`⌫` com o campo vazio remove o último). Nenhum resultado? `↵` salva sua busca como nota.

### Prateleira

1. Comece a arrastar algo: um arquivo no Finder, uma imagem ou um link no navegador, um texto.
2. Sacuda o mouse para os lados. Uma prateleira aparece sob o cursor; solte em cima dela.
3. Depois, arraste a pilha para levar tudo, ou clique nela e arraste itens soltos.

Arrastar para fora funciona como terminar o arraste original: o Finder move um arquivo dentro do
mesmo disco e copia para outro. Segure `⌥` para copiar e mantê-lo na prateleira também. A
prateleira fica na tela enquanto tiver algo (inclusive depois de reiniciar), e o `×` a limpa.
Arquivos na prateleira são referências aos originais, nunca cópias, então vídeos grandes não
custam nada. Soltar coisas no ícone da barra de menus também as coloca na prateleira. Desative a
sacudida em **Ajustes › Prateleira**.

### Teclado

| Tecla | Captura | Biblioteca |
|---|---|---|
| `↵` | Salvar | Abrir |
| `⌘↵` | Salvar e manter o painel aberto | Abrir no momento salvo |
| `⌥↵` | Salvar uma cópia de algo já salvo | |
| `⇥` | Ir para a Biblioteca | Ir para a Captura |
| `↑ ↓ ← →` | Escolher uma tag sugerida | Mover a seleção (← → na grade) |
| `⌘K` | | Ações |
| `⌘G` | | Grade / lista |
| `⌘E` | | Editar nota e tags |
| `⌘C` | | Copiar link, texto, imagem ou arquivo |
| `⌘⇧F` | | Mostrar no Finder |
| `⌘⌫` | Limpar o que foi capturado | Apagar (pergunta antes) |
| `⌘V` | Trocar a captura pelo que está copiado | Colar na busca |
| `⌘,` | Ajustes | Ajustes |
| `Esc` | Fechar | Limpar a busca, depois fechar |

Os dois atalhos globais podem ser trocados em **Ajustes › Atalhos**.

### Ajustes

Atalhos · pasta da biblioteca (escolher, mostrar, refazer o índice) · buscar títulos e miniaturas
· quão recente algo copiado precisa ser para ser oferecido (30 s, 1 min, 5 min, desativado) ·
sacudir para abrir a prateleira · abrir ao iniciar sessão · mostrar o ícone na barra de menus. Se
esconder o ícone, abra o Stash de novo pelo Finder ou pelo Spotlight para voltar aos Ajustes.

## Permissões

O Stash pede o mínimo possível, e só quando precisa:

- **Automação (controlar o navegador)**: na primeira vez que você captura de um navegador, o
  macOS pergunta se o Stash pode controlá-lo. O Stash só lê o endereço e o título da aba atual (e,
  no YouTube, a posição do vídeo). Mude quando quiser em **Ajustes do Sistema › Privacidade e
  Segurança › Automação**.
- **Momentos do YouTube** precisam que o navegador permita JavaScript de Apple Events. Isso vem
  desligado; o Stash mostra uma dica uma vez se não conseguir ler a posição:
  - Chrome, Brave, Edge, Arc: **Visualizar › Desenvolvedor › Permitir JavaScript de Apple Events**.
  - Safari: **Ajustes › Avançado › Mostrar recursos para desenvolvedores web**, depois **Ajustes ›
    Desenvolvedor › Permitir JavaScript de Apple Events**.

  Sem isso, o Stash mantém o `t=` que já estiver no link.
- **Abrir ao iniciar sessão** (opcional) usa os Itens de Início padrão.

O Stash não precisa de Acessibilidade, Gravação de Tela, Acesso Total ao Disco nem de nenhuma
outra permissão.

## Privacidade

- **Seus dados nunca saem do seu Mac.** Sem conta, sem servidor, sem analytics, sem telemetria,
  sem relatórios de falhas.
- **Os únicos acessos à rede** buscam o título, a imagem de prévia e o ícone dos links que você
  salva, no próprio site (no YouTube: o endpoint público de oEmbed e as miniaturas). Nenhum cookie
  é enviado ou guardado. Desative em **Ajustes › Capturar › Buscar títulos e miniaturas** e o Stash
  não faz nenhum acesso à rede.
- **O texto nas imagens** é lido no seu Mac pelo Vision da Apple e fica só no índice de busca;
  seus arquivos não mudam.
- **A prateleira** também fica no seu Mac: arquivos são guardados como referências aos originais,
  e imagens, textos e links arrastados como pequenas cópias privadas em
  `~/Library/Application Support/Stash/Shelf/`. Ela nunca mexe na sua biblioteca nem na rede, e o
  Stash nunca move nem apaga um original por conta própria.
- **A área de transferência** só é lida quando você abre a Captura, e só se você copiou algo há
  pouco. Nada que um gerenciador de senhas marque como secreto é capturado, e o que você copia do
  próprio Stash não é oferecido de volta.

## Onde ficam seus dados

```
~/Stash/                      ← a biblioteca (mude nos Ajustes, por exemplo para o iCloud Drive)
  items/
    2026-10-14-great-hook-in-the-first-3s.md
  assets/
    01JA8K3Q7Z2M4X5C6V7B8N9P0Q.jpg     ← miniaturas, imagens e arquivos, com o ID da referência
    icons/youtube.com.png              ← um ícone por site

~/Library/Application Support/Stash/
  index.sqlite                ← índice de busca (e texto lido das imagens); um cache, refeito a partir dos arquivos quando quiser
  Shelf/                      ← o que está na prateleira (shelf.json + cópias privadas em Items/)
```

Cada referência é um arquivo Markdown com um pequeno cabeçalho:

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

Referências de texto guardam o texto salvo no corpo e a nota num campo `note:`. O Stash preserva
os campos do cabeçalho que não conhece, então você pode adicionar os seus (no Obsidian, por
exemplo).

**Vários Macs:** em **Ajustes › Biblioteca › Escolher…**, mova a biblioteca para o iCloud Drive, o
Dropbox ou uma pasta do Syncthing. No outro Mac, escolha a mesma pasta: o Stash percebe que ela já
tem uma biblioteca e a usa. Apagar uma referência manda os arquivos dela para o Lixo.

**Se o Stash sumir amanhã**, sua biblioteca continua sendo uma pasta de arquivos Markdown e
imagens.

## Compilar a partir do código

Requer macOS 14+ e um **Xcode** recente (testado com o Xcode 27; só as Command Line Tools não
bastam, uma dependência precisa das macros do Xcode).

```sh
git clone https://github.com/S4MU3LDemolidor/stash.git
cd stash
scripts/run.sh
```

O `scripts/run.sh` compila `build/Stash.app`, encerra qualquer cópia aberta e abre a nova.

| Comando | O que faz |
|---|---|
| `scripts/run.sh` | Compila e abre o app |
| `scripts/build-app.sh` | Compila `build/Stash.app` (release, assinatura ad-hoc) |
| `scripts/make-dmg.sh` | Compila o app e `build/Stash-<versão>.dmg` |
| `swift test` | Roda os testes |
| `scripts/check-strings.sh` | Confere os textos de cada idioma com o código |
| `swift scripts/make-icon.swift` | Gera de novo `Support/AppIcon.icns` a partir da arte do ícone |

Defina `STASH_VERSION` (e, se quiser, `STASH_BUILD`) para builds com versão, por exemplo
`STASH_VERSION=0.3.0 scripts/make-dmg.sh`.

**Traduções:** `Support/Localization/<idioma>.lproj/Localizable.strings`, uma tabela por idioma,
em que cada chave é o texto em inglês. Depois de mudar textos da interface, rode
`scripts/check-strings.sh sync-en` para atualizar a tabela em inglês e traduza as chaves novas
(`scripts/check-strings.sh missing pt-BR` lista quais faltam). O CI falha quando falta um texto em
algum idioma.

**Site:** `site/` é publicado no GitHub Pages a cada push na `main` que o altera (veja
[`.github/workflows/pages.yml`](.github/workflows/pages.yml)). `site/index.html` é a página em
inglês; `python3 site/i18n/build.py` gera os outros idiomas a partir de `site/i18n/*.json`. Para
ver localmente: `python3 site/i18n/build.py && python3 -m http.server 8080 --directory site`.

**Homebrew:** o cask fica em [S4MU3LDemolidor/homebrew-tap](https://github.com/S4MU3LDemolidor/homebrew-tap)
(o código-fonte dele está em [`packaging/homebrew-tap`](packaging/homebrew-tap)) e se atualiza
sozinho todo dia a partir da versão mais recente.

**Versões:** enviar uma tag como `v0.1.0` faz o GitHub Actions compilar, testar e publicar
`Stash-0.1.0.dmg` e `Stash-0.1.0.zip` (veja [`.github/workflows/build.yml`](.github/workflows/build.yml)).

**Ajudas para desenvolvimento:**

- Segure `⌥` ao abrir o menu da barra de menus para ver comandos de debug (gerar ou remover 200
  referências de exemplo, com a tag `#sample`).
- `open build/Stash.app --args -libraryPath /tmp/stash-test` usa outra biblioteca por uma execução.
- `open build/Stash.app --args -StashShowPanel library` abre o painel ao iniciar.
- `open build/Stash.app --args -AppleLanguages "(pt-BR)"` abre o Stash em outro idioma.
- Builds de debug (`.build/debug/Stash`) podem ser controlados por scripts: veja
  [`Sources/Stash/App/DebugHooks.swift`](Sources/Stash/App/DebugHooks.swift).

### Estrutura do projeto

```
Sources/Stash/
  App/          ponto de entrada, barra de menus, comandos de debug
  Panel/        o painel flutuante e seu mapa de teclas
  Capture/      aba do navegador, área de transferência, colar e soltar, salvar, duplicados
  Library/      busca, lista, painel de detalhes, grade, ações do ⌘K
  Components/   barra de busca, barra de ações, teclas, filtros, HUD
  Model/        referências, tags, slugs, IDs
  Storage/      arquivos Markdown, sincronia da pasta, índice de busca (GRDB + FTS5), texto nas imagens
  Enrichment/   YouTube, títulos e miniaturas
  Settings/     preferências e a janela de Ajustes
  Shelf/        a prateleira que abre com uma sacudida
  Design/       tokens de design e a marca do Stash
Support/        Info.plist, entitlements, ícone do app, traduções (Localization/)
docs/           arquivos da marca e capturas de tela
site/           o site (HTML, CSS e JS simples; publicado no GitHub Pages)
packaging/      o código-fonte do tap do Homebrew
```

Feito com Swift, SwiftUI e AppKit, mais duas bibliotecas:
[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (atalhos globais) e
[GRDB.swift](https://github.com/groue/GRDB.swift) (busca de texto completo no SQLite).

Veja o [CONTRIBUTING.md](CONTRIBUTING.md) (em inglês) para princípios e convenções.

## Marca

O logo e o ícone do app ficam em [`docs/brand`](docs/brand). O ícone da barra de menus é a mesma
marca, desenhada em vetores em [`StashMark.swift`](Sources/Stash/Design/StashMark.swift) para
ficar nítida e acompanhar a aparência clara ou escura da barra de menus.

## Licença

MIT. Veja [LICENSE](LICENSE).
