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
        // 1. Convert the visible canvas to an OffscreenCanvas
        const offscreen = this.canvas.transferControlToOffscreen();
        
        // 2. Create the Web Worker, passing the OffscreenCanvas
        // The [offscreen] array is for transferable objects (Transferable objects are moved, not copied)
        this.worker = new Worker('canvas-worker.js');
        this.worker.postMessage({ canvas: offscreen }, [offscreen]);

        // 3. Create the MediaStream from the main canvas element (still needed here)
        this.createMediaStream();
    }

    /**
     * Creates a MediaStream from the canvas and attaches it to the video element.
     */
    createMediaStream() {
        // The main canvas element is still used to capture the stream.
        // It reflects the output of the OffscreenCanvas which is being drawn by the worker.
        const frameRate = 30;
        this.stream = this.canvas.captureStream(frameRate);

        this.video.srcObject = this.stream;
        this.video.play().catch(e => console.error("Video playback failed:", e));

        this.displayStreamInfo();
    }

    /**
     * Retrieves the video track and updates the infoDiv element.
     * (Same as before)
     */
    displayStreamInfo() {
        const tracks = this.stream.getVideoTracks();

        if (tracks.length > 0) {
            const videoTrack = tracks[0];
            const settings = videoTrack.getSettings();

            this.infoDiv.innerHTML = `
                <h4>MediaStream (Video Track) Details - Offloaded Rendering!</h4>
                <ul>
                    <li><strong>Rendering:</strong> Offloaded to Web Worker via OffscreenCanvas</li>
                    <li><strong>ID:</strong> ${videoTrack.id}</li>
                    <li><strong>Frame Rate:</strong> ${settings.frameRate || 'N/A'} FPS</li>
                    <li><strong>Resolution:</strong> ${settings.width}x${settings.height}</li>
                </ul>
            `;
        } else {
            this.infoDiv.innerHTML = `<p>Error: No video tracks found in the MediaStream.</p>`;
        }
    }
}

document.addEventListener("DOMContentLoaded", () => {
    let app = new CanvasToMediaStream();
});