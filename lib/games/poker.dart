import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/ai_poker.dart';
import '../core/cards.dart';
import '../core/evaluator.dart';

enum Street { preflop, flop, turn, river, ended }
enum Actor { player, ai }

const sb = 10;
const bb = 20;

/// Moteur Poker Texas Hold'em heads-up contre l'IA « ZIA ».
class PokerEngine extends ChangeNotifier {
  final Random _rand = Random();

  List<PlayingCard> deck = [];
  List<PlayingCard> board = [];
  List<PlayingCard> playerHole = [];
  List<PlayingCard> aiHole = [];
  int pot = 0;
  int pBet = 0;
  int aBet = 0;
  int pStack = 0;
  int aStack = 500;
  bool dealerIsPlayer = true;
  Street street = Street.preflop;
  Actor? toAct;
  bool actedP = false;
  bool actedA = false;
  int raises = 0;
  bool runout = false;
  bool revealAI = false;
  String? result;
  final List<String> log = [];

  PokerEngine({required int buyIn}) {
    pStack = buyIn;
    startHand(first: true);
  }

  bool get playerTurn => toAct == Actor.player && result == null;
  int get toCall => aBet - pBet;

  int get openBetSize {
    final h = (pot * 0.5).round();
    return h > bb ? h : bb;
  }

  int get raiseHalfSize {
    final h = (pot * 0.5).round();
    final base = h > bb ? h : bb;
    final target = aBet + base;
    final minR = aBet + bb;
    return target > minR ? target : minR;
  }

  int get potSizeBet => aBet + pot;

  String get streetLabel {
    switch (street) {
      case Street.preflop:
        return 'Pré-flop';
      case Street.flop:
        return 'Flop';
      case Street.turn:
        return 'Turn';
      case Street.river:
        return 'River';
      case Street.ended:
        return 'Fin de main';
    }
  }

  void _log(String msg) {
    log.insert(0, msg);
    if (log.length > 4) log.removeLast();
  }

  void startHand({bool first = false}) {
    dealerIsPlayer = first ? _rand.nextBool() : !dealerIsPlayer;
    deck = shuffledDeck(_rand);
    board = [];
    playerHole = [deck.removeLast(), deck.removeLast()];
    aiHole = [deck.removeLast(), deck.removeLast()];
    pot = 0;
    pBet = 0;
    aBet = 0;
    actedP = false;
    actedA = false;
    raises = 0;
    runout = false;
    revealAI = false;
    result = null;
    street = Street.preflop;
    log.clear();
    if (aStack <= 0) {
      aStack = 500;
      _log('ZIA se recave (500 🪙).');
    }
    // Blinds (cave insuffisante → tapis pour moins)
    final sbWho = dealerIsPlayer ? Actor.player : Actor.ai;
    final bbWho = dealerIsPlayer ? Actor.ai : Actor.player;
    final sbAmt = sbWho == Actor.player
        ? (pStack < sb ? pStack : sb)
        : (aStack < sb ? aStack : sb);
    final bbAmt = bbWho == Actor.player
        ? (pStack < bb ? pStack : bb)
        : (aStack < bb ? aStack : bb);
    pot = sbAmt + bbAmt;
    if (sbWho == Actor.player) {
      pStack -= sbAmt;
      pBet = sbAmt;
    } else {
      aStack -= sbAmt;
      aBet = sbAmt;
    }
    if (bbWho == Actor.player) {
      pStack -= bbAmt;
      pBet = bbAmt;
    } else {
      aStack -= bbAmt;
      aBet = bbAmt;
    }
    toAct = dealerIsPlayer ? Actor.player : Actor.ai;
    _log('Nouvelle main — blinds $sb/$bb.');
    if (pStack == 0 || aStack == 0) {
      normalizeAllIn();
      runout = true;
      toAct = null;
      revealAI = true;
    }
    notifyListeners();
  }

