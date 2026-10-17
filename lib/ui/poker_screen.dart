import 'package:flutter/material.dart';

import '../app_state.dart';
import '../games/poker.dart';
import 'card_widget.dart';
import 'theme.dart';

class PokerScreen extends StatefulWidget {
  final Bankroll bankroll;

  const PokerScreen({super.key, required this.bankroll});

  @override
  State<PokerScreen> createState() => _PokerScreenState();
}

class _PokerScreenState extends State<PokerScreen> {
  late final PokerEngine engine;
  bool _aiTimer = false;
  bool _runoutTimer = false;

  @override
  void initState() {
    super.initState();
    engine = PokerEngine(buyIn: widget.bankroll.value);
    engine.addListener(_onEngineChanged);
  }

  @override
  void dispose() {
    engine.removeListener(_onEngineChanged);
    widget.bankroll.setTo(engine.pStack);
    engine.dispose();
    super.dispose();
  }

  void _onEngineChanged() {
    if (engine.result == null) {
      if (engine.toAct == Actor.ai && !_aiTimer) {
        _aiTimer = true;
        Future.delayed(const Duration(milliseconds: 1000), () {
          _aiTimer = false;
          if (mounted) engine.aiAct();
        });
      }
      if (engine.runout && !_runoutTimer) {
        _runoutTimer = true;
        Future.delayed(const Duration(milliseconds: 1300), () {
          _runoutTimer = false;
          if (mounted) engine.advanceStreet();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Poker Hold’em'),
        actions: [
          AnimatedBuilder(
            animation: engine,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '🪙 ' + engine.pStack.toString(),
                  style: const TextStyle(
                    color: gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: engine,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _aiSection(),
              const SizedBox(height: 10),
              _table(),
              const SizedBox(height: 10),
              _playerSection(),
              const SizedBox(height: 10),
              if (engine.log.isNotEmpty) _logPanel(),
              const SizedBox(height: 10),
              _actions(),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 12),
      ),
    );
  }

  Widget _dealerBadge() {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'D',
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _aiSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF1E293B),
              child: Icon(Icons.smart_toy, color: gold),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ZIA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '🪙 ' + engine.aStack.toString(),
                  style: const TextStyle(fontSize: 12, color: textSoft),
                ),
              ],
            ),
            if (engine.aBet > 0) ...[
              const SizedBox(width: 12),
              _chip('mise ' + engine.aBet.toString()),
            ],
            if (!engine.dealerIsPlayer) ...[
              const SizedBox(width: 8),
              _dealerBadge(),
            ],
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < engine.aiHole.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PlayingCardView(
                    card: engine.aiHole[i],
                    hidden: !engine.revealAI,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _table() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          colors: [feltLight, Color(0xFF052E16)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Color(0xFF064E3B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: engine.board.isEmpty
                  ? [const CardPlaceholder()]
                  : [
                      for (var i = 0; i < engine.board.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: PlayingCardView(card: engine.board[i]),
                        ),
                    ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _chip('Pot : ' + engine.pot.toString() + ' 🪙'),
              const SizedBox(width: 8),
              _chip(engine.streetLabel),
            ],
          ),
          if (engine.result != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                engine.result!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: gold,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _playerSection() {
    return Column(
      children: [
        SizedBox(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < engine.playerHole.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PlayingCardView(card: engine.playerHole[i]),
                ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Vous',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (engine.pBet > 0) ...[
              const SizedBox(width: 10),
              _chip('mise ' + engine.pBet.toString()),
            ],
            if (engine.dealerIsPlayer) ...[
              const SizedBox(width: 8),
              _dealerBadge(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _logPanel() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < engine.log.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                engine.log[i],
                style: TextStyle(
                  fontSize: 11,
                  color: textSoft.withValues(alpha: 1 - i * 0.2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions() {
    if (engine.result != null) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: engine.pStack > 0 ? engine.startHand : null,
                  style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Color(0xFF052E16)),
                  child: const Text('Main suivante'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Quitter'),
              ),
            ],
          ),
          if (engine.pStack <= 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Plus de jetons — rechargez la banque depuis l’accueil.',
                style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
              ),
            ),
        ],
      );
    }
    if (engine.playerTurn) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => engine.fold(Actor.player),
                  style: FilledButton.styleFrom(backgroundColor: danger),
                  child: const Text('Coucher'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => engine.checkCall(Actor.player),
                  style: FilledButton.styleFrom(backgroundColor: greenAction),
                  child: Text(
                    engine.toCall > 0
                        ? 'Suivre ' + engine.toCall.toString()
                        : 'Checker',
                  ),
                ),
              ),
            ],
          ),
          if (engine.raises < 3 && engine.pStack > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => engine.betRaise(
                    Actor.player,
                    engine.aBet > 0 ? engine.raiseHalfSize : engine.openBetSize,
                  ),
                  child: Text(
                    engine.aBet > 0
                        ? 'Relancer à ' + engine.raiseHalfSize.toString()
                        : 'Miser ' + engine.openBetSize.toString(),
                  ),
                ),
                OutlinedButton(
                  onPressed: () =>
                      engine.betRaise(Actor.player, engine.potSizeBet),
                  child: const Text('Pot'),
                ),
                OutlinedButton(
                  onPressed: () => engine.betRaise(
                    Actor.player,
                    engine.pBet + engine.pStack,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: gold,
                    side: BorderSide(color: gold.withValues(alpha: 0.5)),
                  ),
                  child: const Text('Tapis'),
                ),
              ],
            ),
          ],
        ],
      );
    }
    return SizedBox(
      height: 48,
      child: Center(
        child: Text(
          'ZIA réfléchit…',
          style: TextStyle(color: textSoft.withValues(alpha: 0.9)),
        ),
      ),
    );
  }
}
