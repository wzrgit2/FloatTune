const { app, BrowserWindow, ipcMain, globalShortcut, screen, Menu, Tray, nativeImage } = require('electron');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

const cfgPath = () => path.join(app.getPath('userData'), 'config.json');
const DEFAULTS = {
  width: 380, height: 110, x: null, y: null,
  miniWidth: 330, miniHeight: 56,
  autostart: true,
  alwaysOnTop: true,
  acrylic: true,
  transparentWindow: false,   // true = real per-pixel alpha; on some setups this paints a blank window
  cardAlpha: 0.45,
  locked: false,
  theme: 'dark',
  accent: '#5aa9ff',
  autoHideIdle: true,
  idleGraceMs: 5000,
  hotkeys: { enabled: true, playpause: 'Control+Alt+Space', next: 'Control+Alt+Right', prev: 'Control+Alt+Left' }
};
let config = { ...DEFAULTS };
const SILENT = process.argv.includes('--silent');

function loadConfig() {
  try {
    const raw = JSON.parse(fs.readFileSync(cfgPath(), 'utf8'));
    config = { ...DEFAULTS, ...raw };
    // migrate the old boolean hotkeys flag
    if (typeof raw.hotkeys === 'boolean') config.hotkeys = { ...DEFAULTS.hotkeys, enabled: raw.hotkeys };
    config.hotkeys = { ...DEFAULTS.hotkeys, ...(config.hotkeys || {}) };
  } catch { config = { ...DEFAULTS, hotkeys: { ...DEFAULTS.hotkeys } }; }
}
function saveConfig() {
  try { fs.mkdirSync(path.dirname(cfgPath()), { recursive: true }); fs.writeFileSync(cfgPath(), JSON.stringify(config, null, 2)); }
  catch (e) { console.error('save config failed', e.message); }
}

let win = null, settingsWin = null, bridge = null, buf = '', bridgeRetries = 0, saveTimer = null;
let idleTimer = null, lastPlaying = false, userHidden = false;
let tray = null, trayKey = null;
let mini = false, normalBounds = null, moveTimer = null;

const APP_ICON = () => path.join(__dirname, 'assets', 'app.png');

