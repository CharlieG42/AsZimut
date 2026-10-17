import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../core/cards.dart';

enum BjPhase { bet, player, dealer, done }

/// Valeur d'une main de blackjack (As = 1 ou 11).
int bjValue(List<PlayingCard> cards) {
  var total = 0;
  var aces = 0;
  for (final c in cards) {
    if (c.rank == 14) {
      aces++;
      total += 11;
    } else if (c.rank > 10) {
      total += 10;
    } else {
      total += c.rank;
    }
  }
  while (total > 21 && aces > 0) {
    total -= 10;
    aces--;
  }
  return total;
}

/// Moteur Blackjack : règles + croupier IA (tire jusqu'à 17).
class BlackjackEngine extends ChangeNotifier {
  final Bankroll _bankroll;

  List<PlayingCard> deck = shuffledDeck();
  List<PlayingCard> player = [];
  List<PlayingCard> dealer = [];
  BjPhase phase = BjPhase.bet;
  int bet = 0;
  String message = '';
  bool revealed = false;

  BlackjackEngine(this._bankroll);

  void addToBet(int v) {
    if (phase == BjPhase.bet && v <= _bankroll.value - bet) {
      bet += v;
      notifyListeners();
    }
  }

  void clearBet() {
    if (phase == BjPhase.bet && bet > 0) {
      bet = 0;
      notifyListeners();
    }
  }

  void deal() {
    if (phase != BjPhase.bet || bet < 10 || bet > _bankroll.value) return;
    _bankroll.add(-bet);
    if (deck.length < 15) deck = shuffledDeck();
    player = [deck.removeLast(), deck.removeLast()];
    dealer = [deck.removeLast(), deck.removeLast()];
    revealed = false;
    message = '';
    phase = bjValue(player) == 21 ? BjPhase.dealer : BjPhase.player;
    notifyListeners();
  }

  void hit() {
    if (phase != BjPhase.player) return;
    player.add(deck.removeLast());
    final v = bjValue(player);
    if (v > 21) {
      revealed = true;
      message = 'Vous dépassez ($v). Mise perdue.';
      phase = BjPhase.done;
    } else if (v == 21) {
      phase = BjPhase.dealer;
    }
    notifyListeners();
  }

  void stand() {
    if (phase != BjPhase.player) return;
    phase = BjPhase.dealer;
    notifyListeners();
  }

  void doubleDown() {
    if (phase != BjPhase.player ||
        player.length != 2 ||
        bet > _bankroll.value) {
      return;
    }
    _bankroll.add(-bet);
    bet = bet * 2;
    player.add(deck.removeLast());
    final v = bjValue(player);
    if (v > 21) {
      revealed = true;
      message = 'Vous dépassez ($v). Mise perdue.';
      phase = BjPhase.done;
    } else {
      phase = BjPhase.dealer;
    }
    notifyListeners();
  }

  /// Le croupier tire jusqu'à 17 (s'arrête sur un soft 17), puis résolution.
  void dealerPlays() {
    if (phase != BjPhase.dealer) return;
    while (bjValue(dealer) < 17 && deck.isNotEmpty) {
      dealer.add(deck.removeLast());
    }
    revealed = true;
    _resolve();
    phase = BjPhase.done;
    notifyListeners();
  }

  void _resolve() {
    final pv = bjValue(player);
    final dv = bjValue(dealer);
    final pNat = player.length == 2 && pv == 21;
    final dNat = dealer.length == 2 && dv == 21;
    var payout = 0;
    if (pNat && dNat) {
      payout = bet;
      message = 'Double blackjack — égalité, mise remboursée.';
    } else if (pNat) {
      payout = (bet * 2.5).round();
      message = 'Blackjack ! Vous gagnez ' + ((bet * 1.5).round()).toString() + ' 🎉';
    } else if (dNat) {
      message = 'Blackjack du croupier — mise perdue.';
    } else if (pv > 21) {
      message = 'Vous dépassez ($pv). Mise perdue.';
    } else if (dv > 21) {
      payout = bet * 2;
      message = 'Le croupier crève ($dv) ! Vous gagnez $bet 🎉';
    } else if (pv > dv) {
      payout = bet * 2;
      message = '$pv contre $dv — vous gagnez $bet ! 🎉';
    } else if (pv < dv) {
      message = '$pv contre $dv — le croupier gagne.';
    } else {
      payout = bet;
      message = 'Égalité — mise remboursée.';
    }
    if (payout > 0) _bankroll.add(payout);
  }

  void replay() {
    final nextBet = bet < _bankroll.value ? bet : _bankroll.value;
    player = [];
    dealer = [];
    message = '';
    revealed = false;
    bet = nextBet;
    phase = BjPhase.bet;
    notifyListeners();
  }
}
