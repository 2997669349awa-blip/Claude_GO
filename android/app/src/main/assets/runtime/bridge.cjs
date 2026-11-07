const http = require('http');
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const TOKEN = process.env.CLAUDE_GO_TOKEN || '';
const PORT = 8787;
let child = null;
const home = os.homedir();

function expandHome(value) {
  if (!value) return home;
  if (value === '~') return home;
  if (value.startsWith('$HOME')) return home + value.slice(5);
  if (value.startsWith('~/')) return path.join(home, value.slice(2));
  return value;
}

function claudeBin() {
  const home = os.homedir();
  const candidates = [
    '/usr/local/bin/claude',
    path.join(home, '.local', 'bin', 'claude'),
  ];
  for (const candidate of candidates) {
    try {
      fs.accessSync(candidate, fs.constants.X_OK);
      return candidate;
    } catch (_) {}
  }
  return 'claude';
}

function sendJson(res, code, value) {
  res.writeHead(code, { 'content-type': 'application/json' });
  res.end(JSON.stringify(value));
}

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    return sendJson(res, 200, {
      ok: true,
      claude: claudeBin(),
      installed: fs.existsSync(claudeBin()),
    });
  }
  if (req.method === 'POST' && req.url === '/stop') {
    if (child) {
      try { child.kill('SIGTERM'); } catch (_) {}
      child = null;
    }
    return sendJson(res, 200, { ok: true });
  }
  if (req.method !== 'POST' || req.url !== '/run') {
    return sendJson(res, 404, { error: 'not found' });
  }
  if (TOKEN && req.headers['x-claude-go-token'] !== TOKEN) {
    return sendJson(res, 401, { error: 'unauthorized' });
  }

  let body = '';
  req.on('data', (chunk) => { body += chunk; });
  req.on('end', () => {
    let payload;
    try {
      payload = JSON.parse(body);
    } catch (_) {
      return sendJson(res, 400, { error: 'bad json' });
    }

    const env = Object.assign({}, process.env, payload.env || {});
    env.PATH = '/usr/local/bin:' + path.join(home, '.local', 'bin') + ':' + (env.PATH || '');
    const args = ['-p', '--output-format', 'stream-json', '--verbose', '--include-partial-messages'];
    if (payload.permissionMode) args.push('--permission-mode', payload.permissionMode);
    if (payload.sessionId) args.push('--resume', payload.sessionId);
    const cwd = expandHome(payload.cwd);
    try { fs.mkdirSync(cwd, { recursive: true }); } catch (_) {}

    res.writeHead(200, {
      'content-type': 'application/x-ndjson',
      'cache-control': 'no-cache',
    });

    let proc;
    try {
      proc = spawn(claudeBin(), args, {
        cwd: cwd,
        env,
      });
    } catch (error) {
      res.write(JSON.stringify({ type: 'claude_go_error', message: String(error) }) + '\n');
      return res.end();
    }

    child = proc;
    proc.stdout.on('data', (data) => res.write(data));
    proc.stderr.on('data', (data) => {
      res.write(JSON.stringify({ type: 'claude_go_stderr', message: data.toString() }) + '\n');
    });
    proc.on('error', (error) => {
      res.write(JSON.stringify({ type: 'claude_go_error', message: String(error) }) + '\n');
      res.end();
    });
    proc.on('close', () => {
      child = null;
      res.end();
    });
    res.on('close', () => {
      if (!res.writableEnded && proc && !proc.killed) {
        try { proc.kill('SIGTERM'); } catch (_) {}
      }
    });

    if (payload.prompt) proc.stdin.write(payload.prompt);
    proc.stdin.end();
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log('claude-go bridge listening on ' + PORT);
});
