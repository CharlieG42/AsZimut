# Publication Google Play — checklist AsZimut (WildZimut)

État au 27/11/2026. Le build CI produit un **AAB signé** (`build/aszimut.aab`, artefact
`aszimut-release-aab`) : `versionCode` = n° de run GitHub Actions (strictement croissant),
`targetSdk` = 36, arm64-v8a uniquement, package `com.wildzimut.aszimut`.

## 1. Compte développeur

- [ ] Compte Google Play Developer sous l'organisation **WildZimut** (frais uniques de 25 $,
      e-mail de l'organisation, vérification d'identité).
- [ ] Profil de paiement renseigné (pas de compte marchand nécessaire : l'app est gratuite,
      sans achats in-app).
- [ ] Informations fiscales (formulaire W-8BEN ou équivalent selon le pays de l'organisation).
- [ ] Coordonnées de contact (e-mail public affiché sur la fiche Play) et adresse postale.

## 2. Création de l'app dans la Play Console

- [ ] Nouvelle app : nom **AsZimut**, langue par défaut **français**, type **Jeu**,
      gratuit, sans achats in-app.
- [ ] Package : `com.wildzimut.aszimut` (déjà celui du préréglage d'export — ne jamais le changer,
      il est définitif).

## 3. Signature — Play App Signing (obligatoire)

- [ ] Lors de la création de l'app, **activer Play App Signing** : Google génère la clé de
      signature applicative (c'est elle qui signe les APK distribués aux utilisateurs).
- [ ] Créer **une seule fois** la clé d'upload et la conserver hors du dépôt (gestionnaire de
      mots de passe + copie chiffrée hors ligne — sa perte bloque les mises à jour) :

  ```bash
  keytool -genkeypair -keystore aszimut-upload.keystore -alias aszimut \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass <mot de passe> -keypass <mot de passe> \
    -dname "CN=AsZimut,O=WildZimut,C=FR"
  ```

- [ ] Ajouter les 4 secrets au dépôt GitHub (Settings → Secrets and variables → Actions) :
      `ANDROID_KEYSTORE_BASE64` (`base64 -w0 aszimut-upload.keystore`), `ANDROID_KEY_ALIAS`,
      `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD` (voir README). La CI signe alors l'AAB
      avec cette clé d'upload ; sans secrets valides, la CI signe avec une clé temporaire
      **à ne jamais uploader sur Play** (voir le résumé du run).

## 4. Upload du bundle

- [ ] Piste **Test interne** (Internal testing) → uploader l'artefact `aszimut-release-aab`
      du dernier run vert sur `main`. Play vérifie : AAB valide, `targetSdk` ≥ 36 (obligatoire
      pour les nouvelles apps depuis le 31/08/2026 ; API 35 mini depuis le 31/08/2025),
      64 bits, signature cohérente avec la clé d'upload.
- [ ] Ajouter les e-mails des testeurs, puis consulter le **rapport pre-launch** (crashs,
      sécurité, performances, accessibilité) et corriger ce qui est signalé.
- [ ] Ne jamais uploader manuellement un `versionCode` supérieur au prochain n° de run CI
      (sinon utiliser la variable de dépôt `PUSH_OFFSET`).

## 5. Contenu et déclarations (App content)

- [ ] **Public cible** : 18 ans et plus uniquement. Ne cocher aucun groupe < 18 ans et
      **ne pas s'inscrire au programme Designed for Families** (interdit avec du contenu de
      jeu d'argent, même simulé).
- [ ] **Classification du contenu (questionnaire IARC)** : déclarer le **jeu d'argent simulé**
      (cartes/roulette/baccarat avec jetons virtuels). Descripteur attendu : *Simulated
      Gambling*, classement probable **PEGI 18** / Mature 17+. Répondre honnêtement : un refus
      de classification bloque la publication dans le territoire concerné.
- [ ] **Règles applicables** : aucune mise d'argent réel, aucun gain à valeur réelle, aucun achat
      in-app, aucune publicité (notamment aucune pub de jeu d'argent réel) — déjà le cas de l'app.
- [ ] **Data safety** : aucune donnée collectée, transmise ou partagée. L'app est hors ligne ;
      banque, statistiques, profils et sauvegardes restent en local (`user://`), export/import
      manuel par code ou fichier. Seule permission déclarée dans le manifeste : `VIBRATE`
      (permission normale, sans impact Data safety).
- [ ] **Politique de confidentialité** : publier le brouillon
      [`privacy-policy.md`](privacy-policy.md) (GitHub Pages de ce dépôt ou site WildZimut) et
      coller l'URL dans la console (App content → Privacy policy).
- [ ] **Catégorie** : Jeux → **Casino** (déclaration de jeu d'argent simulé requise et cohérente).
- [ ] **Disponibilité** : tous les pays disponibles par défaut ; exclure ceux qui restreignent
      les contenus de jeu d'argent même simulés si la console le signale.
- [ ] **Fiche store listing** : voir [`store-listing.md`](store-listing.md) pour les textes FR/EN
      et les spécifications des visuels.

## 6. Visuels obligatoires (Main store listing)

- [ ] Icône **512 × 512 px**, PNG 32 bits **avec alpha**, ≤ 1 Mo (dérivée de `icon.svg`).
- [ ] **Feature graphic 1024 × 500 px**, PNG 24 bits ou JPEG **sans alpha**.
- [ ] **2 à 8 captures téléphone** : chaque côté entre 320 et 3840 px, ratio ≤ 2:1,
      JPEG ou PNG 24 bits sans alpha (ex. 1080 × 1920).
- [ ] Captures **7" et 10" recommandées** : le manifeste déclare `large`/`xlarge` (tablettes).
- [ ] Vidéo promo YouTube facultative.
- [ ] Titre ≤ 30 caractères, description courte ≤ 80 caractères, description longue ≤ 4000 caractères.

## 7. Mise en production

- [ ] Test interne OK → **Closed testing** (facultatif) ou directement **Production** en
      déploiement par étapes (ex. 20 % → 100 %).
- [ ] Surveiller les vitals (taux de crash/ANR) après la mise en ligne.
- [ ] Mises à jour suivantes : push sur `main` → nouveau run CI → nouvel AAB signé
      (`versionCode` auto) → upload sur la piste de production.
