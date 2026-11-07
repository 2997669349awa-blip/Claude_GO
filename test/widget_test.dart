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
}
