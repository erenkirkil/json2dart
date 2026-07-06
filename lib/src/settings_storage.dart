import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'common/app_themes.dart';
import 'documents/json_document.dart';
import 'generator/generator_settings.dart';

/// Diskte tutulan tüm çalışma alanı: belgeler, açık sekmeler, aktif belge,
/// üretim ayarları ve tema. Tamamı yerel (shared_preferences) — internet yok.
class WorkspaceSnapshot {
  const WorkspaceSnapshot({
    required this.documents,
    required this.openIds,
    required this.activeId,
    required this.settings,
  });

  final List<JsonDocument> documents;
  final List<String> openIds;
  final String? activeId;
  final GeneratorSettings settings;
}

/// Ayar/belge/tema kalıcılığı (tamamen lokal).
class SettingsStorage {
  static const _settingsKey = 'generator_settings';
  static const _themeKey = 'app_theme';
  static const _docsKey = 'documents_v1';
  static const _openKey = 'open_ids_v1';
  static const _activeKey = 'active_id_v1';

  /// Okuma sarmalayıcısı: herhangi bir hata olursa [fallback] döner.
  Future<T> _read<T>(T fallback, T Function(SharedPreferences p) body) async {
    try {
      return body(await SharedPreferences.getInstance());
    } catch (_) {
      return fallback;
    }
  }

  /// Yazma sarmalayıcısı: hatalar sessizce yutulur (kalıcılık isteğe bağlı).
  Future<void> _write(Future<void> Function(SharedPreferences p) body) async {
    try {
      await body(await SharedPreferences.getInstance());
    } catch (_) {}
  }

  Future<GeneratorSettings> loadSettings() => _read(const GeneratorSettings(), (
    p,
  ) {
    final raw = p.getString(_settingsKey);
    return raw == null
        ? const GeneratorSettings()
        : GeneratorSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  Future<void> saveSettings(GeneratorSettings settings) =>
      _write((p) => p.setString(_settingsKey, jsonEncode(settings.toJson())));

  Future<AppTheme> loadTheme() => _read(
    AppTheme.system,
    (p) =>
        AppTheme.values.asNameMap()[p.getString(_themeKey)] ?? AppTheme.system,
  );

  Future<void> saveTheme(AppTheme theme) =>
      _write((p) => p.setString(_themeKey, theme.name));

  Future<WorkspaceSnapshot> loadWorkspace() async {
    final settings = await loadSettings();
    return _read(
      WorkspaceSnapshot(
        documents: const [],
        openIds: const [],
        activeId: null,
        settings: settings,
      ),
      (p) {
        final documents = <JsonDocument>[];
        for (final raw in p.getStringList(_docsKey) ?? const []) {
          try {
            documents.add(
              JsonDocument.fromJson(jsonDecode(raw) as Map<String, dynamic>),
            );
          } catch (_) {}
        }
        // openIds ve activeId'yi var olan belgelere göre normalize et; böylece
        // aktif belge her zaman ya açık bir sekmedir ya da null olur.
        final openIds = (p.getStringList(_openKey) ?? const [])
            .where((id) => documents.any((d) => d.id == id))
            .toList();
        final rawActiveId = p.getString(_activeKey);
        return WorkspaceSnapshot(
          documents: documents,
          openIds: openIds,
          activeId: openIds.contains(rawActiveId) ? rawActiveId : null,
          settings: settings,
        );
      },
    );
  }

  Future<void> saveWorkspace({
    required List<JsonDocument> documents,
    required List<String> openIds,
    required String? activeId,
  }) => _write((p) async {
    await p.setStringList(
      _docsKey,
      documents.map((d) => jsonEncode(d.toJson())).toList(),
    );
    await p.setStringList(_openKey, openIds);
    if (activeId == null) {
      await p.remove(_activeKey);
    } else {
      await p.setString(_activeKey, activeId);
    }
  });
}