// ---------- bridge ----------
function startBridge() {
  const fake = !!process.env.MW_FAKE;
  const script = fake ? path.join(__dirname, '..', 'tools', 'mock-bridge.js') : path.join(__dirname, '..', 'bridge', 'smtc.ps1');
  bridge = fake
    ? spawn(process.execPath, [script], { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true, env: { ...process.env, ELECTRON_RUN_AS_NODE: '1' } })
    : spawn('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script], { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
  bridge.stdout.setEncoding('utf8');
  bridge.stdout.on('data', chunk => {
    buf += chunk;
    let i;
    while ((i = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, i).trim();
      buf = buf.slice(i + 1);
      if (!line) continue;
      let st; try { st = JSON.parse(line); } catch { continue; }
      updateTray(st);
      onState(st);
      if (win && !win.isDestroyed()) win.webContents.send('state', st);
    }
  });
  bridge.stderr.setEncoding('utf8');
  bridge.stderr.on('data', d => { const s = d.trim(); if (s) console.error('[bridge]', s); });
  bridge.on('error', e => console.error('[bridge spawn]', e.message));
  bridge.on('exit', code => {
    console.error('[bridge] exited', code);
    if (bridgeRetries++ < 10) setTimeout(startBridge, 1500);
  });
}
function sendCmd(c) {
  if (bridge && bridge.stdin && bridge.stdin.writable) {
    try { bridge.stdin.write(c + '\n'); } catch (e) { console.error('cmd failed', e.message); }
  }
}

// ---------- tray ----------
function updateTray(st) {
  if (!tray || tray.isDestroyed()) return;
  const playing = !!st.playing;
  if (!playing) {
    if (trayKey !== null) {
      trayKey = null;
      try { tray.setImage(nativeImage.createFromPath(APP_ICON())); } catch {}
      try { tray.setToolTip('FloatTune - 未在播放'); } catch {}
    }
    return;
  }
  const name = [st.title, st.artist].filter(Boolean).join(' - ') || '未知曲目';
  if (name === trayKey) return;
  trayKey = name;
  try { tray.setToolTip(name); } catch {}
  if (st.cover) {
    try {
      const raw = nativeImage.createFromPath(st.cover);
      if (!raw.isEmpty()) { tray.setImage(raw.resize({ width: 16, height: 16, quality: 'best' })); return; }
    } catch (e) { console.error('[tray cover]', e.message); }
  }
  try { tray.setImage(nativeImage.createFromPath(APP_ICON())); } catch {}
}
function buildTrayMenu() {
  return Menu.buildFromTemplate([
    { label: '显示 / 隐藏', click: () => toggleWindow() },
    { label: '迷你模式', click: () => { if (mini) exitMini(); else enterMini(null); } },
    { label: '固定窗口（锁定位置与大小）', click: () => { config.locked = !config.locked; applyLock(); saveConfig(); } },
    { type: 'separator' },
    { label: '播放 / 暂停', click: () => sendCmd('playpause') },
    { label: '上一首', click: () => sendCmd('prev') },
    { label: '下一首', click: () => sendCmd('next') },
    { type: 'separator' },
    { label: '设置…', click: () => openSettings() },
    { type: 'separator' },
    { label: '退出', click: () => { app.isQuitting = true; app.quit(); } }
  ]);
}
function createTray() {
  try {
    tray = new Tray(nativeImage.createFromPath(APP_ICON()));
    tray.setToolTip('FloatTune');
    tray.setContextMenu(buildTrayMenu());
    tray.on('click', () => toggleWindow());
  } catch (e) { console.error('[tray]', e.message); }
}
function toggleWindow() {
  if (!win || win.isDestroyed()) return;
  if (win.isVisible() && !win.isMinimized()) { userHidden = true; win.hide(); }
  else showWindow(true);
}
function showWindow(activate) {
  if (!win || win.isDestroyed()) return;
  userHidden = false;
  if (win.isMinimized()) win.restore();
  if (activate) { win.show(); win.focus(); } else if (!win.isVisible()) win.showInactive();
}

// auto show only when playback *starts*; respect a manual minimise
function onState(st) {
  if (!win || win.isDestroyed()) return;
  const playing = !!st.playing;
  if (playing) {
    clearTimeout(idleTimer); idleTimer = null;
    if (!lastPlaying && !userHidden && (!win.isVisible() || win.isMinimized())) showWindow(false);
  } else if (config.autoHideIdle && lastPlaying && !idleTimer && win.isVisible() && !win.isMinimized()) {
    idleTimer = setTimeout(() => {
      idleTimer = null;
      if (win && !win.isDestroyed() && !userHidden) win.hide();
    }, config.idleGraceMs);
  }
  lastPlaying = playing;
}

// ---------- mini mode: drag onto the taskbar ----------
function enterMini(keepX) {
  if (!win || win.isDestroyed() || mini) return;
  const wa = screen.getDisplayMatching(win.getBounds()).workArea;
  normalBounds = win.getBounds();
  mini = true;
  const w = config.miniWidth, h = config.miniHeight;
  const x = (keepX === undefined || keepX === null) ? normalBounds.x : keepX;
  win.setMinimumSize(200, 40);
  win.setBounds({ x: Math.max(wa.x, Math.min(x, wa.x + wa.width - w)), y: wa.y + wa.height - h - 4, width: w, height: h });
  win.webContents.send('mini', true);
  config.miniX = win.getBounds().x;
  saveConfig();
}
function exitMini() {
  if (!win || win.isDestroyed() || !mini) return;
  mini = false;
  miniCooldownUntil = Date.now() + 1600; // don't instantly re-enter
  win.setMinimumSize(220, 64);
  const b = normalBounds || { x: config.x, y: config.y, width: config.width, height: config.height };
  const wa = screen.getDisplayMatching(win.getBounds()).workArea;
  const w = Math.max(220, b.width), h = Math.max(64, b.height);
  // never restore onto the taskbar, otherwise we would bounce straight back into mini
  const maxY = wa.y + wa.height - h - 90;
  const y = Math.min(b.y, maxY);
  const x = Math.max(wa.x, Math.min(b.x, wa.x + wa.width - w));
  win.setBounds({ x, y, width: w, height: h });
  win.webContents.send('mini', false);
  const nb = win.getBounds();
  Object.assign(config, { x: nb.x, y: nb.y, width: nb.width, height: nb.height });
  saveConfig();
}
// Watch the window position instead of the 'moved' event (which Windows only
// fires at the end of a user drag). Dropping the card onto the taskbar turns it
// into the mini player; dragging it back up restores the full card.
let miniHits = 0, miniCooldownUntil = 0;
function watchMini() {
  setInterval(() => {
    if (!win || win.isDestroyed()) return;
    const b = win.getBounds();
    const wa = screen.getDisplayMatching(b).workArea;
    const bottom = wa.y + wa.height;
    const nearTaskbar = (b.y + b.height) >= (bottom - 16) && b.y > wa.y + 150;
    if (mini) {
      // a mini player always snaps back to sitting on the taskbar
      if (nearTaskbar) {
        const dockY = bottom - b.height - 4;
        const dockX = Math.max(wa.x, Math.min(b.x, wa.x + wa.width - b.width));
        if (Math.abs(b.y - dockY) > 3 || Math.abs(b.x - dockX) > 3) win.setBounds({ x: dockX, y: dockY, width: b.width, height: b.height });
      } else if ((b.y + b.height) < (bottom - 70)) {
        exitMini();
      }
      return;
    }
    if (nearTaskbar && Date.now() > miniCooldownUntil) { if (++miniHits >= 3) { miniHits = 0; enterMini(b.x); } }
    else miniHits = 0;
  }, 350);
}

// ---------- hotkeys ----------
function registerHotkeys() {
  globalShortcut.unregisterAll();
  const hk = config.hotkeys || {};
  if (!hk.enabled) return;
  const map = { playpause: hk.playpause, next: hk.next, prev: hk.prev };
  for (const [cmd, accel] of Object.entries(map)) {
    if (!accel) continue;
    try { globalShortcut.register(accel, () => sendCmd(cmd)); }
    catch (e) { console.error('hotkey', accel, e.message); }
  }
}

// ---------- windows ----------
function createWindow() {
  const wa = screen.getPrimaryDisplay().workArea;
  const w = Math.max(220, config.width), h = Math.max(64, config.height);
  const x = (config.x === null) ? wa.x + wa.width - w - 40 : config.x;
  const y = (config.y === null) ? wa.y + 60 : config.y;

  const opts = {
    width: w, height: h, x, y, minWidth: 220, minHeight: 64,
    frame: false, icon: APP_ICON(), hasShadow: true, roundedCorners: true,
    resizable: true, maximizable: false, minimizable: true,
    skipTaskbar: true, alwaysOnTop: !!config.alwaysOnTop, fullscreenable: false,
    title: 'FloatTune', show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true, nodeIntegration: false, backgroundThrottling: false
    }
  };
  if (config.transparentWindow && process.platform === 'win32') {
    opts.transparent = true;
    opts.backgroundColor = '#00000000';
  } else if (config.acrylic && process.platform === 'win32') {
    opts.backgroundMaterial = 'acrylic';
    opts.backgroundColor = '#00000000';
  } else {
    opts.backgroundColor = '#14171e';
  }

  win = new BrowserWindow(opts);
  applyAlwaysOnTop();
  setTimeout(() => { try { applyLock(); } catch (e) { console.error(e.message); } }, 300);
  win.setMenuBarVisibility(false);
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  win.webContents.on('console-message', (e) => { const m = (e && e.message) ? e.message : e; console.log('[renderer]', m); });
  win.webContents.on('did-fail-load', (_e, code, desc) => {
    console.error('[renderer] load failed', code, desc);
    try { fs.appendFileSync(path.join(app.getPath('temp'), 'floattune-bridge.log'), new Date().toISOString().slice(11, 19) + ' RENDERER LOAD FAILED ' + code + ' ' + desc + '\n'); } catch {}
  });
  win.webContents.on('render-process-gone', (_e, details) => {
    console.error('[renderer] gone', JSON.stringify(details));
    try { fs.appendFileSync(path.join(app.getPath('temp'), 'floattune-bridge.log'), new Date().toISOString().slice(11, 19) + ' RENDERER GONE ' + JSON.stringify(details) + '\n'); } catch {}
  });
  win.webContents.on('did-finish-load', () => {
    try { fs.appendFileSync(path.join(app.getPath('temp'), 'floattune-bridge.log'), new Date().toISOString().slice(11, 19) + ' renderer loaded ok\n'); } catch {}
  });
  // NOTE: re-applying the background material on focus/blur was tried to keep the glass
  // look while unfocused, but it can reset the window's DWM rounded corners (square
  // corners in acrylic mode). Removed -- corners matter more.
  win.once('ready-to-show', () => { if (!SILENT) { win.show(); } });
  win.on('closed', () => { win = null; });

  win.on('moved', () => {
    if (mini) { config.miniX = win.getBounds().x; clearTimeout(saveTimer); saveTimer = setTimeout(saveConfig, 500); return; }
    if (!win || win.isDestroyed()) return;
    const b = win.getBounds();
    config.x = b.x; config.y = b.y;
    clearTimeout(saveTimer); saveTimer = setTimeout(saveConfig, 500);
  });
  win.on('resized', () => {
    if (!win || win.isDestroyed() || mini) return;
    const b = win.getBounds();
    config.width = b.width; config.height = b.height;
    clearTimeout(saveTimer); saveTimer = setTimeout(saveConfig, 400);
  });
}
function applyAlwaysOnTop() {
  if (!win || win.isDestroyed()) return;
  if (config.alwaysOnTop || config.locked) win.setAlwaysOnTop(true, 'screen-saver');
  else win.setAlwaysOnTop(false);
}

