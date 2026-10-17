import 'package:flutter/material.dart';

import '../app_state.dart';
import 'blackjack_screen.dart';
import 'poker_screen.dart';
import 'theme.dart';

class HomeScreen extends StatelessWidget {
  final Bankroll bankroll;

  const HomeScreen({super.key, required this.bankroll});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: bankroll,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),
                const Text(
                  '🂡',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 8),
                const Text(
                  'AsZimut',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: gold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Blackjack & Poker contre l’IA — WildZimut',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textSoft),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B3B22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: gold.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Banque : ' + bankroll.value.toString() + ' 🪙',
                        style: const TextStyle(
                          color: gold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (bankroll.value < 10) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton(
                      onPressed: () => bankroll.setTo(1000),
                      child: const Text('Recharger la banque (1000)'),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                _GameCard(
                  emoji: '♠️',
                  title: 'Blackjack',
                  subtitle:
                      'Battez le croupier — blackjack payé 3:2, double autorisé.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            BlackjackScreen(bankroll: bankroll),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _GameCard(
                  emoji: '🂠',
                  title: 'Poker Hold’em',
                  subtitle:
                      'Heads-up contre ZIA (Monte-Carlo + Chen), blinds 10/20.',
                  enabled: bankroll.value >= 20,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PokerScreen(bankroll: bankroll),
                      ),
                    );
                  },
                ),
                if (bankroll.value < 20)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Cave minimum : 20 🪙 — rechargez la banque pour jouer au poker.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _GameCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [feltLight, Color(0xFF022C22)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xFF064E3B)),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: gold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: textSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0x66A7D7B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
