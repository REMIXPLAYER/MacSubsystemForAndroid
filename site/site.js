// Mac Subsystem for Android website: menu bar clock, the performance-mode explorer,
// and download links from the latest release.
(() => {
  const repo = "__REPO__";

  const clock = document.getElementById("clock");
  const tick = () => {
    if (clock) clock.textContent = new Date().toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  };
  tick();
  setInterval(tick, 15000);

  // Performance modes. Values mirror PerformanceProfile.swift
  // (cores online, memory kept, frame rate cap); energy is a rough guide.
  const modes = {
    saver: {
      title: "Power Saver",
      text: "A hybrid of saving power and Smart. Android only runs while an Android app is open and turns off 30 seconds after the last one closes. While it runs it saves power (efficiency cores, two cores online, 40% of its memory back to macOS, Android's battery saver, 30 fps) and steps up to Balanced for the app in front when your Mac is plugged in and not busy.",
      cpu: [30, "25–50%"], mem: [65, "60–85%"], fps: [30, "30–60"], energy: [18, "lowest"],
    },
    smart: {
      title: "Smart",
      text: "Stays ready in the background so apps open instantly, and keeps adapting: full speed for the app you're using, and power saving the moment other Mac apps need the processor or memory, the battery runs low, Low Power Mode is on or your Mac gets hot.",
      cpu: [62, "25–100%"], mem: [80, "60–100%"], fps: [50, "30–120"], energy: [40, "adapts"],
    },
    standard: {
      title: "Standard",
      text: "Android runs as it is, with nothing tuned: every processor core, all of its memory and its own power settings, at normal priority. It stays ready in the background.",
      cpu: [100, "100%"], mem: [100, "100%"], fps: [50, "60 fps"], energy: [70, "high"],
    },
    performance: {
      title: "Performance",
      text: "Maximum performance, all the time: every core and all of Android's memory, Android's fixed-performance and game modes, a higher-quality stream, up to 120 fps on ProMotion displays and lower input latency.",
      cpu: [100, "100%"], mem: [100, "100%"], fps: [100, "120 fps"], energy: [92, "highest"],
    },
  };

  const tabs = Array.from(document.querySelectorAll(".mode-tab"));
  const show = (key) => {
    const mode = modes[key];
    if (!mode) return;
    tabs.forEach((tab) => {
      const on = tab.dataset.mode === key;
      tab.setAttribute("aria-selected", on ? "true" : "false");
      tab.tabIndex = on ? 0 : -1;
    });
    document.getElementById("mode-title").textContent = mode.title;
    document.getElementById("mode-text").textContent = mode.text;
    for (const name of ["cpu", "mem", "fps", "energy"]) {
      document.getElementById(`m-${name}`).style.width = `${mode[name][0]}%`;
      document.getElementById(`v-${name}`).textContent = mode[name][1];
    }
    document.getElementById("smart-rules").hidden = key !== "smart";
  };
  tabs.forEach((tab, index) => {
    tab.addEventListener("click", () => show(tab.dataset.mode));
    tab.addEventListener("keydown", (event) => {
      const step = { ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1 }[event.key];
      if (!step) return;
      event.preventDefault();
      const next = tabs[(index + step + tabs.length) % tabs.length];
      next.focus();
      show(next.dataset.mode);
    });
  });
  if (tabs.length) show("smart");

  // Download buttons point at the newest app release's DMG (Android image releases have none).
  if (repo.includes("__")) return;
  fetch(`https://api.github.com/repos/${repo}/releases?per_page=10`, { headers: { Accept: "application/vnd.github+json" } })
    .then((response) => (response.ok ? response.json() : []))
    .then((releases) => {
      const release = releases.find((r) => !r.draft && r.assets.some((a) => a.name.endsWith(".dmg")));
      if (!release) return;
      const dmg = release.assets.find((a) => a.name.endsWith(".dmg"));
      for (const id of ["download", "download-2"]) {
        const link = document.getElementById(id);
        if (link) link.href = dmg.browser_download_url;
      }
      const line = document.getElementById("release-line");
      if (line) {
        const version = release.tag_name.replace(/^v/, "");
        const size = `${Math.round(dmg.size / 1048576)} MB`;
        line.textContent = `Version ${version}${release.prerelease ? " preview" : ""} · ${size} · Apple silicon · macOS 15 or later`;
      }
    })
    .catch(() => {});
})();
