# When Every Byte Counts: Hashing, Golfing, and Packing for Browser Demoscene Releases

**Note:** I used an AI assistant to help edit and structure this post for clarity and readability.  
All code examples are authored by me, inspired by various public demos and community techniques.  
The explanations, workflow, and implementation details reflect my own experimentation and research in browser demoscene releases.


**Description:** 
Dive deep into the extreme optimization techniques used in browser demoscene productions. This post breaks down how WebGL context hashing, aggressive code golfing, and innovative PNG compression combine to squeeze stunning visuals and audio into impossibly small file sizes.

----------

In the world of modern web development, we talk about "bundle budgets" in megabytes. But in the browser demoscene—competitive creative coding focused on tiny size constraints—we talk in bytes.

Creating an intro isn't just about writing efficient rendering code; it's about a fundamental war against entropy and verbosity. How do you fit a complex 3D scene, complex shaders, and even a complete **tiny software synthesizer** for audio into a payload smaller than a standard favicon?

It requires a specific workflow that combines clever runtime tricks, aggressive code "golfing," and abusing browser features for compression. Let's dissect the anatomy of a tiny browser demo, a workflow that allows for impressive results even for something like a 4k intro.

### The Enemy: WebGL Verbosity

WebGL is an incredible API, but it is incredibly verbose. Its constants and method names are long, descriptive strings designed for clarity, not brevity.

Consider setting a uniform matrix. That’s 16 characters of raw text just for the method name. If you call this ten times in your initialization loop, that’s 160 bytes gone just repeating the same word. Even after standard gzip compression, this repetitive text eats up precious space.

In a demo where every byte matters, you simply cannot afford to type these names out.

### The Solution: Context Hashing - Two Stages

To truly conquer WebGL verbosity, we employ a two-stage approach:

1.  **Build-Time Hashing (The "Second Squeeze"):** Before any minification or compression, we statically replace long WebGL method names in our source code with short, predefined aliases.
    
2.  **Runtime Hashing (The "First Squeeze"):** A tiny snippet of code runs _inside_ the browser to create these short aliases on the `gl` context, ensuring that when our demo code calls `gl.d4()` or `gl.x86()`, the correct original WebGL function is executed.
    

Let's look at the runtime hashing first, as it defines the target aliases.

#### Stage 1: Runtime Hashing (The "First Squeeze")

This small loop runs at the very start of your demo execution, dynamically creating the short aliases on the `gl` context. This ensures that when your main demo code (which has been pre-processed to use these short names) runs, the functions are available.

Here is a robust example of a hashing loop that ensures every WebGL function gets a unique, valid JavaScript identifier (using hex codes like `x1f`, `d4`, or `a9`):

```javascript
// The WebGL context is 'gl'
let c = 0, d;
for (let i in gl) {
    if ("function" == typeof gl[i]) {
        // Generate a hex string counter (00 to ff)
        d = (c++ & 255).toString(16);
        // Ensure it's a valid JS identifier (prepend 'x' if it starts with a number)
        d = d.match(/^[0-9].*$/) ? "x" + d : d;
        // Assign the original function to the new short name
        gl[d] = gl[i];
    }
}
// Now, instead of gl.useProgram(p), we can call something like gl.d4(p)

```

By including this small snippet at the top of our code, we have created a runtime environment where every bulky WebGL command is reduced to almost nothing.

##### "Golfing" the Runtime Hasher

In the demoscene, code isn't just written; it's "golfed." Every character removed is a victory. We can take the safe hashing loop above and aggressively squeeze it down, sacrificing readability for size.

A golfed version might remove safety checks and use obscure type coercion tricks to shave off another ~40 bytes:

```javascript
// Alias gl to 'g' for internal references
for(i in g=gl)
  typeof g[i]=='function'&&(
    d=(c++).toString(16),
    // Golfed check: if first char is digit, prepend 'x', else nothing.
    g[(+d[0]==d[0]?'x':'')+d]=g[i]
  )
// Note: Requires variable 'c' to be initialized to 0 previously.

```

