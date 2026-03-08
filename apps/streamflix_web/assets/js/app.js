// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"

// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";

// Disable submit button and show loading text on form submit (login/signup and any form with data-submit-loading)
document.addEventListener("DOMContentLoaded", function () {
  document
    .querySelectorAll("form[data-submit-loading]")
    .forEach(function (form) {
      form.addEventListener("submit", function () {
        const btn = form.querySelector('button[type="submit"]');
        if (btn && !btn.disabled) {
          btn.disabled = true;
          const loadingText =
            btn.getAttribute("data-loading-text") || "Loading...";
          btn.dataset.originalText = btn.textContent;
          btn.textContent = loadingText;
        }
      });
    });
});

// Mobile menu toggle is handled by Phoenix.LiveView.JS commands in the navbar component

// Password visibility toggle (login/signup): accessible show/hide
document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll("[data-password-toggle]").forEach(function (wrap) {
    const input = wrap.querySelector("input[type=password], input[type=text]");
    const btn = wrap.querySelector("[data-password-toggle-btn]");
    if (!input || !btn) return;
    const labelShow = "Mostrar contraseña";
    const labelHide = "Ocultar contraseña";
    const iconShow = wrap.querySelector("[data-icon-show]");
    const iconHide = wrap.querySelector("[data-icon-hide]");
    btn.addEventListener("click", function () {
      const isPass = input.type === "password";
      input.type = isPass ? "text" : "password";
      btn.setAttribute("aria-label", isPass ? labelHide : labelShow);
      if (iconShow) iconShow.classList.toggle("hidden", !isPass);
      if (iconHide) iconHide.classList.toggle("hidden", isPass);
    });
  });
});

// Password strength indicator (signup/reset-password)
document.addEventListener("DOMContentLoaded", function () {
  document
    .querySelectorAll("[data-password-strength]")
    .forEach(function (input) {
      const bar = document.getElementById(
        input.getAttribute("data-password-strength"),
      );
      if (!bar) return;
      const fill = bar.querySelector("[data-strength-fill]");
      const label = bar.querySelector("[data-strength-label]");
      if (!fill || !label) return;

      const colors = ["bg-red-500", "bg-orange-500", "bg-yellow-500", "bg-emerald-500"];
      const labels = {
        en: ["Weak", "Fair", "Good", "Strong"],
        es: ["Débil", "Regular", "Buena", "Fuerte"],
      };

      function getLocale() {
        const m = document.cookie.match(/locale=(es|en)/);
        return m ? m[1] : "en";
      }

      function score(pw) {
        if (!pw || pw.length < 8) return 0;
        let s = 1;
        if (pw.length >= 12) s++;
        if (/[A-Z]/.test(pw) && /[a-z]/.test(pw)) s++;
        if (/\d/.test(pw) && /[^A-Za-z0-9]/.test(pw)) s++;
        return Math.min(s, 4);
      }

      input.addEventListener("input", function () {
        const s = score(input.value);
        const locale = getLocale();
        const widths = ["0%", "25%", "50%", "75%", "100%"];

        bar.classList.toggle("hidden", input.value.length === 0);
        fill.style.width = widths[s];
        colors.forEach(function (c) {
          fill.classList.remove(c);
        });
        if (s > 0) fill.classList.add(colors[s - 1]);
        label.textContent = s > 0 ? (labels[locale] || labels.en)[s - 1] : "";
      });
    });
});

