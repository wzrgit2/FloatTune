const { spawn } = require('child_process');
const path = 'C:\\Users\\SuperWan\\.openclaw\\workspace\\music-widget\\bridge\\smtc.ps1';
const p = spawn('powershell', ['-NoProfile','-ExecutionPolicy','Bypass','-File', path], { stdio: ['pipe','pipe','pipe'] });
let lines = 0, cmdsSent = 0;
p.stdout.on('data', d => {
  for (const l of d.toString('utf8').split(/\r?\n/)) {
    if (!l.trim()) continue;
    lines++;
    if (lines <= 3 || lines === 8) console.log('STATE[' + lines + ']', l.slice(0, 160));
  }
});
p.stderr.on('data', d => console.log('STDERR:', d.toString().slice(0, 300)));
setTimeout(() => { p.stdin.write('playpause\n'); cmdsSent++; console.log('sent: playpause'); }, 2500);
setTimeout(() => { p.stdin.write('volume:1\n'); cmdsSent++; console.log('sent: volume:1 (no-op, keeps current level)'); }, 3200);
setTimeout(() => { console.log('total state lines:', lines, 'commands sent:', cmdsSent); p.kill(); process.exit(0); }, 5200);
