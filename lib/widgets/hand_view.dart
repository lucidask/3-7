import 'package:flutter/material.dart';
import '../models/card_model.dart';
import 'mini_card_widget.dart';

typedef CardTap = void Function(CardModel card);

/// Main de cartes en éventail (chevauchement) SANS scroll.
/// - Ajuste overlap/scale pour faire tenir toutes les cartes.
/// - Validation visuelle: NE JAMAIS griser quand faceDown == true.
class HandView extends StatelessWidget {
  final List<CardModel> cards;
  final bool enabled;
  final CardTap onTap;

  /// Validation par carte. Si null => toutes jouables (si enabled).
  final bool Function(CardModel card)? isPlayable;

  /// Affiche le dos des cartes (utile pour l’adversaire ou pour masquer).
  final bool faceDown;

  /// Chevauchement "souhaité" (px) entre deux cartes (sera ajusté pour tenir).
  final double desiredOverlap;

  /// Chevauchement minimum (px) pour garder lisible/esthétique.
  final double minOverlap;

  /// Échelle minimale appliquée si trop de cartes pour l’espace.
  final double minScale;

  /// Largeur/hauteur BASE d’une MiniCard (doivent matcher MiniCardWidget).
  final double baseCardWidth;
  final double baseCardHeight;

  /// Alignement horizontal de la main (center par défaut).
  final AlignmentGeometry alignment;

  /// Marge latérale pour aérer la main.
  final double sidePadding;

  /// ⬇️ NOUVEAU : facteur d’échelle externe appliqué avant la mise en page.
  /// Permet de lier la taille des cartes à la hauteur de la table.
  final double cardScale;

  const HandView({
    super.key,
    required this.cards,
    required this.enabled,
    required this.onTap,
    this.isPlayable,
    this.faceDown = false,
    this.desiredOverlap = 38,
    this.minOverlap = 28,
    this.minScale = 0.85,
    this.baseCardWidth = 46,
    this.baseCardHeight = 64,
    this.alignment = Alignment.center,
    this.sidePadding = 8,
    this.cardScale = 1.0, // ← NEW (par défaut inchangé)
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Applique l’échelle externe AVANT toute mise en page
        final double bw = (baseCardWidth * cardScale).toDouble();
        final double bh = (baseCardHeight * cardScale).toDouble();
        double dxDesired = (desiredOverlap * cardScale).toDouble();
        final double dxMin = (minOverlap * cardScale).toDouble();

        final double maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (bw * cards.length);

        final int n = cards.length;
        double scale = 1.0; // scale interne auto (en plus de cardScale)
        double dx = dxDesired;

        // largeur réellement dispo, hors marges
        final double available = (maxW - 2 * sidePadding).clamp(0.0, double.infinity).toDouble();

        // largeur requise avec chevauchement souhaité
        double widthNeeded = bw + (n - 1) * dx;

        if (widthNeeded > available) {
          if (n == 1) {
            scale = (available / bw).clamp(minScale, 1.0).toDouble();
          } else {
            // Ajuste dx pour tenir, borné par dxMin et dxDesired
            final double dxCandidate =
            ((available - bw) / (n - 1)).clamp(dxMin, dxDesired).toDouble();
            dx = dxCandidate;

            // Recalcule: si ça dépasse encore -> scale interne
            widthNeeded = bw + (n - 1) * dx;
            if (widthNeeded > available) {
              scale = (available / widthNeeded).clamp(minScale, 1.0).toDouble();
            }
          }
        }

        final double cardW = bw * scale;
        final double cardH = bh * scale;
        final double totalInnerWidth = (cardW + (n - 1) * dx).clamp(0.0, available).toDouble();

        final children = <Widget>[];
        for (var i = 0; i < n; i++) {
          final card = cards[i];

          // Base: est-ce que la carte est jouable selon ta logique ?
          final bool playableBase = (isPlayable?.call(card) ?? true);

          // Interactivité réelle: seulement si la main est enabled ET visible (pas faceDown)
          final bool interactive = enabled && !faceDown && playableBase;

          // IMPORTANT: NE JAMAIS griser quand faceDown == true
          final bool shouldDim = (!interactive && !faceDown) ? true : false;

          final view = MiniCardWidget(
            card,
            faceDown: faceDown,
            dimmed: shouldDim,
          );

          final child = SizedBox(
            width: cardW,
            height: cardH,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: interactive
                  ? Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onTap(card),
                  child: view,
                ),
              )
                  : AbsorbPointer(absorbing: true, child: view),
            ),
          );

          children.add(Positioned(
            left: sidePadding + (i * dx),
            top: 0.0,
            child: child,
          ));
        }

        final handStack = SizedBox(
          width: totalInnerWidth + 2 * sidePadding,
          height: cardH,
          child: Stack(children: children),
        );

        final body = Opacity(opacity: enabled ? 1.0 : 0.6, child: handStack);
        return Align(alignment: alignment, child: body);
      },
    );
  }
}
