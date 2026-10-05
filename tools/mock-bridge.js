// Fake now-playing stream for UI testing (no real player needed).
const cover = require('path').join(__dirname, 'test-cover.png');
let t = 0;
const dur = 214;
const started = Date.now();
const stdin = process.stdin;
stdin.resume();
setInterval(() => {
  const elapsed = (Date.now() - started) / 1000;
  if (elapsed > 22) {
    process.stdout.write(JSON.stringify({ ok: true, playing: false, volume: 0.65 }) + '\n');
    return;
  }
  t = Math.min(dur, 40 + elapsed);
  process.stdout.write(JSON.stringify({
    ok: true, playing: true,
    appId: 'MockPlayer.exe',
    title: '测试曲目 - 夜色电台',
    artist: '示例歌手',
    album: 'Demo Album',
    status: elapsed > 20 ? 'Paused' : 'Playing',
    position: Math.round(t * 100) / 100,
    duration: dur,
    cover,
    volume: 0.65
  }) + '\n');
}, 400);
