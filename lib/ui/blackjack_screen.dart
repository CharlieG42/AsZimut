import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/cards.dart';
import '../games/blackjack.dart';
import 'card_widget.dart';
import 'theme.dart';

class BlackjackScreen extends StatefulWidget {
  final Bankroll bankroll;

  const BlackjackScreen({super.key, required this.bankroll});

  @override
  State<BlackjackScreen> createState() => _BlackjackScreenState();
}

class _BlackjackScreenState extends State<BlackjackScreen> {
  late final BlackjackEngine engine;
  bool _dealerTimer = false;

  @override
  void initState() {
    super.initState();
    engine = BlackjackEngine(widget.bankroll);
    engine.addListener(_onEngineChanged);
  }

  @override
  void dispose() {
    engine.removeListener(_onEngineChanged);
    engine.dispose();
    super.dispose();
  }

  void _onEngineChanged() {
    if (engine.phase == BjPhase.dealer && !_dealerTimer) {
      _dealerTimer = true;
      Future.delayed(const Duration(milliseconds: 900), () {
        _dealerTimer = false;
        if (mounted) engine.dealerPlays();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blackjack'),
        actions: [
          ListenableBuilder(
            listenable: widget.bankroll,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '🪙 ' + widget.bankroll.value.toString(),
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
              _felt(),
              const SizedBox(height: 16),
              _controls(),
            ],
          );
        },
      ),
    );
  }

  Widget _cardsRow(List<PlayingCard> cards, {bool hideSecond = false}) {
    final children = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: PlayingCardView(
            card: cards[i],
            hidden: hideSecond && i == 1 && !engine.revealed,
          ),
        ),
      );
    }
    if (cards.isEmpty) children.add(const CardPlaceholder());
    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _totalBadge(int value) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        value.toString(),
        style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 13),
      ),
    );
  }

  Widget _felt() {
    final dealerVisible = engine.revealed
        ? bjValue(engine.dealer)
        : (engine.dealer.isNotEmpty ? bjValue([engine.dealer.first]) : 0);
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
          const Text(
            'CROUPIER',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 3,
              color: textSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          _cardsRow(engine.dealer, hideSecond: true),
          if (engine.dealer.isNotEmpty) _totalBadge(dealerVisible),
          Divider(
            height: 24,
            color: Color(0xFF064E3B).withValues(alpha: 0.6),
          ),
          _cardsRow(engine.player),
          const Text(
            'VOUS',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 3,
              color: textSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (engine.player.isNotEmpty) _totalBadge(bjValue(engine.player)),
          if (engine.message.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                engine.message,
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

  Widget _controls() {
    switch (engine.phase) {
      case BjPhase.bet:
        return _betPanel();
      case BjPhase.player:
        return _actionButtons();
      case BjPhase.dealer:
        return const SizedBox(
          height: 48,
          child: Center(
            child: Text(
              'Le croupier joue…',
              style: TextStyle(color: textSoft),
            ),
          ),
        );
      case BjPhase.done:
        return FilledButton.tonal(
          onPressed: engine.replay,
          style: FilledButton.styleFrom(
            backgroundColor: gold.withValues(alpha: 0.15),
            foregroundColor: gold,
            side: BorderSide(color: gold.withValues(alpha: 0.4)),
          ),
          child: const Text('Rejouer'),
        );
    }
  }

  Widget _betPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Mise :',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Text(
                engine.bet.toString() + ' 🪙',
                style: const TextStyle(color: gold),
              ),
              const Spacer(),
              if (engine.bet > 0)
                TextButton(
                  onPressed: engine.clearBet,
                  child: const Text('Effacer'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in [10, 25, 50, 100])
                OutlinedButton(
                  onPressed: engine.bet + v > widget.bankroll.value
                      ? null
                      : () => engine.addToBet(v),
                  child: Text('+$v'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: (engine.bet >= 10 && engine.bet <= widget.bankroll.value)
                ? engine.deal
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: Color(0xFF052E16),
            ),
            child: const Text('Distribuer'),
          ),
          if (widget.bankroll.value < 10)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Banque insuffisante — rechargez-la depuis l’accueil.',
                style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: engine.hit,
            style: FilledButton.styleFrom(backgroundColor: greenAction),
            child: const Text('Carte'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: engine.stand,
            style: FilledButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: Color(0xFF052E16),
            ),
            child: const Text('Rester'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.tonal(
            onPressed:
                (engine.player.length == 2 && engine.bet <= widget.bankroll.value)
                    ? engine.doubleDown
                    : null,
            child: const Text('Doubler'),
          ),
        ),
      ],
    );
  }
}
