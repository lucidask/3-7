import 'package:flutter/material.dart';

/// Actions possibles du bouton d'options globales (⋮)
enum GlobalOption {
  save,          // Sauvegarder la partie
  restartRound,  // Relancer la manche
  restartMatch,      // Ouvrir Paramètres
  quit,          // Quitter la partie
}

/// Bouton "options globales" de type Android (3 points ⋮), réutilisable.
/// - `options` permet de choisir la liste et l'ordre des items.
/// - `onSelected` remonte l'action choisie.
class GlobalOptionsButton extends StatelessWidget {
  final ValueChanged<GlobalOption>? onSelected;
  final List<GlobalOption> options;
  final Color? iconColor;
  final double? iconSize;

  const GlobalOptionsButton({
    super.key,
    this.onSelected,
    this.options = const [
      GlobalOption.save,
      GlobalOption.restartRound,
      GlobalOption.restartMatch,
      GlobalOption.quit,
    ],
    this.iconColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PopupMenuButton<GlobalOption>(
      tooltip: 'Options',
      onSelected: onSelected,
      icon: Icon(
        Icons.more_vert,
        color: iconColor ?? cs.onSurfaceVariant,
        size: iconSize ?? 24,
      ),
      itemBuilder: (ctx) => options.map((opt) {
        final data = _meta(opt, theme);
        return PopupMenuItem<GlobalOption>(
          value: opt,
          child: Row(
            children: [
              Icon(data.$1, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(data.$2, style: theme.textTheme.bodyMedium),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Map option -> (icon, label)
  (IconData, String) _meta(GlobalOption opt, ThemeData theme) {
    switch (opt) {
      case GlobalOption.save:
        return (Icons.save_outlined, 'Sauvegarder');
      case GlobalOption.restartRound:
        return (Icons.refresh_outlined, 'Relancer la manche');
      case GlobalOption.restartMatch:
        return (Icons.restart_alt, 'Recommencer le match');
      case GlobalOption.quit:
        return (Icons.exit_to_app, 'Quitter la partie');
    }
  }
}
