import 'package:flutter/material.dart';


/// Satırı sola kaydırarak silme.
///
/// **Onay sorulmaz.** Projedeki standart: silme doğrudan uygulanır, geri alma
/// alttaki "Geri al" ile verilir. İki adımlık onay, tek adımlık geri almadan
/// daha zahmetliydi. Geri almayı sağlamak çağıranın sorumluluğu.
class SwipeToDelete extends StatelessWidget {
  final Key itemKey;
  final Widget child;
  final VoidCallback onDelete;

  const SwipeToDelete({
    super.key,
    required this.itemKey,
    required this.child,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return Dismissible(
      key: itemKey,
      direction: DismissDirection.endToStart,
      background: Container(
        color: errorColor.withValues(alpha: 0.2),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline_rounded, color: errorColor),
      ),
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }
}
