import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'src/common/app_themes.dart';
import 'src/converter/converter_page.dart';
import 'src/documents/documents_panel.dart';
import 'src/documents/tab_bar_strip.dart';
import 'src/documents/workspace_cubit.dart';
import 'src/settings_storage.dart';
import 'src/viewer/viewer_page.dart';

class Json2DartApp extends StatefulWidget {
  const Json2DartApp({super.key});

  @override
  State<Json2DartApp> createState() => _Json2DartAppState();
}

class _Json2DartAppState extends State<Json2DartApp> {
  final SettingsStorage _storage = SettingsStorage();
  AppTheme _theme = AppTheme.system;

  @override
  void initState() {
    super.initState();
    _storage.loadTheme().then((t) {
      if (mounted) setState(() => _theme = t);
    });
  }

  void _setTheme(AppTheme t) {
    setState(() => _theme = t);
    _storage.saveTheme(t);
  }

  @override
  Widget build(BuildContext context) {
    final (lightTheme, darkTheme, mode) = AppThemes.resolve(_theme);
    return BlocProvider(
      create: (_) => WorkspaceCubit(_storage),
      child: MaterialApp(
        title: 'JSON2Dart Studio',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: mode,
        home: AppShell(theme: _theme, onThemeChanged: _setTheme),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.theme,
    required this.onThemeChanged,
  });

  final AppTheme theme;
  final ValueChanged<AppTheme> onThemeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tabIndex = 0;
  bool _showDocs = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) => setState(() => _tabIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: Column(
              children: [
                const SizedBox(height: 8),
                const Icon(Icons.data_object, size: 26),
                const SizedBox(height: 8),
                IconButton(
                  tooltip: _showDocs ? 'Kayıtları gizle' : 'Kayıtları göster',
                  isSelected: _showDocs,
                  icon: const Icon(Icons.folder_outlined),
                  selectedIcon: const Icon(Icons.folder),
                  onPressed: () => setState(() => _showDocs = !_showDocs),
                ),
              ],
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PopupMenuButton<AppTheme>(
                    tooltip: 'Tema: ${widget.theme.label}',
                    icon: Icon(widget.theme.icon),
                    onSelected: widget.onThemeChanged,
                    itemBuilder: (context) => [
                      for (final t in AppTheme.values)
                        PopupMenuItem(
                          value: t,
                          child: Row(
                            children: [
                              Icon(t.icon, size: 18),
                              const SizedBox(width: 10),
                              Text(t.label),
                              if (t == widget.theme) ...[
                                const Spacer(),
                                const Icon(Icons.check, size: 16),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.swap_horiz),
                label: Text('Dönüştür'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_tree_outlined),
                label: Text('Görüntüle'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          if (_showDocs) ...[
            SizedBox(
              width: 230,
              child: DocumentsPanel(
                onOpen: () {
                  // Kayıttan açınca içerik korunur; sekme zaten mevcutsa öne alır.
                },
              ),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: scheme.surfaceContainerLow,
                  child: const TabBarStrip(),
                ),
                const Divider(height: 1),
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      ConverterPage(
                        onOpenInViewer: () => setState(() => _tabIndex = 1),
                      ),
                      ViewerPage(
                        onConvert: () => setState(() => _tabIndex = 0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
