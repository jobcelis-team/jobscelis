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
