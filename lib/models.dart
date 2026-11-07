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
}

class ChatMessage {
  ChatMessage.user(this.text) : role = ChatRole.user;

  ChatMessage.assistant() : role = ChatRole.assistant, text = '';

  final ChatRole role;
  String text;
  final List<ToolCard> tools = [];
  bool streaming = false;
  String? error;
  int? durationMs;
  double? costUsd;
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
