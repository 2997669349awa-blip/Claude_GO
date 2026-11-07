import 'package:claude_go/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assistant text deltas and tool calls are parsed', () {
    final text = parseClaudeLine(
      '{"type":"stream_event","event":{"type":"content_block_delta",'
      '"delta":{"type":"text_delta","text":"hello"}}}',
    );
    expect(text.single.kind, 'text');
    expect(text.single.text, 'hello');

    final tool = parseClaudeLine(
      '{"type":"assistant","message":{"content":[{"type":"tool_use",'
      '"id":"t1","name":"Bash","input":{"command":"ls"}}]}}',
    );
    expect(tool.single.kind, 'tool');
    expect(tool.single.toolName, 'Bash');
  });

  test('init carries the session id', () {
    final events = parseClaudeLine(
      '{"type":"system","subtype":"init","session_id":"abc"}',
    );
    expect(events.single.kind, 'init');
    expect(events.single.sessionId, 'abc');
  });

  test('a session survives a JSON round trip', () {
    final session = ChatSession(id: 's1', mode: BackendMode.cloud, title: '测试');
    session.messages.add(ChatMessage.user('你好'));
    final reply = ChatMessage.assistant()
      ..text = '在'
      ..durationMs = 1200
      ..costUsd = 0.01;
    reply.tools.add(
      ToolCard(id: 't1', name: 'Bash', input: const {'command': 'ls'})
        ..result = 'a.txt'
        ..done = true,
    );
    session.messages.add(reply);

    final restored = ChatSession.fromJson(session.toJson());
    expect(restored.title, '测试');
    expect(restored.mode, BackendMode.cloud);
    expect(restored.messages.length, 2);
    expect(restored.messages.last.tools.single.name, 'Bash');
    expect(restored.messages.last.tools.single.result, 'a.txt');
  });
}
