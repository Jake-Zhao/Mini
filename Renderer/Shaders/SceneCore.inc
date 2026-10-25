float jdHash(float x){return fract(sin(x*12.9898+7.233)*43758.5453);}
float jdBand(float x,float c,float h,float aa){return 1.0-smoothstep(h,h+max(max(aa,fwidth(x)*0.7),0.0001),abs(x-c));}
float3 jdACES(float3 x){return clamp((x*(2.51*x+float3(.03)))/(x*(2.43*x+float3(.59))+float3(.14)),float3(0),float3(1));}
float2 jdProject(float3 p,FrameUniforms u){
 float a=u.viewport.z/u.viewport.w;
 return float2(.5+p.x/(2*u.optics.x*a*p.z),u.camera.w-(p.y-u.camera.z)/(2*u.optics.x*p.z));
}

// Surface ids: 0 road, 1 arch/wall, 3 miss.
// The tunnel is an elliptical arch rather than a screen-space box.
float2 jdIntersect(float3 o,float3 d,FrameUniforms u){
 float best=180.0,id=3.0;
 if(d.y<-.00001){
   float t=-o.y/d.y;
   if(t>.001&&t<best){best=t;id=0.0;}
 }
 float rx=u.camera.x;
 float cy=.78;
 float ry=max(.8,u.camera.y-cy);
 float ox=o.x/rx, oy=(o.y-cy)/ry;
 float dx=d.x/rx, dy=d.y/ry;
 float A=dx*dx+dy*dy;
 float B=2.0*(ox*dx+oy*dy);
 float C=ox*ox+oy*oy-1.0;
 float disc=B*B-4.0*A*C;
 if(A>.000001&&disc>=0.0){
   float q=sqrt(disc);
   float t0=(-B-q)/(2.0*A),t1=(-B+q)/(2.0*A);
   float t=t0>.001?t0:t1;
   if(t>.001&&t<best){best=t;id=1.0;}
 }
 return float2(best,id);
}

float3 jdFog(float3 c,float d){
 float T=exp(-max(d,0.0)*.0105);
 float3 fog=float3(.007,.018,.012);
 return c*T+fog*(1-T);
}

float jdFixtureCell(float z,float offset){
 float cell=floor((z+offset)/8.0);
 return .72+.28*jdHash(cell*1.37+11.0);
}

float3 jdSurface(float3 p,float id,float exposureOffset,FrameUniforms u TEXTURE_PARAMETERS){
 if(id>2.5)return float3(.012,.020,.016);
 float movedZ=p.z+exposureOffset;
 float phase=fract(movedZ/8.0+u.phaseA.x);
 float2 uv=float2(movedZ/1.5+u.phaseA.w,(id<1.5?p.y:p.x)/1.5);
 float3 albedo=SAMPLE_REPEAT(concreteColor,uv).rgb;
 float4 mat=SAMPLE_REPEAT(concreteSurface,uv);
 float2 slope=(mat.rg*2-1)*.20;
 float NdotL=clamp(.66+dot(slope,float2(.26,-.16)),.14,1.0);
 float rib=jdBand(phase,0.02,.012,.012)+jdBand(phase,.98,.012,.012);
 float3 c=albedo*float3(.13,.17,.15)*NdotL*(1-.55*min(rib,1.0));

 // Arch coordinate: 0 at floor-side, 1 near crown.
 float crown=clamp((p.y-.20)/max(.1,u.camera.y-.20),0.0,1.0);
 float fixture=jdFixtureCell(movedZ,0);
 float side=abs(p.x)/max(u.camera.x,.001);

 // Side practicals are recessed and irregular in brightness.
 float sideHousing=jdBand(crown,.23,.085,.025)*jdBand(phase,.48,.12,.024)*smoothstep(.62,.88,side);
 c*=1.0-sideHousing*.72;
 float sideLamp=jdBand(crown,.23,.025,.013)*jdBand(phase,.48,.068,.014)*smoothstep(.66,.92,side);
 c+=float3(.035,3.05,.82)*sideLamp*fixture;

 // Crown fixtures produce sparse neutral highlights, never a uniform arcade.
 float crownHousing=jdBand(crown,.92,.055,.018)*jdBand(phase,.47,.075,.02);
 c*=1.0-crownHousing*.62;
 float crownLamp=jdBand(crown,.92,.016,.010)*jdBand(phase,.47,.042,.012);
 c+=float3(5.3,5.6,4.9)*crownLamp*(.82+.18*fixture);

 // Low emerald guide strip, broken by structural ribs.
 float guide=jdBand(crown,.095,.014,.008)*(1.0-smoothstep(.014,.042,abs(phase-.50)));
 c+=float3(.012,.82,.21)*guide*(.55+.45*fixture);

 // Structural arch ribs read mostly by occlusion, not by neon.
 float structural=jdBand(phase,.02,.014,.012);
 c*=1.0-structural*.27;
 return max(c,float3(0));
}

