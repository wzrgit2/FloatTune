const { spawn } = require('child_process');
function run(file, label) {
  return new Promise(res => {
    const p = spawn('powershell', ['-NoProfile','-ExecutionPolicy','Bypass','-File', file], { stdio: ['pipe','pipe','pipe'] });
    let n = 0, out = '';
    p.stdout.setEncoding('utf8');
    p.stdout.on('data', d => { for (const l of d.split(/\r?\n/)) if (l.trim()) { n++; if (n<=2) out += l + ' | '; } });
    p.stderr.setEncoding('utf8');
    p.stderr.on('data', d => { out += 'ERR:' + d.slice(0,150); });
    p.on('exit', c => res(label + ' lines=' + n + ' exit=' + c + '  sample=' + out));
    setTimeout(() => { p.kill(); }, 4000);
  });
}
(async () => {
  console.log(await run('C:\\Users\\SuperWan\\.openclaw\\workspace\\music-widget\\tools\\mini-a.ps1', 'WITH OutputEncoding '));
  console.log(await run('C:\\Users\\SuperWan\\.openclaw\\workspace\\music-widget\\tools\\mini-b.ps1', 'WITHOUT OutputEncoding'));
  process.exit(0);
})();