  /// Rembourse la part non couverte quand un tapis ne peut pas suivre.
  void normalizeAllIn() {
    final minBet = pBet < aBet ? pBet : aBet;
    if (pBet > minBet) {
      final r = pBet - minBet;
      pStack += r;
      pot -= r;
      pBet = minBet;
    }
    if (aBet > minBet) {
      final r = aBet - minBet;
      aStack += r;
      pot -= r;
      aBet = minBet;
    }
  }

  void showdown() {
    final pScore = evaluate7([...playerHole, ...board]);
    final aScore = evaluate7([...aiHole, ...board]);
    final c = cmpScore(pScore, aScore);
    final won = pot;
    pot = 0;
    revealAI = true;
    toAct = null;
    street = Street.ended;
    if (c > 0) {
      pStack += won;
      result = 'Vous gagnez $won 🪙 avec ' + handName(pScore) + ' !';
    } else if (c < 0) {
      aStack += won;
      result = 'ZIA gagne $won 🪙 avec ' + handName(aScore) + '.';
    } else {
      final half = won ~/ 2;
      pStack += half + (won % 2);
      aStack += half;
      result = 'Égalité — pot partagé (' + handName(pScore) + ').';
    }
    _log('Abattage : ' + result!);
  }

  void advanceStreet() {
    if (street == Street.ended || result != null) return;
    if (street == Street.river) {
      showdown();
      notifyListeners();
      return;
    }
    if (street == Street.preflop) {
      board.add(deck.removeLast());
      board.add(deck.removeLast());
      board.add(deck.removeLast());
    } else {
      board.add(deck.removeLast());
    }
    street = street == Street.preflop
        ? Street.flop
        : (street == Street.flop ? Street.turn : Street.river);
    pBet = 0;
    aBet = 0;
    actedP = false;
    actedA = false;
    raises = 0;
    final allIn = pStack == 0 || aStack == 0;
    if (allIn) {
      runout = true;
      revealAI = true;
      toAct = null;
    } else {
      toAct = dealerIsPlayer ? Actor.ai : Actor.player;
    }
    _log(streetLabel + '.');
    notifyListeners();
  }

  void fold(Actor who) {
    final won = pot;
    pot = 0;
    if (who == Actor.player) {
      aStack += won;
      result = 'Vous vous couchez — ZIA remporte $won 🪙.';
      _log('Vous vous couchez.');
    } else {
      pStack += won;
      result = 'ZIA se couche — vous remportez $won 🪙 !';
      _log('ZIA se couche.');
    }
    street = Street.ended;
    toAct = null;
    notifyListeners();
  }

  void checkCall(Actor who) {
    final other = who == Actor.player ? Actor.ai : Actor.player;
    final myBet = who == Actor.player ? pBet : aBet;
    final otherBet = other == Actor.player ? pBet : aBet;
    final toCallAmount = otherBet - myBet;

    if (toCallAmount <= 0) {
      if (who == Actor.player) actedP = true; else actedA = true;
      _log(who == Actor.player ? 'Vous checkez.' : 'ZIA checke.');
      final otherActed = who == Actor.player ? actedA : actedP;
      if (otherActed) {
        advanceStreet();
        return;
      }
      toAct = other;
      notifyListeners();
      return;
    }

    var myStack = who == Actor.player ? pStack : aStack;
    final add = toCallAmount < myStack ? toCallAmount : myStack;
    myStack -= add;
    pot += add;
    var newPBet = who == Actor.player ? myBet + add : otherBet;
    var newABet = who == Actor.ai ? myBet + add : otherBet;
    var otherStack = other == Actor.player ? pStack : aStack;
    // Tapis non couvert → remboursement du trop-versé à l'adversaire
    if (add < toCallAmount) {
      final refund = toCallAmount - add;
      otherStack += refund;
      pot -= refund;
      if (other == Actor.player) {
        newPBet -= refund;
      } else {
        newABet -= refund;
      }
    }
    pBet = newPBet;
    aBet = newABet;
    pStack = who == Actor.player ? myStack : otherStack;
    aStack = who == Actor.ai ? myStack : otherStack;
    if (who == Actor.player) actedP = true; else actedA = true;
    _log(who == Actor.player
        ? 'Vous suivez $add.'
        : 'ZIA suit $add.');
    if (pStack == 0 || aStack == 0) {
      normalizeAllIn();
      runout = true;
      revealAI = true;
      toAct = null;
      notifyListeners();
      return;
    }
    final otherActed = who == Actor.player ? actedA : actedP;
    if (otherActed) {
      advanceStreet();
      return;
    }
    toAct = other;
    notifyListeners();
  }

