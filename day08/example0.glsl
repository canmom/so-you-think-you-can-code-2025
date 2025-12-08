// CC0: Basic Ray Tracer - Shader Advent Calendar 2025
//
// A simple ray tracer with direct lighting to show where we're starting.
// No shadows, no bounces, just flat diffuse shading. Compare this to the
// path traced versions to see what emerges when light bounces naturally!
//
// Part of my path tracing tutorial series:
// https://github.com/MagnusThor/so-you-think-you-can-code-2025

#define TIME       iTime
#define RENDERSIZE iResolution

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

vec4 simpleRayTracer(vec2 p, vec2 xy) {
  float
    // Vertical offset for sphere bounce animation
    bounce
  ;

  // Compute sphere bounce with easing (parabolic motion)
  bounce = fract(TIME);
  bounce -= .5;
  bounce *= 2.*bounce;

  const vec3
    // Camera origin (eye position)
    ro        = vec3(4,4,-6.)
    // Look-at point (camera target)
  , la        = vec3(0,.5,-2.)
    // Camera forward vector (viewing direction)
  , cam_fwd   = normalize(la - ro)
    // Camera right vector (horizontal axis)
  , cam_right = normalize(cross(cam_fwd, vec3(0,1,0)))
    // Camera up vector (vertical axis)
  , cam_up    = cross(cam_right, cam_fwd)
    // Light direction for diffuse shading
  , light_dir = normalize(vec3(3,3,-2))
  ;

  vec3
    // Animated sphere center (starts at look-at point)
    sphere_center = la
    // Ray direction through pixel (camera-to-world transform)
  , rd            = normalize(-p.x*cam_right + p.y*cam_up + 2.*cam_fwd)
    // Accumulated light (final pixel color)
  , color         = vec3(0)
    // Surface normal at intersection point
  , normal
  ;

  // Animate sphere with bounce and circular motion
  sphere_center.y -= bounce;
  sphere_center.xz += sin(vec2(1,.707)*.5*TIME);

  float
    // Distance to floor intersection (y = -1 plane)
    t_floor   = (-1. - ro.y) / rd.y
    // Distance to wall intersection (z = 1 plane)
  , t_wall    = (1. - ro.z) / rd.z
    // Distance to sphere intersection (unit sphere at sphere_center)
  , t_sphere  = ray_unitsphere(ro - sphere_center, rd)
    // Closest intersection distance found so far
  , t         = 1e3
    // Diffuse lighting coefficient (N·L)
  , diffuse
  ;

  // Find closest intersection by testing all primitives directly
  // We keep the smallest positive t value - this is the nearest surface hit
  if(t_floor>0.   && t_floor<t)   { t=t_floor;  normal=vec3(0,1,0); }
  if(t_wall>0.    && t_wall<t)    { t=t_wall;   normal=vec3(0,0,-1); }
  if(t_sphere>0.  && t_sphere<t)  { t=t_sphere; normal=normalize(ro+rd*t_sphere-sphere_center);}

  if(t < 1e3) {
    // Lambertian diffuse shading (cosine falloff)
    diffuse = max(0., dot(normal, light_dir));
    if(t==t_floor) {
      // Give floor is a reddish color
      color = vec3(1,0,.25);
    } else if(t==t_wall) {
      // Give floor is a bluish color
      color = vec3(0,.25,1);
    } else if(t==t_sphere) {
      // The sphere is white
      color = vec3(1);
    } else {
      // Missed the scene
      color=vec3(0);
    }
    color*=diffuse;
  }

  return vec4(color, 1.);
}

void mainImage(out vec4 O, vec2 C) {
  vec2
    // NDC coordinates [-1,1] with aspect ratio correction
    p=(-RENDERSIZE.xy+2.*C)/RENDERSIZE.y
  ;
  O=simpleRayTracer(p,C);
}