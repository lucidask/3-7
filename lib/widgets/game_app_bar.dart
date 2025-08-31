import 'package:flutter/material.dart';
import 'back_pill_button.dart';
import 'global_options_button.dart';

class GameAppBar extends StatelessWidget implements PreferredSizeWidget {
  // Back
  final bool showBack;
  final VoidCallback? onBack;
  final String? backLabel;  // null => icône seule
  final IconData backIcon;

  // Conseil
  final VoidCallback? onAdviceTap;

  // Options ⋮
  final ValueChanged<GlobalOption>? onOptionSelected;
  final List<GlobalOption>? options;

  const GameAppBar({
    super.key,
    this.showBack = true,
    this.onBack,
    this.backLabel,
    this.backIcon = Icons.arrow_back_rounded,
    this.onAdviceTap,
    this.onOptionSelected,
    this.options,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dividerColor = cs.outlineVariant.withOpacity(0.55);

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: cs.surface,
      surfaceTintColor: cs.surfaceTint,
      centerTitle: false,
      automaticallyImplyLeading: false, // back géré dans la capsule
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.60),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.60)),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              if (showBack) ...[
                BackPillButton(
                  embedded: true,         // ← rendu plat dans la capsule
                  icon: backIcon,
                  label: backLabel,       // laisse null pour icône seule
                ),
                _vDivider(dividerColor),
              ],
              const Expanded(child: SizedBox()), // pousse les actions à droite
              // Conseil
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onAdviceTap,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.tips_and_updates_outlined,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              _vDivider(dividerColor),
              // Options ⋮ (Android)
              GlobalOptionsButton(
                onSelected: onOptionSelected,
                options: options ??
                    const [
                      GlobalOption.save,
                      GlobalOption.restartRound,
                      GlobalOption.restartMatch,
                      GlobalOption.quit,
                    ],
                iconSize: 20,
                iconColor: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vDivider(Color color) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: color,
    );
  }
}
