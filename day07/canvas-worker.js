let canvas = null;
let ctx = null;
let isDrawing = false;
let animationFrameId = null;

/**
 * Renders a simple animated rectangle on the canvas.
 * This function now runs entirely in the Web Worker.
 */
function renderCanvas(time) {
    if (!isDrawing) return;

    const width = canvas.width;
    const height = canvas.height;
    const color = `hsl(${Math.floor(time / 10 % 360)}, 70%, 50%)`;
    const xPos = Math.sin(time / 1000) * (width / 4) + (width / 4);

    // Clear canvas
    ctx.clearRect(0, 0, width, height);

    // Draw background
    ctx.fillStyle = '#1e1e1e';
    ctx.fillRect(0, 0, width, height);

    // Draw animated shape
    ctx.fillStyle = color;
    ctx.fillRect(xPos, height / 3, width / 2, height / 3);

    ctx.font = '48px Arial';
    ctx.fillStyle = 'white';
    ctx.textAlign = 'center';
    ctx.fillText('Rendering in Worker!', width / 2, height / 5);

    // Continue the animation loop using the worker's requestAnimationFrame
    animationFrameId = requestAnimationFrame(renderCanvas);
}

/**
 * Starts the continuous rendering loop.
 */
function startRendering() {
    if (isDrawing) return;
    isDrawing = true;
    // The worker has its own global scope and requestAnimationFrame
    animationFrameId = requestAnimationFrame(renderCanvas);
}

// Listener for messages from the main thread
self.onmessage = (event) => {
    // We receive the OffscreenCanvas object
    if (event.data.canvas) {
        canvas = event.data.canvas;
        ctx = canvas.getContext('2d');
        startRendering();
        console.log("Worker received OffscreenCanvas and started rendering.");
    }
};