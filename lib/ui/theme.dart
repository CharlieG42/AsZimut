import 'package:flutter/material.dart';

const feltDark = Color(0xFF04140C);
const feltGreen = Color(0xFF14532D);
const feltLight = Color(0xFF166534);
const gold = Color(0xFFF5C542);
const textSoft = Color(0xFFA7D7B8);
const danger = Color(0xFFDC2626);
const greenAction = Color(0xFF10B981);

ThemeData asZimutTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: feltGreen,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: feltDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: gold,
      elevation: 0,
      centerTitle: true,
    ),
  );
}
