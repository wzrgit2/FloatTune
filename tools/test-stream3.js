const { spawn } = require('child_process');
const p = spawn('powershell', ['-NoProfile','-ExecutionPolicy','Bypass','-File', 'C:\\Users\\SuperWan\\.openclaw\\workspace\\music-widget\\bridge\\smtc.ps1'], { stdio: ['pipe','pipe','pipe'] });
p.stdout.setEncoding('utf8');
let n = 0; const t0 = Date.now();
p.stdout.on('data', d => {
  for (const l of d.split(/\r?\n/)) {
    if (!l.trim()) continue;
    n++;
    if (n <= 6) console.log('+' + ((Date.now()-t0)/1000).toFixed(1) + 's  ' + l.slice(0, 200));
  }
});
p.stderr.setEncoding('utf8');
p.stderr.on('data', d => console.log('ERR: ' + d.slice(0,200)));
setTimeout(() => { console.log('TOTAL LINES in 22s: ' + n); p.kill(); process.exit(0); }, 22000);
