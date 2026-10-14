// The hero demo: an HTML copy of the Stash panel acting out Capture, Library, Grid and ⌘K.
// Sample content is made up and drawn with CSS, so the page carries no third-party images.
(() => {
  const root = document.getElementById("demo");
  if (!root) return;

  const stage = root.querySelector("[data-stage]");
  const inner = root.querySelector("[data-stage-inner]");
  const panel = root.querySelector("[data-panel]");
  const hud = root.querySelector("[data-hud]");
  const address = root.querySelector(".address");
  const tabs = [...root.querySelectorAll("[data-tab]")];
  const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;

  // The stage is designed at 960×600 and scaled to the column. On phones it crops to the
  // panel (750 wide at x 105) so the panel stays as large as possible.
  const fit = () => {
    const narrow = stage.clientWidth < 700;
    const scale = stage.clientWidth / (narrow ? 790 : 960);
    stage.classList.toggle("narrow", narrow);
    inner.style.setProperty("--scale", scale);
    inner.style.setProperty("--shift", `${narrow ? -85 * scale : 0}px`);
  };
  new ResizeObserver(fit).observe(stage);
  fit();
  root.querySelector(".video-art").innerHTML = art("hooks", 72);

  const keystroke = document.createElement("div");
  keystroke.className = "keystroke";
  inner.append(keystroke);

  // ── Sample library ──────────────────────────────────

  const ITEMS = [
    { title: "How I Write Hooks That Stop the Scroll", sub: "youtube.com · at 4:32", time: "1m ago", icon: "yt", art: "hooks", tags: ["hooks", "thumbnails"], note: "great hook in the first 3s", meta: [["Site", "youtube.com"], ["Saved", "Today, 10:20"], ["Timestamp", "4:32"], ["Type", "YouTube video"]] },
    { title: "Black Friday ad", sub: "Image · 1080×1350", time: "12m ago", icon: "img", art: "ad", tags: ["ads", "hooks"], note: "price first, product second", meta: [["Size", "1080 × 1350"], ["Saved", "Today, 10:09"], ["Type", "Image"]] },
    { title: "Make the viewer the hero, not the brand.", sub: "Text", time: "1h ago", icon: "txt", quote: true, tags: ["copy"], note: "from the workshop", meta: [["Saved", "Today, 9:14"], ["Type", "Text"]] },
    { title: "Landing Page Teardown", sub: "growth.design", time: "2h ago", icon: "link", art: "landing", tags: ["landing"], note: "the pricing table trick", meta: [["Site", "growth.design"], ["Saved", "Today, 8:02"], ["Type", "Link"]] },
    { title: "Pacing Tricks from Movie Trailers", sub: "youtube.com · at 10:10", time: "3h ago", icon: "yt", art: "trailer", tags: ["hooks", "editing"], note: "cut on the beat, not the line", meta: [["Site", "youtube.com"], ["Saved", "Today, 7:31"], ["Timestamp", "10:10"], ["Type", "YouTube video"]] },
    { title: "Brand guidelines 2026.pdf", sub: "File · PDF · 24 pages", time: "1d ago", icon: "file", art: "pdf", tags: ["brand"], note: "", meta: [["Size", "4.2 MB"], ["Saved", "Yesterday, 18:40"], ["Type", "PDF"]], day: "Yesterday" },
    { title: "Holiday edit", sub: "Image · 1080×1080", time: "1d ago", icon: "img", art: "holiday", tags: ["ads"], note: "", meta: [["Size", "1080 × 1080"], ["Type", "Image"]], day: "Yesterday" },
    { title: "Serif headlines", sub: "Image · 1600×1200", time: "1d ago", icon: "img", art: "type", tags: ["typography"], note: "", meta: [["Type", "Image"]], day: "Yesterday" },
  ];
  const TAGS = [["hooks", 12], ["home-pages", 3], ["thumbnails", 8], ["typography", 5], ["inspiration", 9]];
  const ACTIONS = [["Open", ["↵"]], ["Open at 4:32", ["⌘", "↵"]], ["Copy Link", ["⌘", "C"]], ["Edit Note & Tags", ["⌘", "E"]], ["Reveal in Finder", ["⌘", "⇧", "F"]], ["Show as Grid", ["⌘", "G"]], ["Delete", ["⌘", "⌫"], true]];

  // ── Rendering ───────────────────────────────────────

  const ICON_CAPTURE = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 13.5h4.8l1.4 2.5h4.6l1.4-2.5h4.8"/><path d="M3.5 13.5V19a1.5 1.5 0 0 0 1.5 1.5h14a1.5 1.5 0 0 0 1.5-1.5v-5.5L18 7h-2.5M8.5 7H6l-2.5 6.5"/><path d="M12 3v8.5m-3.2-3.2L12 11.5l3.2-3.2"/></svg>';
  const ICON_SEARCH = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="10.5" cy="10.5" r="6.5"/><path d="m15.5 15.5 5 5"/></svg>';

  function art(name, size) {
    if (!name) return "";
    return `<span class="art art-${name}" style="--fs:${size}px"></span>`;
  }

  const keys = (list) => list.map((k) => `<span class="k">${k}</span>`).join("");
  const action = (label, k, primary) => `<span class="p-action${primary ? " primary" : ""}">${label} ${keys(k)}</span>`;
  const bar = (context, actions) =>
    `<div class="p-bar"><img class="p-glyph" src="assets/mark.png" alt="">${context}<div class="p-actions">${actions.join('<span class="p-sep"></span>')}</div></div>`;

  function field({ text = "", placeholder = "", pills = [], token = "" }) {
    const pillHTML = pills.map((p) => `<span class="p-pill">${p} <i>×</i></span>`).join("");
    const empty = !text && !token;
    const content = empty
      ? `<span class="p-caret"></span>${pills.length ? "" : `<span class="p-placeholder">${placeholder}</span>`}`
      : `${escape(text)}<span data-token>${escape(token)}</span><span class="p-caret"></span>`;
    return `${pillHTML}<span class="p-text">${content}</span>`;
  }

  function renderCapture(state) {
    const it = ITEMS[0];
    panel.dataset.mode = "capture";
    patch(`
      <div class="p-search">${ICON_CAPTURE}<div class="p-field">${field({ text: state.note, token: state.token, placeholder: "Add a note or #tags… (optional)" })}</div><span class="p-mode">Capture</span></div>
      <div class="p-body">
        <div class="p-card"><div class="p-thumb">${art(it.art, 13)}</div><div class="p-card-text"><div class="p-title">${it.title}</div><div class="p-sub">${it.sub}</div></div><span class="p-badge">From Arc</span></div>
        ${state.suggest ? suggestions(state.suggest) : ""}
      </div>
      ${bar("Saving to ~/Stash", [action("Save", ["↵"], true), action("Library", ["⇥"])])}`);
    if (state.suggest) placeSuggestions();
  }

  function suggestions(prefix) {
    const rows = TAGS.filter(([t]) => t.startsWith(prefix)).slice(0, 4);
    return `<div class="p-suggest">${rows.map(([t, n], i) => `<div class="${i ? "" : "sel"}">#${t}<small>${n}</small></div>`).join("")}</div>`;
  }

  function placeSuggestions() {
    const token = panel.querySelector("[data-token]");
    const box = panel.querySelector(".p-suggest");
    if (token && box) box.style.setProperty("--at", `${token.offsetLeft + 46 - 10}px`);
  }

  function rowHTML(it, selected) {
    const icon = it.icon === "img" || it.icon === "file" ? `<span class="p-icon ${it.icon}">${art(it.art, 6)}</span>`
      : it.icon === "txt" ? '<span class="p-icon txt">❝</span>'
      : it.icon === "link" ? '<span class="p-icon">G</span>'
      : `<span class="p-icon ${it.icon}"></span>`;
    return `<div class="p-row${selected ? " sel" : ""}">${icon}<div class="p-row-text"><div class="p-title">${it.title}</div><div class="p-sub">${it.sub}</div></div><span class="p-time">${it.time}</span></div>`;
  }

  function detailHTML(it) {
    const media = it.quote ? `<div class="p-quote">${it.title}</div>` : `<div class="p-media">${art(it.art, 34)}</div>`;
    const title = it.quote ? "" : `<h4>${it.title}</h4>`;
    const note = it.note ? `<p class="p-note">${it.note}</p>` : "";
    const meta = it.meta.map(([k, v]) => `<dt>${k}</dt><dd>${v}</dd>`).join("");
    const tags = `<dt>Tags</dt><dd class="p-tags">${it.tags.map((t) => `<span class="p-tag">#${t}</span>`).join("")}</dd>`;
    return `<div class="p-detail">${media}${title}${note}<dl class="p-meta">${meta}${tags}</dl></div>`;
  }

  function renderLibrary(state) {
    const items = state.items;
    const selected = items[state.sel];
    let html = "";
    let day = null;
    items.forEach((it, i) => {
      const d = it.day || "Today";
      if (d !== day) { html += `<div class="p-section">${d}</div>`; day = d; }
      html += rowHTML(it, i === state.sel);
    });
    const body = state.grid
      ? `<div class="p-grid">${items.map((it, i) => `<div class="p-tile${i === state.sel ? " sel" : ""}"><div class="p-media">${it.quote ? `<span class="art art-text">${it.title}</span>` : art(it.art, 26)}</div><span>${it.title}</span></div>`).join("")}</div>`
      : `<div class="p-list">${html}</div>${detailHTML(selected)}`;
    const menu = state.menu ? menuHTML(state.menu) : "";
    panel.dataset.mode = state.grid ? "grid" : "library";
    patch(`
      <div class="p-search">${ICON_SEARCH}<div class="p-field">${field({ text: state.query, pills: state.pills, placeholder: "Search references…" })}</div><span class="p-mode">Library</span></div>
      <div class="p-body">${body}${menu}</div>
      ${bar(`${state.count ?? 204} references`, [action("Open", ["↵"], true), action("Actions", ["⌘", "K"])])}`);
  }

  function menuHTML({ query, sel }) {
    const rows = ACTIONS.filter(([t]) => t.toLowerCase().includes(query.toLowerCase()));
    return `<div class="p-menu"><div class="p-menu-search">${query ? escape(query) + '<span class="p-caret"></span>' : "Search actions…"}</div><div class="p-menu-rows">${rows
      .map(([t, k, danger], i) => `<div class="p-menu-row${i === sel ? " sel" : ""}${danger ? " danger" : ""}">${t}<span class="keys">${keys(k)}</span></div>`)
      .join("")}</div></div>`;
  }

  // Update the panel in place, touching only what changed, so unchanged parts keep their
  // state (no re-run entrance animations, steady caret) the way the real views do.
  function patch(html) {
    const next = document.createElement("div");
    next.innerHTML = html.trim();
    morphChildren(panel, next);
  }

  function morphChildren(from, to) {
    const a = [...from.childNodes];
    const b = [...to.childNodes];
    b.forEach((node, i) => (a[i] ? morph(a[i], node) : from.append(node)));
    a.slice(b.length).forEach((node) => node.remove());
  }

  function morph(from, to) {
    if (from.nodeType !== to.nodeType || from.nodeName !== to.nodeName) return from.replaceWith(to);
    if (from.nodeType === Node.TEXT_NODE) {
      if (from.data !== to.data) from.data = to.data;
      return;
    }
    if (from.isEqualNode(to)) return;
    for (const { name } of [...from.attributes]) if (!to.hasAttribute(name)) from.removeAttribute(name);
    for (const { name, value } of [...to.attributes]) if (from.getAttribute(name) !== value) from.setAttribute(name, value);
    morphChildren(from, to);
  }

  function escape(s) {
    return s.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" })[c]);
  }

  // ── Timeline helpers ────────────────────────────────

  let run = 0;
  const CANCEL = Symbol("cancel");
  const sleep = (ms, id) => new Promise((resolve, reject) => setTimeout(() => (id === run ? resolve() : reject(CANCEL)), ms));

  function openPanel(open) {
    panel.classList.toggle("open", open);
    inner.classList.toggle("panel-open", open);
  }

  async function press(id, list, hold = 520) {
    keystroke.innerHTML = list.map((k) => `<span>${k}</span>`).join("");
    keystroke.classList.add("show");
    await sleep(hold, id);
    keystroke.classList.remove("show");
  }

  async function type(id, text, onChar) {
    for (const ch of text) {
      onChar(ch);
      await sleep(38 + Math.random() * 55, id);
    }
  }

  // ── Scenes ──────────────────────────────────────────

  const SCENES = {
    async capture(id) {
      const s = { note: "", token: "", suggest: null };
      openPanel(false);
      address.textContent = "youtube.com/watch?v=hooks";
      await sleep(700, id);
      await press(id, ["⌥", "⇧", "S"]);
      renderCapture(s);
      openPanel(true);
      await sleep(900, id);
      await type(id, "great hook in the first 3s ", (c) => { s.note += c; renderCapture(s); });
      for (const [partial, tag] of [["#ho", "hooks"], ["#thu", "thumbnails"]]) {
        await type(id, partial, (c) => {
          s.token += c;
          s.suggest = s.token.length > 1 ? s.token.slice(1) : null;
          renderCapture(s);
        });
        await sleep(650, id);
        await press(id, ["⇥"], 380);
        s.note += `#${tag} `;
        s.token = "";
        s.suggest = null;
        renderCapture(s);
        await sleep(350, id);
      }
      await sleep(500, id);
      await press(id, ["↵"], 380);
      panel.classList.add("closing");
      openPanel(false);
      hud.classList.add("show");
      await sleep(1300, id);
      hud.classList.remove("show");
      panel.classList.remove("closing");
      await sleep(900, id);
    },

    async library(id) {
      const s = { items: ITEMS, sel: 0, query: "", pills: [] };
      renderLibrary(s);
      openPanel(true);
      await sleep(1100, id);
      await type(id, "#hooks", (c) => { s.query += c; renderLibrary(s); });
      await sleep(250, id);
      Object.assign(s, { query: "", pills: ["#hooks"], items: ITEMS.filter((it) => it.tags.includes("hooks")), count: 3 });
      renderLibrary(s);
      await sleep(1000, id);
      for (const [key, step] of [["↓", 1], ["↓", 1], ["↑", -1]]) {
        await press(id, [key], 300);
        s.sel += step;
        renderLibrary(s);
        await sleep(1000, id);
      }
      await sleep(600, id);
    },

    async grid(id) {
      const s = { items: ITEMS, sel: 0, query: "", pills: [] };
      renderLibrary(s);
      openPanel(true);
      await sleep(800, id);
      await press(id, ["⌘", "G"]);
      s.grid = true;
      renderLibrary(s);
      await sleep(900, id);
      for (const [key, to] of [["→", 1], ["→", 2], ["↓", 6], ["←", 5]]) {
        await press(id, [key], 300);
        s.sel = to;
        renderLibrary(s);
        await sleep(800, id);
      }
      await sleep(700, id);
    },

    async actions(id) {
      const s = { items: ITEMS, sel: 0, query: "", pills: [] };
      address.textContent = "youtube.com/watch?v=hooks";
      renderLibrary(s);
      openPanel(true);
      await sleep(900, id);
      await press(id, ["⌘", "K"]);
      s.menu = { query: "", sel: 0 };
      renderLibrary(s);
      await sleep(900, id);
      await type(id, "open", (c) => { s.menu.query += c; renderLibrary(s); });
      await sleep(500, id);
      await press(id, ["↓"], 300);
      s.menu.sel = 1;
      renderLibrary(s);
      await sleep(800, id);
      await press(id, ["↵"], 380);
      panel.classList.add("closing");
      openPanel(false);
      address.textContent = "youtube.com/watch?v=hooks&t=272s";
      await sleep(1600, id);
      panel.classList.remove("closing");
    },
  };

  // Still frames for Reduce Motion: each tab shows its most telling moment.
  const STILLS = {
    capture: () => renderCapture({ note: "great hook in the first 3s #hooks ", token: "#thu", suggest: "thu" }),
    library: () => renderLibrary({ items: ITEMS.filter((it) => it.tags.includes("hooks")), sel: 0, query: "", pills: ["#hooks"], count: 3 }),
    grid: () => renderLibrary({ items: ITEMS, sel: 1, query: "", pills: [], grid: true }),
    actions: () => renderLibrary({ items: ITEMS, sel: 0, query: "", pills: [], menu: { query: "", sel: 1 } }),
  };

  // ── Tabs and autoplay ───────────────────────────────

  const ORDER = tabs.map((t) => t.dataset.tab);
  let current = 0;

  function select(index) {
    current = index;
    tabs.forEach((t, i) => t.setAttribute("aria-selected", String(i === index)));
  }

  async function play(index) {
    const id = ++run;
    select(index);
    const name = ORDER[index];
    if (reduced) { STILLS[name](); openPanel(true); return; }
    // The selected tab's underline fills over the scene's length.
    const started = performance.now();
    const tick = () => {
      if (id !== run) return;
      const p = Math.min(1, (performance.now() - started) / DURATION[name]);
      tabs.forEach((t, i) => t.querySelector(".tab-progress").style.transform = `scaleX(${i === index ? p : 0})`);
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
    try {
      await SCENES[name](id);
      if (id === run) play((index + 1) % ORDER.length);
    } catch (e) {
      if (e !== CANCEL) throw e;
    }
  }

  // Rough scene lengths, only for the tab's progress bar.
  const DURATION = { capture: 12500, library: 9000, grid: 7800, actions: 8200 };

  tabs.forEach((tab, i) => tab.addEventListener("click", () => play(i)));

  // Only play while the stage is on screen; restart the current scene when it returns.
  let visible = false;
  new IntersectionObserver(([entry]) => {
    if (entry.isIntersecting === visible) return;
    visible = entry.isIntersecting;
    if (visible) play(current);
    else run++;
  }, { threshold: 0.25 }).observe(stage);
})();
