import 'dart:convert';

enum BackendMode { local, cloud }

enum ChatRole { user, assistant }

class ToolCard {
  ToolCard({required this.id, required this.name, required this.input});

  final String id;
  final String name;
  final Map<String, dynamic> input;
  String? result;
  bool isError = false;
  bool done = false;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'input': input,
    if (result != null) 'result': result,
    'isError': isError,
    'done': done,
  };

  factory ToolCard.fromJson(Map<String, dynamic> json) => ToolCard(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '工具',
    input: (json['input'] as Map?)?.cast<String, dynamic>() ?? const {},
  )
    ..result = json['result'] as String?
    ..isError = json['isError'] == true
    ..done = json['done'] == true;
}

class ChatMessage {
  ChatMessage.user(this.text) : role = ChatRole.user;

  ChatMessage.assistant() : role = ChatRole.assistant, text = '';

  final ChatRole role;
  String text;
  final List<ToolCard> tools = [];
  bool streaming = false;
  String? error;
  DateTime? completedAt;
  int? durationMs;
  double? costUsd;

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'text': text,
    'tools': tools.map((tool) => tool.toJson()).toList(),
    if (error != null) 'error': error,
    if (completedAt != null)
      'completedAt': completedAt!.millisecondsSinceEpoch,
    if (durationMs != null) 'durationMs': durationMs,
    if (costUsd != null) 'costUsd': costUsd,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final role = json['role'] == 'user' ? ChatRole.user : ChatRole.assistant;
    final message = role == ChatRole.user
        ? ChatMessage.user(json['text'] as String? ?? '')
        : ChatMessage.assistant();
    message.text = json['text'] as String? ?? '';
    for (final tool in (json['tools'] as List? ?? const [])) {
      message.tools.add(
        ToolCard.fromJson((tool as Map).cast<String, dynamic>()),
      );
    }
    message.error = json['error'] as String?;
    final completed = json['completedAt'];
    if (completed is num) {
      message.completedAt = DateTime.fromMillisecondsSinceEpoch(
        completed.toInt(),
      );
    }
    message.durationMs = (json['durationMs'] as num?)?.toInt();
    message.costUsd = (json['costUsd'] as num?)?.toDouble();
    return message;
  }
}

class ChatSession {
  ChatSession({
    required this.id,
    required this.mode,
    this.title = '新对话',
    this.sessionId,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
  }) : messages = messages ?? [],
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  BackendMode mode;
  String title;
  String? sessionId;
  final List<ChatMessage> messages;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'mode': mode.name,
    'title': title,
    if (sessionId != null) 'sessionId': sessionId,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'messages': messages.map((message) => message.toJson()).toList(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'] as String? ?? '',
    mode: json['mode'] == 'cloud' ? BackendMode.cloud : BackendMode.local,
    title: json['title'] as String? ?? '新对话',
    sessionId: json['sessionId'] as String?,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['updatedAt'] as num?)?.toInt() ?? 0,
    ),
    messages: [
      for (final message in (json['messages'] as List? ?? const []))
        ChatMessage.fromJson((message as Map).cast<String, dynamic>()),
    ],
  );
}

/// One normalized event from `claude --output-format stream-json`.
class ClaudeEvent {
  const ClaudeEvent(
    this.kind, {
    this.text,
    this.sessionId,
    this.toolId,
    this.toolName,
    this.toolInput,
    this.toolResult,
    this.isError = false,
    this.durationMs,
    this.costUsd,
  });

  /// init / text / tool / toolResult / result / error / stderr / done
  final String kind;
  final String? text;
  final String? sessionId;
  final String? toolId;
  final String? toolName;
  final Map<String, dynamic>? toolInput;
  final String? toolResult;
  final bool isError;
  final int? durationMs;
  final double? costUsd;
}

String stringifyToolContent(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is List) return value.map(stringifyToolContent).join('\n');
  if (value is Map) return const JsonEncoder.withIndent('  ').convert(value);
  return value.toString();
}

/// Parses one NDJSON line. Unknown lines and partial JSON are ignored.
List<ClaudeEvent> parseClaudeLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return const [];
  Map<String, dynamic> map;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) return const [];
    map = decoded.cast<String, dynamic>();
  } catch (_) {
    return const [];
  }

  switch (map['type']) {
    case 'system':
      if (map['subtype'] == 'init') {
        return [
          ClaudeEvent(
            'init',
            sessionId: map['session_id'] as String?,
          ),
        ];
      }
      return const [];

    case 'stream_event':
      final event = map['event'];
      if (event is Map) {
        if (event['type'] == 'content_block_delta') {
          final delta = event['delta'];
          if (delta is Map &&
              delta['type'] == 'text_delta' &&
              delta['text'] is String) {
            return [ClaudeEvent('text', text: delta['text'] as String)];
          }
        }
      }
      return const [];

    case 'assistant':
      final message = map['message'];
      final content = message is Map ? message['content'] : null;
      final events = <ClaudeEvent>[];
      if (content is List) {
        for (final block in content) {
          if (block is Map && block['type'] == 'tool_use') {
            events.add(
              ClaudeEvent(
                'tool',
                toolId: block['id'] as String?,
                toolName: block['name'] as String?,
                toolInput: (block['input'] as Map?)?.cast<String, dynamic>(),
              ),
            );
          }
        }
      }
      return events;

    case 'user':
      final message = map['message'];
      final content = message is Map ? message['content'] : null;
      final events = <ClaudeEvent>[];
      if (content is List) {
        for (final block in content) {
          if (block is Map && block['type'] == 'tool_result') {
            events.add(
              ClaudeEvent(
                'toolResult',
                toolId: block['tool_use_id'] as String?,
                toolResult: stringifyToolContent(block['content']),
                isError: block['is_error'] == true,
              ),
            );
          }
        }
      }
      return events;

    case 'result':
      return [
        ClaudeEvent(
          'result',
          isError: map['is_error'] == true,
          text: map['result'] as String?,
          durationMs: (map['duration_ms'] as num?)?.toInt(),
          costUsd: (map['total_cost_usd'] as num?)?.toDouble(),
        ),
      ];

    case 'claude_go_error':
      return [ClaudeEvent('error', text: map['message'] as String?)];
    case 'claude_go_stderr':
      return [ClaudeEvent('stderr', text: map['message'] as String?)];
    case 'claude_go_exit':
      return const [];
  }
  return const [];
}
