import 'package:flutter/material.dart';

import '../core/cards.dart';

/// Rendu d'une carte à jouer (ou d'un dos bleu motif « Z »).
class PlayingCardView extends StatelessWidget {
  final PlayingCard? card;
  final bool hidden;
  final double scale;

  const PlayingCardView({
    super.key,
    this.card,
    this.hidden = false,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final w = 54.0 * scale;
    final h = 76.0 * scale;
    final radius = BorderRadius.circular(8 * scale);

    if (hidden || card == null) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A8A), Color(0xFF172554)],
          ),
          borderRadius: radius,
          border: Border.all(color: gold.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          'Z',
          style: TextStyle(
            color: gold.withValues(alpha: 0.7),
            fontWeight: FontWeight.w900,
            fontSize: 18 * scale,
          ),
        ),
      );
    }

    final c = card!;
    final color = c.isRed ? const Color(0xFFDC2626) : const Color(0xFF0F172A);
    return Container(
      width: w,
      height: h,
      padding: EdgeInsets.all(4 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text(
              c.rankLabel,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13 * scale,
              ),
            ),
          ),
          Text(
            c.suitChar,
            style: TextStyle(color: color, fontSize: 22 * scale),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              c.rankLabel,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13 * scale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Emplacement vide (board pas encore distribué).
class CardPlaceholder extends StatelessWidget {
  const CardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
    );
  }
}
