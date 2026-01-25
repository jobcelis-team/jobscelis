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
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Custom hooks for LiveView components
let Hooks = {}

// Video player hook: custom controls, no native UI, resume, progress save
Hooks.VideoPlayer = {
  mounted() {
    const src = this.el.dataset.src
    const resume = this.el.dataset.resume ? parseInt(this.el.dataset.resume, 10) : null

    const video = document.createElement("video")
    video.preload = "metadata"
    video.playsInline = true
    video.autoplay = true
    video.muted = false
    video.classList.add("w-full", "flex-1", "object-contain", "bg-black")
    const source = document.createElement("source")
    source.src = src
    source.type = "video/mp4"
    video.appendChild(source)

    const controls = document.createElement("div")
    controls.className = "flex items-center gap-3 px-4 py-2 bg-black/80 text-white"

    const playBtn = document.createElement("button")
    playBtn.type = "button"
    playBtn.className = "p-2 rounded-full hover:bg-white/20 transition"
    playBtn.innerHTML = '<svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>'
    const pauseSvg = '<svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>'
    const playSvg = '<svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>'

    const progressWrap = document.createElement("div")
    progressWrap.className = "flex-1 flex items-center gap-2"
    const range = document.createElement("input")
    range.type = "range"
    range.min = 0
    range.step = 0.1
    range.className = "flex-1 h-2 bg-gray-600 rounded appearance-none cursor-pointer"
    const timeLabel = document.createElement("span")
    timeLabel.className = "text-sm tabular-nums min-w-[90px]"

    progressWrap.appendChild(range)
    progressWrap.appendChild(timeLabel)
    controls.appendChild(playBtn)
    controls.appendChild(progressWrap)

    this.el.appendChild(video)
    this.el.appendChild(controls)

    const format = (s) => {
      if (!Number.isFinite(s) || s < 0) return "0:00"
      const m = Math.floor(s / 60)
      const sec = Math.floor(s % 60)
      return `${m}:${sec.toString().padStart(2, "0")}`
    }

    let lastPush = 0
    const throttleMs = 10000
    const pushProgress = () => {
      const now = Date.now()
      if (now - lastPush >= throttleMs && Number.isFinite(video.duration) && video.duration > 0) {
        lastPush = now
        this.pushEvent("progress", { currentTime: video.currentTime, duration: video.duration })
      }
    }

    video.addEventListener("loadedmetadata", () => {
      range.max = video.duration
      if (resume != null && resume > 0 && resume < video.duration) {
        video.currentTime = resume
        range.value = resume
      }
      timeLabel.textContent = `${format(video.currentTime)} / ${format(video.duration)}`
    })

    video.addEventListener("timeupdate", () => {
      if (Number.isFinite(video.duration)) range.value = video.currentTime
      timeLabel.textContent = `${format(video.currentTime)} / ${format(video.duration)}`
      pushProgress()
    })

    video.addEventListener("play", () => { playBtn.innerHTML = pauseSvg })
    video.addEventListener("pause", () => {
      playBtn.innerHTML = playSvg
      if (Number.isFinite(video.duration) && video.duration > 0) {
        this.pushEvent("progress", { currentTime: video.currentTime, duration: video.duration })
      }
    })

    playBtn.addEventListener("click", () => {
      if (video.paused) video.play()
      else video.pause()
    })

    range.addEventListener("input", () => {
      const t = parseFloat(range.value)
      video.currentTime = t
      timeLabel.textContent = `${format(t)} / ${format(video.duration)}`
    })

    this.handleEvent("play", () => video.play())
    this.handleEvent("pause", () => video.pause())
    this.handleEvent("seek", ({ time }) => {
      video.currentTime = time
      range.value = time
    })
  }
}

// Infinite scroll hook for content lists
Hooks.InfiniteScroll = {
  mounted() {
    this.observer = new IntersectionObserver(entries => {
      const entry = entries[0]
      if (entry.isIntersecting) {
        this.pushEvent("load-more", {})
      }
    })
    this.observer.observe(this.el)
  },
  destroyed() {
    this.observer.disconnect()
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

