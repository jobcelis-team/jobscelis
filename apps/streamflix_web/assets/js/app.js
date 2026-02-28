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

// Mobile menu toggle for site navbar
document.addEventListener("DOMContentLoaded", function () {
  document
    .querySelectorAll("[data-mobile-menu-toggle]")
    .forEach(function (btn) {
      btn.addEventListener("click", function () {
        const header = btn.closest("header");
        if (!header) return;
        const panel = header.querySelector("[data-mobile-menu-panel]");
        const spanOpen = btn.querySelector("[data-menu-icon-open]");
        const spanClose = btn.querySelector("[data-menu-icon-close]");
        if (!panel) return;
        const isHidden = panel.classList.contains("hidden");
        panel.classList.toggle("hidden", !isHidden);
        if (spanOpen) spanOpen.classList.toggle("hidden", isHidden);
        if (spanClose) spanClose.classList.toggle("hidden", !isHidden);
      });
    });
});

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

// Video player hook: full-featured custom player (volume, fullscreen, speed, shortcuts, auto-hide, next episode)
Hooks.VideoPlayer = {
  mounted() {
    const src = this.el.dataset.src;
    const resume = this.el.dataset.resume
      ? parseInt(this.el.dataset.resume, 10)
      : null;
    const title = this.el.dataset.title || "";
    const seriesInfo = this.el.dataset.seriesInfo || "";
    const nextUrl = this.el.dataset.nextEpisodeUrl || "";
    const nextLabel = this.el.dataset.nextEpisodeLabel || "Siguiente episodio";

    // Video element
    const video = document.createElement("video");
    video.preload = "metadata";
    video.playsInline = true;
    video.autoplay = true;
    video.muted = false;
    video.volume = 1;
    video.loop = false;
    video.controls = false;
    video.classList.add("w-full", "h-full", "object-contain", "bg-black");
    const source = document.createElement("source");
    source.src = src;
    source.type = "video/mp4";
    video.appendChild(source);

    // Video container (fills entire player area)
    const videoContainer = document.createElement("div");
    videoContainer.className = "absolute inset-0 w-full h-full z-0";
    videoContainer.appendChild(video);

    // Loading spinner
    const loading = document.createElement("div");
    loading.className =
      "absolute inset-0 z-5 flex items-center justify-center bg-black/60 opacity-0 pointer-events-none transition-opacity duration-200";
    loading.innerHTML =
      '<div class="w-14 h-14 border-4 border-white/30 border-t-white rounded-full animate-spin"/>';
    videoContainer.appendChild(loading);

    // Format time helper
    const format = (s) => {
      if (!Number.isFinite(s) || s < 0) return "0:00";
      const m = Math.floor(s / 60);
      const sec = Math.floor(s % 60);
      return `${m}:${sec.toString().padStart(2, "0")}`;
    };

    // Playback speed options
    const SPEEDS = [0.5, 1, 1.25, 1.5, 2];
    let speedIdx = 1;

    // Play/Pause button
    const playBtn = document.createElement("button");
    playBtn.type = "button";
    playBtn.className =
      "p-2 rounded-full hover:bg-white/20 transition cursor-pointer";
    playBtn.innerHTML =
      '<svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>';
    const pauseSvg =
      '<svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>';
    const playSvg =
      '<svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>';

    // Progress bar and time
    const progressWrap = document.createElement("div");
    progressWrap.className = "flex-1 flex items-center gap-2 min-w-0";
    const range = document.createElement("input");
    range.type = "range";
    range.min = 0;
    range.step = 0.1;
    range.className =
      "flex-1 h-2 bg-gray-600 rounded appearance-none cursor-pointer min-w-0";
    const timeLabel = document.createElement("span");
    timeLabel.className =
      "text-sm tabular-nums min-w-[90px] shrink-0 text-white";

    // Mute button
    const muteBtn = document.createElement("button");
    muteBtn.type = "button";
    muteBtn.className =
      "p-2 rounded-full hover:bg-white/20 transition shrink-0 cursor-pointer";
    muteBtn.title = "Silenciar";
    muteBtn.innerHTML =
      '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg>';
    const mutedSvg =
      '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z"/></svg>';

    // Volume slider
    const volSlider = document.createElement("input");
    volSlider.type = "range";
    volSlider.min = 0;
    volSlider.max = 1;
    volSlider.step = 0.05;
    volSlider.value = 1;
    volSlider.className =
      "w-20 h-1.5 bg-gray-600 rounded appearance-none cursor-pointer accent-red-600";

    // Speed button
    const speedBtn = document.createElement("button");
    speedBtn.type = "button";
    speedBtn.className =
      "px-2 py-1 rounded text-sm hover:bg-white/20 transition shrink-0 cursor-pointer text-white";
    speedBtn.textContent = "1x";

    // Fullscreen button
    const fullscreenBtn = document.createElement("button");
    fullscreenBtn.type = "button";
    fullscreenBtn.className =
      "p-2 rounded-full hover:bg-white/20 transition shrink-0 cursor-pointer";
    fullscreenBtn.title = "Pantalla completa";
    fullscreenBtn.innerHTML =
      '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z"/></svg>';

    // Build progress wrap
    progressWrap.appendChild(range);
    progressWrap.appendChild(timeLabel);

    // Controls bar (bottom)
    const controlsBar = document.createElement("div");
    controlsBar.className =
      "absolute bottom-0 left-0 right-0 z-20 flex items-center gap-2 px-4 py-2 bg-gradient-to-t from-black/95 to-black/70 text-white transition-opacity duration-300";
    controlsBar.appendChild(playBtn);
    controlsBar.appendChild(progressWrap);
    controlsBar.appendChild(muteBtn);
    controlsBar.appendChild(volSlider);
    controlsBar.appendChild(speedBtn);
    controlsBar.appendChild(fullscreenBtn);

    // Top overlay (Volver + title)
    const overlay = document.createElement("div");
    overlay.className =
      "absolute top-0 left-0 right-0 z-20 flex flex-col transition-opacity duration-300";
    const overlayRow = document.createElement("div");
    overlayRow.className =
      "flex items-center justify-between p-4 bg-gradient-to-b from-black/70 to-transparent";
    const volverWrap = document.createElement("div");
    const volverBtn = document.createElement("button");
    volverBtn.type = "button";
    volverBtn.className =
      "text-white hover:text-gray-300 flex items-center bg-black/50 hover:bg-black/70 px-3 py-2 rounded transition cursor-pointer";
    volverBtn.innerHTML =
      '<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/></svg><span class="ml-2">Volver</span>';
    volverBtn.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      const dur =
        Number.isFinite(video.duration) && video.duration > 0
          ? video.duration
          : 0;
      const ct = dur > 0 ? Math.round(video.currentTime) : 0;
      this.pushEvent("save_and_exit", { currentTime: ct, duration: dur });
    });
    volverWrap.appendChild(volverBtn);
    const titleEl = document.createElement("div");
    titleEl.className =
      "text-white text-lg font-medium bg-black/50 px-4 py-2 rounded";
    titleEl.textContent = title + seriesInfo;
    const spacer = document.createElement("div");
    spacer.className = "w-24";
    overlayRow.appendChild(volverWrap);
    overlayRow.appendChild(titleEl);
    overlayRow.appendChild(spacer);
    overlay.appendChild(overlayRow);

    // Next episode button (for series)
    let nextEpisodeWrap = null;
    if (nextUrl) {
      nextEpisodeWrap = document.createElement("div");
      nextEpisodeWrap.className =
        "absolute bottom-20 right-6 z-30 pointer-events-none opacity-0 transition-opacity duration-300";
      const nextEpisodeBtn = document.createElement("button");
      nextEpisodeBtn.type = "button";
      nextEpisodeBtn.className =
        "pointer-events-auto px-4 py-2 rounded bg-white/90 hover:bg-white text-black font-medium text-sm flex items-center gap-2 transition cursor-pointer";
      nextEpisodeBtn.innerHTML = `<span>${nextLabel.replace(/^Siguiente: /, "")}</span><svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M4 18l8.5-6L4 6v12zm9-12v12l8.5-6L13 6z"/></svg>`;
      nextEpisodeBtn.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        const dur =
          Number.isFinite(video.duration) && video.duration > 0
            ? video.duration
            : 0;
        const ct = dur > 0 ? Math.round(video.currentTime) : 0;
        this.pushEvent("save_and_next", { currentTime: ct, duration: dur });
      });
      nextEpisodeWrap.appendChild(nextEpisodeBtn);
    }

    // Ended overlay (when video finishes)
    const endedOverlay = document.createElement("div");
    endedOverlay.className =
      "absolute inset-0 z-40 hidden flex flex-col items-center justify-center bg-black/90";
    endedOverlay.innerHTML = `
      <p class="text-white text-xl font-medium mb-4">Video terminado</p>
      <button type="button" class="video-ended-volver px-4 py-2 rounded bg-white/90 hover:bg-white text-black font-medium transition cursor-pointer">
        Volver
      </button>
    `;
    const endedVolverBtn = endedOverlay.querySelector(".video-ended-volver");
    endedVolverBtn.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      const dur =
        Number.isFinite(video.duration) && video.duration > 0
          ? video.duration
          : 0;
      const ct = dur > 0 ? Math.round(video.currentTime) : 0;
      this.pushEvent("save_and_exit", { currentTime: ct, duration: dur });
    });

    // UI container (all overlays and controls)
    const uiContainer = document.createElement("div");
    uiContainer.className = "absolute inset-0 z-10";
    uiContainer.appendChild(overlay);
    if (nextEpisodeWrap) uiContainer.appendChild(nextEpisodeWrap);
    uiContainer.appendChild(controlsBar);
    uiContainer.appendChild(endedOverlay);

    // Append to player root
    this.el.appendChild(videoContainer);
    this.el.appendChild(uiContainer);

    // Auto-hide UI logic
    let hideTimer = null;
    const HIDE_DELAY_MS = 3000;
    const showUI = () => {
      if (endedOverlay.classList.contains("ended-visible")) return;
      overlay.classList.remove("opacity-0");
      controlsBar.classList.remove("opacity-0");
      if (hideTimer) clearTimeout(hideTimer);
      hideTimer = setTimeout(hideUI, HIDE_DELAY_MS);
    };
    const hideUI = () => {
      if (endedOverlay.classList.contains("ended-visible")) return;
      overlay.classList.add("opacity-0");
      controlsBar.classList.add("opacity-0");
      if (hideTimer) clearTimeout(hideTimer);
      hideTimer = null;
    };
    this.el.addEventListener("mousemove", showUI);
    this.el.addEventListener("mouseenter", showUI);
    this.el.addEventListener("mouseleave", () => {
      if (hideTimer) clearTimeout(hideTimer);
      hideTimer = setTimeout(hideUI, 500);
    });
    showUI();

    // Click on video to play/pause
    videoContainer.addEventListener("click", (e) => {
      if (
        e.target === videoContainer ||
        e.target === video ||
        e.target === loading
      ) {
        showUI();
        if (video.ended) return;
        if (video.paused) video.play();
        else video.pause();
      }
    });

    // Progress tracking
    let lastPush = 0;
    const throttleMs = 10000;
    const pushProgress = () => {
      const now = Date.now();
      if (
        now - lastPush >= throttleMs &&
        Number.isFinite(video.duration) &&
        video.duration > 0
      ) {
        lastPush = now;
        this.pushEvent("progress", {
          currentTime: video.currentTime,
          duration: video.duration,
        });
      }
    };

    // Update next episode visibility
    const updateNextEpisodeVisibility = () => {
      if (!nextUrl || !nextEpisodeWrap) return;
      const d = video.duration;
      const t = video.currentTime;
      if (!Number.isFinite(d) || d <= 0) return;
      const remaining = d - t;
      const threshold = Math.min(90, d * 0.1);
      if (remaining <= threshold) {
        nextEpisodeWrap.classList.remove("opacity-0");
        nextEpisodeWrap.style.pointerEvents = "auto";
      } else {
        nextEpisodeWrap.classList.add("opacity-0");
        nextEpisodeWrap.style.pointerEvents = "none";
      }
    };

    // Video event listeners
    video.addEventListener("loadedmetadata", () => {
      range.max = video.duration;
      if (resume != null && resume > 0 && resume < video.duration) {
        video.currentTime = resume;
        range.value = resume;
      }
      timeLabel.textContent = `${format(video.currentTime)} / ${format(video.duration)}`;
    });

    video.addEventListener("waiting", () => {
      loading.classList.remove("opacity-0");
    });
    video.addEventListener("playing", () => {
      loading.classList.add("opacity-0");
    });
    video.addEventListener("canplay", () => {
      loading.classList.add("opacity-0");
    });

    video.addEventListener("ended", () => {
      if (Number.isFinite(video.duration) && video.duration > 0) {
        this.pushEvent("progress", {
          currentTime: video.duration,
          duration: video.duration,
        });
      }
      endedOverlay.classList.remove("hidden");
      endedOverlay.classList.add("ended-visible");
      if (hideTimer) clearTimeout(hideTimer);
      hideTimer = null;
      overlay.classList.add("opacity-0");
      controlsBar.classList.add("opacity-0");
    });

    video.addEventListener("timeupdate", () => {
      if (Number.isFinite(video.duration)) {
        range.value = video.currentTime;
        timeLabel.textContent = `${format(video.currentTime)} / ${format(video.duration)}`;
      }
      pushProgress();
      updateNextEpisodeVisibility();
    });

    // Track if view has been counted (only count once per session)
    let viewCounted = false;
    video.addEventListener("play", () => {
      playBtn.innerHTML = pauseSvg;
      // Increment view count when video starts playing for the first time
      if (!viewCounted) {
        viewCounted = true;
        this.pushEvent("video_started", {});
      }
    });
    video.addEventListener("pause", () => {
      playBtn.innerHTML = playSvg;
      if (Number.isFinite(video.duration) && video.duration > 0) {
        this.pushEvent("progress", {
          currentTime: video.currentTime,
          duration: video.duration,
        });
      }
    });

    // Control button handlers
    playBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      if (video.ended) return;
      if (video.paused) video.play();
      else video.pause();
    });

    range.addEventListener("input", (e) => {
      e.stopPropagation();
      const t = parseFloat(range.value);
      if (Number.isFinite(t)) {
        video.currentTime = t;
        timeLabel.textContent = `${format(t)} / ${format(video.duration)}`;
      }
    });

    muteBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      video.muted = !video.muted;
      muteBtn.innerHTML = video.muted
        ? mutedSvg
        : '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg>';
      volSlider.value = video.muted ? 0 : video.volume;
    });

    volSlider.addEventListener("input", (e) => {
      e.stopPropagation();
      const v = parseFloat(volSlider.value);
      if (Number.isFinite(v)) {
        video.volume = v;
        video.muted = v === 0;
        muteBtn.innerHTML =
          v === 0
            ? mutedSvg
            : '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg>';
      }
    });

    speedBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      speedIdx = (speedIdx + 1) % SPEEDS.length;
      video.playbackRate = SPEEDS[speedIdx];
      speedBtn.textContent = `${SPEEDS[speedIdx]}x`;
    });

    const toggleFullscreen = () => {
      if (!document.fullscreenElement) {
        this.el.requestFullscreen?.() || this.el.webkitRequestFullScreen?.();
      } else {
        document.exitFullscreen?.() || document.webkitExitFullscreen?.();
      }
    };
    fullscreenBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      toggleFullscreen();
    });

    const onFullscreenChange = () => {
      fullscreenBtn.innerHTML = document.fullscreenElement
        ? '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M5 16h3v3h2v-5H5v2zm3-8H5v2h5V5H8v3zm6 11h2v-3h3v-2h-5v5zm2-11V5h-2v5h5V8h-3z"/></svg>'
        : '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z"/></svg>';
    };
    document.addEventListener("fullscreenchange", onFullscreenChange);

    // Keyboard shortcuts
    const onKey = (e) => {
      if (
        !this.el.contains(document.activeElement) &&
        document.activeElement?.tagName !== "BODY"
      )
        return;
      const tag = e.target?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA") return;
      switch (e.key) {
        case " ":
          e.preventDefault();
          if (video.ended) break;
          if (video.paused) video.play();
          else video.pause();
          break;
        case "f":
        case "F":
          e.preventDefault();
          toggleFullscreen();
          break;
        case "m":
        case "M":
          e.preventDefault();
          video.muted = !video.muted;
          muteBtn.innerHTML = video.muted
            ? mutedSvg
            : '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg>';
          volSlider.value = video.muted ? 0 : video.volume;
          break;
        case "ArrowLeft":
          e.preventDefault();
          video.currentTime = Math.max(0, video.currentTime - 10);
          range.value = video.currentTime;
          timeLabel.textContent = `${format(video.currentTime)} / ${format(video.duration)}`;
          break;
        case "ArrowRight":
          e.preventDefault();
          video.currentTime = Math.min(
            video.duration || 0,
            video.currentTime + 10,
          );
          range.value = video.currentTime;
          timeLabel.textContent = `${format(video.currentTime)} / ${format(video.duration)}`;
          break;
      }
    };
    document.addEventListener("keydown", onKey);
    this._videoPlayerCleanup = () => {
      document.removeEventListener("keydown", onKey);
      document.removeEventListener("fullscreenchange", onFullscreenChange);
    };

    // LiveView event handlers
    this.handleEvent("play", () => video.play());
    this.handleEvent("pause", () => video.pause());
    this.handleEvent("seek", ({ time }) => {
      if (Number.isFinite(time)) {
        video.currentTime = time;
        range.value = time;
      }
    });
  },
  destroyed() {
    if (this._videoPlayerCleanup) this._videoPlayerCleanup();
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
