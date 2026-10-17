import 'dart:math';

/// Couleurs : s = pique, h = cœur, d = carreau, c = trèfle.
enum Suit { s, h, d, c }

class PlayingCard {
  final int rank; // 2..14 (14 = As)
  final Suit suit;

  const PlayingCard(this.rank, this.suit);

  bool get isRed => suit == Suit.h || suit == Suit.d;

  String get rankLabel {
    switch (rank) {
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      case 14:
        return 'A';
      default:
        return rank.toString();
    }
  }

  String get suitChar {
    switch (suit) {
      case Suit.s:
        return '♠';
      case Suit.h:
        return '♥';
      case Suit.d:
        return '♦';
      case Suit.c:
        return '♣';
    }
  }

  @override
  String toString() => rankLabel + suitChar;

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => rank * 4 + suit.index;
}

/// Les 52 cartes, dans l'ordre couleur par couleur.
List<PlayingCard> fullDeck() {
  final deck = <PlayingCard>[];
  for (final s in Suit.values) {
    for (var r = 2; r <= 14; r++) {
      deck.add(PlayingCard(r, s));
    }
  }
  return deck;
}

/// Un deck mélangé (Fisher-Yates).
List<PlayingCard> shuffledDeck([Random? rng]) {
  final rand = rng ?? Random();
  final deck = fullDeck();
  deck.shuffle(rand);
  return deck;
}
