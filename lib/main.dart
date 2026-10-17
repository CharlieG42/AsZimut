import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AsZimut',
      debugShowCheckedModeBanner: false,
      theme: asZimutTheme(),
      home: HomeScreen(bankroll: Bankroll(1000)),
    );
  }
}
