// Festive Path Tracer - Shader Advent Calendar 2025
//
// The final version with anti-aliasing, colored lights, and reflective
// surfaces. A chrome sphere bounces through a scene lit by glowing wall
// squares and a warm yellow floor stripe. All the complex lighting effects
// emerge naturally from bouncing rays randomly until they hit light.
//
// Part of my path tracing tutorial series:
// https://github.com/MagnusThor/so-you-think-you-can-code-2025

#define TIME       iTime
#define RENDERSIZE iResolution

const float
  PI =3.141592654
, TAU=2.*PI
;

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/articles/intersectors/
float ray_unitsphere(vec3 ro, vec3 rd) {
  float
    b=dot(ro, rd)
  , c=dot(ro, ro)-1.
  , h=b*b-c
  ;
  if(h<.0) return -1.;
  return -b-sqrt(h);
}


// License: Unknown, author: Unknown, found: don't remember
float hash(vec2 co) {
  return fract(sin(dot(co.xy ,vec2(12.9898,58.233))) * 13758.5453);
}

// License: Unknown, author: 0b5vr, found: https://www.shadertoy.com/view/ss3SD8
// Returns a rotation matrix that transforms from local space (where Z=up) to world space
mat3 orth_base(vec3 n){
  // Assumes n is normalized
  vec3
    // Pick a helper vector that won't be parallel to n
    // Avoids gimbal lock when normal points straight up/down
    up=abs(n.y)>.999?vec3(0,0,1):vec3(0,1,0)
  , // First tangent: perpendicular to both 'up' and normal
    x=normalize(cross(up,n))
  , // Second tangent: perpendicular to both normal and first tangent
    // Completes the right-handed coordinate system
    y=cross(n,x)
  ;
  return mat3(x,y,n);
}

float g_seed;

// License: Unknown, author: 0b5vr, found: https://www.shadertoy.com/view/ss3SD8
float random() {
  float i = ++g_seed;
  return fract(sin((i)*114.514)*1919.810);
}

// License: Unknown, author: 0b5vr, found: https://www.shadertoy.com/view/ss3SD8
// Generates a cosine-weighted random direction in the hemisphere above normal n
// The sqrt() on cost creates the cosine weighting - more samples near the normal
vec3 uniform_lambert(vec3 n){
  float
    // Random azimuthal angle: spin around the hemisphere (0 to 2π)
    p=PI*2.*random()
  , // Polar angle cosine: sqrt gives cosine-weighted distribution for diffuse
    cost=sqrt(random())
  , // Polar angle sine: derived from cos via trig identity
    sint=sqrt(1.-cost*cost)
  ;
  // Convert from spherical (local) to Cartesian, then transform to world space
  // Local space: Z=up from surface, X/Y=tangent plane
  return orth_base(n)*vec3(cos(p)*sint,sin(p)*sint,cost);
}

vec3 noisy_ray_dir(vec2 uv, vec3 cam_right, vec3 cam_up, vec3 cam_fwd) {
  // Jitter sample position within pixel for antialiasing (stochastic sampling)
  uv += (-1. + 2.*vec2(random(), random())) / RENDERSIZE.y;
  return normalize(-uv.x*cam_right + uv.y*cam_up + 2.*cam_fwd);
}

