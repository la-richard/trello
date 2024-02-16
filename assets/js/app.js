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

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Sortable from "../vendor/sortable"

const hooks = {}

hooks.sortable = {
  mounted() {
    new Sortable(this.el, {
      group: {
        name: this.el.dataset?.group,
        pull: true,
        put: true,
      },
      animation: 150,
      delay: 100,
      delayOnTouchOnly: true,
      dragClass: "draggable-item",
      ghostClass: "bg-slate-400",
      forceFallback: true,
      handle: ".drag-handle",
      onEnd: e => {
        const elements = Array.from(this.el.children)
        const fromList = e.from?.getAttribute("data-group")
        const toList = e.to?.getAttribute("data-group")
        const toListElements = Array.from(e.to?.children)

        if (e.oldIndex === e.newIndex && fromList === toList) {
          return
        }

        let params = {
          movedId: fromList === toList ?
            elements[e.newIndex].getAttribute("data-task-id") :
            toListElements[e.newIndex].getAttribute("data-task-id"),
          previousSiblingId: fromList === toList ?
            elements[e.newIndex - 1]?.getAttribute("data-task-id") :
            toListElements[e.newIndex - 1]?.getAttribute("data-task-id"),
          nextSiblingId: fromList === toList ?
            elements[e.newIndex + 1]?.getAttribute("data-task-id") :
            toListElements[e.newIndex + 1]?.getAttribute("data-task-id"),
          fromList,
          toList
        }

        this.pushEventTo(this.el, "reorder", params)
      }
    })
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: hooks })

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

