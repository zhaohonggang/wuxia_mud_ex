const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

// mtime-snapshot polling watcher for filesystems that do not propagate
// inotify events (e.g. Docker Desktop 9p bind mounts on Windows).
// Watches assets/js, assets/css, assets/static and runs the matching
// non-watch build from package.json when something changes.

const targets = [
  { dir: 'js', cmd: 'node build.js' },
  {
    dir: 'css',
    cmd: 'node_modules/.bin/postcss ./css/app.scss --output ../priv/static/css/app.css'
  },
  {
    dir: 'static',
    cmd: "node_modules/.bin/cpx 'static/**/*' ../priv/static/"
  }
];

const POLL_INTERVAL_MS = 1000;

function snapshot(dir, map) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch (_) {
    return map;
  }
  for (const entry of entries) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      snapshot(p, map);
    } else {
      try {
        map[p] = fs.statSync(p).mtimeMs;
      } catch (_) {}
    }
  }
  return map;
}

let previous = {};
for (const t of targets) snapshot(t.dir, previous);

console.log('[poll-watch] watching: ' + targets.map(t => t.dir).join(', '));

setInterval(() => {
  const current = {};
  for (const t of targets) snapshot(t.dir, current);

  const changedDirs = new Set();
  for (const [f, m] of Object.entries(current)) {
    if (previous[f] !== m) changedDirs.add(path.dirname(f));
  }
  for (const f of Object.keys(previous)) {
    if (!(f in current)) changedDirs.add(path.dirname(f));
  }
  previous = current;

  if (changedDirs.size === 0) return;

  for (const t of targets) {
    const hit = [...changedDirs].some(d => d === t.dir || d.startsWith(t.dir + path.sep));
    if (hit) {
      console.log('[poll-watch] change in ' + t.dir + ' -> ' + t.cmd);
      const r = spawnSync(t.cmd, { shell: true, stdio: 'inherit' });
      if (r.status !== 0) console.error('[poll-watch] build failed for ' + t.dir);
    }
  }
}, POLL_INTERVAL_MS);
