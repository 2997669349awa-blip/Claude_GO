import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'settings.dart';

abstract class ClaudeBackend {
  Stream<ClaudeEvent> stream({required String prompt, String? sessionId});

  Future<void> stop();

  Future<void> dispose() async {}
}

/// Local mode: a small Node bridge inside Termux drives `claude` and streams
/// its NDJSON output back over localhost.
class LocalBackend implements ClaudeBackend {
  LocalBackend(this.settings);

  final AppSettings settings;
  static const _base = 'http://127.0.0.1:8787';
  http.Client? _client;

  static Future<bool> isRunning() async {
    try {
      final response = await http
          .get(Uri.parse('$_base/health'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<ClaudeEvent> stream({
    required String prompt,
    String? sessionId,
  }) async* {
    final client = http.Client();
    _client = client;
    try {
      final request = http.Request('POST', Uri.parse('$_base/run'))
        ..headers['content-type'] = 'application/json'
        ..headers['x-claude-go-token'] = settings.localToken
        ..body = jsonEncode({
          'prompt': prompt,
          'cwd': settings.localWorkspace,
          'sessionId': sessionId,
          'permissionMode': settings.permissionMode,
          'env': settings.claudeEnv,
        });
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('本地桥返回 ${response.statusCode}：$body');
      }
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        for (final event in parseClaudeLine(line)) {
          yield event;
        }
      }
      yield const ClaudeEvent('done');
    } finally {
      client.close();
      _client = null;
    }
  }

  @override
  Future<void> stop() async {
    _client?.close();
    _client = null;
    try {
      await http
          .post(
            Uri.parse('$_base/stop'),
            headers: {'x-claude-go-token': settings.localToken},
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // The bridge may already be gone; stopping is best effort.
    }
  }

  @override
  Future<void> dispose() => stop();
}

/// Cloud mode: SSH into a computer that already has Claude Code installed.
class CloudBackend implements ClaudeBackend {
  CloudBackend(this.settings);

  final AppSettings settings;
  SSHClient? _client;

  Future<SSHClient> _connect() async {
    final host = settings.cloudHost.trim();
    if (host.isEmpty) throw Exception('请先填写电脑地址');
    final socket = await SSHSocket.connect(
      host,
      settings.cloudPort,
      timeout: const Duration(seconds: 15),
    );
    final key = settings.cloudPrivateKey.trim();
    final client = SSHClient(
      socket,
      username: settings.cloudUser.trim(),
      identities: key.isEmpty ? null : SSHKeyPair.fromPem(key),
      onPasswordRequest: settings.cloudPassword.isEmpty
          ? null
          : () => settings.cloudPassword,
      keepAliveInterval: const Duration(seconds: 15),
    );
    await client.authenticated;
    return client;
  }

  Future<String> test() async {
    final client = await _connect();
    try {
      final bytes = await client.run(
        '${_claudePath()} --version 2>&1 || command -v claude || true',
      );
      return utf8.decode(bytes).trim();
    } finally {
      client.close();
    }
  }

  String _claudePath() {
    final path = settings.cloudClaudePath.trim();
    return path.isEmpty ? 'claude' : path;
  }

  String _quote(String value) => "'${value.replaceAll("'", r"'\''")}'";

  String _command(String? sessionId) {
    final exports = settings.claudeEnv.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => 'export ${entry.key}=${_quote(entry.value)};')
        .join(' ');
    final workspace = settings.cloudWorkspace.trim();
    final dir = workspace.isEmpty ? '~' : workspace;
    final resume = (sessionId ?? '').isEmpty
        ? ''
        : ' --resume ${_quote(sessionId!)}';
    return '$exports cd ${_quote(dir)} && ${_claudePath()} -p '
        '--output-format stream-json --verbose --include-partial-messages '
        '--permission-mode ${settings.permissionMode}$resume';
  }

  @override
  Stream<ClaudeEvent> stream({
    required String prompt,
    String? sessionId,
  }) async* {
    final client = await _connect();
    _client = client;
    try {
      final session = await client.execute(_command(sessionId));
      session.stdin.add(Uint8List.fromList(utf8.encode(prompt)));
      await session.stdin.close();

      final controller = StreamController<ClaudeEvent>();
      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();

      session.stdout
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              for (final event in parseClaudeLine(line)) {
                controller.add(event);
              }
            },
            onError: (Object error) =>
                controller.add(ClaudeEvent('error', text: '$error')),
            onDone: () {
              if (!stdoutDone.isCompleted) stdoutDone.complete();
            },
          );
      session.stderr
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.trim().isNotEmpty) {
                controller.add(ClaudeEvent('stderr', text: line));
              }
            },
            onDone: () {
              if (!stderrDone.isCompleted) stderrDone.complete();
            },
          );

      unawaited(() async {
        await Future.wait([stdoutDone.future, stderrDone.future, session.done]);
        controller.add(const ClaudeEvent('done'));
        await controller.close();
      }());

      yield* controller.stream;
    } finally {
      _client = null;
      client.close();
    }
  }

  @override
  Future<void> stop() async {
    _client?.close();
    _client = null;
  }

  @override
  Future<void> dispose() => stop();
}
