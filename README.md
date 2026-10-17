# 🂡 AsZimut

![Build APK](https://github.com/CharlieG42/AsZimut/actions/workflows/build-apk.yml/badge.svg)

**AsZimut** — l'As d'Azimut — est une application Android **WildZimut** (Flutter) pour jouer au
**Blackjack** et au **Poker Texas Hold'em heads-up** contre une IA.

## Jeux

### ♠️ Blackjack
- Croupier IA : tire jusqu'à 17, s'arrête sur un soft 17.
- Blackjack payé **3:2**, **double** autorisé sur les deux premières cartes.
- Mise par jetons (10 / 25 / 50 / 100), banque commune de 1000 🪙 rechargeable.

### 🂠 Poker Texas Hold'em (heads-up)
- Adversaire : **ZIA** 🤖. Blinds 10/20, donneur alterné, relances plafonnées à 3 par street.
- Gestion complète des tapis : runout du board, remboursement du trop-versé non couvert.
- Cave minimale 20 🪙 ; ZIA se recave automatiquement à 500 🪙.

### 🧠 IA (ZIA)
- **Pré-flop** : formule de **Chen** (0–20) pour estimer la force de la main de départ.
- **Post-flop** : **Monte-Carlo** (~200 simulations) sur la main + le board.
- Décisions par **cote du pot**, avec bluffs occasionnels (~13 %) et calls flottants (~10 %).

## Structure

```
lib/
├── main.dart                  # Point d'entrée
├── app_state.dart             # Banque commune (ChangeNotifier)
├── core/
│   ├── cards.dart             # Modèle carte, deck, mélange
│   ├── evaluator.dart         # Évaluateur 5/7 cartes (scores lexicographiques)
│   └── ai_poker.dart          # Formule de Chen + Monte-Carlo
├── games/
│   ├── blackjack.dart         # Moteur blackjack (règles + croupier IA)
│   └── poker.dart             # Moteur poker (machine à états + IA ZIA)
└── ui/
    ├── theme.dart             # Thème "felt" vert/or
    ├── card_widget.dart       # Rendu d'une carte
    ├── home_screen.dart       # Accueil
    ├── blackjack_screen.dart  # Écran blackjack
    └── poker_screen.dart      # Écran poker
```

## Démarrage

Le dépôt ne contient pas le dossier `android/` (généré par Flutter pour rester portable) :

```bash
flutter create --platforms=android --org com.wildzimut --project-name aszimut .
flutter pub get
flutter run
```

## CI/CD

Le workflow [Build APK](.github/workflows/build-apk.yml) :
1. Génère la plateforme Android (`flutter create`),
2. Lance `flutter analyze` (non bloquant, comme sur les autres projets WildZimut),
3. Compile l'APK release (`flutter build apk --release`),
4. Publie l'APK en artefact + les logs de build en cas d'échec.

## Roadmap

- [ ] Persistance des statistiques (victoires, banque max) — Hive, comme Sebae
- [ ] Réglage du niveau de l'IA (agressivité, fréquence de bluff)
- [ ] Plus de jeux (une future table deModuleRegistry ? à la façon Sebae)
- [ ] Signature release via `key.properties` (comme BaroudeurStudio)

---
Prototype interactif de référence : canvas React « AsZimut » (spec avant portage).
