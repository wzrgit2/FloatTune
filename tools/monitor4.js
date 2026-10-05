const { spawn } = require('child_process');
const fs = require('fs');
const out = require('path').join(process.env.TEMP, 'progress-monitor.log');
fs.writeFileSync(out, 'monitor start ' + new Date().toISOString() + '\n');
const p = spawn('powershell', ['-NoProfile','-ExecutionPolicy','Bypass','-File', 'C:\\Users\\SuperWan\\.openclaw\\workspace\\music-widget\\bridge\\smtc.ps1'], { stdio: ['pipe','pipe','pipe'] });
p.stdout.setEncoding('utf8');
let n = 0, playing = 0;
p.stdout.on('data', d => {
  for (const l of d.split(/\r?\n/)) {
    if (!l.trim()) continue;
    n++;
    try {
      const j = JSON.parse(l);
      if (j.status === 'Playing') {
        playing++;
        fs.appendFileSync(out, new Date().toISOString().slice(11,19) + ' PLAYING pos=' + j.position + ' dur=' + j.duration + '\n');
      }
    } catch {}
  }
});
p.on('exit', () => fs.appendFileSync(out, 'bridge exited, lines=' + n + ' playing=' + playing + '\n'));
setTimeout(() => { fs.appendFileSync(out, 'monitor end lines=' + n + ' playing=' + playing + '\n'); p.kill(); process.exit(0); }, 1800000);
