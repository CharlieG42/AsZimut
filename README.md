# AsZimut

![Build APK](https://github.com/CharlieG42/AsZimut/actions/workflows/build-apk.yml/badge.svg)

**AsZimut** — l'As d'Azimut — est une application Android **WildZimut** (**Godot 4.4**, GDScript) pour jouer au
**Blackjack** et au **Poker Texas Hold'em heads-up** contre une IA.

> La première version, écrite en Flutter, est conservée dans la branche
> [`flutter-backup`](../../tree/flutter-backup). `main` est désormais la version Godot.

## Jeux

### Blackjack
- Croupier IA : tire jusqu'à 17, s'arrête sur un soft 17.
- Blackjack payé **3:2**, **double** autorisé sur les deux premières cartes (aussi après un split).
- **Split** d'une paire en deux mains (une fois ; As séparés = une carte chacun), **assurance** quand le croupier montre un As (moitié de la mise, payée 2:1), conseils de stratégie de base pour les deux. Aussi disponibles au blackjack local à plusieurs (les bots séparent selon la stratégie de base et refusent l'assurance).
- Si l'appli est fermée en pleine manche, la mise est rendue au lancement suivant.
- Mise par jetons de casino (10 / 25 / 50 / 100) avec pile de mise, banque commune de 1000 rechargeable.

### Poker Texas Hold'em (face-à-face ou table solo)
La tuile Poker propose le **face-à-face contre ZIA** ou une **table à 4 ou 6** (3 ou 5 ZIA, cave de 1000 max prise sur la banque, blinds croissantes ; la banque suit votre pile pendant la partie).

- Adversaire : **ZIA**. Blinds 10/20, donneur alterné, relances plafonnées à 3 par street.
- Gestion complète des tapis : runout du board, remboursement du trop-versé non couvert.
- Cave minimale 20 ; ZIA se recave automatiquement à 500.
- Relance au **curseur** (min → tapis) avec raccourcis ½ pot / Pot / Tapis.
- Indication de votre meilleure main en cours (« Paire de Rois »…).
- Quitter en pleine main revient à se coucher.