  void betRaise(Actor who, int raiseToRaw) {
    final other = who == Actor.player ? Actor.ai : Actor.player;
    final myBet = who == Actor.player ? pBet : aBet;
    final otherBet = other == Actor.player ? pBet : aBet;
    final myStack = who == Actor.player ? pStack : aStack;
    final diff = otherBet - myBet;
    final minRaiseTo = otherBet > 0 ? otherBet + (bb > diff ? bb : diff) : bb;
    var raiseTo = raiseToRaw > minRaiseTo ? raiseToRaw : minRaiseTo;
    final maxRaiseTo = myBet + myStack;
    if (raiseTo > maxRaiseTo) raiseTo = maxRaiseTo; // tapis
    if (raiseTo <= otherBet) {
      checkCall(who);
      return;
    }
    final add = raiseTo - myBet;
    pot += add;
    if (who == Actor.player) {
      pBet = raiseTo;
      pStack -= add;
      actedP = true;
      _log(otherBet > 0 ? 'Vous relancez à $raiseTo.' : 'Vous misez $raiseTo.');
    } else {
      aBet = raiseTo;
      aStack -= add;
      actedA = true;
      _log(otherBet > 0 ? 'ZIA relance à $raiseTo.' : 'ZIA mise $raiseTo.');
    }
    raises++;
    toAct = other;
    if ((who == Actor.player ? pStack : aStack) == 0) revealAI = true;
    notifyListeners();
  }

  /// Tour de l'IA : Chen pré-flop, Monte-Carlo ensuite, cote du pot + bluff.
  void aiAct() {
    if (toAct != Actor.ai || result != null) return;
    final toCallAmount = pBet - aBet;
    var p = 0.0;
    if (street == Street.preflop) {
      final c = chen(aiHole[0], aiHole[1]);
      p = 0.33 + (c / 20.0) * 0.42;
    } else {
      p = winProb(aiHole, board, 200, _rand);
    }

    if (toCallAmount <= 0) {
      final betSize = (pot * 0.5).round() > bb ? (pot * 0.5).round() : bb;
      if (raises < 3 && p > 0.62 && _rand.nextDouble() < 0.85 && betSize <= aStack) {
        betRaise(Actor.ai, aBet + betSize);
        return;
      }
      if (raises < 3 && p < 0.38 && _rand.nextDouble() < 0.13 && betSize <= aStack) {
        betRaise(Actor.ai, aBet + betSize); // bluff occasionnel
        return;
      }
      checkCall(Actor.ai);
      return;
    }

    final potOdds = toCallAmount / (pot + toCallAmount);
    final half = (pot * 0.6).round();
    final raiseTo = pBet + (half > bb ? half : bb);
    if (raises < 3 && p > 0.8 && _rand.nextDouble() < 0.75 && raiseTo <= aBet + aStack) {
      betRaise(Actor.ai, raiseTo);
      return;
    }
    if (p >= potOdds + 0.02) {
      checkCall(Actor.ai);
      return;
    }
    if (_rand.nextDouble() < 0.1 && p > potOdds * 0.7) {
      checkCall(Actor.ai); // call flottant
      return;
    }
    fold(Actor.ai);
  }
}
