import '../models/card_model.dart';

/// Hiérarchie 3‑7 déjà définie par rankStrength(r).
/// Rappel: 7 < 8 < J < Q < K < As < 9 < 10

/// Retourne true si `b` est STRICTEMENT plus forte que `a` (même couleur, rang supérieur).
bool isStronger(CardModel a, CardModel b) {
  if (a.suit != b.suit) return false;
  return rankStrength(b.rank) > rankStrength(a.rank);
}

/// Vérifie si un coup est légal selon:
/// 1) Obligation de couleur: si le joueur a la couleur demandée, il doit jouer cette couleur.
/// 2) Carte forte: si le joueur a au moins une carte PLUS FORTE dans la couleur demandée,
///    il doit en jouer une forte. Sinon, il peut jouer une carte de la couleur demandée
///    plus faible.
/// 3) S’il n’a pas la couleur demandée, toute carte est légale (il perdra le pli).
///
/// [led] = première carte du pli (null si le pli n’a pas commencé)
bool isLegalMove({
  required List<CardModel> playerHand,
  required CardModel toPlay,
  required CardModel? led,
}) {
  // Si c’est la première carte du pli, tout est légal.
  if (led == null) return true;

  final hasLedSuit = playerHand.any((c) => c.suit == led.suit);
  if (!hasLedSuit) {
    // Pas la couleur demandée en main → libre de jouer n’importe quoi.
    return true;
  }

  // A la couleur: doit jouer la couleur demandée
  if (toPlay.suit != led.suit) {
    return false;
  }

  // A la couleur, doit-il jouer une carte forte ?
  final hasStronger = playerHand.any((c) => c.suit == led.suit && isStronger(led, c));
  if (!hasStronger) {
    // Pas de carte plus forte → peut jouer n’importe quelle carte de la couleur demandée.
    return true;
  }

  // A au moins une carte plus forte → la carte jouée doit être plus forte.
  return isStronger(led, toPlay);
}
