const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('mw', {
  onState: (cb) => ipcRenderer.on('state', (_e, s) => cb(s)),
  onMini: (cb) => ipcRenderer.on('mini', (_e, v) => cb(v)),
  onConfigChanged: (cb) => ipcRenderer.on('config-changed', (_e, c) => cb(c)),
  cmd: (c) => ipcRenderer.send('cmd', c),
  setBounds: (b) => ipcRenderer.send('set-bounds', b),
  minimize: () => ipcRenderer.send('minimize'),
  quit: () => ipcRenderer.send('quit'),
  openSettings: () => ipcRenderer.send('open-settings'),
  toggleMini: () => ipcRenderer.send('toggle-mini'),
  toggleLock: () => ipcRenderer.send('toggle-lock'),
  closeSettings: () => ipcRenderer.send('close-settings'),
  getConfig: () => ipcRenderer.invoke('get-config'),
  getState: () => ipcRenderer.invoke('get-state'),
  setConfig: (patch) => ipcRenderer.invoke('set-config', patch)
});