// Hero code demo: language tabs + run simulation
document.addEventListener("DOMContentLoaded", function () {
  const demo = document.getElementById("hero-code-demo");
  if (!demo) return;

  const panels = demo.querySelectorAll("[data-panel]");
  const tabs = demo.querySelectorAll(".hero-code-tab");
  const runBtn = demo.querySelector("#hero-run-btn");
  const statusEl = demo.querySelector("#hero-run-status");
  const responseArea = demo.querySelector("#hero-response-area");
  const responseJson = demo.querySelector("#hero-response-json");

  // Tab switching
  tabs.forEach(function (tab) {
    tab.addEventListener("click", function () {
      tabs.forEach(function (t) { t.classList.remove("active"); });
      panels.forEach(function (p) { p.classList.add("hidden"); });
      tab.classList.add("active");
      const lang = tab.getAttribute("data-lang");
      demo.querySelector('[data-panel="' + lang + '"]').classList.remove("hidden");
      // Reset response on tab switch
      responseArea.classList.add("hidden");
      responseJson.textContent = "";
      if (statusEl) statusEl.textContent = "";
      if (runBtn) runBtn.disabled = false;
    });
  });

  // Run simulation
  if (!runBtn) return;

  const fakeResponse = JSON.stringify({
    id: "evt_" + Math.random().toString(36).substring(2, 10),
    topic: "user.signup",
    payload: { user_id: "u_123", plan: "free" },
    deliveries: 1,
    created_at: new Date().toISOString()
  }, null, 2);

  runBtn.addEventListener("click", function () {
    if (runBtn.disabled) return;
    runBtn.disabled = true;
    responseArea.classList.add("hidden");
    responseJson.textContent = "";

    // Phase 1: "Sending..."
    statusEl.textContent = "Sending...";
    statusEl.style.opacity = "1";

    setTimeout(function () {
      // Phase 2: "Connected" + show response area
      var ms = 28 + Math.floor(Math.random() * 35);
      statusEl.textContent = ms + "ms";
      var badge = responseArea.querySelector(".hero-response-time");
      if (badge) badge.textContent = "~" + ms + "ms";
      responseArea.classList.remove("hidden");
      responseArea.style.opacity = "0";
      responseArea.style.transform = "translateY(8px)";

      // Animate in
      requestAnimationFrame(function () {
        responseArea.style.transition = "opacity 0.3s, transform 0.3s";
        responseArea.style.opacity = "1";
        responseArea.style.transform = "translateY(0)";
      });

      // Phase 3: Typewriter effect for JSON
      var i = 0;
      var speed = 8;
      function typeChar() {
        if (i < fakeResponse.length) {
          responseJson.textContent += fakeResponse.charAt(i);
          i++;
          setTimeout(typeChar, speed);
        } else {
          runBtn.disabled = false;
        }
      }
      typeChar();
    }, 600 + Math.floor(Math.random() * 400));
  });
});

// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

// Custom hooks for LiveView components
let Hooks = {};

// Password visibility toggle hook for LiveView inputs.
// Each hook instance keeps its own _visible state so LiveView re-renders
// (triggered by phx-change validation) never reset the input type.
Hooks.PasswordToggle = {
  mounted() {
    this._visible = false;
    this._bind();
  },
  updated() {
    // LiveView just patched the DOM → re-apply the saved visibility state
    // and re-bind the button in case morphdom replaced it
    this._apply();
    this._bind();
  },
  _bind() {
    const btn = this.el.querySelector("[data-pw-toggle-btn]");
    if (!btn || btn._pwBound) return;
    btn._pwBound = true;

    btn.addEventListener("click", () => {
      this._visible = !this._visible;
      this._apply();
    });
  },
  _apply() {
    const input = this.el.querySelector("input");
    const btn = this.el.querySelector("[data-pw-toggle-btn]");
    if (!input) return;

    input.type = this._visible ? "text" : "password";

    if (btn) {
      const iconShow = btn.querySelector("[data-pw-icon-show]");
      const iconHide = btn.querySelector("[data-pw-icon-hide]");
      if (iconShow) iconShow.classList.toggle("hidden", this._visible);
      if (iconHide) iconHide.classList.toggle("hidden", !this._visible);
    }
  },
};

// Copy to clipboard hook for API token section
Hooks.CopyClipboard = {
  mounted() {
    this.el.addEventListener("click", () => {
      const targetId = this.el.getAttribute("data-copy-target");
      const target = targetId && document.getElementById(targetId);
      const value =
        (target && target.getAttribute("data-real-value")) ||
        (target && target.value) ||
        "";
      if (!value) return;

      const icon = this.el.querySelector("[data-copy-icon]");
      const check = this.el.querySelector("[data-check-icon]");

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(value).then(() => {
          this._showCheck(icon, check);
        });
      } else if (target) {
        // Fallback: select text in input
        target.select();
        target.setSelectionRange(0, 99999);
        try {
          document.execCommand("copy");
          this._showCheck(icon, check);
        } catch (_e) {
          // silent
        }
      }
    });
  },
  _showCheck(icon, check) {
    if (icon) icon.classList.add("hidden");
    if (check) check.classList.remove("hidden");
    setTimeout(() => {
      if (icon) icon.classList.remove("hidden");
      if (check) check.classList.add("hidden");
    }, 2000);
  },
};

