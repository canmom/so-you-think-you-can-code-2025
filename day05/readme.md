# 🎨 CSS Houdini for Developers - Paint Worklets

### 🤖 TL;DR: CSS Paint Worklets

**CSS Paint Worklets** let you generate **dynamic, procedural images** (like backgrounds or borders) with **JavaScript**, running **off the main thread** for smooth performance. They react to **CSS Custom Properties** for customization and can be animated by updating these properties from the main thread. Using a limited **PaintRenderingContext2D**, they deliver **high-performance, resolution-independent graphics** entirely via CSS—without DOM access, pixel manipulation, or GPU APIs.


### 🤖 AI Summary: CSS Paint Worklets in a Nutshell
The **CSS Paint Worklet** is part of **CSS Houdini** and acts as an **off-main-thread procedural image generator**. It allows developers to write **JavaScript** to draw complex, dynamic visuals (e.g., backgrounds, borders, masks) and use them directly in CSS properties that accept images (`background-image`, `border-image`, etc.).

**Core Benefits:**

-   Runs in a **separate worker thread**, offloading heavy rendering from the main thread to prevent **UI jank** and ensure smooth performance.    
-   **Highly customizable**, since the Worklet can read and react to **CSS Custom Properties**.    
-   Enables **dynamic animation** by updating CSS properties on the main thread, which triggers redraws without blocking UI.    
-   Uses a restricted **PaintRenderingContext2D**, similar to Canvas 2D but focused on geometric drawing, intentionally disallowing pixel manipulation, text, and GPU APIs for **security and performance**.    

This approach delivers **high-performance, resolution-independent graphics** that are fully configurable via CSS, making it ideal for procedural backgrounds, custom borders, and other advanced visual effects.

----

## 🚀 Paint Worklets

