const fs = require('fs'), zlib = require('zlib'), path = require('path');
function crc32(buf){let c,t=[];for(let n=0;n<256;n++){c=n;for(let k=0;k<8;k++)c=c&1?0xEDB88320^(c>>>1):c>>>1;t[n]=c>>>0;}let crc=0xFFFFFFFF;for(const b of buf)crc=t[(crc^b)&0xFF]^(crc>>>8);return (crc^0xFFFFFFFF)>>>0;}
function chunk(id,data){const len=Buffer.alloc(4);len.writeUInt32BE(data.length,0);const d=Buffer.concat([Buffer.from(id,'ascii'),data]);const c=Buffer.alloc(4);c.writeUInt32BE(crc32(d),0);return Buffer.concat([len,d,c]);}
function png(w,h,rgba){const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(w,0);ihdr.writeUInt32BE(h,4);ihdr[8]=8;ihdr[9]=6;const raw=Buffer.alloc((w*4+1)*h);for(let y=0;y<h;y++){raw[y*(w*4+1)]=0;rgba.copy(raw,y*(w*4+1)+1,y*w*4,(y+1)*w*4);}return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',ihdr),chunk('IDAT',zlib.deflateSync(raw,{level:9})),chunk('IEND',Buffer.alloc(0))]);}
const SS = 4;
function canvas(w,h){return {w,h,d:Buffer.alloc(w*h*4)};}
function px(c,x,y,r,g,b,a){if(x<0||y<0||x>=c.w||y>=c.h)return;const i=(y*c.w+x)*4;const sa=a/255;const da=c.d[i+3]/255;const oa=sa+da*(1-sa);if(oa<=0){c.d[i+3]=0;return;}c.d[i]=Math.round((r*sa+c.d[i]*da*(1-sa))/oa);c.d[i+1]=Math.round((g*sa+c.d[i+1]*da*(1-sa))/oa);c.d[i+2]=Math.round((b*sa+c.d[i+2]*da*(1-sa))/oa);c.d[i+3]=Math.round(oa*255);}
function tri(c,ax,ay,bx,by,cx,cy,r,g,b){const minx=Math.max(0,Math.floor(Math.min(ax,bx,cx))),maxx=Math.min(c.w-1,Math.ceil(Math.max(ax,bx,cx))),miny=Math.max(0,Math.floor(Math.min(ay,by,cy))),maxy=Math.min(c.h-1,Math.ceil(Math.max(ay,by,cy)));const s=SS;for(let y=miny;y<=maxy;y++)for(let x=minx;x<=maxx;x++){let hit=0;for(let sy=0;sy<s;sy++)for(let sx=0;sx<s;sx++){const X=x+(sx+0.5)/s,Y=y+(sy+0.5)/s;const d1=(X-bx)*(ay-by)-(ax-bx)*(Y-by),d2=(X-cx)*(by-cy)-(bx-cx)*(Y-cy),d3=(X-ax)*(cy-ay)-(cx-ax)*(Y-ay);const neg=(d1<0)||(d2<0)||(d3<0),pos=(d1>0)||(d2>0)||(d3>0);if(!(neg&&pos))hit++;}if(hit)px(c,x,y,r,g,b,Math.round(255*hit/(s*s)));}}
function rect(c,x0,y0,x1,y1,r,g,b,rad){rad=rad||0;const s=SS;for(let y=Math.floor(y0);y<y1;y++)for(let x=Math.floor(x0);x<x1;x++){let hit=0;for(let sy=0;sy<s;sy++)for(let sx=0;sx<s;sx++){const X=x+(sx+0.5)/s,Y=y+(sy+0.5)/s;if(rad>0){const cx=Math.min(Math.max(X,x0+rad),x1-rad),cy=Math.min(Math.max(Y,y0+rad),y1-rad);const dx=X-cx,dy=Y-cy;if(Math.sqrt(dx*dx+dy*dy)>rad)continue;}hit++;}if(hit)px(c,x,y,r,g,b,Math.round(255*hit/(s*s)));}}
function circ(c,cx,cy,rad,r,g,b){const s=SS;for(let y=Math.floor(cy-rad);y<=cy+rad;y++)for(let x=Math.floor(cx-rad);x<=cx+rad;x++){let hit=0;for(let sy=0;sy<s;sy++)for(let sx=0;sx<s;sx++){const dx=x+(sx+0.5)/s-cx,dy=y+(sy+0.5)/s-cy;if(Math.sqrt(dx*dx+dy*dy)<=rad)hit++;}if(hit)px(c,x,y,r,g,b,Math.round(255*hit/(s*s)));}}
function drawIcon(S){
  const c=canvas(S,S); const k=S/256;
  rect(c, 0,0, S,S, 26,30,38, 56*k);
  rect(c, 8*k,8*k, S-8*k,S-8*k, 32,37,47, 48*k);
  circ(c, 104*k,182*k, 30*k, 255,255,255);
  rect(c, 128*k,60*k, 142*k,186*k, 255,255,255);
  tri(c, 142*k,58*k, 142*k,96*k, 196*k,74*k, 255,255,255);
  tri(c, 142*k,58*k, 196*k,74*k, 176*k,90*k, 255,255,255);
  return c;
}
function down(c, S){
  if (S === c.w) return c;
  const out = canvas(S,S); const f = c.w/S;
  for(let y=0;y<S;y++)for(let x=0;x<S;x++){
    let r=0,g=0,b=0,a=0,n=0;
    for(let sy=Math.floor(y*f);sy<Math.floor((y+1)*f);sy++)for(let sx=Math.floor(x*f);sx<Math.floor((x+1)*f);sx++){
      const i=(sy*c.w+sx)*4; r+=c.d[i]; g+=c.d[i+1]; b+=c.d[i+2]; a+=c.d[i+3]; n++;
    }
    const i=(y*S+x)*4; out.d[i]=Math.round(r/n); out.d[i+1]=Math.round(g/n); out.d[i+2]=Math.round(b/n); out.d[i+3]=Math.round(a/n);
  }
  return out;
}
// --- build .ico with 32bpp DIB entries ---
function dib(c){
  const S=c.w, rowBytes = S*4, maskRow = Math.ceil(S/32)*4;
  const bih = Buffer.alloc(40);
  bih.writeUInt32LE(40,0); bih.writeInt32LE(S,4); bih.writeInt32LE(S*2,8);
  bih.writeUInt16LE(1,12); bih.writeUInt16LE(32,14); bih.writeUInt32LE(0,16);
  bih.writeUInt32LE(rowBytes*S + maskRow*S,20);
  const xor = Buffer.alloc(rowBytes*S);
  const mask = Buffer.alloc(maskRow*S);
  for(let y=0;y<S;y++){
    const sy = S-1-y;
    for(let x=0;x<S;x++){
      const si=(sy*S+x)*4, di=(y*S+x)*4;
      xor[di]=c.d[si+2]; xor[di+1]=c.d[si+1]; xor[di+2]=c.d[si]; xor[di+3]=c.d[si+3];
      if (c.d[si+3] < 128) mask[y*maskRow + (x>>3)] |= (0x80>>(x&7));
    }
  }
  return Buffer.concat([bih, xor, mask]);
}
const base = drawIcon(256);
const sizes = [16,24,32,48,64,128,256];
const dibs = sizes.map(s => dib(down(base, s)));
const dir = Buffer.alloc(6 + 16*sizes.length);
dir.writeUInt16LE(0,0); dir.writeUInt16LE(1,2); dir.writeUInt16LE(sizes.length,4);
let off = dir.length;
sizes.forEach((s,i)=>{
  const e = 6 + i*16;
  dir.writeUInt8(s>=256?0:s, e); dir.writeUInt8(s>=256?0:s, e+1);
  dir.writeUInt8(0,e+2); dir.writeUInt8(0,e+3);
  dir.writeUInt16LE(1,e+4); dir.writeUInt16LE(32,e+6);
  dir.writeUInt32LE(dibs[i].length, e+8);
  dir.writeUInt32LE(off, e+12);
  off += dibs[i].length;
});
const ico = Buffer.concat([dir, ...dibs]);
const outDir = 'C:/Users/SuperWan/.openclaw/workspace/music-widget/build';
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(outDir + '/icon.ico', ico);
fs.writeFileSync(outDir + '/icon.png', png(256,256,base.d));
console.log('icon.ico ' + ico.length + ' bytes, sizes ' + sizes.join(','));