vec4 pathTracer(vec2 p, vec2 xy) {
  float
    // Number of samples accumulated for this pixel
    samples = 0.
    // Fresnel term for reflectance calculation
  , fresnel
    // Distance to nearest surface intersection
  , t
    // Throughput: remaining light transport capacity of the path
  , throughput
    // Distance to wall plane intersection
  , t_wall
    // Distance to floor plane intersection
  , t_floor
    // Distance to sphere intersection
  , t_sphere
    // Sphere vertical bounce offset
  , bounce
    // Hash value for current wall cell
  , cell_hash
  ;
  vec2
    // Wall surface position in texture space
    wall_pos
    // Wall cell indices for texture tiling
  , cell_idx
    // Position within wall cell [-.5, .5]
  , cell_uv
  ;

  // Initialize RNG seed from pixel position and time
  g_seed = fract(hash(p) + TIME);

  // Compute sphere bounce with easing
  bounce = fract(TIME);
  bounce -= .5;
  bounce *= 2.*bounce;

  const vec3
    // Camera position
    ro        = vec3(4,4,-6.)
    // Camera look-at point
  , la        = vec3(0,.5,-2.)
    // Camera forward basis vector
  , cam_fwd   = normalize(la - ro)
    // Camera right basis vector
  , cam_right = normalize(cross(cam_fwd, vec3(0,1,0)))
    // Camera up basis vector
  , cam_up    = cross(cam_right, cam_fwd)
  ;
  vec3
    // Sphere center position
  , sphere_center = la
    // Accumulated radiance for this pixel
  , radiance      = vec3(0)
    // Current path vertex position
  , pos
    // Previous path vertex position
  , prev_pos
    // Previous path vertex surface normal
  , prev_normal
    // Current surface normal
  , normal
    // Specular reflection direction
  , reflect_dir
    // Diffuse (Lambert) reflection direction
  , diffuse_dir
    // Previous frame color for temporal accumulation
  , prev_frame = texelFetch(iChannel0, ivec2(xy), 0).xyz
  ;

  // Animate sphere with bounce and circular motion
  sphere_center.y -= bounce;
  sphere_center.xz += sin(vec2(1,.707)*.5*TIME);

  // Path termination conditions
  bool
    // Ray missed scene or throughput exhausted
    missed
    // Ray hit emissive wall cell
  , hit_light
    // Ray hit emissive floor stripe
  , hit_stripe
  ;

  // Initialize path from camera
  prev_pos    = ro;
  prev_normal = noisy_ray_dir(p, cam_right, cam_up, cam_fwd);
  throughput  = 1.;

  // Path tracing loop: trace one path per iteration
  for(int i=0; i<150; ++i) {
    // Ray-plane intersection: floor at y = -1
    t_floor   = (-1. - prev_pos.y) / prev_normal.y;
    // Ray-plane intersection: wall at z = 1
    t_wall    = (1. - prev_pos.z) / prev_normal.z;
    // Ray-sphere intersection: unit sphere at sphere_center
    t_sphere  = ray_unitsphere(prev_pos - sphere_center, prev_normal);

    // Find closest intersection
    t = 1e3;
    if(t_floor>0. && t_floor<t)  { t=t_floor;  normal=vec3(0,1,0); }
    if(t_wall>0. && t_wall<t)    { t=t_wall;   normal=vec3(0,0,-1); }
    if(t_sphere>0. && t_sphere<t){ t=t_sphere; normal=normalize(prev_pos+prev_normal*t_sphere-sphere_center);}

    // Advance ray to intersection point
    pos = prev_pos + prev_normal*t;

    // Transform wall intersection to scrolling texture space
    wall_pos  = pos.xy - vec2(TIME, 0.5);
    // Compute cell indices for procedural tiling
    cell_idx  = floor(wall_pos + .5);
    // Compute position within cell
    cell_uv   = wall_pos - cell_idx;
    // Hash cell indices for material properties
    cell_hash = hash(123.4*cell_idx);

    // Check path termination conditions
    missed      = t==1e3 || throughput<1e-1;
    // Wall cells with hash > 0.9 are emissive
    hit_light   = cell_hash>0.9 && t==t_wall;
    // Floor stripe at z = -2 is emissive
    hit_stripe  = t==t_floor && abs(pos.z+2.)<.1 && sin(wall_pos.x)>0.;

    // Early exit: first ray missed entire scene
    if(i==0 && missed) {
      break;
    }

    // Path completed: we hit a light source or missed
    if(missed || hit_light || hit_stripe) {
      if(hit_light) {
        // Procedural light color based on cell hash and distance
        radiance += throughput*(1.1 - length(cell_uv) + sin(vec3(2,1,0) + TAU*fract(8667.*cell_hash)));
      }
      if(hit_stripe) {
        // White emissive stripe
        radiance += throughput*vec3(1,.5,0.);
      }

      // Start new path from camera
      prev_pos    = ro;
      prev_normal = noisy_ray_dir(p, cam_right, cam_up, cam_fwd);
      throughput  = 1.;
      ++samples;
      continue;
    }

    // We hit a non-emissive surface: compute next path segment

    // Schlick's approximation for Fresnel reflectance
    fresnel = 1. + dot(prev_normal, normal);
    fresnel *= fresnel;
    fresnel *= fresnel;
    fresnel *= fresnel;

    // Ideal specular reflection direction
    reflect_dir = reflect(prev_normal, normal);
    // Cosine-weighted hemisphere sample for diffuse
    diffuse_dir = uniform_lambert(normal);

    if(
        // Russian Roulette path splitting approximation:
        // randomly choose specular or diffuse based on Fresnel term
        random() < fresnel
        // Some wall cells are mirrors
      ||(fract(cell_hash*7677.)>0.5 && t==t_wall)
        // Sphere is reflective
      || t==t_sphere
      ) {
      // Specular bounce
      prev_normal = reflect_dir;
      throughput *= .9;
    } else {
      // Diffuse bounce
      prev_normal = diffuse_dir;
      throughput *= .4;
    }

    // Advance path with small offset to prevent self-intersection
    prev_pos = pos + 1e-3*normal;
  }

  // Monte Carlo estimator: average over all samples
  radiance /= max(samples, 1.);
  // Clamp to prevent NaN propagation in temporal accumulation
  radiance = max(radiance, 0.);
  // Temporal accumulation: exponential moving average for variance reduction
  radiance = mix(radiance, prev_frame*prev_frame, .5);
  // Gamma correction (linear to sRGB approximation)
  radiance = sqrt(radiance);

  return vec4(radiance, 1.);
}

void mainImage(out vec4 O, vec2 C) {
  vec2
    p=(-RENDERSIZE.xy+2.*C)/RENDERSIZE.y
  ;
  O=pathTracer(p,C);
}

