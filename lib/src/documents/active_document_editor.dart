import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/context_ext.dart';
import '../common/text_offset.dart';
import 'workspace_cubit.dart';

/// Uygulama-seviyesi geri al/ileri al kısayolunun (bkz. AppShell) hedef aldığı
/// belge editörünü işaretler: odak bu kapsamın altındaki bir metin alanındayken
/// Cmd/Ctrl+Z belge geçmişine gider; kapsam dışındaki metin alanları (arama,
/// değiştir, ayarlar) kendi yerleşik geri-al davranışını korur.
class DocumentEditorScope extends InheritedWidget {
  const DocumentEditorScope({super.key, required super.child});

  @override
  bool updateShouldNotify(DocumentEditorScope oldWidget) => false;
}

/// Aktif belge üzerinde çalışan editör sayfalarının (Dönüştür / Görüntüle)
/// paylaştığı ortak davranış: cubit erişimi, panodan yapıştırma, biçimlendirme
/// ve içeriği controller ile senkron tutan listener.
mixin ActiveDocumentEditor<T extends StatefulWidget> on State<T> {
  /// Bu sayfanın metin editörü controller'ı.
  TextEditingController get editorController;

  WorkspaceCubit get cubit => context.read<WorkspaceCubit>();

  /// Son senkronlanan belge kimliği: sekme değişimini, aynı belgedeki dış
  /// kaynaklı içerik değişiminden (geri al, biçimlendir, tümünü değiştir)
  /// ayırmak için tutulur — imleç yalnızca ikincisinde korunur.
  String? _lastSyncedId;

  /// initState'te çağrılır: editörü aktif belgeyle doldurur ve senkron
  /// takibini başlatır.
  void initEditorContent() {
    editorController.text = cubit.state.activeContent;
    _lastSyncedId = cubit.state.activeId;
  }

  Future<void> pasteIntoActive() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    cubit.setActiveContent(text, immediate: true);
  }

  void formatActive() {
    final pretty = cubit.prettify(editorController.text);
    if (pretty == null) {
      context.showSnack('Biçimlendirilemedi: geçerli bir JSON değil.');
      return;
    }
    cubit.setActiveContent(pretty, immediate: true);
  }

  /// Aktif belge/içerik dışarıdan değişince (sekme geçişi, biçimlendirme,
  /// örnek yükleme) controller'ı senkronlar. [onSwitch] ek temizlik için.
  BlocListener<WorkspaceCubit, WorkspaceState> contentSyncListener({
    VoidCallback? onSwitch,
  }) {
    return BlocListener<WorkspaceCubit, WorkspaceState>(
      listenWhen: (p, c) =>
          p.activeId != c.activeId ||
          (p.activeContent != c.activeContent &&
              c.activeContent != editorController.text),
      listener: (context, state) {
        if (editorController.text != state.activeContent) {
          // `controller.text` setter'ı seçimi geçersiz (-1) bırakır; alan
          // odaklıysa Flutter imleci metnin SONUNA taşır (EditableTextState
          // ._didChangeTextEditingValue). Klavyeyle geri al tam bu yoldan
          // geçtiği için imleç, aynı belgedeki dış kaynaklı değişimde korunur.
          final selection = editorController.selection;
          final switched = _lastSyncedId != state.activeId;
          if (switched || !selection.isValid) {
            // Sekme geçişi ya da hiç imleç yoksa eski davranış: seçimi
            // geçersiz bırak, konumu Flutter odaklanınca kendisi belirlesin.
            editorController.text = state.activeContent;
          } else {
            // Aralığa sığmak yetmez; offset bir vekil çiftinin ortasına
            // düşerse sonraki tuş vuruşu eşsiz vekil üretip metni bozar.
            final offset = codePointBoundary(
              state.activeContent,
              selection.baseOffset.clamp(0, state.activeContent.length),
            );
            editorController.value = TextEditingValue(
              text: state.activeContent,
              selection: TextSelection.collapsed(offset: offset),
            );
          }
        }
        _lastSyncedId = state.activeId;
        onSwitch?.call();
      },
    );
  }
}