// pin: no moving, no resizing, always on top
function applyLock() {
  if (!win || win.isDestroyed()) return;
  const lk = !!config.locked;
  try { win.setMovable(!lk); } catch (e) { console.error('setMovable', e.message); }
  try { win.setResizable(!lk); } catch (e) { console.error('setResizable', e.message); }
  applyAlwaysOnTop();
  if (win.webContents && !win.webContents.isDestroyed()) {
    win.webContents.send('config-changed', JSON.parse(JSON.stringify(config)));
  }
}

function openSettings() {
  if (settingsWin && !settingsWin.isDestroyed()) { settingsWin.show(); settingsWin.focus(); return; }
  settingsWin = new BrowserWindow({
    width: 430, height: 560, resizable: false, maximizable: false, minimizable: false,
    title: 'FloatTune 设置', icon: APP_ICON(), parent: win && !win.isDestroyed() ? win : undefined,
    show: false, backgroundColor: '#1a1e26',
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false }
  });
  settingsWin.setMenuBarVisibility(false);
  const dbg = (m) => { try { fs.appendFileSync(path.join(app.getPath('temp'), 'floattune-bridge.log'), new Date().toISOString().slice(11, 19) + ' SETTINGS ' + m + '\n'); } catch { } };
  settingsWin.webContents.on('did-finish-load', () => dbg('loaded ok'));
  settingsWin.webContents.on('did-fail-load', (_e, code, desc) => dbg('LOAD FAILED ' + code + ' ' + desc));
  settingsWin.webContents.on('render-process-gone', (_e, d) => dbg('RENDERER GONE ' + JSON.stringify(d)));
  settingsWin.loadFile(path.join(__dirname, 'settings', 'settings.html'));
  // show only after the page has actually painted, otherwise a blank frame can appear
  settingsWin.webContents.once('did-finish-load', () => settingsWin.show());
  setTimeout(() => { if (settingsWin && !settingsWin.isDestroyed() && !settingsWin.isVisible()) { dbg('fallback show'); settingsWin.show(); } }, 2500);
  settingsWin.on('closed', () => { settingsWin = null; });
}

