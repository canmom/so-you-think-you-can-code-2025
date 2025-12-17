# Day 22: A Nest of Divergence-Free Fields

On creating complex, swirly shapes with compute shaders in Rust and wgpu.

> Absolutely no AI was used.

## What are we trying to do here?

Have a look at this image.

![A spiraling shape made of white strands.](assets/uzumaki.png)

That's pretty cool, isn't it? I made that in Blender in a few hours, using Geometry Nodes. And, I'll tell you this, I love Geometry Nodes. But I wanted to animate an effect like this in realtime, on the GPU, so that I could use it in demos and such-like things. In particular, I want these noodles in my game *<cite>Shaderland</cite>*!

So what are we actually looking at? This is an example of integrating **curl noise**. It's a type of **vector field** which, crucially, has **zero divergence** everywhere (up to numerical precision, anyway).

### A quick overview of the maths

In slightly more detail: A *<dfn>field</dfn>* in this context is essentially a function of space. For any given point in 3D space, you can get a value.

A mathematician would write that as

$$f \colon \mathbb{R}^3 \to S $$

for some output set $S$, but we are programmers, so let's write it in Rust instead.

```rust
trait Field {
  type Output;

  fn evaluate(p: Point) -> Output;
}
```

A [*<dfn>vector field</dfn>*](https://en.wikipedia.org/wiki/Vector_field) is a field whose values are vectors: multi-dimensional objects, with a magnitude and a direction. Some classic examples of vector fields are the wind and the magnetic field. In graphics we might also think of things like surface normals and hair directions.

In mathematical notation, a vector field is a function like this...

$$\mathbf{F} \colon \mathbb{R}^3 \to \mathbb{R}^3$$

(or more generally, to some vector space), while the programmer might think of specialising the trait above...

```rust
Field<Output = Vector>
```

You can do calculus on these! Just like you can calculate the derivative of a scalar-valued function, you can calculate the derivatives of a vector field, essentially by treating each component of the vector field as its own scalar-valued function and doing calculus on that.

Let's go over some notation. I'm going to be using physicist-style notation because guess what, I studied physics. So: if $\mathbf{F}(\mathbf{r})$ is a vector field, it has three components written $F_x(\mathbf{r})$, $F_y(\mathbf{r})$ and $F_z(\mathbf{r})$. $\mathbf{r}$ represents a point in space with components $x$, $y$ and $z$.

Since these are just regular old single-valued functions, we can calculate their derivatives. Generally speaking we'll be calculating partial derivatives such as $$\frac{\partial F_x}{\partial x}$$, which means 'keep $y$ and $z$ constant and take the derivative with respect to $x$'.

Today, we are specifically interested in [divergence-free fields](https://en.wikipedia.org/wiki/Solenoidal_vector_field). What that essentially means is that there are no 'sources' or 'sinks'. It's a field of vortices, much as you might observe in a fluid; you can get closed loops and helices but if you follow along the field, two field lines will never cross each other. But, it's also *noise*, which means it's smoothly varying and random-looking.

In more mathematical terms, the *<dfn>divergence</dfn>* of a vector field $\mathbf{F}(\mathbf{r})$ is the scalar field

$$
\nabla \cdot \mathbf{F} = \frac{\partial F_x}{\partial x} + \frac{\partial F_y}{\partial y} + \frac{\partial F_z}{\partial z}
$$

It has a sibling in the *<dfn>curl</dfn>*, which is a *vector* field calculated like this...

$$
\nabla \times \mathbf{F} = \begin{pmatrix}
  \frac{\partial F_z}{\partial y} - \frac{\partial F_y}{\partial z} \\
  \frac{\partial F_x}{\partial z} - \frac{\partial F_z}{\partial x} \\
  \frac{\partial F_y}{\partial x} - \frac{\partial F_x}{\partial z} \\
\end{pmatrix}
$$

In very rough terms, when you have nonzero divergence, the vector field is either spreading or converging at that point. And when you have nonzero curl, it's twisting around that point. Want to visualise that? [3Blue1Brown](https://www.youtube.com/watch?v=rB83DpBJQsE) has a nice little video on it.

## Begone, divergence!

Luckily, if you have a way to calculate noise (for example, good old Perlin noise), it's actually quite easy to calculate divergence-free noise! The impetus for all of this came from a Wikipedia article called [simulation noise](https://en.wikipedia.org/wiki/Simulation_noise), which provides some convenient tricks.

You need to start with some sort of noise field, and you need to be able to calculate its derivatives. For this we can turn to Inigo Quilez's [GLSL implementation](https://iquilezles.org/articles/gradientnoise/) of gradient noise with an analytic derivative. Big love to Inigo once again.

Once you've got a way to calculate noise, there are two ways to proceed. 'Curl noise' takes a vector-valued noise function (or three scalar-valued noise functions), while 'bitangent noise' takes two scalar-valued noise functions.

A wrinkle here is that we are trying to use the same noise hash function to calculate multiple different fields. What can we do? A simple trick is to add some large offset to the point where we calculate the noise function. This will take us to a different region of the hash function, which should have absolutely nothing to do with any other region. So, if you have a favourite hash function (mine is `pcg3d`), you can use that for as many noise fields as you require.

Recently in the FieldFX shader jams I've been creating particle sims which use this kind of noise to move particles around, and that can create some beautiful plasma shapes. However, we don't just want particles. We want *noodles*.

### Finding a field line

The trick we use to calculate these noodles is to integrate the field, finding a [*field line*](https://en.wikipedia.org/wiki/Field_line). (In fluid dynamics, this is called a [*streamline*](https://en.wikipedia.org/wiki/Streamlines,_streaklines,_and_pathlines), and in general this is an [integral curve](https://en.wikipedia.org/wiki/Integral_curve)).

Let's say we start at a point $\mathbf{p}_0$. We evaluate the field at $\mathbf{p}_0$, getting a vector $\mathbf{F}(\mathbf{p}_0)$; then walk a small distance in that direction to a new point $\mathbf{p}_1$. Repeat as many times as we want, and we get a series of points along the streamline (up to numerical error, anyway).

In mathematical terms, this is using [Euler's method](https://en.wikipedia.org/wiki/Euler_method) to calculate an approximate solution to this differential equation:

$$
\frac{d\mathbf{r}}{dt}=\mathbf{F}(\mathbf{r}(t))
$$

with the initial condition $\mathbf{r}(0) = \mathbf{p}_0$. If you want a more accurate result, you can use a different integration scheme like implicit Euler or RK4, but regular explicit Euler has the advantage of being dead simple and fast, and really, the only thing we care about is 'does it look pretty'. Better integration is an exercise to the reader ;P

## Drawing a field line

OK, what do we do once we have those points? Well, there are various possibilities, but since we're using the GPU, my inclination is to do an **instanced draw** where an instance is one cylindrical segment stretching between two successive points of the noodle.

### Drawing in wgpu

Today I'll be using [wgpu](https://docs.rs/wgpu/latest/wgpu/), a Rust library which gives a WebGPU-like abstraction over APIs such as Vulkan, Metal and DirectX12. Although it was invented for Firefox's implementation of webgpu, it has become pretty much the backbone of the Rust game ecosystem.

In order to draw our noodles, we need to carry out the following operations:

- create the 'noodle segment' instance model and upload it to the GPU
- create a compute shader pipeline to calculate where all the instances should be
- create a graphics pipeline to render the noodle segments
- queue up the compute pipeline and then the graphics pipeline on every frame

But before we do any of that, we've got some homework to do.

### Let's get started, shall we?

For the sake of this project, I'll demonstrate it in a standalone application. But it should be easy enough to extract the relevant bits to an existing Rust program using wpgu.

This is not a sizecoding project! The binary will probably be several megabytes just from the library code alone. But we don't want to be extravagant, not to mention we would like our code to be faster, so let's turn on stripping and link-time optimisation:

```toml
[profile.release]
lto = "thin"

[target.'cfg(not(target_arch = "wasm32"))'.profile.release]
strip = "symbols"
```
At time of writing, having `strip` enabled breaks `wasm-opt` for mysterious reasons related to bulk memory operations, so we have to disable it for web builds.

By default, Rust will give us a 'hello world' program. Let's run `cargo build --release` and make sure nothing untoward has happened. On Windows, this will result in a `noodles.exe` program weighing about 133KB.

(Yeah, that's pretty huge for a hello world, but Rust is not optimised for sizecoding out of the box! It will by default generate a lot of panic-handling code to unwind the stack and print the results to the console, and statically link the pre-built standard library. We can run `cargo bloat` and find that nearly all of those kilobytes are from backtrace code and string handling. This can be removed easily enough, see [min-sized Rust](https://github.com/johnthagen/min-sized-rust) to find out how, but for our purposes this is fine and having backtraces will be useful when something goes wrong.)

### Getting a window on the screen

So, we need a window to see anything. I will broadly follow along with [Learn WGPU](https://sotrh.github.io/learn-wgpu/beginner/tutorial1-window/) to create a window with winit and set up wgpu state. The code for setting everything up is mostly not of interest for this article, so I will mostly brush over it.

At the time of writing, the versions of `wgpu` and `winit` I am using are...

```toml
[dependencies]
wgpu = "27.0.1"
winit = "0.30.12"
```

But if you're reading this article in the future, a different version may be current! The API of `wgpu` changes sometimes, mainly to add features. If you're using an IDE, it should warn you if you're missing a struct field or similar problems.

Following the first two parts of the guide, we will set up a basic `wgpu` and `winit` application, creating a resizable window on native targets and a WASM+WebGPU application on web targets. I've added the option to switch between fullscreen and windowed with the F11 key. Then, we'll set up a basic render pass which clears the screen.

We need some types to store vectors and matrices. I will be using [`glam`](https://docs.rs/glam/0.30.9/glam/index.html), since it offers some convenient features. It is potentially possible to use other crates, like cgmath. I'll also be using [`bytemuck`](https://docs.rs/bytemuck/1.24.0/bytemuck/index.html) for casting to bytes to send to the GPU.

```toml
bytemuck = "1.24.0"
glam = {version = "0.30.9", features = ["bytemuck"]}
```

We'll diverge from the tutorial on page 3, where we start creating pipelines. If you have an existing wgpu application (including projects using other Rust libraries which use wgpu, such as Bevy or Iced), this should be able to be dropped into your existing rendering logic.

With all the logging features and such, a basic 'clears the screen' wgpu application weighs around 8MB on native. I won't keep track of this further, just noting this to give a sense of what a default Rust application looks like to the sizecoding-curious.

## Let's make some pipelines

So, we need to do two things here: a compute pipeline and a standard rendering pipeline. We'll start with the latter, since we'll have a hard time knowing if the compute pipeline is doing its job if we can't render the results.

First, we need to figure out what data we'll be sending to the GPU. To begin with, our model segment will be made up of vertices. For a geometer, a vertex is a point in space. For a graphics programmer, a vertex is a struct. Here's what I'll be using today:

```rust
#[repr(C)]
#[derive(Debug, Copy, Clone, bytemuck::Zeroable, bytemuck::Pod)]
pub struct Vertex {
    pub position: glam::Vec3,
    pub colour: glam::Vec3,
}
```
Nice and simple: six floats, 24 bytes. Why no normals? For the specific model we're using, we don't actually need them, they can be calculated from the position.

We'll also need to tell wgpu how this struct is laid out, which involves creating an array of vertex attribute descriptors. There is a helper macro [`vertex_attr_array`](https://docs.rs/wgpu/latest/wgpu/macro.vertex_attr_array.html) to help here. I didn't know about that macro for months, so I was adding up all the offsets by hand. Don't be me...

```rust
impl Vertex {
    pub const LAYOUT: wgpu::VertexBufferLayout<'static> = wgpu::VertexBufferLayout {
        array_stride: std::mem::size_of::<Self>() as wgpu::BufferAddress,
        step_mode: wgpu::VertexStepMode::Vertex,
        attributes: &wgpu::vertex_attr_array![
            0 => Float32x3,
            1 => Float32x3,
        ],
    };
}
```

A pipeline segment needs both a start point and an endpoint. At each point, we need the [normal and bitangent](https://en.wikipedia.org/wiki/Frenet%E2%80%93Serret_formulas): the basis vectors of a 2D space perpendicular to the line we're following.

I think we could in principle overlap the data of successive segments since the endpoint of one segment is the start point of the next, which would save about half the data. But that might lead to problems to do with the array stride, and handling endpoints would get a fiddly, so for simplicity's sake, we'll treat each segment as its own, non-overlapping struct.

We define an instance like so:

```rust
#[repr(C)]
#[derive(Copy, Clone, Debug, bytemuck::Pod, bytemuck::Zeroable)]
pub struct TubeInstance {
    pub start_position: [f32; 3],
    pub start_normal: [f32; 3],
    pub start_bitangent: [f32; 3],
    pub end_position: [f32; 3],
    pub end_normal: [f32; 3],
    pub end_bitangent: [f32; 3],
    pub radius: f32,
}
```

This adds up to a total of 19 floats, or 76 bytes, per instance. We need to provide a `VertexBufferLayout` to wgpu to describe this struct. 

```rust
impl TubeInstance {
    pub const LAYOUT: wgpu::VertexBufferLayout<'static> = wgpu::VertexBufferLayout {
        array_stride: std::mem::size_of::<Self>() as wgpu::BufferAddress,
        step_mode: wgpu::VertexStepMode::Instance,
        attributes: &wgpu::vertex_attr_array![
            2 => Float32x3,
            3 => Float32x3,
            4 => Float32x3,
            5 => Float32x3,
            6 => Float32x3,
            7 => Float32x3,
            8 => Float32,
        ],
    };
}
```
These numbers will be used in our shader to read out the attributes, so it's important they don't overlap for the instance and vertex.

### Filling out the forms

Since it's abstracting modern, low-level APIs like DirectX 12 and Vulkan, to draw something in wgpu amounts to a lot of 'filling out forms'. In some ways, it's quite easy. The type system tells you more or less what you need at each stage, so it's your job to construct the desired types.

With wgpu, you can usually work backwards. Ultimately, to render stuff we're going to need a [`RenderPipeline`](https://docs.rs/wgpu/latest/wgpu/struct.RenderPipeline.html). How do we create a render pipeline? The documentation helpfully tells us: we need to call [`create_render_pipeline`](https://docs.rs/wgpu/latest/wgpu/struct.Device.html#method.create_render_pipeline) on a `Device`, and that takes a `RenderPipelineDescriptor`.

Well, then we can ask what goes into a `RenderPipelineDescriptor`? Follow the documentation, and we find it takes this stuff:

```rust
pub struct RenderPipelineDescriptor<'a> {
    pub label: Label<'a>,
    pub layout: Option<&'a PipelineLayout>,
    pub vertex: VertexState<'a>,
    pub primitive: PrimitiveState,
    pub depth_stencil: Option<DepthStencilState>,
    pub multisample: MultisampleState,
    pub fragment: Option<FragmentState<'a>>,
    pub multiview: Option<NonZeroU32>,
    pub cache: Option<&'a PipelineCache>,
}
```
Most of these are structs defined by wgpu, and for each one, we can look up how to create it, typically by calling a function on `Device`. (It's a lot easier with an IDE which supports Rust-Analyzer, which can autofill the skeleton of the type for you.)

What are the important fields for this article? Well, we definitely need a vertex and fragment shader, so let's start with that.

## The vertex shader

We will need to start by telling the vertex shader what to expect, and what to output. This largely follows the attributes we defined above, just wgsl flavoured instead of Rust-flavoured.

```wgsl
struct VertexInput {
    @location(0) position: vec3<f32>,
    @location(1) colour: vec3<f32>,
}

struct Instance {
    @location(2) start_position: vec3<f32>,
    @location(3) start_normal: vec3<f32>,
    @location(4) start_bitangent: vec3<f32>,
    @location(5) end_position: vec3<f32>,
    @location(6) end_normal: vec3<f32>,
    @location(7) end_bitangent: vec3<f32>,
    @location(8) radius: f32,
}

struct VertexOutput {
    @builtin(position) clip_position : vec4<f32>,
    @location(0) normal: vec3<f32>,
    @location(1) colour: vec3<f32>,
}
```

We'll also need the camera view-projection matrix. This can be passed in as a uniform, I'll get into that subject later. For now, from the shader point of view, it's declared like this:

```wgsl
struct Uniforms {
    camera: mat4x4<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
```
I'll be adding more stuff to the uniforms later!

To draw a segment we need to figure out where the vertices must end up, then project them into perspective. Let's start with the first part.

Each invocation of the vertex shader gets a copy of the instance data, and the data for one specific vertex of the original model. So, we need to know a little about the structure of the model we're going to be rendering. Essentially, it will be a cylinder of radius 1, pointed in the `z` direction. So you have some number of vertices in a circle in the xy plane, and some other number of vertices in a circle in the z=1.0 plane.

As such, we can select whether to use the start or endpoint based on the value of `z`. So, the first three lines of our shader select which part of the instance data to use.

```wgsl
@vertex
fn vs_main(vert: VertexInput, instance: Instance) -> VertexOutput {
    let curve_position = mix(instance.start_position, instance.end_position, vert.position.z);
    let curve_normal = mix(instance.start_normal, instance.end_normal, vert.position.z);
    let curve_bitangent = mix(instance.start_bitangent, instance.end_bitangent, vert.position.z);
    //continued...
```
Would it be faster to do a branch instead of a multiply? Not sure. Perhaps we can benchmark it later. I doubt it will make a huge difference, but perhaps if we can find a way to let the compiler know that `vert.position.z` will only take two values, it can make some optimisation.

The curve's normal and bitangent vectors are essentially the 'new' `x` and `y` for our cylinder. So we can project into 'cylinder space' simply by multiplying the unit vectors by the coordinates.

```wgsl
    //...
    let world_normal = vert.position.x * spline_normal + vert.position.y * spline_bitangent;
    let world_position = spline_position + world_normal * instance.radius;
    //...
```
Now we need to project it into camera space. This is just a matrix-vector multiplication:

```wgsl
    //...
    let clip_position = uniforms.camera * vec4(world_position, 1.0);
    return VertexOutput(clip_position, world_normal, vert.colour);
}
```
Of course, we do need to actually *calculate* the camera matrix.

### Back to Rust...

Back on the CPU, we now need to pass the shader we just wrote to the pipeline. This means we need a module. A module can be compiled directly from the WGSL source, but if you are dealing with user-written shaders, it's good to validate it by compiling it with Naga and handling errors before you pass the resulting module to wgpu, or your program will panic. (If you find yourself writing a game about shader programming, this may be important...)

We can use Rust's `include_str!` macro to include the shader directly inside our executable as a static string reference.

```rust
let shaders = device.create_shader_module(wgpu::ShaderModuleDescriptor {
    label: Some("Noodles vertex shader"),
    source: wgpu::ShaderSource::Wgsl(include_str!("shaders/tube.wgsl").into()),
});
```

Then we can pass a reference to this module in the render pipeline descriptor.

```rust
wgpu::RenderPipelineDescriptor {
    //...
    vertex: wgpu::VertexState {
        module: &shaders,
        entry_point: Some("vs_main"),
        compilation_options: Default::default(),
        buffers: &[Vertex::LAYOUT, TubeInstance::LAYOUT],
    },
    //...
}
```

## Fragment shader

We can do pretty much any sort of surface we can imagine with the fragment shader, but to begin with, I'm going to go for bog-standard Lambertian diffuse lighting. First, let's put a light direction into the uniforms, so change the declaration to...

```wgsl
struct Uniforms {
    camera: mat4x4<f32>,
    light_direction: vec3<f32>,
    ambient: vec3<f32>
}
```
Then, we can do this:

```wgsl
@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    return vec4(in.colour * saturate(dot(uniforms.light_direction, in.normal))
        + in.colour * uniforms.ambient, 1.0);
}
```
This should be enough to verify whether the shader is working. We can make it prettier later.

### Once again, to Rust...

We can include the fragment shader very simply. Only real difference is that we need to include the colour target state instead of the input buffer layouts.

```rust
wgpu::RenderPipelineDescriptor {
    //...
    fragment: Some(wgpu::VertexState {
        module: &shaders,
        entry_point: Some("fs_main"),
        compilation_options: Default::default(),
        targets: &[Some(wgpu::ColorTargetState {
            format: surface_format,
            blend: Some(wgpu::BlendState::REPLACE),
            write_mask: wgpu::ColorWrites::ALL,
        })],
    }),
    //...
}
```
Our noodles will be completely opaque, so we don't have to do anything fancy here. Where do we get `surface_format`? We have to pass that in from outside when constructing the render pipeline.

We'll also need to handle the depth buffer. For this, you must create a texture and view the same size as the screen buffer. We can largely follow [Learn WGPU](https://sotrh.github.io/learn-wgpu/beginner/tutorial8-depth/) here, but this is important to note if you're using a framework (such as Iced) which gives you a framebuffer but not a depth buffer.

For the depth buffer, we can use the [clever trick](https://www.reedbeta.com/blog/depth-precision-visualized/) of reversing the depth values to better distribute floating point precision. Right now that simply means using `Greater` rather than `Less` as our comparison function.

```rust
wgpu::RenderPipelineDescriptor {
    //...
    depth_stencil: Some(wgpu::DepthStencilState {
        format: wgpu::TextureFormat::Depth32Float,
        depth_write_enabled: true,
        depth_compare: wgpu::CompareFunction::Greater,
        stencil: Default::default(),
        bias: Default::default(),
    }),
    //...
}
```
That leaves the uniforms.

## Putting on the uniform

Let's first make a struct on the Rust side to store our uniforms. 

```rust
#[repr(C)]
#[derive(Debug, Copy, Clone, bytemuck::AnyBitPattern)]
struct Uniforms {
    camera: glam::Mat4,
    light_direction: glam::Vec3,
    ambient: glam::Vec3,
}
```
This can't be `Pod` due to the padding brought in by the `glam` types, since the `Mat4` needs 16-byte alignment and the two `Vec3`s add up to 12 bytes between them. We could work around this by adding some padding floats, but actually it's fine for it to just have `AnyBitPattern`.

Now we need to create the pipeline layout, and also the uniform buffer itself. First the buffer:

```rust
let uniform_buffer = device.create_buffer(&wgpu::BufferDescriptor {
    label: Some("Noodle uniform buffer"),
    size: (std::mem::size_of::<Uniforms>() as u64).div_ceil(16) * 16,
    usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
    mapped_at_creation: false,
});
```
wgpu requires a 16-byte aligned size, and will get upset if it doesn't get it. In this case we are actually guaranteed that, but I always round the size to a multiple of 16 just in case.

The pipeline layout tells the pipeline what resources such as uniform buffers, storage buffers, texture samplers and so forth to provide to the shaders. It is actually possible to derive this automatically from the shaders by passing `None` instead of a layout when creating the render pipeline. However, we will still need to create a bind group that matches the layout. Although we haven't finished creating the render pipeline yet, the way to do this will be like so...

```rust
let bind_group_layout = render_pipeline.get_bind_group_layout(0);

let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
    label: Some("Noodle bind group"),
    layout: &bind_group_layout,
    entries: &[wgpu::BindGroupEntry {
        binding: 0,
        resource: uniform_buffer.as_entire_binding(),
    }],
});
```
The rest of the stuff going into the render pipeline is all pretty standard, we're mostly disabling stuff like multisampling for this render pipeline. (Later we might want to add MSAA, but for now, keeping it chunky.)

### The camera matrix

The [perspective projection matrix](https://scratchapixel.com/lessons/3d-basic-rendering/perspective-and-orthographic-projection-matrix/opengl-perspective-projection-matrix.html). Don't we love it? It's the beautiful, magic gem at the heart of the temple of rasterisation.

If you're not familiar with this beast, I highly recommend taking a look through Scratchapixel. Maybe you could try writing [a software rasteriser](https://canmom.art/programming/graphics/rasteriser/), like I did eight years ago... who could have known where that would lead.

Since the vertex shader already handles the transformation from model space into world space for our spline segments, what we are calculating here is just the View-Projection matrix. We need to rotate everything into the space of our camera, project it to normalised device coordinates, and set up the z-divide.

We could work through the maths of constructing a perspective projection matrix for our problem right here, or we can just [use `glam`](https://docs.rs/glam/latest/glam/f32/struct.Mat4.html#method.perspective_infinite_reverse_rh to do it].

