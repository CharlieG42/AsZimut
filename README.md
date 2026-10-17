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
- Mise par jetons (10 / 25 / 50 / 100), banque commune de 1000 rechargeable.

### Poker Texas Hold'em (heads-up)
- Adversaire : **ZIA**. Blinds 10/20, donneur alterné, relances plafonnées à 3 par street.
- Gestion complète des tapis : runout du board, remboursement du trop-versé non couvert.
- Cave minimale 20 ; ZIA se recave automatiquement à 500.
- Quitter en pleine main revient à se coucher.

### IA (ZIA)
- **Pré-flop** : formule de **Chen** (0–20) pour estimer la force de la main de départ.
- **Post-flop** : **Monte-Carlo** (~200 simulations) sur la main + le board.
- Décisions par **cote du pot**, avec bluffs occasionnels (~13 %) et calls flottants (~10 %).

### Banque
La banque est commune aux deux jeux et **sauvegardée sur l'appareil** (`user://aszimut.cfg`).

## Structure

```
project.godot            # Réglages (portrait 540x960, renderer Compatibilité, autoload Bankroll)
export_presets.cfg       # Préréglage d'export Android (arm64, APK)
icon.svg
scenes/                  # home / blackjack / poker (un nœud Control + son script)
scripts/
├── bankroll_state.gd    # Autoload « Bankroll » : banque commune + sauvegarde
├── core/
│   ├── cards.gd         # Cartes = entiers 0..51, deck, mélange
│   ├── hand_evaluator.gd# Évaluateur 5/7 cartes (scores lexicographiques)
│   └── poker_ai.gd      # Formule de Chen + Monte-Carlo
├── games/
│   ├── blackjack_engine.gd  # Moteur blackjack (règles + croupier IA)
│   └── poker_engine.gd      # Moteur poker (machine à états + IA ZIA)
└── ui/
    ├── ui_kit.gd        # Palette feutre vert/or + fabriques de widgets
    ├── card_view.gd     # Carte dessinée en code (pas d'emoji ni d'image)
    ├── card_row.gd      # Rangée de cartes animée (apparition, retournement)
    ├── coin_label.gd    # « montant + jeton »
    ├── game_card.gd     # Tuile de l'accueil
    └── *_screen.gd      # Écrans accueil, blackjack, poker
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
3. Génère ou charge la clé de signature,
4. Exporte l'APK **release** (`arm64-v8a`),
5. Publie l'APK en artefact `aszimut-release-apk`.

### Clé de signature (recommandé)
Sans configuration, le workflow génère une clé temporaire : chaque APK a alors une signature
différente et il faut **désinstaller** l'ancienne version avant d'installer la nouvelle.
Pour garder la même signature, ajouter ces secrets au dépôt
(*Settings → Secrets and variables → Actions*) :

| Secret | Contenu |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | le fichier `.keystore` encodé en base64 (`base64 -w0 aszimut.keystore`) |
| `ANDROID_KEYSTORE_ALIAS` | l'alias de la clé |
| `ANDROID_KEYSTORE_PASSWORD` | le mot de passe (store et clé) |

## Roadmap

- [ ] Statistiques persistantes (victoires, banque max)
- [ ] Réglage du niveau de l'IA (agressivité, fréquence de bluff)
- [ ] Sons et effets (distribution, jetons)
- [ ] Plus de jeux (une future table de modules à la façon Sebae)

---
Prototype interactif de référence : canvas React « AsZimut » (spec avant portage).
