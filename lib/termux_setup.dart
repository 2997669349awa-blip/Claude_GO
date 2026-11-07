import 'dart:convert';

/// The Node bridge that runs inside Termux. It exposes localhost:8787 and
/// spawns `claude` in headless stream-json mode.
const bridgeScript = r'''
const http = require('http');
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const TOKEN = process.env.CLAUDE_GO_TOKEN || '';
const PORT = 8787;
let child = null;

function claudeBin() {
  const home = os.homedir();
  const candidates = [
    path.join(home, '.local', 'bin', 'claude'),
    '/data/data/com.termux/files/usr/bin/claude',
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
    return sendJson(res, 200, { ok: true, claude: claudeBin() });
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
    env.PATH = path.join(os.homedir(), '.local', 'bin') + ':' + (env.PATH || '');
    const args = ['-p', '--output-format', 'stream-json', '--verbose', '--include-partial-messages'];
    if (payload.permissionMode) args.push('--permission-mode', payload.permissionMode);
    if (payload.sessionId) args.push('--resume', payload.sessionId);

    res.writeHead(200, {
      'content-type': 'application/x-ndjson',
      'cache-control': 'no-cache',
    });

    let proc;
    try {
      proc = spawn(claudeBin(), args, {
        cwd: payload.cwd || os.homedir(),
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
''';

String _shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";

String _bridgeFile() => r'~/.claude-go/bridge.cjs';

String _installBridge() {
  final encoded = base64Encode(utf8.encode(bridgeScript));
  return '''
mkdir -p ~/.claude-go
printf %s ${_shellQuote(encoded)} | base64 -d > ${_bridgeFile()}
''';
}

String _startBridge(String token) => '''
if [ -f ~/.claude-go/bridge.pid ]; then
  kill "\$(cat ~/.claude-go/bridge.pid)" 2>/dev/null || true
fi
CLAUDE_GO_TOKEN=${_shellQuote(token)} nohup node ${_bridgeFile()} >> ~/.claude-go/bridge.log 2>&1 &
echo \$! > ~/.claude-go/bridge.pid
''';

/// First run: installs Node, Claude Code and the bridge, then starts it.
String buildSetupCommand({
  required String token,
  required String workspace,
}) =>
    '''
set -e
termux-wake-lock 2>/dev/null || true
termux-setup-storage 2>/dev/null || true
pkg update -y
pkg install -y nodejs-lts git curl
curl -fsSL https://claude.ai/install.sh | bash
${_installBridge()}
mkdir -p ${_shellQuote(workspace)} 2>/dev/null || true
${_startBridge(token)}
echo CLAUDE_GO_SETUP_DONE
''';

/// Later runs: keep the installed files, just restart the bridge.
String buildStartCommand({
  required String token,
  required String workspace,
}) =>
    '''
set -e
termux-wake-lock 2>/dev/null || true
termux-setup-storage 2>/dev/null || true
${_installBridge()}
mkdir -p ${_shellQuote(workspace)} 2>/dev/null || true
${_startBridge(token)}
echo CLAUDE_GO_STARTED
''';
