import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../store.dart';
import 'settings_page.dart';
import 'widgets.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.maxScrollExtent - position.pixels < 260) {
        _scroll.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(AppStore store) async {
    final text = _input.text;
    if (text.trim().isEmpty || store.busy) return;
    _input.clear();
    final future = store.send(text);
    _jumpToEnd();
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final local = store.settings.mode == BackendMode.local;
    _jumpToEnd();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const BrandMark(size: 26, shadow: false),
            const SizedBox(width: 9),
            Text(
              local ? '本地容器' : '云端电脑',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            Pill(store.settings.permissionLabel, active: true),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '新对话',
            onPressed: store.busy
                ? null
                : () async {
                    await store.newSession();
                    _jumpToEnd();
                  },
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: store.messages.isEmpty
                ? const _EmptyChat()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                    itemCount: store.messages.length,
                    itemBuilder: (context, index) =>
                        _MessageView(message: store.messages[index]),
                  ),
          ),
          _Composer(
            controller: _input,
            busy: store.busy,
            onSend: () => _send(store),
            onStop: store.stop,
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 74),
            const SizedBox(height: 20),
            Text(
              '开始一段对话',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              '描述你想做的事。Claude Code 会读文件、改代码、跑命令。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (message.role == ChatRole.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 12, left: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(
            message.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    final hasBody = message.text.trim().isNotEmpty || message.tools.isNotEmpty;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 12, right: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasBody)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.text.trim().isNotEmpty)
                      Text(
                        message.text,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                        ),
                      ),
                    for (final tool in message.tools) ToolTile(tool: tool),
                  ],
                ),
              ),
            if (message.streaming && !hasBody)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    ),
                    const SizedBox(width: 9),
                    Text('正在思考…', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            if (message.error != null && message.error!.trim().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x14B4442F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x33B4442F)),
                ),
                child: Text(
                  message.error!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Color(0xFFB4442F),
                  ),
                ),
              ),
            if (!message.streaming &&
                (message.durationMs != null || message.costUsd != null))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  [
                    if (message.durationMs != null)
                      _formatDuration(message.durationMs!),
                    if (message.costUsd != null)
                      '\$${message.costUsd!.toStringAsFixed(3)}',
                  ].join('  ·  '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.42),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(int ms) {
    if (ms < 1000) return '${ms}ms';
    final seconds = (ms / 1000).round();
    if (seconds < 60) return '$seconds 秒';
    return '${seconds ~/ 60} 分 ${seconds % 60} 秒';
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '给 Claude 发消息…',
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 46,
              height: 46,
              child: busy
                  ? OutlinedButton(
                      onPressed: onStop,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(46, 46),
                        shape: const CircleBorder(),
                      ),
                      child: const Icon(Icons.stop_rounded, size: 20),
                    )
                  : FilledButton(
                      onPressed: onSend,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(46, 46),
                        shape: const CircleBorder(),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, size: 20),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
