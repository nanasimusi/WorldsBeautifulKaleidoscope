#include <metal_stdlib>
using namespace metal;

float3 particle_hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

struct ParticleUniforms {
    float deltaTime;
    float time;
    float2 emitterPosition;
    float2 gravity;
    float2 windForce;
    float turbulence;
    float attractorStrength;
    float dampening;
    float colorShift;
    int symmetryCount;
    float breathingPhase;
    float goldenRatio;
};

struct Particle {
    float4 position;
    float4 velocity;
    float4 color;
    float size;
    float life;
    float maxLife;
    float mass;
};

struct ParticleVertexOut {
    float4 position [[position]];
    float4 color;
    float size [[point_size]];
};

kernel void particle_update_compute(uint id [[thread_position_in_grid]],
                                  device Particle* particles [[buffer(0)]],
                                  constant ParticleUniforms& uniforms [[buffer(1)]]) {
    
    if (id >= 10000) return;
    
    device Particle& particle = particles[id];
    
    if (particle.color.w <= 0.0) return;
    
    float2 position = particle.position.xy;
    float2 velocity = particle.velocity.xy;
    
    float2 forces = float2(0.0);
    
    forces += uniforms.gravity * particle.mass;
    
    forces += uniforms.windForce;
    
    float2 toCenter = uniforms.emitterPosition - position;
    float distanceToCenter = length(toCenter);
    if (distanceToCenter > 0.001) {
        forces += normalize(toCenter) * uniforms.attractorStrength / (distanceToCenter * distanceToCenter);
    }
    
    float noise = sin(uniforms.time * 3.0 + float(id) * 0.1) * cos(uniforms.time * 2.0 + float(id) * 0.2);
    forces += float2(noise, noise * 0.7) * uniforms.turbulence;
    
    for (int sym = 0; sym < uniforms.symmetryCount; sym++) {
        float angle = float(sym) * 2.0 * M_PI_F / float(uniforms.symmetryCount);
        float2 symmetryCenter = float2(cos(angle), sin(angle)) * 0.3;
        
        float2 toSymmetryCenter = symmetryCenter - position;
        float distToSymCenter = length(toSymmetryCenter);
        if (distToSymCenter > 0.001) {
            forces += normalize(toSymmetryCenter) * 0.1 / (distToSymCenter + 0.1);
        }
    }
    
    velocity += forces * uniforms.deltaTime / particle.mass;
    velocity *= pow(uniforms.dampening, uniforms.deltaTime);
    
    position += velocity * uniforms.deltaTime;
    
    float boundaryRadius = 1.5;
    if (length(position) > boundaryRadius) {
        position = normalize(position) * boundaryRadius;
        velocity = reflect(velocity, -normalize(position)) * 0.7;
    }
    
    particle.position.xy = position;
    particle.velocity.xy = velocity;
    
    particle.life -= uniforms.deltaTime;
    
    float lifeRatio = particle.life / particle.maxLife;
    particle.color.w = smoothstep(0.0, 0.2, lifeRatio) * smoothstep(1.0, 0.8, lifeRatio);
    
    float colorShiftAmount = sin(uniforms.time * 0.5 + float(id) * 0.02) * 0.1;
    float hue = fract(uniforms.colorShift + colorShiftAmount + float(id) * 0.01);
    float saturation = 0.8 + sin(uniforms.time * 0.3 + float(id) * 0.05) * 0.2;
    float brightness = lifeRatio * (0.8 + sin(uniforms.time * 0.4 + float(id) * 0.03) * 0.2);
    
    particle.color.rgb = particle_hsv2rgb(float3(hue, saturation, brightness));
    
    float breathingScale = 1.0 + uniforms.breathingPhase * 0.3;
    particle.size = particle.size * breathingScale * (0.5 + lifeRatio * 0.5);
}

vertex ParticleVertexOut particle_vertex(uint vertexID [[vertex_id]],
                                        constant Particle* particles [[buffer(0)]],
                                        constant ParticleUniforms& uniforms [[buffer(1)]]) {
    
    ParticleVertexOut out;
    
    Particle particle = particles[vertexID];
    
    if (particle.color.w <= 0.0) {
        out.position = float4(0, 0, -1000, 1);
        out.color = float4(0);
        out.size = 0;
        return out;
    }
    
    out.position = float4(particle.position.xy, 0, 1);
    out.color = particle.color;
    out.size = particle.size * 50.0;
    
    return out;
}

fragment float4 particle_fragment(ParticleVertexOut in [[stage_in]],
                                float2 pointCoord [[point_coord]]) {
    
    float2 center = pointCoord - 0.5;
    float distance = length(center);
    
    if (distance > 0.5) {
        discard_fragment();
    }
    
    float alpha = 1.0 - smoothstep(0.3, 0.5, distance);
    alpha *= alpha;
    
    float4 color = in.color;
    color.w *= alpha;
    
    float glow = exp(-distance * distance * 8.0);
    color.rgb += glow * 0.3;
    
    return color;
}

