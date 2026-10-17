import 'cards.dart';

/// Évalue 5 cartes et renvoie un score comparable
/// (liste triée par priorité : [catégorie, bris d'égalité...]).
/// 8 = quinte flush ... 0 = hauteur.
List<int> evaluate5(List<PlayingCard> cs) {
  final ranks = cs.map((c) => c.rank).toList()..sort((a, b) => b - a);
  final isFlush = cs.every((c) => c.suit == cs.first.suit);
  final uniq = ranks.toSet().toList()..sort((a, b) => b - a);
  var isStraight = false;
  var straightHigh = 0;
  if (uniq.length == 5) {
    if (uniq[0] - uniq[4] == 4) {
      isStraight = true;
      straightHigh = uniq[0];
    } else if (uniq[0] == 14 && uniq[1] == 5) {
      // Quinte « wheel » : A-2-3-4-5
      isStraight = true;
      straightHigh = 5;
    }
  }

  final counts = <int, int>{};
  for (final r in ranks) {
    counts[r] = (counts[r] ?? 0) + 1;
  }
  final groups = counts.entries.toList()
    ..sort((a, b) => b.value != a.value ? b.value - a.value : b.key - a.key);

  if (isStraight && isFlush) return [8, straightHigh];
  if (groups[0].value == 4) return [7, groups[0].key, groups[1].key];
  if (groups[0].value == 3 && groups[1].value == 2) {
    return [6, groups[0].key, groups[1].key];
  }
  if (isFlush) return [5, ...ranks];
  if (isStraight) return [4, straightHigh];
  if (groups[0].value == 3) return [3, groups[0].key, groups[1].key, groups[2].key];
  if (groups[0].value == 2 && groups[1].value == 2) {
    return [2, groups[0].key, groups[1].key, groups[2].key];
  }
  if (groups[0].value == 2) {
    return [1, groups[0].key, groups[1].key, groups[2].key, groups[3].key];
  }
  return [0, ...ranks];
}

/// Comparaison lexicographique de deux scores.
int cmpScore(List<int> a, List<int> b) {
  final n = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final x = i < a.length ? a[i] : -1;
    final y = i < b.length ? b[i] : -1;
    if (x != y) return x - y;
  }
  return 0;
}

List<List<int>> _combos7() {
  final out = <List<int>>[];
  for (var a = 0; a < 7; a++) {
    for (var b = a + 1; b < 7; b++) {
      for (var c = b + 1; c < 7; c++) {
        for (var d = c + 1; d < 7; d++) {
          for (var e = d + 1; e < 7; e++) {
            out.add([a, b, c, d, e]);
          }
        }
      }
    }
  }
  return out;
}

final List<List<int>> combos7 = _combos7();

/// Meilleure main de 5 cartes parmi 7 (21 combinaisons).
List<int> evaluate7(List<PlayingCard> cs) {
  var best = <int>[];
  for (final idx in combos7) {
    final score = evaluate5(idx.map((i) => cs[i]).toList());
    if (best.isEmpty || cmpScore(score, best) > 0) best = score;
  }
  return best;
}

const handNames = [
  'Hauteur',
  'Paire',
  'Double paire',
  'Brelan',
  'Quinte',
  'Couleur',
  'Full',
  'Carré',
  'Quinte flush',
];

String handName(List<int> score) {
  if (score[0] == 8 && score[1] == 14) return 'Quinte flush royale';
  return handNames[score[0]];
}
