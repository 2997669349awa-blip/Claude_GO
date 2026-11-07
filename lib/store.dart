import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backends.dart';
import 'models.dart';
import 'settings.dart';

class AppStore extends ChangeNotifier {
  AppStore._(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  final AppSettings settings = AppSettings();
  final List<ChatMessage> messages = [];

  bool busy = false;
  String? lastStderr;

  ClaudeBackend? _backend;
  StreamSubscription<ClaudeEvent>? _subscription;

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    final store = AppStore._(prefs, secure);
    await store._read();
    return store;
  }

  Future<void> _read() async {
    final mode = _prefs.getString('mode');
    settings.mode = mode == 'cloud' ? BackendMode.cloud : BackendMode.local;
    settings.baseUrl =
        _prefs.getString('baseUrl') ?? settings.baseUrl;
    settings.model = _prefs.getString('model') ?? settings.model;
    settings.opusModel =
        _prefs.getString('opusModel') ?? settings.opusModel;
    settings.sonnetModel =
        _prefs.getString('sonnetModel') ?? settings.sonnetModel;
    settings.haikuModel =
        _prefs.getString('haikuModel') ?? settings.haikuModel;
    settings.subagentModel =
        _prefs.getString('subagentModel') ?? settings.subagentModel;
    settings.permissionMode =
        _prefs.getString('permissionMode') ?? settings.permissionMode;
    settings.protectBackground =
        _prefs.getBool('protectBackground') ?? false;
    settings.externalStorage =
        _prefs.getBool('externalStorage') ?? false;
    settings.localWorkspace = settings.externalStorage
        ? '/storage/emulated/0/ClaudeGO'
        : (r'$HOME/ClaudeGO');
    settings.localToken = _prefs.getString('localToken') ?? _newToken();
    settings.localSessionId = _prefs.getString('localSessionId');
    settings.cloudHost = _prefs.getString('cloudHost') ?? '';
    settings.cloudPort = _prefs.getInt('cloudPort') ?? 22;
    settings.cloudUser = _prefs.getString('cloudUser') ?? '';
    settings.cloudWorkspace = _prefs.getString('cloudWorkspace') ?? '~';
    settings.cloudClaudePath =
        _prefs.getString('cloudClaudePath') ?? 'claude';
    settings.cloudSessionId = _prefs.getString('cloudSessionId');

    try {
      settings.apiKey = await _secure.read(key: 'apiKey') ?? '';
      settings.cloudPassword =
          await _secure.read(key: 'cloudPassword') ?? '';
      settings.cloudPrivateKey =
          await _secure.read(key: 'cloudPrivateKey') ?? '';
    } catch (_) {
      // A locked keystore should not stop the app from opening.
    }
  }

  static String _newToken() {
    final random = Random.secure();
    return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
  }

  Future<void> save() async {
    await _prefs.setString('mode', settings.mode.name);
    await _prefs.setString('baseUrl', settings.baseUrl);
    await _prefs.setString('model', settings.model);
    await _prefs.setString('opusModel', settings.opusModel);
    await _prefs.setString('sonnetModel', settings.sonnetModel);
    await _prefs.setString('haikuModel', settings.haikuModel);
    await _prefs.setString('subagentModel', settings.subagentModel);
    await _prefs.setString('permissionMode', settings.permissionMode);
    await _prefs.setBool('protectBackground', settings.protectBackground);
    await _prefs.setBool('externalStorage', settings.externalStorage);
    await _prefs.setString('localToken', settings.localToken);
    if (settings.localSessionId == null) {
      await _prefs.remove('localSessionId');
    } else {
      await _prefs.setString('localSessionId', settings.localSessionId!);
    }
    await _prefs.setString('cloudHost', settings.cloudHost);
    await _prefs.setInt('cloudPort', settings.cloudPort);
    await _prefs.setString('cloudUser', settings.cloudUser);
    await _prefs.setString('cloudWorkspace', settings.cloudWorkspace);
    await _prefs.setString('cloudClaudePath', settings.cloudClaudePath);
    if (settings.cloudSessionId == null) {
      await _prefs.remove('cloudSessionId');
    } else {
      await _prefs.setString('cloudSessionId', settings.cloudSessionId!);
    }
    try {
      await _secure.write(key: 'apiKey', value: settings.apiKey);
      await _secure.write(
        key: 'cloudPassword',
        value: settings.cloudPassword,
      );
      await _secure.write(
        key: 'cloudPrivateKey',
        value: settings.cloudPrivateKey,
      );
    } catch (_) {
      // Keep the rest of the settings usable if the keystore fails.
    }
  }

