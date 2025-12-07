# Off-Thread Graphics, On-Stream Video


> **Note:** A few days ago, [PCrush on Day 05](https://github.com/MagnusThor/so-you-think-you-can-code-2025/blob/main/day05/readme.md) wrote about CSS Houdini.  
> While it’s not exactly the same topic, it’s somewhat similar — both deal with offloading work from the main thread.  
> This article takes a different approach: **OffscreenCanvas + Web Workers for live WebRTC streaming**.

High-performance graphics in the browser are a double-edged sword. The same `<canvas>` that draws your WebGL worlds or CPU-heavy effects is _also_ running on the **main browser thread**, fighting for time with layout, input handling, event dispatch, and everything else the user expects to feel responsive.

Today, we go one step beyond merely offloading that work:  
We’ll **render complex graphics off-thread using OffscreenCanvas + Web Workers, and then stream the result live over WebRTC**, all without blocking the UI.

----------

# Why Offload Rendering?

### Main-Thread Rendering Limitations

The moment you put a continuous animation loop inside the main JavaScript thread — especially a 3D/WebGPU/WebGL-intensive one — the browser starts to choke:

-   Input gets sluggish    
-   UI updates hitch    
-   Animations stutter    
-   Frame pacing becomes inconsistent    
-   WebRTC or MediaRecorder pipelines fall behind
    
This happens because **`requestAnimationFrame` + heavy rendering + DOM all share the same single thread**.

Our solution is to **isolate the rendering loop** and keep the main thread doing what it's best at:

-   WebRTC / MediaStream operations    
-   UI responsiveness    
-   Event handling    
-   DOM updates    

----------

#  The Offloading Architecture

We combine **three browser technologies**:

----------

## OffscreenCanvas — a Canvas Without a Body

`OffscreenCanvas` is a powerful concept:  
A canvas that **exists outside the DOM**, controlled entirely from JS — and crucially, one whose rendering context can be **transferred to another thread**.

```js
const offscreen = canvas.transferControlToOffscreen();
worker.postMessage({ canvas: offscreen }, [offscreen]);

```

Once transferred, the main thread loses access; the worker becomes the sole owner.  
Yet the `<canvas>` in the DOM still mirrors the OffscreenCanvas’s output automatically.

----------

## Web Workers — The Background Render Engine

All expensive drawing (WebGL, WebGPU, or even heavy 2D) lives entirely inside the worker:

-   Independent animation loop    
-   No UI stalls    
-   Stable frame pacing    
-   Dedicated compute/render thread
    
The worker becomes your **rendering engine**.

----------

## `canvas.captureStream()` — Turning Graphics Into Video

Because the DOM canvas mirrors the worker’s rendering, the main thread can do:

```js
const stream = canvas.captureStream(30);

```

This gives a standard **MediaStream**, fully compatible with:

-   WebRTC    
-   MediaRecorder    
-   `<video>` playback
    

The browser effectively becomes a lightweight **real-time graphics encoder**.

----------

#  Putting It All Together

## 📂 [mainThread.js](mainThread.js)

```javascript
class CanvasToMediaStream {

    constructor() {
        this.canvas = document.querySelector("canvas#my-canvas");
        this.video = document.querySelector("video#my-video");
        this.infoDiv = document.querySelector("div#mediaStreamInfo"); 
        this.stream = null;
        this.worker = null;

        this.init();
    }

    init() {
        const offscreen = this.canvas.transferControlToOffscreen();
        this.worker = new Worker('canvas-worker.js');
        this.worker.postMessage({ canvas: offscreen }, [offscreen]);
        this.createMediaStream();
    }

    createMediaStream() {
        const frameRate = 30;
        this.stream = this.canvas.captureStream(frameRate);

        this.video.srcObject = this.stream;
        this.video.play().catch(console.error);

        this.displayStreamInfo();
    }

    displayStreamInfo() {
        const track = this.stream.getVideoTracks()[0];
        if (!track) return;

        const settings = track.getSettings();

        this.infoDiv.innerHTML = `
            <h4>MediaStream Details</h4>
            <ul>
                <li><strong>ID:</strong> ${track.id}</li>
                <li><strong>Frame Rate:</strong> ${settings.frameRate}</li>
                <li><strong>Resolution:</strong> ${settings.width}×${settings.height}</li>
            </ul>`;
    }
}

document.addEventListener("DOMContentLoaded", () => {
    new CanvasToMediaStream();
});

```

----------

## 📂 [canvas-worker.js](canvas-worker.js)

```javascript
let canvas = null;
let ctx = null;
let isDrawing = false;

function renderCanvas(time) {
    if (!isDrawing) return;

    const { width, height } = canvas;
    const hue = Math.floor((time / 10) % 360);
    const xPos = Math.sin(time / 1000) * (width / 4) + width / 4;

    ctx.clearRect(0, 0, width, height);
    ctx.fillStyle = "#1e1e1e";
    ctx.fillRect(0, 0, width, height);

    ctx.fillStyle = `hsl(${hue}, 70%, 50%)`;
    ctx.fillRect(xPos, height / 3, width / 2, height / 3);

    ctx.font = "48px Arial";
    ctx.fillStyle = "white";
    ctx.textAlign = "center";
    ctx.fillText("Rendering in Worker!", width / 2, height / 5);

    requestAnimationFrame(renderCanvas);
}

self.onmessage = (event) => {
    if (event.data.canvas) {
        canvas = event.data.canvas;
        ctx = canvas.getContext("2d");
        isDrawing = true;
        requestAnimationFrame(renderCanvas);
    }
};

```

----------

# 🎥 Streaming It Over WebRTC

Once you have a `MediaStream`, WebRTC needs only this single call:

```js
// You can pipe the OffscreenCanvas stream directly into WebRTC
rtc.AddLocalStream(stream);

```

This creates a full live video pipeline using nothing but:

-   Web Workers    
-   OffscreenCanvas    
-   `captureStream()`    
-   RTCPeerConnection
    

----------

#  Using ThorIO for Signaling (Conceptual Overview)

ThorIO provides a structured WebSocket signaling layer that coordinates peer discovery and SDP/ICE exchange. Here’s a minimal conceptual sketch:

```js
import { Factory, WebRTC } from "thor-io.client-vnext";

const factory = new Factory("wss://kollokvium.herokuapp.com", ["broker"]);

factory.OnOpen = (broker) => {
    const rtc = new WebRTC(broker, {
        iceServers: [{ urls: "stun:stun.l.google.com:19302" }]
    });

    // When your OffscreenCanvas MediaStream is ready:
    // rtc.AddLocalStream(stream);

    rtc.ChangeContext("#my-room");

    rtc.OnRemoteTrack = (track, peer) => {
        const remoteStream = new MediaStream([track]);
        // Attach remoteStream to <video> or display logic
    };

    broker.Connect();
};

```

**Key Notes:**

-   OffscreenCanvas streams can be added directly via `rtc.AddLocalStream(stream)`    
-   ThorIO handles signaling, context/room membership, and peer coordination
-   Any client capable of WebSocket can connect to `wss://kollokvium.herokuapp.com`
    

----------

#  Final Takeaway

By combining:

-   **OffscreenCanvas** for off-thread graphics    
-   **Web Workers** for stable rendering    
-   **`canvas.captureStream()`** for video generation    
-   **ThorIO + WebRTC** for real-time transport
    

you get a **modern, high-performance architecture** for browser-based visualization or streaming.

| Task             | Main Thread | Worker |
|-----------------|------------|--------|
| UI + DOM         | ✔          | –      |
| Stream capture   | ✔          | –      |
| Heavy rendering  | –          | ✔      |
| Maintain FPS     | ✔          | ✔      |


The user experiences a smooth interface.  The browser gets predictable rendering.  
You get real-time graphics streaming — with virtually no main-thread cost.

----------

*Thanks, for reading.*
