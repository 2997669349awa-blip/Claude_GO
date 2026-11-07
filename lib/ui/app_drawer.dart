import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import 'cloud_setup_page.dart';
import 'local_setup_page.dart';
import 'settings_page.dart';
import 'widgets.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _open(BuildContext context, Widget page) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _delete(BuildContext context, String id) async {
    final store = StoreScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话？'),
        content: const Text('这段对话会从本机历史里移除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.deleteSession(id);
  }

  static String _when(DateTime time) {
    final now = DateTime.now();
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day) {
      return '$hour:$minute';
    }
    return '${time.month}/${time.day} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              child: Row(
                children: [
                  const BrandMark(size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Claude GO',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 23,
                          ),
                        ),
                        Text(
                          'CLAUDE CODE ON MOBILE',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: store.busy
                      ? null
                      : () async {
                          await store.newSession();
                          if (context.mounted) Navigator.pop(context);
                        },
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('新对话'),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '会话',
                    style: theme.textTheme.labelSmall,
                  ),
                  const Spacer(),
                  Text(
                    '${store.sessions.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: store.sessions.isEmpty
                  ? Center(
                      child: Text(
                        '还没有对话',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: store.sessions.length,
                      itemBuilder: (context, index) {
                        final session = store.sessions[index];
                        final selected = session.id == store.activeSessionId;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: ListTile(
                            selected: selected,
                            selectedTileColor: scheme.primary.withValues(
                              alpha: 0.09,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            title: Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              '${session.mode == BackendMode.local ? '本地' : '云端'}'
                              ' · ${_when(session.updatedAt)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: '更多',
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                size: 18,
                                color: scheme.onSurface.withValues(alpha: 0.4),
                              ),
                              onSelected: (value) {
                                if (value == 'delete') _delete(context, session.id);
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('删除'),
                                ),
                              ],
                            ),
                            onTap: () async {
                              await store.openSession(session.id);
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            ListTile(
              leading: Icon(
                Icons.terminal_rounded,
                size: 20,
                color: store.settings.mode == BackendMode.local
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.5),
              ),
              title: const Text('本地容器'),
              subtitle: const Text('内置 Ubuntu + Claude Code'),
              onTap: () => _open(context, const LocalSetupPage()),
            ),
            ListTile(
              leading: Icon(
                Icons.laptop_mac_rounded,
                size: 20,
                color: store.settings.mode == BackendMode.cloud
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.5),
              ),
              title: const Text('云端电脑'),
              subtitle: Text(
                store.settings.cloudHost.isEmpty
                    ? '未绑定'
                    : '${store.settings.cloudUser}@${store.settings.cloudHost}',
              ),
              onTap: () => _open(context, const CloudSetupPage()),
            ),
            ListTile(
              leading: const Icon(Icons.tune_rounded, size: 20),
              title: const Text('设置'),
              onTap: () => _open(context, const SettingsPage()),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