### Stage 2: Build-Time Hashing with `demolishedcompressor.Mjolnir` (The "Second Squeeze")

Now that we know what our short runtime aliases will be, we need to rewrite our actual source code to _use_ them. This is the crucial build step that dramatically reduces the raw file size before final compression.

While general minifiers like **Terser** can help with variable renaming, **demolishedcompressor** provides a dedicated and robust solution for this specific problem with its `Mjolnir` function. For the ultimate squeeze, you might still use a specialized demoscene packer like **RegPack** _after_ `Mjolnir` but _before_ the final PNG packing. The use of `Mjolnir` or other tools depends on your specific golfing needs and project setup, as `Mjolnir` is an _option_ in your build chain.

The `Mjolnir` function works by taking a predefined JSON map and performing direct string replacements in your source code. This map is vital because it allows you to precisely control which long names are replaced with which short aliases. This flexibility is key for fine-tuning your golfing strategy and adapting to different WebGL contexts or specific demo needs. The short alias (`key`) on the left must correspond to the alias generated by your runtime hasher.

Here's an example of what a `webgl-method-map.json` file might look like (a representative subset):

```json
// config/webgl-method-map.json
{
    "x0": "copyBufferSubData",
    "x1": "getBufferSubData",
    "x10": "getFragDataLocation",
    "x1f": "vertexAttribI4i",
    "x41": "createTransformFeedback",
    "x58": "activeTexture",
    "x59": "attachShader",
    "x86": "enable",
    "d4": "useProgram",
    "d5": "validateProgram",
    "de": "vertexAttribPointer",
    "df": "viewport"
}

```

This map tells `Mjolnir` to find instances of `gl.useProgram(` in your code and replace them with `gl.d4(`. This ensures that your development code, which might look like `gl.useProgram(P);`, is transformed into `gl.d4(P);` _before_ the final compression, significantly shrinking your raw JavaScript text.

Here's a look at the `Mjolnir` implementation within `demolishedcompressor`:

```typescript
   /**
    * Mjolnir - Hash methods of any API using a map, reduce names etc..
    *
    * @static
    * @param {string} src   - Path to your source JavaScript file (e.g., "my-bundle.js")
    * @param {string} dest  - Path to save the output (hashed) JavaScript file (e.g., "my-hashed-bundle.js")
    * @param {string} map   - Path to the JSON map file (e.g., "webgl-hash-map.json")
    * @returns {Promise<boolean>}
    * @memberof Compressor
    */
    static Mjolnir(src: string, dest: string, map: any): Promise<boolean> {
        return new Promise((resolve, reject) => {
            fs.readFile(path.join(process.cwd(), map), (err, hash: any) => {
                var o = JSON.parse(hash.toString()); // Parse the JSON map
                fs.readFile(path.join(process.cwd(), src), (err, payload) => {
                    if (err) reject(false);
                    var source = payload.toString();
                    Object.keys(o).forEach((key: string) => {
                        var s = "." + o[key] + "("; // The long method name pattern (e.g., ".useProgram(")
                        if (source.includes(s)) {
                            console.log("Mjolnor replacing", o[key] + " with " + key);
                            source = source.split(s).join("." + key + ("(")); // Replace
                        }
                    });
                    fs.writeFile(path.join(process.cwd(), dest), source, function (err) {
                        if (err) reject(err);
                        console.log(dest, " is now completed, see ", dest, "resulted in ", payload.length - source.length, "bytes less (", (100 - (source.length / payload.length) * 100).toFixed(2), "%)");
                        resolve(true);
                    });
                });
            });
        });
    }

```

### The Final Payload: Pixels as Code

We have hashed our context, golfed our code, and run `Mjolnir` to apply the build-time replacements. We are down to a few kilobytes of dense text. How do we deliver the final blow to file size?

We turn the code into an image.

