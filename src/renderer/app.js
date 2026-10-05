const el = id => document.getElementById(id);
const card = el('card');
const coverImg = el('coverImg'), titleEl = el('title'), artistEl = el('artist');
const bar = el('bar'), barFill = el('barFill'), barKnob = el('barKnob');
const curEl = el('cur'), durEl = el('dur'), toggleBtn = el('toggle');
const miniCoverImg = el('miniCoverImg'), miniTitleEl = el('miniTitle'), mToggle = el('mToggle');

let state = { playing: false, position: 0, duration: 0, status: 'Closed' };
let lastStateAt = 0, dragging = false, dragPos = 0, lastCoverKey = '';
let lastText = {}, lastPct = -1, lastFillPct = -1, isMini = false, isLocked = false;
// progress estimator: some players (Soda Music) freeze the system timeline while playing,
// so we run our own clock and only re-anchor on a real jump.
let anchorPos = 0, anchorAt = 0, lastReportedPos = null;

const fmt = s => { s = Math.max(0, Math.round(s || 0)); return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0'); };
function setText(node, key, value) { if (lastText[key] === value) return; lastText[key] = value; node.textContent = value; }

function applyTheme(cfg) {
  if (!cfg) return;
  document.body.dataset.theme = cfg.theme === 'light' ? 'light' : 'dark';
  if (cfg.accent) document.documentElement.style.setProperty('--accent', cfg.accent);
  if (typeof cfg.cardAlpha === 'number') document.documentElement.style.setProperty('--card-alpha', String(cfg.cardAlpha));
}

function render() {
  const now = Date.now();
  if (isMini) { requestAnimationFrame(render); return; }
  const dur = Number(state.duration) || 0;
  // only run our own clock while actually playing; when paused/stopped the bar must
  // stay pinned to the reported position (it used to creep forward between state
  // packets and then snap back)
  let pos = (state.status === 'Playing') ? anchorPos + (now - anchorAt) / 1000 : anchorPos;
  if (dur > 0 && pos > dur) pos = dur;
  if (pos < 0) pos = 0;
  const shown = dragging ? dragPos : pos;
  const pct = dur > 0 ? Math.min(100, (shown / dur) * 100) : 0;
  if (Math.abs(pct - lastFillPct) > 0.2) {
    lastFillPct = pct;
    barFill.style.width = pct + '%';
    barKnob.style.left = pct + '%';
  }
  const sec = Math.round(shown);
  if (sec !== lastPct) {
    lastPct = sec;
    setText(curEl, 'cur', fmt(shown));
    setText(durEl, 'dur', dur > 0 ? fmt(dur) : '0:00');
  }
  requestAnimationFrame(render);
}

function trackProgress(s, now) {
  const pos = Number(s.position) || 0;
  const dur = Number(s.duration) || 0;
  if (s.status !== 'Playing') {
    anchorPos = pos; anchorAt = now; lastReportedPos = pos;
    return;
  }
  // Judge the player by whether its *own* reported position moved -- never by comparing
  // it with our clock. A frozen timeline (Soda Music) reports the same value forever; the
  // old drift-based test mistook that for a seek and yanked the bar backwards every few
  // seconds, which is exactly the "advances then jumps back / out of sync" bug.
  // Soda Music reports the position in coarse steps (frozen for seconds, then a jump),
  // so treat even a small change as "the player moved" and follow it exactly; only a
  // completely unchanged value means the timeline is frozen.
  const moved = lastReportedPos === null || Math.abs(pos - lastReportedPos) > 0.05;
  if (moved) {
    anchorPos = pos; anchorAt = now;                 // real progress, a seek, or a new track
  }
  // otherwise: the player's timeline is frozen -> keep running on our own clock
  lastReportedPos = pos;
  if (dur > 0 && anchorPos > dur) { anchorPos = dur; anchorAt = now; }
}

function apply(s) {
  state = s;
  const nowMs = Date.now();
  lastStateAt = nowMs;
  trackProgress(s, nowMs);
  const toggleGlyph = (s.status === 'Playing') ? '❚❚' : '▶';

  if (!s.playing) {
    if (!card.classList.contains('idle')) card.classList.add('idle');
    setText(titleEl, 'title', '未在播放');
    setText(artistEl, 'artist', '—');
    setText(toggleBtn, 'toggle', '▶');
    setText(miniTitleEl, 'miniTitle', '未在播放');
    setText(mToggle, 'mtoggle', '▶');
    if (lastCoverKey !== '') {
      lastCoverKey = '';
      coverImg.classList.remove('on'); miniCoverImg.classList.remove('on');
    }
    return;
  }
  if (card.classList.contains('idle')) card.classList.remove('idle');
  setText(titleEl, 'title', s.title || '未知曲目');
  setText(artistEl, 'artist', [s.artist, s.album].filter(Boolean).join(' · ') || '未知歌手');
  setText(miniTitleEl, 'miniTitle', s.title || '未知曲目');
  setText(toggleBtn, 'toggle', toggleGlyph);
  setText(mToggle, 'mtoggle', toggleGlyph);

  const key = (s.title || '') + '|' + (s.artist || '');
  if (s.cover && key !== lastCoverKey) {
    lastCoverKey = key;
    const url = 'file:///' + String(s.cover).replace(/\\/g, '/') + '?v=' + encodeURIComponent(key);
    coverImg.src = url; coverImg.classList.add('on');
    miniCoverImg.src = url; miniCoverImg.classList.add('on');
  } else if (!s.cover && lastCoverKey !== '') {
    lastCoverKey = '';
    coverImg.classList.remove('on'); miniCoverImg.classList.remove('on');
  }
}

window.mw.onState(apply);
window.mw.onMini(v => {
  isMini = !!v;
  card.classList.toggle('mini', isMini);
});
function applyLockState(v) {
  isLocked = !!v;
  el('pin').classList.toggle('on', isLocked);
  card.classList.toggle('locked', isLocked);
}
window.mw.onConfigChanged(c => { applyTheme(c); applyLockState(c.locked); });
window.mw.getConfig().then(c => { applyTheme(c); applyLockState(c.locked); });
window.mw.getState().then(s => {
  if (!s) return;
  if (s.mini) { isMini = true; card.classList.add('mini'); }
  applyLockState(s.locked);
});
el('pin').onclick = () => window.mw.toggleLock();

toggleBtn.onclick = () => window.mw.cmd('playpause');
el('prev').onclick = () => window.mw.cmd('prev');
el('next').onclick = () => window.mw.cmd('next');
mToggle.onclick = () => window.mw.cmd('playpause');
el('mPrev').onclick = () => window.mw.cmd('prev');
el('mNext').onclick = () => window.mw.cmd('next');
el('close').onclick = () => window.mw.quit();
el('min').onclick = () => window.mw.minimize();
el('settings').onclick = () => window.mw.openSettings();
card.addEventListener('dblclick', e => { if (e.target === bar || bar.contains(e.target)) return; window.mw.toggleMini(); });

function seekFromEvent(e) {
  const r = bar.getBoundingClientRect();
  return Math.max(0, Math.min(1, (e.clientX - r.left) / r.width)) * (state.duration || 0);
}
bar.addEventListener('mousedown', e => { if (!state.playing) return; dragging = true; dragPos = seekFromEvent(e); e.preventDefault(); });
window.addEventListener('mousemove', e => { if (dragging) dragPos = seekFromEvent(e); });
window.addEventListener('mouseup', () => {
  if (!dragging) return;
  dragging = false;
  if ((state.duration || 0) > 0) window.mw.cmd('seek:' + dragPos.toFixed(2));
});

const grip = el('grip');
grip.addEventListener('mousedown', e => {
  if (isLocked) return;
  e.preventDefault(); e.stopPropagation();
  const startX = e.screenX, startY = e.screenY;
  const b = { width: window.innerWidth, height: window.innerHeight, x: window.screenX, y: window.screenY };
  const move = ev => window.mw.setBounds({ x: b.x, y: b.y, width: b.width + (ev.screenX - startX), height: b.height + (ev.screenY - startY) });
  const up = () => { window.removeEventListener('mousemove', move); window.removeEventListener('mouseup', up); };
  window.addEventListener('mousemove', move);
  window.addEventListener('mouseup', up);
});

requestAnimationFrame(render);