### Three Card Poker (contre le croupier)
Poker à **3 cartes** contre la banque, avec les jetons de votre banque :
- **Ante** (obligatoire) et **Pair Plus** (facultatif). Après avoir vu vos 3 cartes, vous **jouez** (seconde mise égale à l'Ante) ou vous **vous couchez** (Ante perdue). Il faut donc pouvoir couvrir le Jeu : l'Ante ne dépasse pas la moitié de la banque.
- Le croupier se qualifie avec **Dame haute ou mieux**. Non qualifié : Ante payée 1:1, Jeu rendu. Qualifié : il faut le battre (Ante et Jeu 1:1), égalité = tout rendu.
- Mains : quinte flush > brelan > quinte > couleur > paire > hauteur (A-2-3 est la plus petite quinte).
- **Bonus d'Ante** (quinte 1:1, brelan 4:1, quinte flush 5:1), payé quand on joue même si le croupier gagne. **Pair Plus** indépendant du croupier : paire 1:1, couleur 4:1, quinte 6:1, brelan 30:1, quinte flush 40:1.
- Mode débutant : conseil « jouer dès Dame-6-4 ». Statistiques globales et par joueur (couchés, Pair Plus gagnés), 3 succès.

### Dutch (variante « Cabo », 2 à 5 joueurs)
Jeu de mémoire sans mise : **le moins de points gagne**. Disponible **seul contre ZIA** (tuile de l'accueil) ou **à plusieurs sur le même appareil** (Multijoueur local → Dutch, avec sièges IA possibles).
- 4 cartes face cachées par joueur, 2 connues au départ (pastille dorée = carte mémorisée, affichée face visible pour son propriétaire).
- Un tour : piocher ou prendre la défausse, puis échanger avec une de ses cartes (ou défausser la carte piochée).
- Valeurs : As 1, 2 à 10 = numéro, Valet 11, Dame 12, Roi noir 13, **Roi rouge 0**.
- Pouvoirs d'une carte piochée puis défaussée : 7/8 regarder une des siennes, 9/10 regarder un adversaire, Valet/Dame échange à l'aveugle, Roi noir regarder puis échanger.
- **DUTCH** : à partir de son 2e tour, on peut l'annoncer ; les autres jouent un dernier tour. Preneur seul au plus bas : 0 ; sinon total + 10. La partie s'arrête au score cible (30, 50 ou 100).
- ZIA retient les cartes vues (avec des oublis aux niveaux faibles) et n'annonce Dutch que sur une main estimée très basse. Règles retenues : pas de « tape » (jouer en simultané n'a pas de sens sur un seul appareil).

### Multijoueur local (même appareil, hors ligne)
Bouton « Multijoueur local » de l'accueil : on choisit le jeu, le nombre de joueurs, leurs noms et les jetons de départ.
La partie est indépendante de la banque et des statistiques solo.
- **Blackjack, 2 à 5 joueurs** contre le croupier : chacun a sa pile, mise puis joue à son tour (carte, rester, doubler).
- **Poker Hold'em, 2 à 6 joueurs** : tapis, pots annexes, relance au curseur, blinds qui augmentent toutes les 8 mains,
  éliminations et classement final.
- **Écran « passez l'appareil »** avant chaque tour de poker et de Dutch : les cartes ne sont visibles que pour le joueur dont c'est le tour.
- **Joueurs IA** : chaque siège peut être « Humain » ou « IA » (ZIA). Au poker, les IA jouent avec la formule de Chen et le Monte-Carlo, plus prudemment à plusieurs ; au blackjack, elles suivent la stratégie de base (avec des erreurs aux niveaux faibles). Leur niveau se règle dans Options. La partie s'arrête quand il ne reste plus d'humain.
- Quitter avant la fin (deux appuis) rend les mises en cours et affiche le classement.

### Aide, mode débutant et tutoriel
- **Tutoriel au lancement** : 7 pages (règles du blackjack, du poker, du Three Card Poker et de Dutch, classement des mains, multijoueur et aide). Une case « Ne plus afficher au démarrage » le désactive ; **Options → « Revoir le tutoriel »** le relance à tout moment (et « Afficher le tutoriel au démarrage » le réactive).
- **Bouton « ? »** dans chaque partie : rappel des règles (et du classement des mains au poker).
- **Écran Options** en trois onglets sous un en-tête fixe : **Réglages**, **Statistiques** (banque, courbe, stats par jeu) et **Succès**.
  Défilement tactile maison (`TouchScroll`) : on fait glisser la page en partant de n'importe où, même d'un bouton
  (qui n'est alors pas activé), avec élan au lâcher ; la position est conservée quand un réglage change.
- **Mode débutant** (Options, aide en jeu ou fin de tutoriel) : un bandeau « Conseil » explique la meilleure décision : stratégie de base au blackjack (tirer, rester, doubler et pourquoi), force de la main et cote du pot au poker.

### IA (ZIA)
- **Pré-flop** : formule de **Chen** (0–20) pour estimer la force de la main de départ.
- **Post-flop** : **Monte-Carlo** (~200 simulations) sur la main + le board.
- Décisions par **cote du pot**, avec bluffs occasionnels et calls flottants.
- **3 niveaux** réglables (Facile / Normal / Difficile) : nombre de simulations, bluff, seuils et bruit de jugement.

### Joueurs enregistrés (progression d'une rencontre à l'autre)
Un **carnet de joueurs** illimité, sur l'appareil (`user://aszimut_profiles.json`) :
- En préparant une partie locale, les nouveaux noms sont **enregistrés** (case cochée par défaut).
- **Groupes récents** (« Papa · Lou · Tom », « Julie · Marc · Sophie ») : un appui replace tout le groupe à table.
  On peut aussi toucher un joueur du carnet pour l'ajouter ou le retirer.
- Chaque joueur garde ses **statistiques** par jeu (parties, victoires, gains, meilleur total au Dutch).
- Option **« Banques perso »** (blackjack et poker) : chacun joue avec sa banque personnelle et la retrouve
  à la prochaine partie (rechargée à 1000 si elle passe sous 100). Invités et ZIA partent avec la mise choisie.
- Chaque joueur garde le **même détail que l'appareil** (victoires, défaites, égalités, blackjacks, plus gros pot, parts égales…)
  et un **historique de ses gains cumulés** (blackjack + poker, jusqu'à 300 parties, parties locales comprises).
  Options → **Statistiques** : des boutons permettent d'afficher l'appareil entier ou un joueur, avec sa courbe de gains cumulés.
- Écran **Joueurs** (depuis l'accueil, la préparation de partie ou Options) : progression, renommer, remettre la banque à 1000, supprimer.
- **Joueur actif en solo** : le bouton « Joueur : … » de l'accueil permet de créer un joueur et de choisir qui joue
  contre ZIA (ou « invité » sans profil). Le joueur actif donne son nom à la table (Blackjack, Poker, Three Card, Dutch), sa banque
  personnelle devient la banque solo (la banque d'invité est conservée à part) et ses résultats solo s'ajoutent à ses
  statistiques. Le premier joueur créé depuis l'écran Joueurs devient actif ; il est inclus dans la sauvegarde.
  En multijoueur local, le joueur actif est placé d'office au premier siège (retirable d'un appui).

### Sauvegarde : export / import
Options → Réglages → **Sauvegarde des données** :
- **Exporter** : « Copier le code de sauvegarde » met dans le presse-papiers un code compact (`AZSAVE1:…`, JSON compressé)
  contenant banque, statistiques, succès, réglages et joueurs enregistrés. À coller dans une note, un mail, un message…
  Si le téléphone propose le sélecteur de fichiers natif, « Enregistrer dans un fichier… » produit aussi un `.json`.
- **Importer** : coller le code (le texte autour et les retours à la ligne sont tolérés), « Lire le code » montre un résumé, puis
  **Remplacer toutes mes données** (nouveau téléphone, avec confirmation) ou **Ajouter seulement les joueurs** (fusion des carnets
  de deux appareils : un joueur déjà présent garde sa version jouée le plus récemment ; banque et stats inchangées).

### Reprise de partie
Les parties longues (multijoueur local, Dutch, table de poker solo) sont **sauvegardées au début de chaque main ou manche**.
Si Android ferme l'appli, l'accueil propose « ▶ Reprendre » : la main / manche en cours redémarre avec les piles
(ou scores) du moment où elle a commencé. « ✕ » abandonne la sauvegarde.

### Sons
Sons de cartes, de jetons, de boutons et de fin de manche **synthétisés en code** (aucun fichier audio) ;
désactivables dans Options (« Sons »).

### Banque
La banque est commune aux deux jeux et **sauvegardée sur l'appareil** (`user://aszimut.cfg`), avec le **record** de banque.

### Succès et courbe de la banque
12 **succès** (premier blackjack, gros pot, table solo gagnée, annonce DUTCH gagnante…) : un bandeau
« Succès débloqué » s'affiche quel que soit l'écran, et la liste est dans Options. Options montre aussi
la **courbe de la banque** sur les 80 dernières manches solo et les **statistiques Dutch** (parties contre ZIA).

### Animations
Les cartes **glissent depuis le sabot** l'une après l'autre à la distribution, et se retournent quand elles sont révélées.

### Statistiques et réglages
Écran « Options & statistiques » : parties, victoires, gains nets, plus gros pot, niveau de ZIA (aussi pour les bots),
vibrations, sons, mode débutant, tutoriel, et réinitialisation en deux étapes (`user://aszimut_stats.cfg`).

## Structure

```
project.godot            # Réglages (portrait 540x960, renderer Compatibilité, autoloads Bankroll et Stats)
export_presets.cfg       # Préréglage d'export Android (arm64, APK)
icon.svg
scenes/                  # home / blackjack / poker / dutch / about / stats (Options) / setup / multi_* / results / tutorial (un nœud Control + son script)
scripts/
├── bankroll_state.gd    # Autoload « Bankroll » : banque commune + record + sauvegarde
├── local_session.gd     # Paramètres de la partie multijoueur locale (jeu, joueurs, jetons, classement)
├── stats_state.gd       # Autoload « Stats » : statistiques + réglages (niveau IA, vibrations)
├── core/
│   ├── blackjack_advisor.gd # Stratégie de base : conseils débutant + cerveau des bots
│   ├── poker_advisor.gd     # Force de main, cote du pot, action recommandée
│   ├── cards.gd         # Cartes = entiers 0..51, deck, mélange
│   ├── hand_evaluator.gd# Évaluateur 5/7 cartes (scores lexicographiques)
│   └── poker_ai.gd      # Formule de Chen + Monte-Carlo
├── games/
│   ├── blackjack_engine.gd        # Moteur blackjack (règles + croupier IA)
│   ├── poker_engine.gd            # Moteur poker heads-up (machine à états + IA ZIA)
│   ├── multi_blackjack_engine.gd  # Blackjack 2–5 joueurs (même appareil)
│   ├── poker_table_engine.gd      # Poker 2–6 joueurs : blinds croissantes, pots annexes
│   ├── three_card_engine.gd       # Three Card Poker : mains, Ante / Jeu / Pair Plus
│   └── dutch_engine.gd            # Dutch 2–5 joueurs : pouvoirs, mémoire, IA
└── ui/
    ├── ui_kit.gd        # Palette feutre vert/or + fabriques de widgets
    ├── card_view.gd     # Carte dessinée en code (pas d'emoji ni d'image)
    ├── card_row.gd      # Rangée de cartes animée (apparition, retournement)
    ├── help_content.gd / help_view.gd / help_overlay.gd  # Règles, bouton « ? »
    ├── tutorial_screen.gd   # Tutoriel de démarrage
    ├── dutch_screen.gd / card_button.gd  # Dutch (solo et local) et carte tapable
    ├── about_screen.gd      # À propos : version 0.0.01.PR.PUSH (scripts/app_info.gd)
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
4. Numérote la version `0.0.01.xxx.yyy` (affichée dans **À propos**) : `xxx` = numéro de la dernière PR fusionnée (API GitHub), `yyy` = numéro du run (= du push). Décalages réglables via les variables de dépôt `PR_OFFSET` et `PUSH_OFFSET` (Settings → Variables → Actions) ; sans réponse de l'API, `xxx` vaut 000. `versionCode` = numéro de run. En local : `0.0.01.000.000`.
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
| `ANDROID_KEY_ALIAS` | l'alias de la clé |
| `ANDROID_STORE_PASSWORD` | le mot de passe du keystore |
| `ANDROID_KEY_PASSWORD` | le mot de passe de la clé (peut différer ; le workflow l'aligne) |

Le script [`.github/scripts/signing.sh`](.github/scripts/signing.sh) vérifie les secrets **un par un** et
indique dans le résumé du run lequel pose problème : base64 illisible ou fichier qui n'est pas un keystore,
mot de passe du keystore refusé, alias absent (avec la liste des alias trouvés), ou mot de passe de clé
incorrect. Les espaces et retours à la ligne collés par erreur sont corrigés automatiquement. Les valeurs
des secrets ne sont jamais affichées.

Encoder le keystore : `base64 -w0 aszimut.keystore` (Linux), `base64 -i aszimut.keystore` (macOS) ou
`certutil -encode aszimut.keystore out.txt` (Windows, coller tout le contenu de `out.txt`).

## Roadmap

- [x] Sons (cartes, jetons, résultats)
- [x] Animation de distribution des cartes
- [x] Statistiques Dutch, succès, courbe de la banque
- [x] Split et assurance au blackjack local à plusieurs
- [ ] Animation des jetons vers le pot
- [ ] Plus de jeux (une future table de modules à la façon Sebae)

---
Prototype interactif de référence : canvas React « AsZimut » (spec avant portage).
