import 'package:flutter/material.dart';

/// Kod ve JSON görünümlerinde kullanılan eş aralıklı yazı stili.
const TextStyle codeTextStyle = TextStyle(
  fontFamily: 'Consolas',
  fontFamilyFallback: ['Menlo', 'Monaco', 'Courier New', 'monospace'],
  fontSize: 13,
  height: 1.45,
);

/// Başlık + araç çubuğu + içerik barındıran çerçeveli panel.
class PaneCard extends StatelessWidget {
  const PaneCard({
    super.key,
    required this.title,
    this.actions = const <Widget>[],
    required this.child,
  });

  final String title;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Material (Container yerine): içindeki ListTile/InkWell ink efektlerinin
    // yüzey rengi üzerine doğru çizilmesini sağlar.
    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: scheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                // Butonlar sığmazsa taşma yerine yatay kaydırılabilir olsun;
                // reverse:true, yer varken sağa yaslar, taşınca sağdan kaydırır.
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(children: actions),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Araç çubuklarındaki kompakt ikonlu buton.
class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: const TextStyle(fontSize: 12.5),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Hata mesajı bandı.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              message,
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
