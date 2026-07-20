import 'package:flutter/material.dart';

extension SnackX on BuildContext {
  /// Uygulama genelinde tutarlı, yüzen (floating) kısa bir bildirim gösterir.
  void showSnack(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          width: 380,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// İçeriğin üzerine yazacak (geri döndürülmesi yalnızca "Geri Al"a bağlı
  /// olan) eylemler için onay ister. Kullanıcı onaylarsa true döner.
  Future<bool> confirm({
    required String title,
    required String message,
    String confirmLabel = 'Uygula',
    String cancelLabel = 'Vazgeç',
  }) async {
    final result = await showDialog<bool>(
      context: this,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
