import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/json_error.dart';
import '../generator/json_to_dart_generator.dart';
import '../settings_storage.dart';
import 'json_document.dart';

/// Aktif belge için türetilmiş çıktı (Dart kodu + JSON ayrıştırma sonucu).
class WorkspaceState extends Equatable {
  const WorkspaceState({
    this.documents = const [],
    this.openIds = const [],
    this.activeId,
    this.settings = const GeneratorSettings(),
    this.loaded = false,
    this.dartCode = '',
    this.genError,
    this.classCount = 0,
    this.parsed,
    this.jsonError,
    this.jsonErrorLine,
    this.parseRevision = 0,
  });

  final List<JsonDocument> documents;
  final List<String> openIds;
  final String? activeId;
  final GeneratorSettings settings;
  final bool loaded;

  // Aktif belge türevleri:
  final String dartCode;
  final String? genError;
  final int classCount;
  final dynamic parsed;
  final String? jsonError;
  final int? jsonErrorLine;
  final int parseRevision;

  JsonDocument? get activeDocument {
    for (final d in documents) {
      if (d.id == activeId) return d;
    }
    return null;
  }

  String get activeContent => activeDocument?.content ?? '';

  List<JsonDocument> get openDocuments {
    final byId = {for (final d in documents) d.id: d};
    return [
      for (final id in openIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// Kayıt listesi: en son değişen üstte.
  List<JsonDocument> get sortedDocuments {
    final list = [...documents];
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  WorkspaceState copyWith({
    List<JsonDocument>? documents,
    List<String>? openIds,
    Object? activeId = _sentinel,
    GeneratorSettings? settings,
    bool? loaded,
    String? dartCode,
    Object? genError = _sentinel,
    int? classCount,
    Object? parsed = _sentinel,
    Object? jsonError = _sentinel,
    Object? jsonErrorLine = _sentinel,
    int? parseRevision,
  }) {
    return WorkspaceState(
      documents: documents ?? this.documents,
      openIds: openIds ?? this.openIds,
      activeId: activeId == _sentinel ? this.activeId : activeId as String?,
      settings: settings ?? this.settings,
      loaded: loaded ?? this.loaded,
      dartCode: dartCode ?? this.dartCode,
      genError: genError == _sentinel ? this.genError : genError as String?,
      classCount: classCount ?? this.classCount,
      parsed: parsed == _sentinel ? this.parsed : parsed,
      jsonError: jsonError == _sentinel ? this.jsonError : jsonError as String?,
      jsonErrorLine: jsonErrorLine == _sentinel
          ? this.jsonErrorLine
          : jsonErrorLine as int?,
      parseRevision: parseRevision ?? this.parseRevision,
    );
  }

  static const _sentinel = Object();

  @override
  List<Object?> get props => [
    documents,
    openIds,
    activeId,
    settings,
    loaded,
    dartCode,
    genError,
    classCount,
    jsonError,
    jsonErrorLine,
    parseRevision,
  ];
}

class WorkspaceCubit extends Cubit<WorkspaceState> {
  WorkspaceCubit(this._storage) : super(const WorkspaceState()) {
    _init();
  }

  final SettingsStorage _storage;
  static const _generator = JsonToDartGenerator();

  Timer? _recomputeTimer;
  Timer? _persistTimer;
  int _idCounter = 0;

  Future<void> _init() async {
    final snap = await _storage.loadWorkspace();
    if (isClosed) return;

    var documents = snap.documents;
    var openIds = snap.openIds;
    var activeId = snap.activeId;

    if (documents.isEmpty) {
      final doc = _newDoc(title: 'Belge 1', content: '');
      documents = [doc];
      openIds = [doc.id];
      activeId = doc.id;
    } else {
      if (openIds.isEmpty) openIds = [documents.first.id];
      if (activeId == null || !documents.any((d) => d.id == activeId)) {
        activeId = openIds.first;
      }
    }

    final base = state.copyWith(
      documents: documents,
      openIds: openIds,
      activeId: activeId,
      settings: snap.settings,
      loaded: true,
    );
    emit(_withDerived(base, base.activeContent, immediate: true));
  }

  JsonDocument _newDoc({required String title, required String content}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'doc_${now}_${_idCounter++}';
    return JsonDocument(id: id, title: title, content: content, updatedAt: now);
  }

  /// Verilen id'ye ait belgenin içeriği; id null ya da bulunamazsa boş string.
  static String _contentFor(List<JsonDocument> docs, String? id) {
    if (id == null) return '';
    for (final d in docs) {
      if (d.id == id) return d.content;
    }
    return '';
  }

  /// Bir sekme kapatıldığında yeni aktif id: kapanan aktifse son açık sekme
  /// (yoksa null), değilse aktif değişmez.
  static String? _nextActiveAfterClose(
    List<String> openIds,
    String? active,
    String closedId,
  ) {
    if (active != closedId) return active;
    return openIds.isEmpty ? null : openIds.last;
  }

  // ------------------------------------------------------------- belge işlemleri

  void newDocument({String? content, String? title}) {
    final n = state.documents.length + 1;
    final doc = _newDoc(title: title ?? 'Belge $n', content: content ?? '');
    final documents = [...state.documents, doc];
    final openIds = [...state.openIds, doc.id];
    final next = state.copyWith(
      documents: documents,
      openIds: openIds,
      activeId: doc.id,
    );
    emit(_withDerived(next, doc.content, immediate: true));
    _schedulePersist();
  }

  void openDocument(String id) {
    if (!state.documents.any((d) => d.id == id)) return;
    final openIds = state.openIds.contains(id)
        ? state.openIds
        : [...state.openIds, id];
    final doc = state.documents.firstWhere((d) => d.id == id);
    final next = state.copyWith(openIds: openIds, activeId: id);
    emit(_withDerived(next, doc.content, immediate: true));
    _schedulePersist();
  }

  void closeTab(String id) {
    final openIds = [...state.openIds]..remove(id);
    final activeId = _nextActiveAfterClose(openIds, state.activeId, id);
    final next = state.copyWith(openIds: openIds, activeId: activeId);
    emit(
      _withDerived(
        next,
        _contentFor(state.documents, activeId),
        immediate: true,
      ),
    );
    _schedulePersist();
  }

  void deleteDocument(String id) {
    final documents = [...state.documents]..removeWhere((d) => d.id == id);
    final openIds = [...state.openIds]..remove(id);
    final activeId = _nextActiveAfterClose(openIds, state.activeId, id);
    final next = state.copyWith(
      documents: documents,
      openIds: openIds,
      activeId: activeId,
    );
    emit(_withDerived(next, _contentFor(documents, activeId), immediate: true));
    _schedulePersist();
  }

  void renameDocument(String id, String title) {
    final documents = [
      for (final d in state.documents)
        if (d.id == id)
          d.copyWith(title: title.trim().isEmpty ? d.title : title)
        else
          d,
    ];
    emit(state.copyWith(documents: documents));
    _schedulePersist();
  }

  // ------------------------------------------------------------- içerik & ayar

  /// Aktif belgenin içeriğini günceller.
  /// [immediate] false ise üretim 300 ms geciktirilir (yazarken performans).
  void setActiveContent(String text, {bool immediate = false}) {
    final activeId = state.activeId;
    if (activeId == null) {
      newDocument(content: text);
      return;
    }
    final documents = [
      for (final d in state.documents)
        if (d.id == activeId)
          d.copyWith(
            content: text,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          )
        else
          d,
    ];
    final next = state.copyWith(documents: documents);
    emit(_withDerived(next, text, immediate: immediate));
    _schedulePersist();
  }

  void updateSettings(GeneratorSettings settings) {
    _storage.saveSettings(settings);
    final next = state.copyWith(settings: settings);
    emit(_withDerived(next, next.activeContent, immediate: true));
  }

  // --------------------------------------------------------------- biçimlendirme

  String? prettify(String text) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
    } catch (_) {
      return null;
    }
  }

  String? minify(String text) {
    try {
      return jsonEncode(jsonDecode(text));
    } catch (_) {
      return null;
    }
  }

  // --------------------------------------------------------------- türetme

  /// Aktif içerikten Dart kodu + JSON ağacı türetir. [immediate] false ise
  /// yalnızca içerik state'e yazılır, üretim zamanlayıcıyla ertelenir.
  WorkspaceState _withDerived(
    WorkspaceState base,
    String content, {
    required bool immediate,
  }) {
    _recomputeTimer?.cancel();
    if (!immediate) {
      _recomputeTimer = Timer(const Duration(milliseconds: 300), () {
        if (isClosed) return;
        emit(_computeDerived(state, state.activeContent));
      });
      return base;
    }
    return _computeDerived(base, content);
  }

  WorkspaceState _computeDerived(WorkspaceState base, String content) {
    // Boş belge: hata gösterme, boş çıktı ver.
    if (content.trim().isEmpty) {
      return base.copyWith(
        dartCode: '',
        genError: null,
        classCount: 0,
        parsed: null,
        jsonError: null,
        jsonErrorLine: null,
        parseRevision: base.parseRevision + 1,
      );
    }

    final parse = _parseJson(content, base); // görüntüleyici için
    final result = _generator.generate(content, base.settings); // dönüştürücü

    return base.copyWith(
      dartCode: result.isSuccess ? result.code : '',
      genError: result.isSuccess ? null : result.error,
      classCount: result.classCount,
      parsed: parse.parsed,
      jsonError: parse.error,
      jsonErrorLine: parse.line,
      parseRevision: parse.revision,
    );
  }

  /// JSON'u ayrıştırır; parseRevision artırım kuralı tek yerde toplanır.
  /// Başarısızsa eski ağaç korunur ve hata satırı döndürülür.
  ({dynamic parsed, String? error, int? line, int revision}) _parseJson(
    String content,
    WorkspaceState base,
  ) {
    try {
      return (
        parsed: jsonDecode(content),
        error: null,
        line: null,
        revision: base.parseRevision + 1,
      );
    } on FormatException catch (e) {
      return (
        parsed: base.parsed, // eski ağacı koru
        error: describeJsonError(e, content),
        line: jsonErrorLineOf(e, content),
        revision: base.parseRevision,
      );
    }
  }

  void _persistNow() => _storage.saveWorkspace(
    documents: state.documents,
    openIds: state.openIds,
    activeId: state.activeId,
  );

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 500), _persistNow);
  }

  @override
  Future<void> close() {
    _recomputeTimer?.cancel();
    _persistTimer?.cancel();
    _persistNow(); // kapanışta son durumu hemen kaydet
    return super.close();
  }
}
