#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float time;
    float2 resolution;
    float aspectRatio;
    float colorShift;
    float complexity;
    int symmetry;
    float goldenRatio;
    float breathing;
};

struct Particle {
    float2 position;
    float2 velocity;
    float4 color;
    float life;
    float size;
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]],
                            constant float2* vertices [[buffer(0)]]) {
    VertexOut out;
    out.position = float4(vertices[vertexID], 0.0, 1.0);
    out.texCoord = vertices[vertexID] * 0.5 + 0.5;
    return out;
}

float2 rotate2D(float2 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}

float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float mandelbrot(float2 c, int maxIter) {
    float2 z = float2(0.0);
    for (int i = 0; i < maxIter; i++) {
        if (dot(z, z) > 4.0) return float(i) / float(maxIter);
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
    }
    return 0.0;
}

float julia(float2 z, float2 c, int maxIter) {
    for (int i = 0; i < maxIter; i++) {
        if (dot(z, z) > 4.0) return float(i) / float(maxIter);
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
    }
    return 0.0;
}

float fibonacci(float2 p, float time) {
    float angle = atan2(p.y, p.x) + time * 0.1;
    float radius = length(p);
    
    float fib = sin(angle * 8.0 + radius * 20.0 - time * 2.0) * 0.5 + 0.5;
    fib *= exp(-radius * 2.0);
    
    return fib;
}

float goldenSpiral(float2 p, float goldenRatio, float time) {
    float angle = atan2(p.y, p.x);
    float radius = length(p);
    
    float spiral = sin(angle * goldenRatio + log(radius + 0.001) * goldenRatio * 4.0 - time * 3.0);
    spiral = spiral * 0.5 + 0.5;
    spiral *= smoothstep(0.0, 0.3, radius) * smoothstep(1.5, 0.8, radius);
    
    return spiral;
}

float kaleidoscope(float2 p, int symmetry, float time) {
    float angle = atan2(p.y, p.x);
    float radius = length(p);
    
    angle = fmod(angle + M_PI_F, 2.0 * M_PI_F / float(symmetry));
    if (angle > M_PI_F / float(symmetry)) {
        angle = 2.0 * M_PI_F / float(symmetry) - angle;
    }
    
    float2 kp = float2(cos(angle), sin(angle)) * radius;
    
    float pattern = 0.0;
    pattern += sin(kp.x * 15.0 + time * 2.0) * cos(kp.y * 12.0 + time * 1.5);
    pattern += sin(kp.x * 8.0 - time * 1.2) * sin(kp.y * 10.0 + time * 0.8);
    pattern += cos(kp.x * 20.0 + kp.y * 18.0 + time * 3.0);
    
    return pattern * 0.33 + 0.5;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms& uniforms [[buffer(0)]],
                             constant Particle* particles [[buffer(1)]]) {
    
    float2 uv = (in.texCoord * 2.0 - 1.0);
    uv.x *= uniforms.aspectRatio;
    
    float2 center = float2(0.0);
    uv = (uv - center) * (1.0 + uniforms.breathing * 0.3) + center;
    
    float kaleidoPattern = kaleidoscope(uv, uniforms.symmetry, uniforms.time);
    
    float mandelbrotValue = mandelbrot(uv * 2.0 + float2(sin(uniforms.time * 0.1), cos(uniforms.time * 0.15)), 64);
    
    float2 juliaC = float2(sin(uniforms.time * 0.2) * 0.8, cos(uniforms.time * 0.25) * 0.8);
    float juliaValue = julia(uv * 1.5, juliaC, 32);
    
    float fibValue = fibonacci(uv, uniforms.time);
    
    float spiralValue = goldenSpiral(uv, uniforms.goldenRatio, uniforms.time);
    
    float combinedPattern = kaleidoPattern * 0.4 + mandelbrotValue * 0.2 + juliaValue * 0.2 + fibValue * 0.1 + spiralValue * 0.1;
    
    float hue = combinedPattern + uniforms.colorShift + uniforms.time * 0.05;
    float saturation = 0.8 + sin(uniforms.time * 0.3) * 0.2;
    float brightness = 0.6 + combinedPattern * 0.4;
    
    float3 baseColor = hsv2rgb(float3(hue, saturation, brightness));
    
    float3 particleColor = float3(0.0);
    float2 fragCoord = uv;
    
    for (int i = 0; i < 1000; i++) {
        if (i >= 1000) break;
        
        Particle p = particles[i];
        float2 diff = fragCoord - p.position;
        float dist = length(diff);
        
        if (dist < p.size * 50.0) {
            float influence = exp(-dist * dist / (p.size * p.size * 2500.0));
            particleColor += p.color.rgb * influence * p.life;
        }
    }
    
    float3 finalColor = baseColor + particleColor * 0.5;
    finalColor = pow(finalColor, float3(1.0 / 2.2));
    
    float alpha = 1.0;
    return float4(finalColor, alpha);
}

kernel void particle_compute(uint id [[thread_position_in_grid]],
                           device Particle* particles [[buffer(0)]],
                           constant Uniforms& uniforms [[buffer(1)]]) {
    
    if (id >= 10000) return;
    
    Particle particle = particles[id];
    
    float time = uniforms.time;
    float2 center = float2(0.0);
    
    float2 toCenter = center - particle.position;
    float distToCenter = length(toCenter);
    
    float2 attraction = normalize(toCenter) * 0.0001;
    
    float angle = atan2(particle.position.y, particle.position.x);
    float2 spiral = float2(-sin(angle), cos(angle)) * 0.0002;
    
    float2 noise = float2(
        sin(time * 2.0 + float(id) * 0.1) * 0.0001,
        cos(time * 1.5 + float(id) * 0.15) * 0.0001
    );
    
    particle.velocity += attraction + spiral + noise;
    particle.velocity *= 0.995;
    
    particle.position += particle.velocity;
    
    if (distToCenter > 1.2) {
        particle.position = normalize(particle.position) * 1.2;
        particle.velocity *= -0.5;
    }
    
    particle.life -= 0.001;
    if (particle.life <= 0.0) {
        particle.life = 1.0;
        float newAngle = float(id) * 0.628 + time * 0.1;
        particle.position = float2(cos(newAngle), sin(newAngle)) * 0.1;
        particle.velocity = float2(0.0);
        
        float hue = fract(time * 0.1 + float(id) * 0.01);
        particle.color = float4(hsv2rgb(float3(hue, 0.8, 1.0)), 1.0);
    }
    
    float colorShift = sin(time * 0.5 + float(id) * 0.02) * 0.1;
    float3 hsv = float3(
        fract(uniforms.colorShift + colorShift),
        0.7 + sin(time + float(id) * 0.05) * 0.3,
        particle.life
    );
    particle.color.rgb = hsv2rgb(hsv);
    
    particles[id] = particle;
}