// Chart.js hook for analytics charts
Hooks.Chart = {
  mounted() {
    this._renderChart();
  },
  updated() {
    if (this._chart) {
      this._chart.destroy();
    }
    this._renderChart();
  },
  destroyed() {
    if (this._chart) {
      this._chart.destroy();
    }
  },
  _renderChart() {
    const type = this.el.dataset.chartType || "line";
    const labels = JSON.parse(this.el.dataset.chartLabels || "[]");
    const datasets = JSON.parse(this.el.dataset.chartDatasets || "[]");

    // Dynamically load Chart.js from CDN if not already loaded
    if (typeof Chart === "undefined") {
      const script = document.createElement("script");
      script.src =
        "https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js";
      script.onload = () => this._createChart(type, labels, datasets);
      document.head.appendChild(script);
    } else {
      this._createChart(type, labels, datasets);
    }
  },
  _createChart(type, labels, datasets) {
    const ctx = this.el.getContext("2d");
    this._chart = new Chart(ctx, {
      type: type,
      data: { labels: labels, datasets: datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: "bottom", labels: { usePointStyle: true } },
        },
        scales: {
          y: { beginAtZero: true, ticks: { precision: 0 } },
        },
      },
    });
  },
};

// Cookie consent banner hook (LiveView pages)
Hooks.CookieBanner = {
  mounted() {
    this._init();
  },
  updated() {
    this._init();
  },
  _init() {
    if (!localStorage.getItem("cookie_consent_dismissed")) {
      this.el.classList.remove("hidden");
    }
    const btn = this.el.querySelector("[data-cookie-accept]");
    if (btn) {
      btn.addEventListener("click", () => {
        localStorage.setItem("cookie_consent_dismissed", "1");
        this.el.classList.add("hidden");
      });
    }
  },
};

// Cookie consent banner (non-LiveView pages: home, login, signup, etc.)
document.addEventListener("DOMContentLoaded", function () {
  var banner = document.getElementById("cookie-banner");
  if (!banner) return;
  if (!localStorage.getItem("cookie_consent_dismissed")) {
    banner.classList.remove("hidden");
  }
  var btn = banner.querySelector("[data-cookie-accept]");
  if (btn) {
    btn.addEventListener("click", function () {
      localStorage.setItem("cookie_consent_dismissed", "1");
      banner.classList.add("hidden");
    });
  }
});

// Docs scroll spy: watches section[id] elements, highlights active nav item directly.
// Uses IntersectionObserver for scroll detection + click handler fallback + bottom-of-page detection.
Hooks.DocsScrollSpy = {
  mounted() {
    this._activeId = null;
    this._sections = [];
    this._skipObserverUntil = 0;
    this._collectSections();

    // IntersectionObserver: detect which section is in the top 60% of viewport
    this._observer = new IntersectionObserver(
      (entries) => {
        // Skip observer updates briefly after a click (let click handler take priority)
        if (Date.now() < this._skipObserverUntil) return;

        for (const entry of entries) {
          if (entry.isIntersecting) {
            this._setActive(entry.target.id);
            break;
          }
        }
      },
      { rootMargin: "-80px 0px -40% 0px", threshold: 0 },
    );
    for (const s of this._sections) this._observer.observe(s);

    // Click handler: fallback for sidebar links — immediately sets active state
    this._clickHandler = (e) => {
      const link = e.target.closest("a[id^='nav-']");
      if (!link) return;
      const targetId = link.id.replace("nav-", "");
      // Skip observer updates for 800ms to prevent race condition with scroll
      this._skipObserverUntil = Date.now() + 800;
      this._setActive(targetId);
    };
    this.el.addEventListener("click", this._clickHandler);

    // Scroll handler: detect bottom-of-page to activate last visible section
    this._scrollHandler = () => {
      if (Date.now() < this._skipObserverUntil) return;
      const scrollBottom = window.innerHeight + window.scrollY;
      const docHeight = document.documentElement.scrollHeight;
      if (docHeight - scrollBottom < 100) {
        // At bottom of page: find the last section that starts above viewport bottom
        for (let i = this._sections.length - 1; i >= 0; i--) {
          var rect = this._sections[i].getBoundingClientRect();
          if (rect.top < window.innerHeight) {
            this._setActive(this._sections[i].id);
            break;
          }
        }
      }
    };
    window.addEventListener("scroll", this._scrollHandler, { passive: true });

    // Initial state
    this._setActive("intro");
  },
  updated() {
    if (this._observer) this._observer.disconnect();
    this._collectSections();
    for (const s of this._sections) this._observer.observe(s);
  },
  destroyed() {
    if (this._observer) this._observer.disconnect();
    if (this._scrollHandler)
      window.removeEventListener("scroll", this._scrollHandler);
    if (this._clickHandler)
      this.el.removeEventListener("click", this._clickHandler);
  },
  _collectSections() {
    this._sections = Array.from(document.querySelectorAll("section[id]"));
  },
  _setActive(id) {
    if (this._activeId === id) return;
    const activeClasses = [
      "text-indigo-700",
      "dark:text-indigo-400",
      "bg-indigo-50",
      "dark:bg-indigo-950/40",
      "border-l-2",
      "border-indigo-500",
      "font-medium",
    ];
    const inactiveClasses = ["text-slate-600", "dark:text-slate-400"];
    // Deactivate previous
    if (this._activeId) {
      var old = document.getElementById("nav-" + this._activeId);
      if (old) {
        old.classList.remove(...activeClasses);
        old.classList.add(...inactiveClasses);
      }
    }
    this._activeId = id;
    // Activate new
    var nav = document.getElementById("nav-" + id);
    if (nav) {
      nav.classList.remove(...inactiveClasses);
      nav.classList.add(...activeClasses);
      nav.scrollIntoView({ block: "nearest", behavior: "smooth" });
    }
  },
};

