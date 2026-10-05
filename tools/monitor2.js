const { spawn } = require('child_process');
const fs = require('fs');
const out = require('path').join(process.env.TEMP, 'progress-monitor.log');
fs.writeFileSync(out, 'monitor start ' + new Date().toISOString() + '\n');
const p = spawn('powershell', ['-NoProfile','-ExecutionPolicy','Bypass','-File', 'C:\\Users\\SuperWan\\.openclaw\\workspace\\music-widget\\bridge\\smtc.ps1'], { stdio: ['pipe','pipe','pipe'] });
p.stdout.setEncoding('utf8');
let n = 0;
p.stdout.on('data', d => {
  for (const l of d.split(/\r?\n/)) {
    if (!l.trim()) continue;
    n++;
    if (n % 4 !== 0) continue;
    try { const j = JSON.parse(l); fs.appendFileSync(out, new Date().toISOString().slice(11,19) + ' status=' + j.status + ' pos=' + j.position + ' dur=' + j.duration + ' title=' + (j.title||'').slice(0,24) + '\n'); } catch {}
  }
});
setTimeout(() => { fs.appendFileSync(out, 'monitor end, lines=' + n + '\n'); p.kill(); process.exit(0); }, 300000);
