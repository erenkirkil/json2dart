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
}
