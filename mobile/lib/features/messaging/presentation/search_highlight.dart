import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Le fond d'une bulle trouvée par la recherche : il s'allume puis s'éteint
/// en fondu, le temps que l'œil retrouve le message dans le fil.
class SearchHighlight extends StatelessWidget {
  const SearchHighlight({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeOut,
    decoration: BoxDecoration(
      color: active
          ? AppColors.accentPrimary.withValues(alpha: 0.18)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}
