#ifndef JAKE_SHADER_TYPES
#define JAKE_SHADER_TYPES
struct FrameUniforms {
    float4 viewport;
    float4 travel;
    float4 camera;
    float4 effects;
    float4 flags;
    float4 carRect;
    float4 heroRect;
    float4 tuning;
    float4 optics;
    float4 phaseA;
    float4 phaseB;
    float4 phaseC;
    float4 vehicle;
    float4 sampling;
};
struct SpriteInstance { float4 rect; float4 uvRect; float4 color; };
struct Particle { float4 position; float4 seed; };
#endif
