import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/context_ext.dart';
import 'workspace_cubit.dart';

/// Aktif belge üzerinde çalışan editör sayfalarının (Dönüştür / Görüntüle)
/// paylaştığı ortak davranış: cubit erişimi, panodan yapıştırma, biçimlendirme
/// ve içeriği controller ile senkron tutan listener.
mixin ActiveDocumentEditor<T extends StatefulWidget> on State<T> {
  /// Bu sayfanın metin editörü controller'ı.
  TextEditingController get editorController;

  WorkspaceCubit get cubit => context.read<WorkspaceCubit>();

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
          editorController.text = state.activeContent;
        }
        onSwitch?.call();
      },
    );
  }
}
