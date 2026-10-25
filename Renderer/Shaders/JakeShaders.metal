#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"
#define TEXTURE_PARAMETERS , texture2d<float> asphaltColor, texture2d<float> asphaltSurface, texture2d<float> concreteColor, texture2d<float> concreteSurface, texture2d<float> flowNoise
#define TEXTURE_ARGUMENTS , asphaltColor, asphaltSurface, concreteColor, concreteSurface, flowNoise
constexpr sampler materialSampler(coord::normalized, address::repeat, filter::linear, mip_filter::linear, max_anisotropy(8));
constexpr sampler spriteSampler(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::linear);
constexpr sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear);
#define SAMPLE_REPEAT(T,U) T.sample(materialSampler,U)
#include "SceneCore.inc"
struct ScreenVertex { float4 position [[position]]; float2 uv; };
vertex ScreenVertex fullscreenVertex(uint vid [[vertex_id]]) {
    float2 v=float2((vid << 1) & 2, vid & 2);
    ScreenVertex out;out.position=float4(v.x*2.0-1.0,1.0-v.y*2.0,0,1);out.uv=v;return out;
}
struct SceneAttachments {
    half4 color [[color(0)]];
    half4 motionDepth [[color(1)]];
    half4 materialData [[color(2)]];
};
fragment SceneAttachments sceneFragment(ScreenVertex in [[stage_in]], constant FrameUniforms &u [[buffer(0)]],
    texture2d<float> asphaltColor [[texture(0)]], texture2d<float> asphaltSurface [[texture(1)]],
    texture2d<float> concreteColor [[texture(2)]], texture2d<float> concreteSurface [[texture(3)]], texture2d<float> flowNoise [[texture(4)]]) {
    SceneSample s=jdScene(in.uv,u TEXTURE_ARGUMENTS);
    SceneAttachments out;
    out.color=half4(half3(s.color),1);
    out.motionDepth=half4(half2(s.velocity),half(s.depth),half(s.surface));
    out.materialData=half4(half(s.roughness),half(s.wetness),half(s.objectID),1);
    return out;
}
fragment half4 motionBlurFragment(ScreenVertex in [[stage_in]], constant FrameUniforms &u [[buffer(0)]],
    texture2d<float> color [[texture(0)]], texture2d<float> motion [[texture(1)]]) {
    if(u.sampling.y>.5) return half4(color.sample(linearSampler,in.uv));
    float4 md=motion.sample(linearSampler,in.uv);
    float2 velocity=md.xy;
    float pixels=length(velocity*u.viewport.xy);
    velocity*=min(1.0,u.effects.y/max(pixels,0.0001));
    int count=clamp(int(u.tuning.x),3,17);
    float3 sum=float3(0);float total=0;
    for(int i=0;i<17;++i) {
        if(i>=count) break;
        float t=float(i)/float(count-1)-0.5;
        float2 coord=clamp(in.uv+velocity*t,float2(0.001),float2(0.999));
        float4 other=motion.sample(linearSampler,coord);
        float edge=abs(other.w-md.w)<0.1 && abs(other.z-md.z)<max(1.8,md.z*0.12) ? 1.0 : 0.0;
        float weight=exp(-t*t*6.0)*edge;
        sum+=color.sample(linearSampler,coord).rgb*weight;total+=weight;
    }
    if(total<0.001) return half4(color.sample(linearSampler,in.uv));
    return half4(half3(sum/total),1);
}
fragment half4 focusDepthFragment(ScreenVertex in [[stage_in]],constant FrameUniforms &u [[buffer(0)]],
    texture2d<float> source [[texture(0)]],texture2d<float> depth [[texture(1)]]) {
    float d=depth.sample(linearSampler,in.uv).z;
    float radius=smoothstep(12.0,90.0,d)*2.5*u.tuning.y;
    float2 px=1.0/u.viewport.xy;
    float3 total=source.sample(linearSampler,in.uv).rgb;float weights=1.0;
    for(int i=0;i<8;++i) {
        float angle=float(i)*0.785398163;
        float2 uv=in.uv+float2(cos(angle),sin(angle))*px*radius;
        float neighbor=depth.sample(linearSampler,uv).z;
        float weight=abs(neighbor-d)<max(2.0,d*0.2)?0.5:0.0;
        total+=source.sample(linearSampler,uv).rgb*weight;weights+=weight;
    }
    return half4(half3(total/weights),1);
}
constant uint messageBits[96] = {
1,1,1,0,0,1,0,0,1,0,1,1,1,0,0,0,1,0,0,0,0,0,0,0,1,1,1,0,1,0,0,0,1,0,1,1,0,1,1,1,1,0,1,0,1,1,1,1,1,1,1,0,0,1,0,1,1,0,1,1,1,0,0,1,1,0,1,1,0,0,1,1,1,1,1,0,0,1,0,1,1,0,1,0,1,1,1,0,1,0,0,0,1,0,0,1
};
fragment half4 environmentFragment(ScreenVertex in [[stage_in]],constant FrameUniforms &u [[buffer(0)]],
    texture2d<float> background [[texture(0)]],texture2d<float> carBody [[texture(1)]],
    texture2d<float> brakeEmission [[texture(2)]],texture2d<float> brakeHalo [[texture(3)]],
    texture2d<float> binaryGlyphs [[texture(4)]],texture2d<float> flowNoise [[texture(5)]],texture2d<float> contactShadow [[texture(6)]]) {
    float2 uv=in.uv;
    float3 c=background.sample(linearSampler,uv).rgb;
    if(u.tuning.z>0.5) for(int layer=0;layer<2;++layer) {
        float columns=layer==0?100.0:72.0;
        float rows=layer==0?60.0:48.0;
        float col=floor(uv.x*columns);
        float seed=jdHash(col+float(layer)*117.0);
        float y=uv.y*rows-u.phaseC.x*76800.0*((28.0+floor(seed*45.0))*0.00125)+seed*63.0;
        int index=(int(floor(y))+int(col)*7+layer*31)%96;if(index<0)index+=96;
        float2 cell=float2(fract(uv.x*columns),fract(y));
        float bit=float(messageBits[index]);
        float ink=binaryGlyphs.sample(linearSampler,float2(cell.x*0.5+bit*0.5,cell.y)).a;
        float bottom=1.0-smoothstep(0.25+seed*0.12,0.70,uv.y);
        float maskCenter=1.0-0.72*exp(-dot((uv-float2(0.5,0.43))*float2(3.7,3.3),(uv-float2(0.5,0.43))*float2(3.7,3.3)));
        float dropout=smoothstep(0.15,0.65,seed);
        float pulse=0.30+0.70*pow(0.5+0.5*sin(y*0.261799388+seed*17.0),4.0);
        c+=float3(0.0025,0.013,0.005)*ink*bottom*maskCenter*dropout*pulse*(layer==0?1.0:0.52);
    }
    if(u.tuning.w>0.5) {
        float2 local=(uv-u.carRect.xy)/u.carRect.zw;
        float ground=u.vehicle.w;
        float2 c0=(local-float2(.080,.790))*float2(14,48);
        float2 c1=(local-float2(.478,.920))*float2(10,48);
        float2 c2=(local-float2(.888,.920))*float2(12,48);
        float shadow=0.30*max(max(exp(-dot(c0,c0)),exp(-dot(c1,c1))),exp(-dot(c2,c2)));
        c*=1.0-shadow;
        float2 reflectUV=float2(local.x,2.0*ground-local.y);
        float noise=flowNoise.sample(materialSampler,float2(uv.x*4,uv.y*17+u.phaseB.z)).r;
        if(local.y>ground&&local.y<ground+.55&&reflectUV.x>0&&reflectUV.x<1){
            float4 rc=float4(0),re=float4(0);
            for(int j=-2;j<=2;++j){float2 tap=reflectUV+float2(float(j)*.007+(noise-.5)*.012,0);rc+=carBody.sample(spriteSampler,tap)*.2;re+=brakeEmission.sample(spriteSampler,tap)*.2;}
            float fade=exp(-(local.y-ground)*8.0)*.17;
            c=c*(1-rc.a*fade)+rc.rgb*float3(.42,.49,.44)*fade;c+=re.rgb*fade*2.0*u.flags.x;
        }
        if(all(local>=float2(0))&&all(local<=float2(1))){
            float4 car=carBody.sample(spriteSampler,local);
            float ambient=0.94+0.06*sin(u.phaseA.x*6.2831853);
            float trans=exp(-u.vehicle.y*.009);
            float3 pm=(car.rgb*float3(.52,.58,.53)*ambient)*trans+float3(.009,.019,.014)*(1-trans)*car.a;
            c=pm+c*(1-car.a);
            float4 lamp=brakeEmission.sample(spriteSampler,local),halo=brakeHalo.sample(spriteSampler,local);
            c+=(lamp.rgb*4.6+halo.rgb*.65)*u.flags.x;
        }
    }
    return half4(half3(max(c,float3(0))),1);
}
fragment half4 bloomExtractFragment(ScreenVertex in [[stage_in]],texture2d<float> input [[texture(0)]]) {
    float2 px=1.0/float2(input.get_width(),input.get_height());float3 c=float3(0);
    for(int y=-1;y<=1;++y)for(int x=-1;x<=1;++x)c+=input.sample(linearSampler,in.uv+float2(x,y)*px*2.0).rgb/9.0;
    float lum=max(max(c.r,c.g),c.b);return half4(half3(c*smoothstep(0.45,1.4,lum)),1);
}
fragment half4 bloomHorizontalFragment(ScreenVertex in [[stage_in]],texture2d<float> input [[texture(0)]]) {
    float2 p=float2(1.0/float(input.get_width()),0);float3 c=input.sample(linearSampler,in.uv).rgb*0.227027;
    c+=(input.sample(linearSampler,in.uv+p*1.384615).rgb+input.sample(linearSampler,in.uv-p*1.384615).rgb)*0.316216;
    c+=(input.sample(linearSampler,in.uv+p*3.230769).rgb+input.sample(linearSampler,in.uv-p*3.230769).rgb)*0.070270;
    return half4(half3(c),1);
}
fragment half4 bloomVerticalFragment(ScreenVertex in [[stage_in]],texture2d<float> input [[texture(0)]]) {
    float2 p=float2(0,1.0/float(input.get_height()));float3 c=input.sample(linearSampler,in.uv).rgb*0.227027;
    c+=(input.sample(linearSampler,in.uv+p*1.384615).rgb+input.sample(linearSampler,in.uv-p*1.384615).rgb)*0.316216;
    c+=(input.sample(linearSampler,in.uv+p*3.230769).rgb+input.sample(linearSampler,in.uv-p*3.230769).rgb)*0.070270;
    return half4(half3(c),1);
}
fragment half4 outputFragment(ScreenVertex in [[stage_in]],constant FrameUniforms &u [[buffer(0)]],
    texture2d<float> scene [[texture(0)]],texture2d<float> bloom [[texture(1)]],
    texture2d<float> motion [[texture(2)]],texture2d<float> material [[texture(3)]]) {
    float3 c=scene.sample(linearSampler,in.uv).rgb+bloom.sample(linearSampler,in.uv).rgb*u.effects.z;
    if(u.flags.z>0.5&&u.flags.z<1.5){float d=motion.sample(linearSampler,in.uv).z/120.0;return half4(half3(d),1);}
    if(u.flags.z>1.5&&u.flags.z<2.5){float2 m=motion.sample(linearSampler,in.uv).xy*60.0;return half4(half(m.x+0.5),half(m.y+0.5),0,1);}
    float4 mat=material.sample(linearSampler,in.uv);
    if(u.flags.z>2.5&&u.flags.z<3.5){return half4(half3(mat.xxx),1);}
    if(u.flags.z>3.5&&u.flags.z<4.5){return half4(half3(mat.yyy),1);}
    if(u.flags.z>4.5&&u.flags.z<5.5){float id=mat.z;return half4(half(id<.5),half(id>.5),0,1);}
    return half4(half3(jdACES(c*u.optics.y)),1);
}
kernel void advanceSpray(device Particle *particles [[buffer(0)]],constant FrameUniforms &u [[buffer(1)]],uint id [[thread_position_in_grid]]){
 if(id>=384||u.flags.y<.5)return;
 Particle p=particles[id];p.position.z-=u.travel.z*.42;p.position.y+=u.travel.w*(.02+p.seed.y*.09);
 if(p.position.z<u.vehicle.y-3.5||p.position.y>.30){p.position.z=u.vehicle.y-.30-p.seed.z*.65;p.position.y=.012;p.position.x=u.vehicle.x-1.4+p.seed.x*1.45;}
 particles[id]=p;
}
struct ParticleOut{float4 position [[position]];float2 uv;float2 screenUV;float depth;float alpha;};
vertex ParticleOut sprayVertex(uint vertexID [[vertex_id]],uint instanceID [[instance_id]],constant FrameUniforms &u [[buffer(0)]],device const Particle *p [[buffer(1)]]){
 const float2 corners[6]={float2(0,0),float2(1,0),float2(0,1),float2(1,0),float2(1,1),float2(0,1)};
 float2 corner=corners[vertexID];float3 pos=p[instanceID].position.xyz;
 float2 center=jdProject(pos,u);float aspect=u.viewport.z/u.viewport.w;
 float size=clamp(.07/pos.z,.0005,.008)*(.4+p[instanceID].seed.w);
 float2 uv=center+(corner-float2(.5))*float2(size/aspect,size*.4);
 ParticleOut o;o.position=float4(uv.x*2-1,1-uv.y*2,0,1);o.uv=corner;o.screenUV=uv;o.depth=pos.z;
 o.alpha=min(u.travel.y/27.7778,1.0)*u.flags.y*.08;return o;
}
fragment half4 sprayFragment(ParticleOut in [[stage_in]],constant FrameUniforms &u [[buffer(0)]],texture2d<float> car [[texture(0)]],texture2d<float> motion [[texture(1)]]) {
 float2 p=(in.screenUV-u.carRect.xy)/u.carRect.zw;
 if(all(p>=float2(0))&&all(p<=float2(1))&&car.sample(spriteSampler,p).a>.02)discard_fragment();
 float depth=motion.sample(linearSampler,in.screenUV).z;if(in.depth>depth+.2)discard_fragment();
 float a=exp(-dot((in.uv-float2(.5))*4.5,(in.uv-float2(.5))*4.5))*in.alpha;
 return half4(half3(float3(.48,.62,.52)*a),half(a));
}
struct SpriteOut {float4 position [[position]];float2 uv;float4 color;};
vertex SpriteOut glyphVertex(uint vertexID [[vertex_id]],uint instanceID [[instance_id]],device const SpriteInstance *sprites [[buffer(0)]],constant FrameUniforms &u [[buffer(1)]]) {
    const float2 corners[6]={float2(0,0),float2(1,0),float2(0,1),float2(1,0),float2(1,1),float2(0,1)};
    SpriteInstance s=sprites[instanceID];float2 corner=corners[vertexID];float2 pos=s.rect.xy+corner*s.rect.zw;
    SpriteOut out;out.position=float4(pos.x*2-1,1-pos.y*2,0,1);out.uv=s.uvRect.xy+corner*s.uvRect.zw;out.color=s.color;return out;
}
fragment half4 glyphFragment(SpriteOut in [[stage_in]],texture2d<float> atlas [[texture(0)]]) {
    float4 ink=atlas.sample(linearSampler,in.uv,level(0));
    float3 ivory=ink.rgb*in.color.rgb;
    return half4(half3(ivory*in.color.a),half(ink.a*in.color.a));
}
fragment half4 accentFragment(ScreenVertex in [[stage_in]],constant FrameUniforms &u [[buffer(0)]]) {
    if(u.flags.y<0.5||u.flags.w<0.5)return half4(0);
    float2 p=(in.uv-u.heroRect.xy)/u.heroRect.zw;
    float left=smoothstep(-0.48,-0.03,p.x)*(1.0-smoothstep(0.01,0.12,p.x));
    float yMask=smoothstep(-0.05,0.08,p.y)*(1.0-smoothstep(0.86,1.02,p.y));
    float lines=pow(0.5+0.5*sin(p.y*92.0+sin(p.y*37.0)*1.8),16.0);
    float pulse=0.45+0.55*sin(p.x*10.0+u.phaseB.y*6.283185307+p.y*30.0)*sin(p.x*10.0+u.phaseB.y*6.283185307+p.y*30.0);
    float alpha=left*yMask*lines*pulse*clamp(u.travel.y/27.7778,0.0,1.2)*0.24;
    return half4(half3(float3(0.15,0.94,0.48)*alpha),half(alpha));
}
fragment half4 badgeFragment(ScreenVertex in [[stage_in]],constant float4 &rect [[buffer(0)]]) {
    float2 p=(in.uv-rect.xy)/rect.zw;
    if(any(p<float2(0))||any(p>float2(1)))return half4(0);
    float bevel=min(min(p.x,p.y),min(1-p.x,1-p.y));
    float diagonal=min(p.x+p.y,(1-p.x)+(1-p.y));
    if(diagonal<0.09)return half4(0);
    float edge=1.0-smoothstep(0.007,0.020,bevel);
    float alpha=0.30+edge*0.35;float3 c=mix(float3(0.002,0.009,0.005),float3(0.07,0.35,0.18),edge);
    return half4(half3(c*alpha),half(alpha));
}
