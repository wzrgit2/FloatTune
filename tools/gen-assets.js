const fs = require('fs'), zlib = require('zlib'), path = require('path');
function crc32(buf){let c,t=[];for(let n=0;n<256;n++){c=n;for(let k=0;k<8;k++)c=c&1?0xEDB88320^(c>>>1):c>>>1;t[n]=c>>>0;}let crc=0xFFFFFFFF;for(const b of buf)crc=t[(crc^b)&0xFF]^(crc>>>8);return (crc^0xFFFFFFFF)>>>0;}
function chunk(id,data){const len=Buffer.alloc(4);len.writeUInt32BE(data.length,0);const d=Buffer.concat([Buffer.from(id,'ascii'),data]);const c=Buffer.alloc(4);c.writeUInt32BE(crc32(d),0);return Buffer.concat([len,d,c]);}
function png(w,h,rgba){const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(w,0);ihdr.writeUInt32BE(h,4);ihdr[8]=8;ihdr[9]=6;const raw=Buffer.alloc((w*4+1)*h);for(let y=0;y<h;y++){raw[y*(w*4+1)]=0;rgba.copy(raw,y*(w*4+1)+1,y*w*4,(y+1)*w*4);}return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',ihdr),chunk('IDAT',zlib.deflateSync(raw,{level:9})),chunk('IEND',Buffer.alloc(0))]);}
const SS = 4;
function canvas(w,h){return {w,h,d:Buffer.alloc(w*h*4)};}
function px(c,x,y,r,g,b,a){if(x<0||y<0||x>=c.w||y>=c.h)return;const i=(y*c.w+x)*4;const sa=a/255;const da=c.d[i+3]/255;const oa=sa+da*(1-sa);if(oa<=0){c.d[i+3]=0;return;}c.d[i]=Math.round((r*sa+c.d[i]*da*(1-sa))/oa);c.d[i+1]=Math.round((g*sa+c.d[i+1]*da*(1-sa))/oa);c.d[i+2]=Math.round((b*sa+c.d[i+2]*da*(1-sa))/oa);c.d[i+3]=Math.round(oa*255);}
function tri(c,ax,ay,bx,by,cx,cy,r,g,b){const minx=Math.max(0,Math.floor(Math.min(ax,bx,cx))),maxx=Math.min(c.w-1,Math.ceil(Math.max(ax,bx,cx))),miny=Math.max(0,Math.floor(Math.min(ay,by,cy))),maxy=Math.min(c.h-1,Math.ceil(Math.max(ay,by,cy)));const s=SS;for(let y=miny;y<=maxy;y++)for(let x=minx;x<=maxx;x++){let hit=0;for(let sy=0;sy<s;sy++)for(let sx=0;sx<s;sx++){const px_=x+(sx+0.5)/s,py_=y+(sy+0.5)/s;const d1=(px_-bx)*(ay-by)-(ax-bx)*(py_-by),d2=(px_-cx)*(by-cy)-(bx-cx)*(py_-cy),d3=(px_-ax)*(cy-ay)-(cx-ax)*(py_-ay);const neg=(d1<0)||(d2<0)||(d3<0),pos=(d1>0)||(d2>0)||(d3>0);if(!(neg&&pos))hit++;}if(hit)px(c,x,y,r,g,b,Math.round(255*hit/(s*s)));}}
function rect(c,x0,y0,x1,y1,r,g,b,rad){rad=rad||0;const s=SS;for(let y=Math.floor(y0);y<y1;y++)for(let x=Math.floor(x0);x<x1;x++){let hit=0;for(let sy=0;sy<s;sy++)for(let sx=0;sx<s;sx++){const X=x+(sx+0.5)/s,Y=y+(sy+0.5)/s;if(rad>0){const cx=Math.min(Math.max(X,x0+rad),x1-rad),cy=Math.min(Math.max(Y,y0+rad),y1-rad);const dx=X-cx,dy=Y-cy;if(Math.sqrt(dx*dx+dy*dy)>rad)continue;}hit++;}if(hit)px(c,x,y,r,g,b,Math.round(255*hit/(s*s)));}}
function circ(c,cx,cy,rad,r,g,b){const s=SS;for(let y=Math.floor(cy-rad);y<=cy+rad;y++)for(let x=Math.floor(cx-rad);x<=cx+rad;x++){let hit=0;for(let sy=0;sy<s;sy++)for(let sx=0;sx<s;sx++){const dx=x+(sx+0.5)/s-cx,dy=y+(sy+0.5)/s-cy;if(Math.sqrt(dx*dx+dy*dy)<=rad)hit++;}if(hit)px(c,x,y,r,g,b,Math.round(255*hit/(s*s)));}}

const dir = 'C:/Users/SuperWan/.openclaw/workspace/music-widget/src/assets';
fs.mkdirSync(dir, { recursive: true });
function make(color){ return { r: color[0], g: color[1], b: color[2] }; }

function iconSet(suffix, col){
  let c;
  c = canvas(32,32); tri(c, 9,6, 9,26, 24,16, col.r,col.g,col.b); fs.writeFileSync(dir+'/play'+suffix+'.png', png(32,32,c.d));
  c = canvas(32,32); rect(c, 9,6, 14,26, col.r,col.g,col.b); rect(c, 18,6, 23,26, col.r,col.g,col.b); fs.writeFileSync(dir+'/pause'+suffix+'.png', png(32,32,c.d));
  c = canvas(32,32); rect(c, 6,6, 10.5,26, col.r,col.g,col.b); tri(c, 25,6, 25,26, 11,16, col.r,col.g,col.b); fs.writeFileSync(dir+'/prev'+suffix+'.png', png(32,32,c.d));
  c = canvas(32,32); tri(c, 7,6, 7,26, 21,16, col.r,col.g,col.b); rect(c, 21.5,6, 26,26, col.r,col.g,col.b); fs.writeFileSync(dir+'/next'+suffix+'.png', png(32,32,c.d));
}
iconSet('', [255,255,255]);
iconSet('_dark', [26,26,26]);

// app icon 256x256: dark rounded square + white music note
{
  const S=256; const c=canvas(S,S);
  rect(c, 0,0, S,S, 26,30,38, 56);
  rect(c, 8,8, S-8,S-8, 32,37,47, 48);
  circ(c, 104,182, 30, 255,255,255);
  rect(c, 128,60, 142,186, 255,255,255);
  tri(c, 142,58, 142,96, 196,74, 255,255,255);
  tri(c, 142,58, 196,74, 176,90, 255,255,255);
  fs.writeFileSync(dir+'/app.png', png(S,S,c.d));
}
// test cover for the mock bridge
{
  const S=256; const c=canvas(S,S);
  for(let y=0;y<S;y++)for(let x=0;x<S;x++){const r=Math.round(60+150*(x/S)),g=Math.round(40+90*(y/S)),b=Math.round(160-90*(x/S));px(c,x,y,r,g,b,255);}
  circ(c, 128,128, 62, 24,26,32); circ(c, 128,128, 22, 230,230,235); circ(c, 128,128, 8, 24,26,32);
  fs.writeFileSync('C:/Users/SuperWan/.openclaw/workspace/music-widget/tools/test-cover.png', png(S,S,c.d));
}
console.log('assets: ' + fs.readdirSync(dir).join(', '));
