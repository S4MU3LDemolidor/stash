// Page behavior: nav state, scroll reveals, copy button, and download links that point
// straight at the latest release's .dmg on GitHub.
(() => {
  const REPO = "S4MU3LDemolidor/stash";

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

  // Copy the build-from-source commands.
  for (const button of document.querySelectorAll("[data-copy]")) {
    button.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(button.dataset.copy);
        button.textContent = "Copied";
      } catch {
        button.textContent = "Select and copy";
      }
      setTimeout(() => (button.textContent = "Copy"), 1600);
    });
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
