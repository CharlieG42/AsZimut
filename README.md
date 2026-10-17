# AsZimut

![Build APK](https://github.com/CharlieG42/AsZimut/actions/workflows/build-apk.yml/badge.svg)

**AsZimut** — l'As d'Azimut — est une application Android **WildZimut** (**Godot 4.4**, GDScript) pour jouer au
**Blackjack** et au **Poker Texas Hold'em heads-up** contre une IA.

> La première version, écrite en Flutter, est conservée dans la branche
> [`flutter-backup`](../../tree/flutter-backup). `main` est désormais la version Godot.

## Jeux

### Blackjack
- Croupier IA : tire jusqu'à 17, s'arrête sur un soft 17.
- Blackjack payé **3:2**, **double** autorisé sur les deux premières cartes.
- Mise par jetons de casino (10 / 25 / 50 / 100) avec pile de mise, banque commune de 1000 rechargeable.

### Poker Texas Hold'em (heads-up)
- Adversaire : **ZIA**. Blinds 10/20, donneur alterné, relances plafonnées à 3 par street.
- Gestion complète des tapis : runout du board, remboursement du trop-versé non couvert.
- Cave minimale 20 ; ZIA se recave automatiquement à 500.
- Relance au **curseur** (min → tapis) avec raccourcis ½ pot / Pot / Tapis.
- Indication de votre meilleure main en cours (« Paire de Rois »…).
- Quitter en pleine main revient à se coucher.

### Multijoueur local (même appareil, hors ligne)
Bouton « Multijoueur local » de l'accueil : on choisit le jeu, le nombre de joueurs, leurs noms et les jetons de départ.
La partie est indépendante de la banque et des statistiques solo.
- **Blackjack, 2 à 5 joueurs** contre le croupier : chacun a sa pile, mise puis joue à son tour (carte, rester, doubler).
- **Poker Hold'em, 2 à 6 joueurs** : tapis, pots annexes, relance au curseur, blinds qui augmentent toutes les 8 mains,
  éliminations et classement final.
- **Écran « passez l'appareil »** avant chaque tour de poker : les cartes ne sont visibles que pour le joueur dont c'est le tour.
- Quitter avant la fin (deux appuis) rend les mises en cours et affiche le classement.

### IA (ZIA)
- **Pré-flop** : formule de **Chen** (0–20) pour estimer la force de la main de départ.
- **Post-flop** : **Monte-Carlo** (~200 simulations) sur la main + le board.
- Décisions par **cote du pot**, avec bluffs occasionnels et calls flottants.
- **3 niveaux** réglables (Facile / Normal / Difficile) : nombre de simulations, bluff, seuils et bruit de jugement.

### Banque
La banque est commune aux deux jeux et **sauvegardée sur l'appareil** (`user://aszimut.cfg`), avec le **record** de banque.

### Statistiques et réglages
Écran « Statistiques & réglages » : parties, victoires, gains nets, plus gros pot, niveau de ZIA,
vibrations, et réinitialisation en deux étapes (`user://aszimut_stats.cfg`).

## Structure

```
project.godot            # Réglages (portrait 540x960, renderer Compatibilité, autoloads Bankroll et Stats)
export_presets.cfg       # Préréglage d'export Android (arm64, APK)
icon.svg
scenes/                  # home / blackjack / poker / stats / setup / multi_* / results (un nœud Control + son script)
scripts/
├── bankroll_state.gd    # Autoload « Bankroll » : banque commune + record + sauvegarde
├── local_session.gd     # Paramètres de la partie multijoueur locale (jeu, joueurs, jetons, classement)
├── stats_state.gd       # Autoload « Stats » : statistiques + réglages (niveau IA, vibrations)
├── core/
│   ├── cards.gd         # Cartes = entiers 0..51, deck, mélange
│   ├── hand_evaluator.gd# Évaluateur 5/7 cartes (scores lexicographiques)
│   └── poker_ai.gd      # Formule de Chen + Monte-Carlo
├── games/
│   ├── blackjack_engine.gd        # Moteur blackjack (règles + croupier IA)
│   ├── poker_engine.gd            # Moteur poker heads-up (machine à états + IA ZIA)
│   ├── multi_blackjack_engine.gd  # Blackjack 2–5 joueurs (même appareil)
│   └── poker_table_engine.gd      # Poker 2–6 joueurs : blinds croissantes, pots annexes
└── ui/
    ├── ui_kit.gd        # Palette feutre vert/or + fabriques de widgets
    ├── card_view.gd     # Carte dessinée en code (pas d'emoji ni d'image)
    ├── card_row.gd      # Rangée de cartes animée (apparition, retournement)
    ├── coin_label.gd    # « montant + jeton » (compteur animé)
    ├── chip_button.gd   # Jeton de casino cliquable
    ├── chip_pile.gd     # Piles de jetons pour une mise / un pot
    ├── avatar_badge.gd  # Visage de ZIA
    ├── game_card.gd     # Tuile de l'accueil
    └── *_screen.gd      # Écrans : accueil, solo, stats, configuration, multijoueur, classement
tests/
├── run_tests.gd         # Tests logiques (évaluateur, moteurs, simulations)
└── smoke_test.gd        # Parcourt les écrans en appuyant sur les vrais boutons
```

Les moteurs (`*_engine.gd`) ne dépendent pas de l'interface : ils émettent un signal `changed`
et les écrans se redessinent. Les cartes, jetons et symboles sont dessinés en code, donc
aucune police d'emoji n'est requise sur l'appareil.

## Développement

Ouvrir le dossier dans **Godot 4.4** (ou plus récent) et lancer la scène principale (`scenes/home.tscn`).

Tests en ligne de commande (sans fenêtre) :

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/smoke_test.gd
```

## CI/CD

Le workflow [Build APK](.github/workflows/build-apk.yml) (image `barichello/godot-ci`) :
1. Prépare les templates d'export et les réglages Android,
2. Importe le projet, lance les **tests logiques** et le **test de fumée** (bloquants),
3. Choisit la clé de signature (voir ci-dessous),
4. Numérote la version (`versionCode` = numéro de run, `versionName` = `config/version` du projet),
5. Exporte l'APK **release** (`arm64-v8a`),
6. Publie l'APK en artefact `aszimut-release-apk` et un résumé dans l'onglet du run.

### Clé de signature : avec ou sans secrets
Le workflow **réussit dans les deux cas** :
- **Secrets absents, incomplets ou invalides** (mauvais mot de passe, alias inconnu…) : une
  clé temporaire est générée et un avertissement s'affiche. Chaque APK a alors une signature
  différente : il faut **désinstaller** l'ancienne version avant d'installer la nouvelle.
- **Secrets valides** : la clé est vérifiée avec `keytool` puis utilisée, la signature reste
  identique d'une version à l'autre et l'APK se met à jour par-dessus l'ancien.

Pour garder la même signature, ajouter ces secrets au dépôt
(*Settings → Secrets and variables → Actions*) :

| Secret | Contenu |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | le fichier `.keystore` encodé en base64 (`base64 -w0 aszimut.keystore`) |
| `ANDROID_KEYSTORE_ALIAS` | l'alias de la clé |
| `ANDROID_KEYSTORE_PASSWORD` | le mot de passe (store et clé) |

## Roadmap

- [ ] Sons et effets (distribution, jetons)
- [ ] Plus de jeux (une future table de modules à la façon Sebae)

---
Prototype interactif de référence : canvas React « AsZimut » (spec avant portage).
