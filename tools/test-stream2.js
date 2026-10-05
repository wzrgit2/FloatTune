const { spawn } = require('child_process');
const path = 'C:\\Users\\SuperWan\\.openclaw\\workspace\\music-widget\\bridge\\smtc.ps1';
const p = spawn('powershell', ['-NoProfile','-ExecutionPolicy','Bypass','-File', path], { stdio: ['pipe','pipe','pipe'] });
let n = 0;
p.stdout.setEncoding('utf8');
p.stdout.on('data', d => {
  for (const l of d.split(/\r?\n/)) {
    if (!l.trim()) continue;
    n++;
    if (n <= 4) console.log('LINE ' + n + ': ' + l.slice(0, 300));
  }
});
p.stderr.setEncoding('utf8');
p.stderr.on('data', d => console.log('STDERR: ' + d.slice(0, 400)));
setTimeout(() => { p.stdin.write('playpause\n'); console.log('--> sent playpause'); }, 2500);
setTimeout(() => { console.log('TOTAL LINES: ' + n); p.kill(); process.exit(0); }, 6000);
