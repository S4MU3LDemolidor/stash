// Page behavior: nav state, scroll reveals, copy button, and download links that point
// straight at the latest release's .dmg on GitHub.
(() => {
  const REPO = "S4MU3LDemolidor/stash";
  // Translated pages carry their strings (see site/i18n/build.py); English is the fallback.
  const STRINGS = window.STASH_I18N || {};
  const tr = (text) => STRINGS[text] ?? text;

  // Nav gets a glass background once the page scrolls.
  const nav = document.querySelector(".nav");
  const onScroll = () => nav.classList.toggle("scrolled", scrollY > 8);
  addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // Reveal sections as they come into view.
  const reveals = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        entry.target.classList.add("in");
        io.unobserve(entry.target);
      }
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.12 });
    reveals.forEach((el) => io.observe(el));
  } else {
    reveals.forEach((el) => el.classList.add("in"));
  }

  // The film plays (muted) while it's on screen, unless the viewer prefers reduced motion.
  const film = document.querySelector("[data-film]");
  if (film && "IntersectionObserver" in window && !matchMedia("(prefers-reduced-motion: reduce)").matches) {
    new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) film.play().catch(() => {});
      else film.pause();
    }, { threshold: 0.5 }).observe(film);
  }

  // Copy buttons (build from source, Homebrew).
  for (const button of document.querySelectorAll("[data-copy]")) {
    const label = button.textContent;
    button.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(button.dataset.copy);
        button.textContent = tr("Copied");
      } catch {
        button.textContent = tr("Select and copy");
      }
      setTimeout(() => (button.textContent = label), 1600);
    });
  }

  // Language menu: closes on outside click or Esc.
  const langMenu = document.querySelector("[data-lang-menu]");
  if (langMenu) {
    document.addEventListener("click", (e) => { if (!langMenu.contains(e.target)) langMenu.open = false; });
    document.addEventListener("keydown", (e) => { if (e.key === "Escape") langMenu.open = false; });
  }

  // Offer the visitor's language once, in that language. Never redirects.
  const OFFERS = {
    en: "This page is also in English",
    "pt-br": "Esta página também está em português",
    es: "Esta página también está en español",
    fr: "Cette page existe aussi en français",
  };
  const pageLanguage = document.documentElement.lang.toLowerCase();
  const wanted = (navigator.languages || [navigator.language]).map((l) => l.toLowerCase())
    .map((l) => (l.startsWith("pt") ? "pt-br" : l.slice(0, 2)))
    .find((l) => l in OFFERS);
  let dismissed = false;
  try { dismissed = localStorage.getItem("stash-language-offer") === "dismissed"; } catch {}
  const target = wanted && document.querySelector(`[data-lang="${wanted}"]`);
  if (target && !pageLanguage.startsWith(wanted.slice(0, 2)) && !dismissed) {
    const offer = document.createElement("div");
    offer.className = "lang-offer";
    offer.lang = target.lang;
    offer.innerHTML = `<a href="${target.getAttribute("href")}">${OFFERS[wanted]} <span aria-hidden="true">&rarr;</span></a><button type="button" aria-label="Close">&times;</button>`;
    offer.querySelector("button").addEventListener("click", () => {
      offer.remove();
      try { localStorage.setItem("stash-language-offer", "dismissed"); } catch {}
    });
    document.body.append(offer);
    requestAnimationFrame(() => offer.classList.add("show"));
  }

  // Download buttons already link to the latest release page. When GitHub answers, point them
  // at the .dmg itself and show the version. No cookies or tracking, just two public API reads.
  const cached = (key, url) => {
    try {
      const hit = JSON.parse(sessionStorage.getItem(key) || "null");
      if (hit) return Promise.resolve(hit);
    } catch {}
    return fetch(url, { headers: { Accept: "application/vnd.github+json" } })
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((json) => {
        try { sessionStorage.setItem(key, JSON.stringify(json)); } catch {}
        return json;
      });
  };

  cached("stash-release", `https://api.github.com/repos/${REPO}/releases/latest`)
    .then((release) => {
      const dmg = release.assets?.find((a) => a.name.endsWith(".dmg"));
      if (dmg) document.querySelectorAll("[data-download]").forEach((a) => (a.href = dmg.browser_download_url));
      const size = dmg ? ` · ${(dmg.size / 1e6).toFixed(1)} MB` : "";
      document.querySelectorAll("[data-version]").forEach((el) => (el.textContent = `${release.tag_name}${size}`));
    })
    .catch(() => {});

  cached("stash-repo", `https://api.github.com/repos/${REPO}`)
    .then((repo) => {
      const stars = repo.stargazers_count;
      // A count only helps once there is one worth showing.
      if (typeof stars !== "number" || stars < 5) return;
      const label = stars >= 1000 ? `${(stars / 1000).toFixed(1)}k` : String(stars);
      document.querySelectorAll("[data-stars]").forEach((el) => (el.textContent = `GitHub ★ ${label}`));
      document.querySelectorAll("[data-stars-full]").forEach((el) => (el.textContent = `★ ${label}`));
    })
    .catch(() => {});
})();