float3 jdRoadRadiance(float3 p,float3 dir,float exposureOffset,FrameUniforms u TEXTURE_PARAMETERS,
                      thread float &roughness,thread float &wetness){
 float movedZ=p.z+exposureOffset;
 float2 texuv=float2(p.x/3.0,movedZ/3.0+u.phaseA.z);
 float3 base=SAMPLE_REPEAT(asphaltColor,texuv).rgb;
 float4 m=SAMPLE_REPEAT(asphaltSurface,texuv);
 wetness=clamp(m.a,0.0,1.0);
 roughness=mix(m.b,u.optics.z,wetness);
 float2 nxy=(m.rg*2-1)*mix(.22,.030,wetness);
 float3 n=normalize(float3(nxy.x,sqrt(max(.01,1-dot(nxy,nxy))),nxy.y));
 float3 reflected=reflect(dir,n);

 // Rough reflection with asymmetric longitudinal spread to mimic a wet road film.
 float3 ref=float3(0);
 constexpr float golden=2.39996323;
 for(int j=0;j<7;++j){
   float a=float(j)*golden;
   float radial=(j==0?0.0:roughness*roughness*(.045+.010*float(j)));
   float3 jitter=float3(cos(a)*radial,abs(sin(a))*radial*.22,sin(a)*radial*1.7);
   float3 ray=normalize(reflected+jitter);
   float3 start=p+n*.015;
   float2 rh=jdIntersect(start,ray,u);
   float3 hitColor=jdSurface(start+ray*rh.x,rh.y,exposureOffset,u TEXTURE_ARGUMENTS);
   ref+=jdFog(hitColor,rh.x)/7.0;
 }

 float ndv=clamp(dot(-dir,n),0.0,1.0);
 float f0=mix(.04,.02037,wetness);
 float F=f0+(1-f0)*pow(1-ndv,5.0);
 float3 ambient=float3(.105,.145,.122);
 float3 c=(1-F)*base*ambient+F*ref*mix(.30,1.0,wetness);

 // Road markings are nearly black in this artistic shot; practical reflections remain dominant.
 float edgeDrain=smoothstep(u.camera.x-.62,u.camera.x-.22,abs(p.x));
 c*=1.0-.24*edgeDrain;
 float centerWear=exp(-p.x*p.x*.18)*(.92+.08*SAMPLE_REPEAT(flowNoise,float2(movedZ*.025,p.x*.11)).r);
 c*=centerWear;

 // Sparse micro glints derived from wetness and fixture phase.
 float glintNoise=SAMPLE_REPEAT(flowNoise,float2(p.x*.33,movedZ*.075)).g;
 float glint=pow(max(0.0,glintNoise-.74)/.26,4.0)*wetness*(.15+.85*(1-ndv));
 c+=float3(.12,.26,.18)*glint;
 return max(c,float3(0));
}

float3 jdRadiance(float2 uv,float offset,FrameUniforms u TEXTURE_PARAMETERS){
 float aspect=u.viewport.z/u.viewport.w;
 float3 origin=float3(0,u.camera.z,0);
 float3 dir=normalize(float3((uv.x-.5)*2*u.optics.x*aspect,(u.camera.w-uv.y)*2*u.optics.x,1));
 float2 hit=jdIntersect(origin,dir,u);
 float3 p=origin+dir*hit.x;
 float3 c;
 if(hit.y<.5){
   float r=0,w=0;
   c=jdRoadRadiance(p,dir,offset,u TEXTURE_ARGUMENTS,r,w);
 }else c=jdSurface(p,hit.y,offset,u TEXTURE_ARGUMENTS);
 c=jdFog(c,hit.x);

 // restrained atmospheric shaft around the vanishing corridor
 float2 h=(uv-float2(.5,u.camera.w))*float2(26,54);
 c+=float3(.035,.075,.050)*exp(-dot(h,h))*(.4+.6*clamp(u.travel.y/27.7778,0.0,1.0));
 float vignette=1-.22*smoothstep(.60,1.10,length((uv-float2(.5))*float2(1.0,.72)));
 return c*vignette;
}

struct SceneSample{
 float3 color;
 float depth;
 float2 velocity;
 float surface;
 float roughness;
 float wetness;
 float objectID;
};

SceneSample jdScene(float2 uv,FrameUniforms u TEXTURE_PARAMETERS){
 float3 origin=float3(0,u.camera.z,0);
 float aspect=u.viewport.z/u.viewport.w;
 float3 dir=normalize(float3((uv.x-.5)*2*u.optics.x*aspect,(u.camera.w-uv.y)*2*u.optics.x,1));
 float2 hit=jdIntersect(origin,dir,u);
 float3 p=origin+dir*hit.x;

 float shutter=u.travel.y*u.effects.x;
 int count=(u.sampling.y>.5 && abs(shutter)>.0000001)?clamp(int(u.sampling.x),1,33):1;
 float3 color=float3(0);
 for(int k=0;k<33;++k){
   if(k>=count)break;
   float t=(float(k)+.5)/float(count)-.5;
   color+=jdRadiance(uv,t*shutter,u TEXTURE_ARGUMENTS)/float(count);
 }

 float2 previous=jdProject(p+float3(0,0,shutter),u);
 float rough=.84,wet=.03,obj=1.0;
 if(hit.y<.5){
   float movedZ=p.z;
   float2 texuv=float2(p.x/3.0,movedZ/3.0+u.phaseA.z);
   float4 m=SAMPLE_REPEAT(asphaltSurface,texuv);
   wet=clamp(m.a,0.0,1.0);
   rough=mix(m.b,u.optics.z,wet);
   obj=0.0;
 }

 SceneSample result;
 result.color=color;result.depth=p.z;
 result.velocity=hit.y<2.5?uv-previous:float2(0);
 result.surface=hit.y;result.roughness=rough;result.wetness=wet;result.objectID=obj;
 return result;
}
