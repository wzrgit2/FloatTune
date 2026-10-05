const { spawn } = require('child_process');
const p = spawn('powershell', ['-NoProfile','-ExecutionPolicy','Bypass','-File', 'C:\\Users\\SuperWan\\.openclaw\\workspace\\music-widget\\bridge\\smtc.ps1'], { stdio: ['pipe','pipe','pipe'] });
p.stdout.setEncoding('utf8');
let n = 0; const t0 = Date.now();
console.log('t(s) | status | position | duration | title');
p.stdout.on('data', d => {
  for (const l of d.split(/\r?\n/)) {
    if (!l.trim()) continue;
    n++;
    try {
      const j = JSON.parse(l);
      if (n % 3 === 0 || n <= 3) console.log(((Date.now()-t0)/1000).toFixed(1) + ' | ' + j.status + ' | ' + j.position + ' | ' + j.duration + ' | ' + (j.title||'').slice(0,28));
    } catch {}
  }
});
p.stderr.setEncoding('utf8');
p.stderr.on('data', d => { const s = d.trim(); if (s) console.log('ERR ' + s.slice(0,140)); });
setTimeout(() => { console.log('TOTAL ' + n + ' lines in 24s'); p.kill(); process.exit(0); }, 24000);