// SDK language switcher: toggles code panels and tab styles purely client-side
Hooks.SdkSwitcher = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      const btn = e.target.closest("[data-sdk-lang]");
      if (!btn) return;
      const lang = btn.dataset.sdkLang;

      // Update all tab buttons (in code blocks)
      document.querySelectorAll(".sdk-tab").forEach((el) => {
        const isActive = el.dataset.sdkLang === lang;
        el.classList.toggle("bg-white", isActive);
        el.classList.toggle("text-indigo-700", isActive);
        el.classList.toggle("shadow-sm", isActive);
        el.classList.toggle("text-slate-600", !isActive);
      });

      // Update grid buttons
      document.querySelectorAll(".sdk-grid-btn").forEach((el) => {
        const isActive = el.dataset.sdkLang === lang;
        el.classList.toggle("bg-indigo-50", isActive);
        el.classList.toggle("border-indigo-300", isActive);
        el.classList.toggle("text-indigo-700", isActive);
        el.classList.toggle("bg-white", !isActive);
        el.classList.toggle("border-slate-200", !isActive);
        el.classList.toggle("text-slate-600", !isActive);
      });

      // Toggle code panels
      document.querySelectorAll("[data-sdk-panel]").forEach((el) => {
        el.classList.toggle("hidden", el.dataset.sdkPanel !== lang);
      });
    });
  },
};

// Copy code block content to clipboard
Hooks.CopyCode = {
  mounted() {
    this.el.addEventListener("click", () => {
      const code = this.el.getAttribute("data-code");
      if (!code) return;

      const icon = this.el.querySelector("[data-copy-icon]");
      const check = this.el.querySelector("[data-check-icon]");

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(code).then(() => {
          if (icon) icon.classList.add("hidden");
          if (check) check.classList.remove("hidden");
          setTimeout(() => {
            if (icon) icon.classList.remove("hidden");
            if (check) check.classList.add("hidden");
          }, 2000);
        });
      }
    });
  },
};

// Infinite scroll hook for content lists
Hooks.InfiniteScroll = {
  mounted() {
    this.observer = new IntersectionObserver((entries) => {
      const entry = entries[0];
      if (entry.isIntersecting) {
        this.pushEvent("load-more", {});
      }
    });
    this.observer.observe(this.el);
  },
  destroyed() {
    this.observer.disconnect();
  },
};

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener(
    "phx:live_reload:attached",
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs();

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown;
      window.addEventListener("keydown", (e) => (keyDown = e.key));
      window.addEventListener("keyup", (_e) => (keyDown = null));
      window.addEventListener(
        "click",
        (e) => {
          if (keyDown === "c") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          } else if (keyDown === "d") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          }
        },
        true,
      );

      window.liveReloader = reloader;
    },
  );
}