Browsers have incredibly optimized, native decoders for PNG images. PNG uses DEFLATE compression internally (similar to gzip). By treating the string of code as raw pixel data—mapping character codes to R, G, and B values—we can "hide" our payload inside a tiny image file.

This approach requires a "bootstrapper"—a sliver of HTML and JS that loads the PNG onto a canvas, reads the pixels back out, converts them back to a string, and `eval()`s the result.

#### The Audio Autoplay Challenge

A crucial consideration for browser demos with sound is the **browser's autoplay policy**. Modern browsers prevent audio from playing automatically without user interaction. This means your bootstrapper, or the initial logic of your unpacked demo, will likely need to display a simple "Click to Play" or "Press Any Key" prompt. This user interaction then triggers the audio context to start.

#### Enter `demolishedcompressor`'s `Pngify`

Doing this manually is tedious. Fortunately, the demoscene community builds amazing tools.

**[demolishedcompressor](https://github.com/MagnusThor/demolishedcompressor)** by MagnusThor is an excellent tool for automating this workflow.

It takes your final, minified code payload (which now includes your software synth and hashed WebGL calls from `Mjolnir`), pads it to fit a texture, generates the optimized PNG image, and—crucially—provides the highly golfed HTML/JS bootstrapper code needed to unpack and run it.

You can easily integrate it into a Node.js build script to automate the creation of your final release HTML file. Here is an example of a full build sequence:

```typescript
import { Compressor } from 'demolishedcompressor';
import path from 'path';

// Define the minimal HTML structure for the final demo entry point
// This example includes a button that the bootstrapper JS can hook into
// to trigger the audio context after user interaction.
let html = `<canvas style="width:100%;height:100vh;left:0;position:absolute" id=w width=1280 height=720/>
  <style>body{margin:0;background:#000}</style>
  <button id="play" style="position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);font-size:2em;padding:1em;cursor:pointer;">Click to Play</button>`;

// --- Build Sequence ---
// 1. Mjolnir: Hash WebGL methods in the source JavaScript
//    The 'webgl-method-map.json' should contain the aliases for your runtime hasher.
Compressor.Mjolnir(
    path.join(process.cwd(), "src/my-demo-bundle.js"), // Your original bundled JS
    path.join(process.cwd(), "build/my-hashed-demo.js"), // Output hashed JS
    path.join(process.cwd(), "config/webgl-method-map.json") // Your predefined hash map
)
.then(() => {
    console.log("WebGL method hashing completed with Mjolnir.");
    // 2. Pngify: Compress the hashed JS into a PNG and generate the final HTML
    return Compressor.Pngify(
        path.join(process.cwd(), "build/my-hashed-demo.js"), // The hashed JS output
        path.join(process.cwd(), "release/my-demo.html"),   // Final HTML output
        html
    );
})
.then(() => {
    console.log("Demo successfully packed into PNG and HTML generated!");
})
.catch(err => {
    console.error("Build failed:", err);
});

```

This powerful combination handles the heavy lifting of the entire packaging pipeline, ensuring you get the benefits of native browser image decompression with minimal overhead.

### Summary

Creating a tiny browser demo is a journey of transformation. The entire process can be visualized in four key stages:

1.  **Verbose Source:** You start with readable WebGL and audio synth code.
    
2.  **Context Hashing:**
    
    -   **Build-time (`Mjolnir`):** Your build script statically replaces long WebGL method names with short aliases, driven by a flexible JSON map. This map is custom-designed to match your runtime hasher.
        
    -   **Runtime:** A small snippet of code inside your demo dynamically creates these short aliases on the `gl` context.
        
3.  **The Squeeze:** You use minifiers (like Terser or RegPack) to further compress the code, now using the short aliases.
    
4.  **The Pack (`Pngify`):** You use **demolishedcompressor** to turn that squeezed code into pixels in a PNG file, ready to be unpacked by a tiny HTML/JS bootstrapper (which handles user interaction for audio).
    

It’s an extreme workflow for extreme constraints, forcing a deep understanding of both the core language and the browser platform itself.


***Merry christmas.***
