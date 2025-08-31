import 'package:flutter/material.dart';
import '../models/card_model.dart';
import 'mini_card_widget.dart';

/// Style visuel de la pile.
enum PileVisual { fan, diagonal }

/// Pile de cartes générique:
/// - "fan": petit éventail (idéal pour pile gagnée)
/// - "diagonal": pile décalée (idéal pour pioche)
/// Affiche un badge quantité (optionnel). AUCUN label en dessous.
class Pile extends StatelessWidget {
  /// Liste de cartes (pile gagnée). Si null, on se base sur [count] (pioche).
  final List<CardModel>? cards;

  /// Compteur total quand on n’a pas de liste (ex: deck.length).
  final int? count;

  /// Visuel: éventail ou pile diagonale.
  final PileVisual visual;

  /// Afficher le badge quantité en haut/droite.
  final bool showBadge;

  /// Nombre d’éléments visibles dans le rendu (le badge = total réel).
  final int showTop;

  /// Échelle appliquée à la MiniCard (base 46x64).
  final double scale;

  /// Chevauchement horizontal/vertical (diagonal) ou horizontal (fan).
  final double overlapX;
  final double overlapY;

  /// Pas de rotation (en degrés) entre cartes de l’éventail (fan).
  final double rotationStepDeg;

  /// Action au tap (optionnel).
  final VoidCallback? onTap;

  /// Carte factice (avec id) pour dessiner le dos quand on n’a que count.
  final CardModel? backStub;

  /// Dimensions base de MiniCardWidget (doivent matcher le widget).
  static const double _baseW = 46.0;
  static const double _baseH = 64.0;

  const Pile({
    super.key,
    this.cards,
    this.count,
    this.visual = PileVisual.fan,
    this.showBadge = true,
    this.showTop = 3,
    this.scale = 40 / 46, // ~40x56
    this.overlapX = 8,    // fan: spacing horizontal entre cartes
    this.overlapY = 3,    // diagonal: spacing vertical
    this.rotationStepDeg = 3,
    this.onTap,
    this.backStub,
  }) : assert(cards != null || count != null,
  'Pile: fournir soit `cards`, soit `count`.');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final int total = cards != null ? cards!.length : (count ?? 0);
    final int n = total <= 0 ? 0 : (total < showTop ? total : showTop);

    final double cardW = _baseW * scale;
    final double cardH = _baseH * scale;

    final Size stackSize = switch (visual) {
      PileVisual.fan => Size(
        cardW + (n > 0 ? (n - 1) * overlapX : 0),
        cardH,
      ),
      PileVisual.diagonal => Size(
        cardW + (n > 0 ? (n - 1) * overlapX : 0),
        cardH + (n > 0 ? (n - 1) * overlapY : 0),
      ),
    };

    // Stub par défaut si rien passé
    final CardModel stub = backStub ?? const CardModel(
      id: '_pileBack',
      suit: Suit.clubs,
      rank: Rank.seven,
    );

    Widget stack;
    if (n == 0) {
      stack = _emptyPlaceholder(cardW, cardH, theme);
    } else {
      final children = <Widget>[];

      if (cards != null) {
        // On affiche les showTop dernières cartes de la pile gagnée.
        final visible = cards!
            .reversed
            .take(showTop)
            .toList()
            .reversed
            .toList();

        for (int i = 0; i < visible.length; i++) {
          final card = visible[i];
          final pos = _positionFor(i);
          final angle = visual == PileVisual.fan ? _angleFor(i, visible.length) : 0.0;
          children.add(
            Positioned(
              left: pos.dx,
              top: pos.dy,
              child: Transform.rotate(
                angle: angle,
                child: SizedBox(
                  width: cardW,
                  height: cardH,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topLeft,
                    child: MiniCardWidget(
                      card,
                      faceDown: true, // Pile gagnée: dos uniquement
                      dimmed: false,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      } else {
        // count-only (ex: pioche) => on dessine n dos
        for (int i = 0; i < n; i++) {
          final pos = _positionFor(i);
          children.add(
            Positioned(
              left: pos.dx,
              top: pos.dy,
              child: SizedBox(
                width: cardW,
                height: cardH,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: MiniCardWidget(
                    stub, // variable non-const avec id
                    faceDown: true,
                    dimmed: false,
                  ),
                ),
              ),
            ),
          );
        }
      }

      stack = SizedBox(
        width: stackSize.width,
        height: stackSize.height,
        child: Stack(clipBehavior: Clip.none, children: [
          ...children,
          if (showBadge)
            Positioned(
              right: -2,
              top: -2,
              child: _countBadge(total, theme),
            ),
        ]),
      );
    }

    // Tappable si onTap fourni, sinon purement visuel
    final widgetBody = (onTap != null)
        ? Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: stack,
      ),
    )
        : stack;

    // AUCUN label sous la pile — on renvoie directement le visuel
    return widgetBody;
  }

  /// Position d'une carte à l'index i selon le visuel choisi.
  Offset _positionFor(int i) {
    return switch (visual) {
      PileVisual.fan => Offset(i * overlapX, 0),
      PileVisual.diagonal => Offset(i * overlapX, i * overlapY),
    };
  }

  /// Angle (radians) pour l’éventail.
  double _angleFor(int i, int n) {
    if (visual != PileVisual.fan) return 0.0;
    final center = (n - 1) / 2.0;
    final deg = (i - center) * rotationStepDeg;
    return deg * 3.1415926535 / 180.0;
  }

  Widget _emptyPlaceholder(double w, double h, ThemeData theme) {
    final cs = theme.colorScheme;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: cs.surfaceVariant.withOpacity(0.20),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.55),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          )
        ],
      ),
    );
  }

  Widget _countBadge(int value, ThemeData theme) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withOpacity(.30)),
      ),
      child: Text(
        '$value',
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w800,
          letterSpacing: .2,
        ),
      ),
    );
  }
}
