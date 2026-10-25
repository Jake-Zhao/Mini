float jdHash(float x){return fract(sin(x*12.9898+7.233)*43758.5453);}
float jdBand(float x,float c,float h,float aa){return 1.0-smoothstep(h,h+max(max(aa,fwidth(x)*0.7),0.0001),abs(x-c));}
float3 jdACES(float3 x){return clamp((x*(2.51*x+float3(.03)))/(x*(2.43*x+float3(.59))+float3(.14)),float3(0),float3(1));}
float2 jdProject(float3 p,FrameUniforms u){float a=u.viewport.z/u.viewport.w;return float2(.5+p.x/(2*u.optics.x*a*p.z),u.camera.w-(p.y-u.camera.z)/(2*u.optics.x*p.z));}
float2 jdIntersect(float3 o,float3 d,FrameUniforms u){
 float t=160.0,id=3.0;
 if(d.y<-.00001){float a=-o.y/d.y;if(a>.001&&a<t){t=a;id=0;}}
 if(d.y>.00001){float a=(u.camera.y-o.y)/d.y;if(a>.001&&a<t){t=a;id=2;}}
 if(abs(d.x)>.00001){float a=((d.x>0?u.camera.x:-u.camera.x)-o.x)/d.x;if(a>.001&&a<t){t=a;id=1;}}
 return float2(t,id);
}
float3 jdFog(float3 c,float d){float T=exp(-max(d,0.0)*.009);return c*T+float3(.009,.019,.014)*(1-T);}
float3 jdSurface(float3 p,float id,float exposureOffset,FrameUniforms u TEXTURE_PARAMETERS){
 if(id>2.5)return float3(.018,.027,.023);
 float phase=fract(p.z/8.0+u.phaseA.x+exposureOffset/8.0);
 float2 uv=float2(p.z/1.5+u.phaseA.w+exposureOffset/1.5,(id<1.5?p.y:p.x)/1.5);
 float3 albedo=SAMPLE_REPEAT(concreteColor,uv).rgb;
 float4 mat=SAMPLE_REPEAT(concreteSurface,uv);
 float2 slope=(mat.rg*2-1)*.22;
 float NdotL=clamp(.70+dot(slope,float2(.28,-.18)),.15,1.0);
 float seam=jdBand(phase,0,.009,.012)+jdBand(phase,1,.009,.012);
 float3 c=albedo*float3(.16,.20,.18)*NdotL*(1-.42*min(seam,1.0));
 if(id<1.5){
  float hous=jdBand(p.y,2.4,.19,.04)*jdBand(phase,.45,.105,.025);
  c*=1.0-hous*.78;
  float lamp=jdBand(p.y,2.4,.063,.022)*jdBand(phase,.45,.070,.014);
  float strip=jdBand(p.y,.38,.022,.014)*jdBand(phase,.48,.34,.03);
  c+=float3(6.1,6.5,5.6)*lamp+float3(.06,2.7,.72)*strip;
  float edge=jdBand(p.y,1.05,.012,.008)*jdBand(phase,.5,.38,.02);
  c+=float3(.018,.19,.07)*edge;
  c+=albedo*float3(.02,.12,.045)*exp(-abs(p.y-.38)*2.2);
 }else{c*=.65;float housing=jdBand(abs(p.x),2.0,.18,.03)*jdBand(phase,.48,.14,.03);c*=1-housing*.7;}
 return max(c,float3(0));
}
float3 jdRadiance(float2 uv,float offset,FrameUniforms u TEXTURE_PARAMETERS){
 float aspect=u.viewport.z/u.viewport.w;
 float3 origin=float3(0,u.camera.z,0);
 float3 dir=normalize(float3((uv.x-.5)*2*u.optics.x*aspect,(u.camera.w-uv.y)*2*u.optics.x,1));
 float2 hit=jdIntersect(origin,dir,u);float3 p=origin+dir*hit.x;
 float3 c;
 if(hit.y<.5){
  float2 texuv=float2(p.x/3.0,p.z/3.0+u.phaseA.z+offset/3.0);
  float3 base=SAMPLE_REPEAT(asphaltColor,texuv).rgb;
  float4 m=SAMPLE_REPEAT(asphaltSurface,texuv);
  float wet=clamp(m.a,0.0,1.0),r=mix(m.b,u.optics.z,wet);
  float2 nxy=(m.rg*2-1)*mix(.22,.035,wet);
  float3 n=normalize(float3(nxy.x,sqrt(max(.01,1-dot(nxy,nxy))),nxy.y));
  float3 reflected=reflect(dir,n);
  float3 ref=float3(0);
  for(int j=0;j<5;++j){
   float angle=float(j)*2.39996323,rad=j==0?0:r*r*.10;
   float3 ray=normalize(reflected+float3(cos(angle)*rad,0,sin(angle)*rad));
   float3 start=p+n*.015;float2 rh=jdIntersect(start,ray,u);
   ref+=jdFog(jdSurface(start+ray*rh.x,rh.y,offset,u TEXTURE_ARGUMENTS),rh.x)*.2;
  }
  float ndv=clamp(dot(-dir,n),0.0,1.0);
  float f0=mix(.04,.02037,wet);float F=f0+(1-f0)*pow(1-ndv,5.0);
  float3 ambient=float3(.15,.20,.17);
  c=(1-F)*base*ambient+F*ref*mix(.32,1.0,wet);
  float lane=jdBand(abs(p.x),1.95,.035,.012)*jdBand(fract(p.z/12+u.phaseA.y+offset/12),.45,.18,.02);
  c+=float3(.018,.020,.017)*lane;
  c*=1.0-.16*smoothstep(u.camera.x-.55,u.camera.x-.35,abs(p.x));
 }else c=jdSurface(p,hit.y,offset,u TEXTURE_ARGUMENTS);
 c=jdFog(c,hit.x);
 float2 h=(uv-float2(.5,u.camera.w))*float2(32,60);
 c+=float3(.13,.18,.15)*exp(-dot(h,h));
 float vignette=1-.20*smoothstep(.65,1.1,length((uv-float2(.5))*float2(1.0,.7)));
 return c*vignette;
}
struct SceneSample{float3 color;float depth;float2 velocity;float surface;};
SceneSample jdScene(float2 uv,FrameUniforms u TEXTURE_PARAMETERS){
 float3 origin=float3(0,u.camera.z,0);float aspect=u.viewport.z/u.viewport.w;
 float3 dir=normalize(float3((uv.x-.5)*2*u.optics.x*aspect,(u.camera.w-uv.y)*2*u.optics.x,1));
 float2 hit=jdIntersect(origin,dir,u);float3 p=origin+dir*hit.x;
 float3 color=float3(0);
 float shutter=u.travel.y*u.effects.x;
 int count=(u.sampling.y>.5 && abs(shutter)>0.0000001)?clamp(int(u.sampling.x),1,33):1;
 for(int k=0;k<33;++k){if(k>=count)break;float t=(float(k)+.5)/float(count)-.5;color+=jdRadiance(uv,t*shutter,u TEXTURE_ARGUMENTS)/float(count);}
 float2 previous=jdProject(p+float3(0,0,shutter),u);
 SceneSample result;result.color=color;result.depth=p.z;result.velocity=hit.y<2.5?uv-previous:float2(0);result.surface=hit.y;return result;
}
