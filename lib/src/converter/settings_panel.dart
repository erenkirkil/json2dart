import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/context_ext.dart';
import '../common/widgets.dart';
import '../documents/workspace_cubit.dart';
import '../generator/json_to_dart_generator.dart';

/// Üretim ayarları paneli.
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key});

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late final TextEditingController _rootNameController;
  late final TextEditingController _partNameController;
  late final TextEditingController _targetController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<WorkspaceCubit>().state.settings;
    _rootNameController = TextEditingController(text: settings.rootClassName);
    _partNameController = TextEditingController(text: settings.partName);
    _targetController = TextEditingController(text: settings.targetPath);
  }

  @override
  void dispose() {
    _rootNameController.dispose();
    _partNameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _update(GeneratorSettings settings) {
    context.read<WorkspaceCubit>().updateSettings(settings);
  }

  /// Controller'ı yalnızca gerçekten farklıysa senkronlar (imleç korunur).
  void _syncField(TextEditingController c, String value) {
    if (c.text != value) c.text = value;
  }

  String _nullabilityHint(NullabilityMode m) => switch (m) {
    NullabilityMode.smart =>
      'Değeri null görülen alanlar nullable, '
          'diğerleri required olur. Null safety her zaman açıktır.',
    NullabilityMode.nonNullable =>
      'Dikkat: JSON\'da null gelen alanlarda '
          'çalışma zamanı hatası olabilir.',
    NullabilityMode.allNullable =>
      'Tüm alanlar opsiyonel olur; required üretilmez.',
  };

  @override
  Widget build(BuildContext context) {
    bool settingsChanged(WorkspaceState p, WorkspaceState c) =>
        p.settings != c.settings;
    return BlocConsumer<WorkspaceCubit, WorkspaceState>(
      listenWhen: settingsChanged,
      listener: (context, state) {
        _syncField(_rootNameController, state.settings.rootClassName);
        _syncField(_partNameController, state.settings.partName);
        _syncField(_targetController, state.settings.targetPath);
      },
      buildWhen: settingsChanged,
      builder: (context, state) {
        final s = state.settings;
        final isFreezed = s.style == SerializerStyle.freezed && !s.typesOnly;
        final needsCodegen = !s.typesOnly && s.style != SerializerStyle.manual;

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            ..._buildBasics(s),
            const Divider(height: 24),
            ..._buildSwitches(s, isFreezed),
            if (needsCodegen) ...[
              const Divider(height: 24),
              _CodegenSection(
                settings: s,
                targetController: _targetController,
                onTargetChanged: (v) =>
                    _update(s.copyWithSettings(targetPath: v)),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Kök sınıf adı + üretim tarzı/null durumu dropdown'ları + null notu.
  List<Widget> _buildBasics(GeneratorSettings s) {
    return [
      TextField(
        controller: _rootNameController,
        decoration: const InputDecoration(
          labelText: 'Kök sınıf adı',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        onChanged: (v) => _update(s.copyWithSettings(rootClassName: v)),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<SerializerStyle>(
        key: ValueKey('style-${s.style.name}'),
        initialValue: s.style,
        decoration: const InputDecoration(
          labelText: 'Üretim tarzı',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(
            value: SerializerStyle.jsonSerializable,
            child: Text('json_serializable'),
          ),
          DropdownMenuItem(
            value: SerializerStyle.freezed,
            child: Text('freezed'),
          ),
          DropdownMenuItem(
            value: SerializerStyle.manual,
            child: Text('Saf Dart (paket gerekmez)'),
          ),
        ],
        onChanged: s.typesOnly
            ? null
            : (v) {
                if (v != null) _update(s.copyWithSettings(style: v));
              },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<NullabilityMode>(
        key: ValueKey('null-${s.nullability.name}'),
        initialValue: s.nullability,
        decoration: const InputDecoration(
          labelText: 'Null durumu',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(
            value: NullabilityMode.smart,
            child: Text("Akıllı (JSON'dan çıkar)"),
          ),
          DropdownMenuItem(
            value: NullabilityMode.allNullable,
            child: Text('Hepsi nullable / opsiyonel'),
          ),
          DropdownMenuItem(
            value: NullabilityMode.nonNullable,
            child: Text('Hepsi non-null / required'),
          ),
        ],
        onChanged: (v) {
          if (v != null) _update(s.copyWithSettings(nullability: v));
        },
      ),
      const SizedBox(height: 4),
      _InfoNote(text: _nullabilityHint(s.nullability)),
    ];
  }

  /// Serileştirme + algılama aç/kapa anahtarları.
  List<Widget> _buildSwitches(GeneratorSettings s, bool isFreezed) {
    return [
      _SettingSwitch(
        title: 'Sadece tipler',
        subtitle: 'fromJson/toJson üretme',
        value: s.typesOnly,
        onChanged: (v) => _update(s.copyWithSettings(typesOnly: v)),
      ),
      _SettingSwitch(
        title: 'final alanlar',
        subtitle: 'Immutable model (bloc/cubit için önerilir)',
        value: s.finalFields,
        onChanged: (v) => _update(s.copyWithSettings(finalFields: v)),
      ),
      _SettingSwitch(
        title: 'copyWith üret',
        subtitle: isFreezed ? 'freezed zaten üretir' : null,
        value: isFreezed ? true : s.copyWith,
        onChanged: isFreezed
            ? null
            : (v) => _update(s.copyWithSettings(copyWith: v)),
      ),
      _SettingSwitch(
        title: 'Equatable',
        subtitle: isFreezed
            ? 'freezed kendi == üretir'
            : 'props ile değer eşitliği (bloc state için ideal)',
        value: isFreezed ? false : s.equatable,
        onChanged: isFreezed
            ? null
            : (v) => _update(s.copyWithSettings(equatable: v)),
      ),
      _SettingSwitch(
        title: 'fromRawJson / toRawJson',
        subtitle: 'String ↔ model kısayolları',
        value: s.effectiveRawJson,
        onChanged: (isFreezed || s.typesOnly)
            ? null
            : (v) => _update(s.copyWithSettings(rawJsonHelpers: v)),
      ),
      _SettingSwitch(
        title: 'fromMap/toMap adları',
        subtitle: 'fromJson/toJson yerine (yalnızca Saf Dart)',
        value: s.effectiveMapNames,
        onChanged: (s.style != SerializerStyle.manual || s.typesOnly)
            ? null
            : (v) => _update(s.copyWithSettings(useMapMethodNames: v)),
      ),
      const Divider(height: 24),
      _SettingSwitch(
        title: 'Tarihleri algıla',
        subtitle: 'ISO-8601 string -> DateTime',
        value: s.detectDates,
        onChanged: (v) => _update(s.copyWithSettings(detectDates: v)),
      ),
      _SettingSwitch(
        title: "Map'leri algıla",
        subtitle: '{"1": ...} -> Map<String, T>',
        value: s.detectMaps,
        onChanged: (v) => _update(s.copyWithSettings(detectMaps: v)),
      ),
      _SettingSwitch(
        title: 'Benzer sınıfları birleştir',
        subtitle: 'Aynı alanlara sahip nesneler tek sınıf olur',
        value: s.mergeSimilarClasses,
        onChanged: (v) => _update(s.copyWithSettings(mergeSimilarClasses: v)),
      ),
      _SettingSwitch(
        title: 'Hive anotasyonları',
        subtitle: '@HiveType / @HiveField',
        value: s.effectiveHive,
        onChanged: (isFreezed || s.typesOnly)
            ? null
            : (v) => _update(s.copyWithSettings(hiveAnnotations: v)),
      ),
    ];
  }
}

/// build_runner komutu + hedef dosya yolu bölümü.
class _CodegenSection extends StatelessWidget {
  const _CodegenSection({
    required this.settings,
    required this.targetController,
    required this.onTargetChanged,
  });

  final GeneratorSettings settings;
  final TextEditingController targetController;
  final ValueChanged<String> onTargetChanged;

  String _partHint(GeneratorSettings s) {
    final base = s.partName.trim().isEmpty
        ? s.targetBaseName
        : s.partName.trim();
    final clean = base
        .replaceAll('.freezed.dart', '')
        .replaceAll('.g.dart', '')
        .replaceAll('.dart', '');
    final parts = s.isFreezed
        ? "part '$clean.freezed.dart'; part '$clean.g.dart';"
        : "part '$clean.g.dart';";
    return '$parts (bu yola göre üretilir)';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kod üretimi (build_runner)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: targetController,
          decoration: const InputDecoration(
            labelText: 'Modelin yapıştırılacağı dosya yolu',
            hintText: 'lib/data/models/user_model.dart',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(fontSize: 12.5),
          onChanged: onTargetChanged,
        ),
        const SizedBox(height: 4),
        _InfoNote(text: _partHint(settings)),
        const SizedBox(height: 10),
        // 1) Yalnızca bu modeli üreten filtreli komut.
        _CommandBox(
          label: 'Sadece bu modeli üretir',
          command: settings.buildRunnerCommand,
        ),
        const SizedBox(height: 4),
        _InfoNote(
          text:
              '--build-filter yalnızca bu dosyanın çıktısını üretir; diğer '
              'klasörlerdeki önceden üretilmiş .g.dart dosyaları ne silinir '
              'ne de yeniden üretilir.',
        ),
        const SizedBox(height: 12),
        // 2) Tüm projeyi yeniden üreten filtresiz tam build komutu.
        _CommandBox(
          label: 'Tüm projeyi yeniden üretir',
          command: settings.buildRunnerFullCommand,
        ),
        const SizedBox(height: 4),
        _InfoNote(
          text:
              'Filtre yok: projedeki tüm üretilmiş dosyalar tazelenir. '
              '--delete-conflicting-outputs çakışan/öksüz çıktıları temizler; '
              'elle yazılan kaynak kodu etkilenmez.',
        ),
      ],
    );
  }
}

/// Kopyalanabilir tek bir terminal komutu kutusu.
class _CommandBox extends StatelessWidget {
  const _CommandBox({required this.label, required this.command});

  final String label;
  final String command;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terminal, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Komutu kopyala',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: command));
                  context.showSnack('build_runner komutu panoya kopyalandı.');
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            command,
            style: codeTextStyle.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 13.5)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 11.5)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
