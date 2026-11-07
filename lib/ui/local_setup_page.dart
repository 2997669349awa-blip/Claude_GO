import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../native.dart';
import 'chat_page.dart';
import 'widgets.dart';

class LocalSetupPage extends StatefulWidget {
  const LocalSetupPage({super.key});

  @override
  State<LocalSetupPage> createState() => _LocalSetupPageState();
}

class _LocalSetupPageState extends State<LocalSetupPage> {
  Map<String, dynamic> _status = const {};
  Timer? _poll;

  bool get _installed => _status['installed'] == true;
  bool get _claude => _status['claudeInstalled'] == true;
  bool get _running => _status['bridgeRunning'] == true;
  String get _phase => (_status['phase'] as String?) ?? 'idle';
  int get _progress => (_status['progress'] as num?)?.toInt() ?? -1;
  String get _log => (_status['log'] as String?) ?? '';
  bool get _extracting => _phase == 'extracting';
  bool get _installingClaude => _phase == 'installing-claude';

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final status = await Native.runtimeStatus();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // The channel is not ready yet; the next tick tries again.
    }
  }

  Future<void> _installRuntime() async {
    await Native.installRuntime();
    await _refresh();
  }

  Future<void> _installClaude() async {
    await Native.installClaudeCode();
    await _refresh();
  }

  Future<void> _startBridge() async {
    final store = StoreScope.of(context);
    await Native.startBridge(store.settings.localToken);
    await _refresh();
  }

  Future<void> _stopBridge() async {
    await Native.stopBridge();
    await _refresh();
  }

  Future<void> _enterChat() async {
    final store = StoreScope.of(context);
    await store.setMode(BackendMode.local);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatPage()),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final settings = store.settings;
    final logTail = _log.trim().split('\n');
    final shownLog = logTail.length <= 24
        ? _log
        : logTail.sublist(logTail.length - 24).join('\n');

    return Scaffold(
      appBar: AppBar(
        title: const Text('本地容器'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        children: [
          Text('容器里跑 Claude Code。', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            '本地模式在 App 内置的 Ubuntu 容器里运行 Claude Code，不再依赖 Termux。'
            '发一条消息会送进容器里的 Claude Code，输出实时传回这个界面。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 24),
          _StatusPanel(
            installed: _installed,
            claude: _claude,
            running: _running,
          ),
          if (_extracting) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _progress < 0 ? null : _progress / 100,
                minHeight: 7,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _progress < 0 ? '正在解压…' : '正在解压容器 $_progress%',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_installingClaude) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(minHeight: 7),
            const SizedBox(height: 6),
            Text('正在容器内安装 Claude Code…', style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 18),
          if (!_installed)
            FilledButton.icon(
              onPressed: _extracting ? null : _installRuntime,
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: Text(_extracting ? '正在安装容器…' : '安装容器'),
            )
          else if (!_claude)
            FilledButton.icon(
              onPressed: _installingClaude ? null : _installClaude,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(
                _installingClaude ? '正在安装 Claude Code…' : '安装 Claude Code',
              ),
            )
          else if (!_running)
            FilledButton.icon(
              onPressed: _phase == 'starting-bridge' ? null : _startBridge,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('启动本地桥'),
            )
          else
            FilledButton.icon(
              onPressed: _enterChat,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('进入对话'),
            ),
          if (_running) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _stopBridge,
              icon: const Icon(Icons.stop_rounded, size: 18),
              label: const Text('停止本地桥'),
            ),
          ],
          const SizedBox(height: 26),
          const SectionLabel('运行方式'),
          const SizedBox(height: 10),
          _Note(
            index: '1',
            text: '安装容器：把内置的 Ubuntu + Node 运行时解压到 App 私有目录，'
                '首次约 800 MB，需要约 1 GB 空闲空间。',
          ),
          _Note(
            index: '2',
            text: '安装 Claude Code：在容器内执行 npm 安装，需要网络。'
                '安装完成后容器里就有 claude 命令。',
          ),
          _Note(
            index: '3',
            text: '启动本地桥：在容器内监听 127.0.0.1:8787。'
                '之后每条消息都会通过它送进容器里的 Claude Code。',
          ),
          const SizedBox(height: 22),
          const SectionLabel('工作区'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: SelectableText(
              settings.localWorkspace,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            settings.externalStorage
                ? '外部存储只影响工作区；容器本身固定在 App 私有存储，'
                      '以保证 proot 的权限和性能。'
                : '容器和工作区都在 App 私有存储；卸载 App 会一起删除。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 22),
          const SectionLabel('运行日志'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 74, maxHeight: 240),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(
                shownLog.trim().isEmpty ? '等待操作…' : shownLog,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            '容器通过 proot 运行，不会获得 root 权限，也不会修改系统分区。'
            '建议在设置里开启后台保护；系统清理 App 时容器进程也会停止。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.installed,
    required this.claude,
    required this.running,
  });

  final bool installed;
  final bool claude;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          _StatusRow(
            label: 'Linux 容器',
            value: installed ? '已安装' : '未安装',
            ok: installed,
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          _StatusRow(
            label: 'Claude Code',
            value: claude ? '已安装' : '未安装',
            ok: claude,
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          _StatusRow(
            label: '本地桥',
            value: running ? '运行中' : '未运行',
            ok: running,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok
                  ? const Color(0xFF4F8A5B)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: ok
                  ? const Color(0xFF4F8A5B)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.index, required this.text});

  final String index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              index,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
