import 'package:flutter/material.dart';

import '../app.dart';
import '../backends.dart';
import '../models.dart';
import '../native.dart';
import '../termux_setup.dart';
import 'chat_page.dart';
import 'widgets.dart';

class LocalSetupPage extends StatefulWidget {
  const LocalSetupPage({super.key});

  @override
  State<LocalSetupPage> createState() => _LocalSetupPageState();
}

class _LocalSetupPageState extends State<LocalSetupPage> {
  bool? _termux;
  bool? _permission;
  bool _bridge = false;
  bool _working = false;
  String _log = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final termux = await Native.termuxInstalled();
    final permission = await Native.hasTermuxPermission();
    final bridge = await LocalBackend.isRunning();
    if (!mounted) return;
    setState(() {
      _termux = termux;
      _permission = permission;
      _bridge = bridge;
    });
  }

  Future<bool> _waitForBridge({
    int attempts = 80,
    Duration interval = const Duration(seconds: 3),
  }) async {
    for (var i = 0; i < attempts; i++) {
      if (await LocalBackend.isRunning()) return true;
      await Future.delayed(interval);
      if (mounted) {
        setState(() => _log = '等待本地桥启动… ${i + 1}/$attempts');
      }
    }
    return false;
  }

  Future<void> _install() async {
    final store = StoreScope.of(context);
    setState(() {
      _working = true;
      _log = '正在向 Termux 下发安装命令。首次需要下载 Node 与 Claude Code，请保持 Termux 在前台。';
    });
    try {
      await Native.runTermux(
        buildSetupCommand(
          token: store.settings.localToken,
          workspace: store.settings.localWorkspace,
        ),
      );
      final ok = await _waitForBridge();
      if (!mounted) return;
      setState(() {
        _working = false;
        _bridge = ok;
        _log = ok
            ? '本地桥已启动，可以进入对话。'
            : '等待超时。请打开 Termux 查看 ~/.claude-go/bridge.log，并确认 Termux 设置里已开启 allow-external-apps。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _log = '下发失败：$error';
      });
    }
  }

  Future<void> _startOnly() async {
    final store = StoreScope.of(context);
    setState(() {
      _working = true;
      _log = '正在启动本地桥…';
    });
    try {
      await Native.runTermux(
        buildStartCommand(
          token: store.settings.localToken,
          workspace: store.settings.localWorkspace,
        ),
      );
      final ok = await _waitForBridge(attempts: 20);
      if (!mounted) return;
      setState(() {
        _working = false;
        _bridge = ok;
        _log = ok ? '本地桥已启动。' : '没有连上本地桥，请打开 Termux 检查 bridge.log。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _log = '启动失败：$error';
      });
    }
  }

  Future<void> _requestPermission() async {
    final granted = await Native.requestTermuxPermission();
    if (!mounted) return;
    setState(() => _permission = granted);
    if (!granted) {
      setState(() => _log = '权限未授予。请在系统设置里允许 Claude GO 调用 Termux。');
    }
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
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final settings = store.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('本地容器'),
        actions: [
          IconButton(
            tooltip: '刷新状态',
            onPressed: _working ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        children: [
          Text(
            '在手机里运行 Claude Code。',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            '本地模式使用 Termux 作为容器。首次安装会下载 Node 与 Claude Code，'
            '之后每次只需启动本地桥。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 24),
          _StatusPanel(
            termux: _termux,
            permission: _permission,
            bridge: _bridge,
          ),
          const SizedBox(height: 18),
          if (_termux == false)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton.tonalIcon(
                onPressed: () =>
                    Native.openUrl('https://f-droid.org/packages/com.termux/'),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('安装 Termux'),
              ),
            ),
          if (_permission == false)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                onPressed: _requestPermission,
                icon: const Icon(Icons.key_rounded, size: 18),
                label: const Text('授予 RUN_COMMAND 权限'),
              ),
            ),
          FilledButton.icon(
            onPressed: _working || _termux == false ? null : _install,
            icon: _working
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.rocket_launch_rounded, size: 18),
            label: Text(_working ? '处理中…' : '一键安装并启动'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _working || _termux == false ? null : _startOnly,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('仅启动本地桥'),
          ),
          if (_bridge) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _enterChat,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('进入对话'),
            ),
          ],
          const SizedBox(height: 26),
          const SectionLabel('第一次使用'),
          const SizedBox(height: 10),
          _Note(
            index: '1',
            text: '打开 Termux，长按空白处 → Settings → 勾选 Allow external apps。'
                '没有这一步，Claude GO 无法把你的安装命令送进去。',
          ),
          _Note(
            index: '2',
            text: '点“一键安装并启动”。安装脚本会执行 pkg update、安装 Node、'
                '运行 Claude Code 官方安装脚本，然后启动本地桥。',
          ),
          _Note(
            index: '3',
            text: '看到“本地桥已启动”后进入对话。日常只需点“仅启动本地桥”。',
          ),
          const SizedBox(height: 22),
          const SectionLabel('当前工作区'),
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
          if (settings.externalStorage) ...[
            const SizedBox(height: 8),
            Text(
              '外部存储在 Termux 里需要先通过 termux-setup-storage 授权；'
              '首次安装会弹出系统存储授权。',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_log.isNotEmpty) ...[
            const SizedBox(height: 22),
            const SectionLabel('运行日志'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                _log,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 26),
          Text(
            '本地模式依赖 Termux。若系统杀掉了 Termux，本地桥也会中断；'
            '可在设置里开启后台保护，并在系统里给 Termux 加锁。',
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
    required this.termux,
    required this.permission,
    required this.bridge,
  });

  final bool? termux;
  final bool? permission;
  final bool bridge;

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
            label: 'Termux',
            value: termux == null ? '检查中' : (termux! ? '已安装' : '未安装'),
            ok: termux == true,
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          _StatusRow(
            label: 'RUN_COMMAND 权限',
            value: permission == null
                ? '检查中'
                : (permission! ? '已授予' : '未授予'),
            ok: permission == true,
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          _StatusRow(
            label: '本地桥',
            value: bridge ? '运行中' : '未运行',
            ok: bridge,
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
