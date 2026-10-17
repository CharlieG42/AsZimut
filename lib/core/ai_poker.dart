import 'dart:math';

import 'cards.dart';
import 'evaluator.dart';

/// Formule de Chen : force d'une main de départ (0 à 20, AA = 20).
int chen(PlayingCard c1, PlayingCard c2) {
  final hi = c1.rank > c2.rank ? c1.rank : c2.rank;
  final lo = c1.rank < c2.rank ? c1.rank : c2.rank;
  final base = hi == 14
      ? 10.0
      : hi == 13
          ? 8.0
          : hi == 12
              ? 7.0
              : hi == 11
                  ? 6.0
                  : hi == 10
                      ? 5.0
                      : hi / 2.0;
  var pts = c1.rank == c2.rank ? (base * 2 > 5 ? base * 2 : 5) : base;
  if (c1.suit == c2.suit) pts += 2;
  final gap = hi - lo - 1;
  if (c1.rank != c2.rank) {
    if (gap == 1) {
      pts -= 1;
    } else if (gap == 2) {
      pts -= 2;
    } else if (gap == 3) {
      pts -= 4;
    } else if (gap >= 4) {
      pts -= 5;
    }
    if (gap <= 1 && hi < 12) pts += 1;
  }
  final rounded = pts.ceil();
  return rounded < 0 ? 0 : rounded;
}

/// Probabilité de gain par Monte-Carlo contre une main adverse aléatoire.
double winProb(
  List<PlayingCard> hole,
  List<PlayingCard> board, [
  int iters = 200,
  Random? rng,
]) {
  final rand = rng ?? Random();
  final used = <String>{};
  for (final c in hole) {
    used.add(c.toString());
  }
  for (final c in board) {
    used.add(c.toString());
  }
  final deck = fullDeck().where((c) => !used.contains(c.toString())).toList();
  final need = 5 - board.length;
  var score = 0.0;
  for (var i = 0; i < iters; i++) {
    deck.shuffle(rand);
    final opp = deck.sublist(0, 2);
    final rest = deck.sublist(2, 2 + need);
    final fullBoard = [...board, ...rest];
    final cmp = cmpScore(
      evaluate7([...hole, ...fullBoard]),
      evaluate7([...opp, ...fullBoard]),
    );
    score += cmp > 0 ? 1.0 : (cmp == 0 ? 0.5 : 0.0);
  }
  return score / iters;
}
