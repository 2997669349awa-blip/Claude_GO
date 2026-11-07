import 'package:flutter/material.dart';

import 'store.dart';
import 'theme.dart';
import 'ui/chat_page.dart';
import 'ui/launch_splash.dart';

class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({
    super.key,
    required AppStore store,
    required super.child,
  }) : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'StoreScope is missing above this widget');
    return scope!.notifier!;
  }
}

class ClaudeGoApp extends StatelessWidget {
  const ClaudeGoApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Claude GO',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const LaunchSplash(child: ChatPage()),
      ),
    );
  }
}