  Future<void> setMode(BackendMode mode) async {
    if (settings.mode == mode) return;
    settings.mode = mode;
    notifyListeners();
    await save();
  }

  void notify() => notifyListeners();

  Future<void> send(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty || busy) return;

    final reply = ChatMessage.assistant()..streaming = true;
    messages.add(ChatMessage.user(text));
    messages.add(reply);
    busy = true;
    lastStderr = null;
    notifyListeners();

    final backend = settings.mode == BackendMode.local
        ? LocalBackend(settings)
        : CloudBackend(settings);
    _backend = backend;
    final completion = Completer<void>();

    _subscription = backend
        .stream(prompt: text, sessionId: settings.sessionId)
        .listen(
          (event) => _apply(reply, event),
          onError: (Object error) {
            reply.error = _friendly(error);
            reply.streaming = false;
            busy = false;
            _backend = null;
            _subscription = null;
            notifyListeners();
            if (!completion.isCompleted) completion.complete();
          },
          onDone: () {
            reply.streaming = false;
            if (reply.error == null &&
                reply.tools.every((tool) => tool.done) &&
                reply.text.isEmpty &&
                lastStderr != null) {
              reply.error = lastStderr;
            }
            busy = false;
            _backend = null;
            _subscription = null;
            notifyListeners();
            if (!completion.isCompleted) completion.complete();
          },
          cancelOnError: false,
        );

    await completion.future;
    await save();
  }

  void _apply(ChatMessage reply, ClaudeEvent event) {
    switch (event.kind) {
      case 'init':
        if (event.sessionId != null && event.sessionId!.isNotEmpty) {
          settings.sessionId = event.sessionId;
        }
        break;
      case 'text':
        reply.text += event.text ?? '';
        break;
      case 'tool':
        final id = event.toolId;
        if (id != null && id.isNotEmpty) {
          reply.tools.add(
            ToolCard(
              id: id,
              name: event.toolName ?? '工具',
              input: event.toolInput ?? const {},
            ),
          );
        }
        break;
      case 'toolResult':
        final index =
            reply.tools.indexWhere((tool) => tool.id == event.toolId);
        if (index >= 0) {
          reply.tools[index].result = event.toolResult;
          reply.tools[index].isError = event.isError;
          reply.tools[index].done = true;
        }
        break;
      case 'result':
        reply.durationMs = event.durationMs;
        reply.costUsd = event.costUsd;
        if (event.isError && reply.error == null && event.text != null) {
          reply.error = event.text;
        }
        break;
      case 'stderr':
        lastStderr = event.text;
        break;
      case 'error':
        reply.error = event.text;
        break;
    }
    notifyListeners();
  }

  String _friendly(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('Connection refused') ||
        text.contains('Failed to connect')) {
      return '本地桥没有启动。请到“本地容器”里点“启动本地桥”。';
    }
    return text;
  }

  Future<void> stop() async {
    await _backend?.stop();
    await _subscription?.cancel();
    _subscription = null;
    _backend = null;
    if (messages.isNotEmpty && messages.last.streaming) {
      messages.last.streaming = false;
    }
    busy = false;
    notifyListeners();
  }

  Future<void> newSession() async {
    messages.clear();
    settings.localSessionId = null;
    settings.cloudSessionId = null;
    lastStderr = null;
    notifyListeners();
    await save();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _backend?.dispose();
    super.dispose();
  }
}