The **CSS Painting API**, commonly known as the **Paint Worklet**, is a component of **[CSS Houdini](https://developer.mozilla.org/en-US/docs/Web/API/Houdini_APIs)**—a suite of APIs that grants developers direct access to the browser's rendering engine. In essence, it lets you programmatically generate images using **JavaScript** and apply them directly to any CSS property that accepts an image, such as `background-image`, `border-image`, `list-style-image`, or `mask-image`. So yes, it's quite flexible as long as the property expects an image resource!

The Worklet runs in a specialized **worker thread**, entirely separate from the browser's main thread. This offloads computationally heavy drawing tasks, preventing **jank** (UI freezing) and ensuring a smooth user experience.

----------

## 💻 Feature Breakdown & Capabilities


A **Paint Worklet** runs all heavy rendering **off-main-thread**, so procedural graphics and complex calculations never block the UI. This keeps the main thread smooth and prevents jank.

Worklets are flexible because they can read **CSS Custom Properties**, allowing you to control parameters and styling directly from CSS.

### **Drawing in a Worklet**

`paint(ctx, size, props)` uses a **PaintRenderingContext2D**, which is similar to a normal canvas 2D context but intentionally limited.

You _can_ use:

-   Basic drawing operations: `fillRect`, `beginPath`, `lineTo`, `arc`, etc.
    

You **cannot** use:

-   Pixel manipulation (`getImageData`, `putImageData`)
    
-   Text drawing
    
-   UI-related canvas APIs
    
-   WebGL or WebGPU
    

### **Pixel-like effects are still possible**

Even without real pixel access, a **clever developer can still achieve pixel-style or shader-like effects** by drawing many small rectangles or cells.

This makes it possible to simulate:

-   Dithering patterns    
-   Noise and procedural textures    
-   Pixel-art or grid-based rendering    
-   LED-matrix-style visuals    
-   Per-cell shading (similar to miniature shaders)
    
If you can compute a color from an (x, y) coordinate, you can draw it — just using geometry instead of raw pixels.

#### **Example: Simulating a Shader with Geometry**

The following code demonstrates how to create a reusable **`PixelRenderer`** that iterates over the output area and calls a function to compute the color for each "pixel" (which is actually a small `fillRect`). This pattern is directly analogous to how a pixel shader operates on normalized coordinates.

```javascript
class PixelRenderer {
    constructor() {
    
    }
    
    // fn is the "shader function" that returns [r, g, b] for a normalized coordinate
    run(ctx, size, fn) {
        const w = Math.floor(size.width);
        const h = Math.floor(size.height);
        // PIXEL determines the resolution. Set to 1 for full resolution.
        const PIXEL = 1; 
        
        for (let x = 0; x < w; x += PIXEL) {
            for (let y = 0; y < h; y += PIXEL) {
                // Normalize coordinates to a range like -1 to 1 (common for shaders)
                const xn = x / w * 2 - 1; 
                const yn = y / h * 2 - 1;
                
                // Call the color computation function
                const [r, g, b] = fn(xn, yn); 
                
                // Draw the result using fillRect - the key workaround!
                ctx.fillStyle = `rgb(${r|0},${g|0},${b|0})`;
                ctx.fillRect(x, y, PIXEL, PIXEL);
            }
        }
    }
}

class PixelKindOfThing {
    static get inputProperties() {
        return [
            '--time' // Used like a 'uniform' variable to drive animation
        ];
    }
    constructor(){
        this.renderer = new PixelRenderer();
    }
    paint(ctx, size, props) {
        const drawFuncForEachPixel = (x, y) => {
             // In a real implementation, 'x', 'y', and '--time' would be used 
             // to compute complex, evolving colors.
             const r = 255; // Simple Red for demonstration
             const g = 0;
             const b = 0;
             return [r, g, b];
        };
        this.renderer.run(ctx, size, drawFuncForEachPixel);
    } 
}
registerPaint('shader-worklet', PixelKindOfThing);
```


### **Raster output, vector-like sharpness**

The output is always a **raster image**, but if you base all coordinates on the element’s size, the result scales cleanly and appears **as sharp as vector graphics**.

### **Current limitation**

Paint Worklets only support a **2D context**. There is no GPU rendering, no WebGL, and no WebGPU access.

----------

## 💡 Primary Use Cases & Why Choose Worklets

The Paint Worklet is the ideal solution when performance, customization, and resolution are critical:

-   **Procedural Backgrounds:** Creates unique, mathematical, and seamlessly repeating patterns (e.g., noise, complex geometric tessellations).    
-   **Custom Borders & Masks:** Defines custom shapes and effects for borders or clipping paths impossible with standard CSS.    
-   **Dynamic Data Visualization:** Renders small, efficient charts or graphs directly into an element's background based on changing CSS variables.    

----------

## 🔄 Animation: The Main Thread Bridge

Since the Worklet is a sandbox and **cannot use `requestAnimationFrame` (rAF)** or other timing APIs, continuous animation requires a bridge:

1.  **Main Thread (rAF):** An animation loop runs on the main thread using `requestAnimationFrame`.    
2.  **State Update:** The loop calculates the evolving animation state (e.g., angle, zoom factor).    
3.  **CSS Bridge:** The loop updates a CSS Custom Property (`--my-scale`, `--my-angle`) every frame.    
4.  **Worklet Reaction:** The Worklet is forced to repaint because its input property changed, rendering the next frame of the animation off the main thread.    

Furthermore, this setup allows for excellent performance when combining animations: the Worklet handles the complex **internal geometry changes**, while you use standard, hardware-accelerated CSS **`transform`** properties to animate the **entire element's position or rotation**, maximizing efficiency.

----------

## 🌌 Example: The Sierpinski Worklet

The Worklet excels at tasks requiring continuous geometry calculation, such as fractals. Our **Sierpinski Worklet** demonstrates combining exponential zoom, rotation, and color-by-depth, all driven by the main thread.

### 1. The Paint Worklet (`sierpinski-worklet.js`)

This class handles all drawing and transformation logic off the main thread:

```javascript
class SierpinskiTriangle {
    static get inputProperties() {
        return [
            '--sierpinski-iterations',
            '--zoom-factor',
            '--fractal-opacity',
            '--rotation-angle'
        ];
    }
    paint( ctx, size, props) {

        const maxIterations = parseInt(props.get('--sierpinski-iterations').toString()) || 12;

        const zoom = parseFloat(props.get('--zoom-factor').toString()) || 1.0;
        const opacity = parseFloat(props.get('--fractal-opacity').toString()) || 0.5;
        const rotationDegrees = parseFloat(props.get('--rotation-angle').toString()) || 0;
        const rotationRadians = rotationDegrees * Math.PI / 180;

        // --- 2. Context Setup ---
        ctx.globalAlpha = opacity;

        const zoom_center_x = size.width / 2;
        const zoom_center_y = size.height / 2;

        // --- 3. Apply Canvas Transformation (Rotation) ---
        ctx.save();
        ctx.translate(zoom_center_x, zoom_center_y);
        ctx.rotate(rotationRadians);
        ctx.translate(-zoom_center_x, -zoom_center_y);

        // --- 4. Infinite Tunneling Logic ---
        // Animating the logarithm (Math.log2(zoom)) provides constant perceived speed
        const log2Zoom = Math.log2(zoom);
        const scaleFactor = Math.pow(2, log2Zoom % 1); // Scale cycles from 1.0 to 2.0

        // --- 5. Define Base Triangle ---
        const maxDim = Math.max(size.width, size.height);
        const sideLength = maxDim * 1.5;
        const h = sideLength * Math.sqrt(3) / 2;

        const p1_base = { x: zoom_center_x, y: zoom_center_y - h / 2 };
        const p2_base = { x: zoom_center_x - sideLength / 2, y: zoom_center_y + h / 2 };
        const p3_base = { x: zoom_center_x + sideLength / 2, y: zoom_center_y + h / 2 };

        // --- 6. Apply Zoom Scaling ---
        const p1_final = this.transformPoint(p1_base, scaleFactor, zoom_center_x, zoom_center_y);
        const p2_final = this.transformPoint(p2_base, scaleFactor, zoom_center_x, zoom_center_y);
        const p3_final = this.transformPoint(p3_base, scaleFactor, zoom_center_x, zoom_center_y);

        // --- 7. Start Recursion (and Color by Depth) ---
        this.drawTriangle(ctx, p1_final, p2_final, p3_final, maxIterations, maxIterations);

        ctx.restore(); // Restore context to remove rotation
    }
    // Helper for geometric scaling around a center point (cx, cy)
    transformPoint(p, scale, cx, cy) {
        return {
            x: cx + (p.x - cx) * scale,
            y: cy + (p.y - cy) * scale
        };
    }
    // Recursive function with color-by-depth logic
    drawTriangle(ctx, pA, pB, pC, level, maxLevel) {
        if (level === 0) {
            // Base case: Draw the filled triangle
            const depth = maxLevel - level;
            // Using a high-contrast HSL range for better visual effect
            const hue = 240 + depth * (60 / maxLevel);
            const lightness = 20 + depth * (30 / maxLevel);
            ctx.fillStyle = `hsl(${hue}, 100%, ${lightness}%)`;

            ctx.beginPath();
            ctx.moveTo(pA.x, pA.y);
            ctx.lineTo(pB.x, pB.y);
            ctx.lineTo(pC.x, pC.y);
            ctx.closePath();
            ctx.fill();
        } else {
            // Recursive step: Find the midpoints of the sides
            const pAB = { x: (pA.x + pB.x) / 2, y: (pA.y + pB.y) / 2 };
            const pBC = { x: (pB.x + pC.x) / 2, y: (pB.y + pC.y) / 2 };
            const pCA = { x: (pC.x + pA.x) / 2, y: (pC.y + pA.y) / 2 };

            // Recursively call for the three smaller outer triangles
            this.drawTriangle(ctx, pA, pAB, pCA, level - 1, maxLevel);
            this.drawTriangle(ctx, pAB, pB, pBC, level - 1, maxLevel);
            this.drawTriangle(ctx, pCA, pBC, pC, level - 1, maxLevel);
        }
    }
}
registerPaint('sierpinski-triangle', SierpinskiTriangle);

```

### 2. The Main Animation Loop (`index.html` Script Block)

This loop uses `requestAnimationFrame` to continuously update the Worklet's CSS variables, driving the animation:

JavaScript

```
const fractalElement = document.querySelector('.fractal-element');
let currentLogZoom = 0.0;
let currentRotation = 0.0;
let lastTime;
const SPEED_FACTOR = 0.0006; // Exponential zoom speed
const ROTATION_RATE = 0.015; // Angular rotation speed

function animateZoom(time) {
    if (lastTime) {
        const delta = time - lastTime;

        // 1. Exponential Zoom Logic (constant perceived speed)
        currentLogZoom += delta * SPEED_FACTOR;
        const currentZoom = Math.pow(2, currentLogZoom);

        // 2. Rotation Logic
        currentRotation += delta * ROTATION_RATE;
        currentRotation %= 360;

        // 3. Update the CSS Custom Properties (the bridge)
        fractalElement.style.setProperty('--zoom-factor', currentZoom.toFixed(3));
        fractalElement.style.setProperty('--rotation-angle', currentRotation.toFixed(2));
    }

    lastTime = time;
    requestAnimationFrame(animateZoom);
}

// Load Worklet and start animation
if (CSS.paintWorklet) {
    CSS.paintWorklet.addModule('sierpinski-worklet.js').then(() => {
        requestAnimationFrame(animateZoom);
    });
}

```

----------

## ⚛️ Integrating the Worklet with CSS

The final step is connecting the registered **Paint Worklet** to an HTML element using standard CSS. This integration is handled by the **`paint()`** function, which you can use anywhere a CSS property expects an image resource.

In the example below, we apply the Worklet as a **`background`** (stacking it with a fallback image), and we define its initial state using CSS Custom Properties.

CSS

```css
.fractal-element {
    /* 1. Initial Configuration via Custom Properties */
    --sierpinski-iterations: 3; /* Defines the fractal's complexity */
    --element-size: 100vw;
    --rotation-angle: 0;
    --fractal-opacity: 0.3; /* Sets the global transparency */

    /* 2. Worklet Integration */
    /* The Worklet is called using paint(worklet-name) */
    /* We stack it with a regular background image using a comma-separated list */
    background:
        paint(sierpinski-triangle), /* The procedural image generated off-main-thread */
        url("https://picsum.photos/1920/1080") center/cover; /* Fallback/stacked image */

    /* Basic element styling */
    width: var(--element-size);
    height: var(--element-size);
}

```
----------

## 🔮 What's Next for CSS Houdini?

The Paint Worklet is a stepping stone. Future Houdini APIs promise to give developers full control over the CSS pipeline:

-   **Layout Worklets (CSS Layout API):** To write custom layout algorithms (e.g., implementing a masonry or custom grid).    
-   **Animation Worklets:** To bind high-performance animations directly to input or scroll events.   

Houdini marks a massive step toward giving web developers granular control over the styling and rendering engine, ushering in an era of highly customizable and performant web graphics.

> __Huge thanks to Gemeni :-) for helping speedrun the final polish and make sure the language is on point._

Kind regards, Frank. ( Looking forward to coming posts )

----------


## Test URL

_Edit Magnus Thor_

I took the liberty of posting the example on codesandbox so we can test it.

Preview url https://5dq68q.csb.app/

----------
