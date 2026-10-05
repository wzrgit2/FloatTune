const { spawn } = require('child_process');
const p = spawn('powershell', ['-NoProfile','-ExecutionPolicy','Bypass','-File', 'C:\\Users\\SuperWan\\.openclaw\\workspace\\music-widget\\bridge\\smtc.ps1'], { stdio: ['pipe','pipe','pipe'] });
p.stdout.setEncoding('utf8');
let n = 0;
p.stdout.on('data', d => {
  for (const l of d.split(/\r?\n/)) {
    if (!l.trim()) continue;
    n++;
    if (n <= 12) {
      try { const j = JSON.parse(l); console.log('#' + n + ' status=' + j.status + ' pos=' + j.position + ' dur=' + j.duration + ' title=' + j.title); }
      catch { console.log('#' + n + ' RAW ' + l.slice(0,120)); }
    }
  }
});
setTimeout(() => { console.log('total lines: ' + n); p.kill(); process.exit(0); }, 7000);
