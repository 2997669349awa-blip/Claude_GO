import 'dart:async';
import 'dart:convert';
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
  final List<ChatSession> sessions = [];
  String? activeSessionId;

  bool busy = false;
  String? lastStderr;

  ClaudeBackend? _backend;
  StreamSubscription<ClaudeEvent>? _subscription;

  ChatSession? get activeSession {
    for (final session in sessions) {
      if (session.id == activeSessionId) return session;
    }
    return null;
  }

  List<ChatMessage> get messages => activeSession?.messages ?? const [];

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
    settings.baseUrl = _prefs.getString('baseUrl') ?? settings.baseUrl;
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
    settings.showPet = _prefs.getBool('showPet') ?? true;
    settings.localWorkspace = settings.externalStorage
        ? '/storage/emulated/0/ClaudeGO'
        : (r'$HOME/ClaudeGO');
    settings.localToken = _prefs.getString('localToken') ?? _newToken();
    settings.cloudHost = _prefs.getString('cloudHost') ?? '';
    settings.cloudPort = _prefs.getInt('cloudPort') ?? 22;
    settings.cloudUser = _prefs.getString('cloudUser') ?? '';
    settings.cloudWorkspace = _prefs.getString('cloudWorkspace') ?? '~';
    settings.cloudClaudePath =
        _prefs.getString('cloudClaudePath') ?? 'claude';

    final rawSessions = _prefs.getString('sessions');
    if (rawSessions != null) {
      try {
        for (final item in jsonDecode(rawSessions) as List) {
          sessions.add(
            ChatSession.fromJson((item as Map).cast<String, dynamic>()),
          );
        }
      } catch (_) {
        // A broken history must not stop the app from opening.
      }
    }
    activeSessionId = _prefs.getString('activeSession');
    if (sessions.isEmpty) {
      final session = ChatSession(id: _newId(), mode: settings.mode);
      sessions.add(session);
      activeSessionId = session.id;
    } else if (!sessions.any((session) => session.id == activeSessionId)) {
      activeSessionId = sessions.first.id;
    }
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

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

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}';

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
    await _prefs.setBool('showPet', settings.showPet);
    await _prefs.setString('localToken', settings.localToken);
    await _prefs.setString('cloudHost', settings.cloudHost);
    await _prefs.setInt('cloudPort', settings.cloudPort);
    await _prefs.setString('cloudUser', settings.cloudUser);
    await _prefs.setString('cloudWorkspace', settings.cloudWorkspace);
    await _prefs.setString('cloudClaudePath', settings.cloudClaudePath);
    await _prefs.setString(
      'sessions',
      jsonEncode(sessions.map((session) => session.toJson()).toList()),
    );
    await _prefs.setString('activeSession', activeSessionId ?? '');
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
    final current = activeSession;
    settings.mode = mode;
    if (current == null || current.mode != mode) {
      final existing = sessions
          .where((session) => session.mode == mode)
          .toList();
      if (existing.isNotEmpty) {
        activeSessionId = existing.first.id;
      } else {
        final session = ChatSession(id: _newId(), mode: mode);
        sessions.insert(0, session);
        activeSessionId = session.id;
      }
    }
    notifyListeners();
    await save();
  }

  void notify() => notifyListeners();

  ChatSession _ensureSession() {
    final current = activeSession;
    if (current != null) return current;
    final session = ChatSession(id: _newId(), mode: settings.mode);
    sessions.insert(0, session);
    activeSessionId = session.id;
    return session;
  }

  Future<void> send(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty || busy) return;

    final session = _ensureSession();
    final reply = ChatMessage.assistant()..streaming = true;
    session.messages.add(ChatMessage.user(text));
    session.messages.add(reply);
    session.updatedAt = DateTime.now();
    if (session.title == '新对话') session.title = _titleFor(text);
    busy = true;
    lastStderr = null;
    notifyListeners();

    final backend = session.mode == BackendMode.local
        ? LocalBackend(settings)
        : CloudBackend(settings);
    _backend = backend;
    final completion = Completer<void>();

    _subscription = backend
        .stream(prompt: text, sessionId: session.sessionId)
        .listen(
          (event) => _apply(session, reply, event),
          onError: (Object error) {
            reply.error = _friendly(error);
            reply.streaming = false;
            session.updatedAt = DateTime.now();
            busy = false;
            _backend = null;
            _subscription = null;
            notifyListeners();
            if (!completion.isCompleted) completion.complete();
          },
          onDone: () {
            reply.streaming = false;
            reply.completedAt = DateTime.now();
            session.updatedAt = DateTime.now();
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
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await save();
  }

  void _apply(ChatSession session, ChatMessage reply, ClaudeEvent event) {
    switch (event.kind) {
      case 'init':
        if (event.sessionId != null && event.sessionId!.isNotEmpty) {
          session.sessionId = event.sessionId;
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

  String _titleFor(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.length <= 26 ? clean : '${clean.substring(0, 26)}…';
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
    final session = activeSession;
    if (session != null && session.messages.isNotEmpty) {
      session.messages.last.streaming = false;
    }
    busy = false;
    notifyListeners();
  }

  Future<void> newSession() async {
    if (busy) return;
    final session = ChatSession(id: _newId(), mode: settings.mode);
    sessions.insert(0, session);
    activeSessionId = session.id;
    lastStderr = null;
    notifyListeners();
    await save();
  }

  Future<void> openSession(String id) async {
    if (busy) return;
    for (final session in sessions) {
      if (session.id == id) {
        activeSessionId = id;
        settings.mode = session.mode;
        break;
      }
    }
    notifyListeners();
    await save();
  }

  Future<void> deleteSession(String id) async {
    if (busy) return;
    sessions.removeWhere((session) => session.id == id);
    if (activeSessionId == id) {
      if (sessions.isEmpty) {
        final session = ChatSession(id: _newId(), mode: settings.mode);
        sessions.add(session);
      }
      activeSessionId = sessions.first.id;
      settings.mode = sessions.first.mode;
    }
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
