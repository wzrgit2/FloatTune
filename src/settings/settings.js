const el = id => document.getElementById(id);
let cfg = null;
const DEFAULTS = {
  theme: 'dark', accent: '#5aa9ff', alwaysOnTop: true, acrylic: true, autostart: true,
  autoHideIdle: true, idleGraceMs: 5000, cardAlpha: 0.45, transparentWindow: true,
  hotkeys: { enabled: true, playpause: 'Control+Alt+Space', next: 'Control+Alt+Right', prev: 'Control+Alt+Left' }
};

function toast(msg) {
  const t = el('toast');
  t.textContent = msg;
  t.classList.add('on');
  setTimeout(() => t.classList.remove('on'), 1200);
}

function paint() {
  document.documentElement.style.setProperty('--accent', cfg.accent || '#5aa9ff');
  [...el('theme').children].forEach(b => b.classList.toggle('on', b.dataset.v === cfg.theme));
  [...el('accent').querySelectorAll('button')].forEach(b => b.classList.toggle('on', b.dataset.c === cfg.accent));
  el('accentCustom').value = /^#[0-9a-f]{6}$/i.test(cfg.accent || '') ? cfg.accent : '#5aa9ff';
  el('alwaysOnTop').checked = !!cfg.alwaysOnTop;
  el('acrylic').checked = !!cfg.acrylic;
  el('transparentWindow').checked = !!cfg.transparentWindow;
  el('autostart').checked = !!cfg.autostart;
  el('autoHideIdle').checked = !!cfg.autoHideIdle;
  el('idleGrace').value = Math.round((cfg.idleGraceMs || 5000) / 1000);
  const ca = Math.round((typeof cfg.cardAlpha === 'number' ? cfg.cardAlpha : 0.45) * 100);
  el('cardAlpha').value = String(ca);
  el('cardAlphaVal').textContent = ca + '%';
  document.documentElement.style.setProperty('--card-alpha', String(ca / 100));
  el('hkEnabled').checked = !!cfg.hotkeys.enabled;
  el('hkPlaypause').value = cfg.hotkeys.playpause || '';
  el('hkPrev').value = cfg.hotkeys.prev || '';
  el('hkNext').value = cfg.hotkeys.next || '';
}

async function save(patch, msg) {
  cfg = await window.mw.setConfig(patch);
  paint();
  if (msg) toast(msg);
}

// theme
el('theme').addEventListener('click', e => {
  const b = e.target.closest('button');
  if (b) save({ theme: b.dataset.v }, '主题已更新');
});
el('accent').addEventListener('click', e => {
  const b = e.target.closest('button');
  if (b) save({ accent: b.dataset.c }, '主题色已更新');
});
el('accentCustom').addEventListener('change', e => save({ accent: e.target.value }, '主题色已更新'));

// toggles
el('alwaysOnTop').addEventListener('change', e => save({ alwaysOnTop: e.target.checked }, '已更新'));
el('acrylic').addEventListener('change', e => save({ acrylic: e.target.checked, transparentWindow: false }, '重启程序后生效'));
el('transparentWindow').addEventListener('change', e => save({ transparentWindow: e.target.checked, acrylic: false }, '重启程序后生效'));
el('autostart').addEventListener('change', e => save({ autostart: e.target.checked }, '已更新'));
el('autoHideIdle').addEventListener('change', e => save({ autoHideIdle: e.target.checked }, '已更新'));
el('cardAlpha').addEventListener('input', e => {
  el('cardAlphaVal').textContent = e.target.value + '%';
  document.documentElement.style.setProperty('--card-alpha', String(parseInt(e.target.value, 10) / 100));
});
el('cardAlpha').addEventListener('change', e => save({ cardAlpha: parseInt(e.target.value, 10) / 100 }, '已更新'));
el('idleGrace').addEventListener('change', e => {
  const sec = Math.max(0, Math.min(120, parseInt(e.target.value, 10) || 0));
  save({ idleGraceMs: sec * 1000 }, '已更新');
});
el('hkEnabled').addEventListener('change', e => save({ hotkeys: { enabled: e.target.checked } }, '已更新'));

// hotkey capture
function accelFromEvent(e) {
  const mods = [];
  if (e.ctrlKey) mods.push('Control');
  if (e.altKey) mods.push('Alt');
  if (e.shiftKey) mods.push('Shift');
  if (e.metaKey) mods.push('Super');
  const c = e.code || '';
  let key = null;
  if (c.startsWith('Key')) key = c.slice(3);
  else if (c.startsWith('Digit')) key = c.slice(5);
  else if (/^F([1-9]|1[0-9]|2[0-4])$/.test(c)) key = c;
  else if (c === 'Space') key = 'Space';
  else if (c === 'ArrowUp') key = 'Up';
  else if (c === 'ArrowDown') key = 'Down';
  else if (c === 'ArrowLeft') key = 'Left';
  else if (c === 'ArrowRight') key = 'Right';
  else if (c === 'Escape') return 'CANCEL';
  if (!key) return null;
  if (!mods.length) return null;
  return mods.join('+') + '+' + key;
}
const hkTarget = { hkPlaypause: 'playpause', hkPrev: 'prev', hkNext: 'next' };
Object.keys(hkTarget).forEach(id => {
  const input = el(id);
  input.addEventListener('focus', () => { input.classList.add('rec'); input.value = '按下组合键…'; });
  input.addEventListener('blur', () => { input.classList.remove('rec'); paint(); });
  input.addEventListener('keydown', e => {
    e.preventDefault();
    const accel = accelFromEvent(e);
    if (accel === 'CANCEL') { input.blur(); return; }
    if (!accel) return;
    const patch = { hotkeys: {} };
    patch.hotkeys[hkTarget[id]] = accel;
    input.value = accel;
    save(patch, '快捷键已更新').then(() => input.blur());
  });
});

el('reset').addEventListener('click', async () => {
  cfg = await window.mw.setConfig({
    theme: DEFAULTS.theme, accent: DEFAULTS.accent, alwaysOnTop: DEFAULTS.alwaysOnTop,
    acrylic: DEFAULTS.acrylic, transparentWindow: DEFAULTS.transparentWindow, autostart: DEFAULTS.autostart, autoHideIdle: DEFAULTS.autoHideIdle, cardAlpha: DEFAULTS.cardAlpha,
    idleGraceMs: DEFAULTS.idleGraceMs, hotkeys: { ...DEFAULTS.hotkeys }
  });
  paint();
  toast('已恢复默认');
});
el('close').addEventListener('click', () => window.mw.closeSettings());

window.mw.getConfig().then(c => { cfg = c; paint(); });
