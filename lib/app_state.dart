import 'package:flutter/foundation.dart';

/// Banque commune au Blackjack et au Poker (jetons).
class Bankroll extends ChangeNotifier {
  int value;

  Bankroll([this.value = 1000]);

  void add(int amount) {
    value += amount;
    notifyListeners();
  }

  void setTo(int amount) {
    value = amount;
    notifyListeners();
  }
}