// ---------- ipc ----------
ipcMain.on('cmd', (_e, c) => { if (typeof c === 'string') sendCmd(c); });
ipcMain.on('set-bounds', (_e, b) => {
  if (!win || win.isDestroyed() || mini) return;
  const cur = win.getBounds();
  const nb = {
    x: b.x === undefined ? cur.x : Math.round(b.x),
    y: b.y === undefined ? cur.y : Math.round(b.y),
    width: Math.max(220, Math.round(b.width || cur.width)),
    height: Math.max(64, Math.round(b.height || cur.height))
  };
  win.setBounds(nb);
  Object.assign(config, { x: nb.x, y: nb.y, width: nb.width, height: nb.height });
  clearTimeout(saveTimer); saveTimer = setTimeout(saveConfig, 400);
});
ipcMain.on('minimize', () => { if (win && !win.isDestroyed()) { userHidden = true; win.hide(); } });
ipcMain.on('quit', () => { app.isQuitting = true; app.quit(); });
ipcMain.on('open-settings', () => openSettings());
ipcMain.on('toggle-mini', () => { if (mini) exitMini(); else enterMini(null); });
ipcMain.on('toggle-lock', () => { config.locked = !config.locked; applyLock(); saveConfig(); });
ipcMain.on('close-settings', () => { if (settingsWin && !settingsWin.isDestroyed()) settingsWin.close(); });
ipcMain.handle('get-config', () => JSON.parse(JSON.stringify(config)));
ipcMain.handle('get-state', () => ({ mini, alwaysOnTop: !!config.alwaysOnTop, locked: !!config.locked, theme: config.theme, accent: config.accent }));
ipcMain.handle('set-config', (_e, patch) => {
  if (patch && typeof patch === 'object') {
    if (patch.hotkeys) config.hotkeys = { ...config.hotkeys, ...patch.hotkeys };
    const { hotkeys, ...rest } = patch;
    Object.assign(config, rest);
    if ('alwaysOnTop' in patch || 'locked' in patch) { applyAlwaysOnTop(); applyLock(); }
    if ('hotkeys' in patch || 'alwaysOnTop' in patch) registerHotkeys();
    if ('autostart' in patch && app.isPackaged) {
      try { app.setLoginItemSettings({ openAtLogin: !!config.autostart, args: ['--silent'] }); } catch {}
    }
    if (win && !win.isDestroyed()) win.webContents.send('config-changed', JSON.parse(JSON.stringify(config)));
    saveConfig();
  }
  return JSON.parse(JSON.stringify(config));
});

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => showWindow(true));
  app.whenReady().then(() => {
    Menu.setApplicationMenu(null);
    loadConfig();
    createWindow();
    createTray();
    watchMini();
    startBridge();
    registerHotkeys();
    if (app.isPackaged) {
      try { app.setLoginItemSettings({ openAtLogin: !!config.autostart, args: ['--silent'] }); } catch (e) { console.error(e.message); }
    }
    app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
  });
}

app.on('will-quit', () => {
  globalShortcut.unregisterAll();
  if (tray) { try { tray.destroy(); } catch {} }
  if (bridge) { try { bridge.stdin.end(); bridge.kill(); } catch {} }
});
app.on('window-all-closed', () => { app.isQuitting = true; app.quit(); });
