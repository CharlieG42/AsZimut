#!/usr/bin/env bash
# Choisit la clé de signature de l'APK et explique précisément quel secret pose problème.
# Entrées (variables d'environnement) : KS_B64, KS_ALIAS, KS_PASS, KEY_PASS, KS_FILE.
# Sorties (sur stdout, format KEY=VALUE, à ajouter à $GITHUB_ENV) : chemin, alias, mot de passe, mode.
# Les valeurs des secrets ne sont jamais affichées (seulement leur présence et les messages de keytool).
set -u

KS_FILE="${KS_FILE:-${RUNNER_TEMP:-/tmp}/aszimut-release.keystore}"
LOG="${SIGN_LOG:-/dev/stderr}"
say() { echo "$*" >> "$LOG"; }
warn() { echo "::warning::$*" >> "$LOG"; }
trim() { printf '%s' "$1" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

# Masque aussi les variantes nettoyées des secrets dans les journaux.
for v in "${KS_ALIAS:-}" "${KS_PASS:-}" "${KEY_PASS:-}"; do
  t="$(trim "$v")"
  [ -n "$t" ] && echo "::add-mask::$t" >> "$LOG"
done

MODE="temporaire"
REASON="aucun secret de signature"
DIAG=""

present() { if [ -n "$2" ]; then say "  - $1 : présent"; else say "  - $1 : ABSENT"; fi; }

try_secrets() {
  say "Diagnostic des secrets de signature :"
  present ANDROID_KEYSTORE_BASE64 "${KS_B64:-}"
  present ANDROID_KEY_ALIAS "${KS_ALIAS:-}"
  present ANDROID_STORE_PASSWORD "${KS_PASS:-}"
  present ANDROID_KEY_PASSWORD "${KEY_PASS:-}"

  if [ -z "${KS_B64:-}${KS_ALIAS:-}${KS_PASS:-}" ]; then
    REASON="aucun secret de signature"
    return 1
  fi
  for pair in "ANDROID_KEYSTORE_BASE64:${KS_B64:-}" "ANDROID_KEY_ALIAS:${KS_ALIAS:-}" "ANDROID_STORE_PASSWORD:${KS_PASS:-}"; do
    if [ -z "${pair#*:}" ]; then
      DIAG="${pair%%:*}"
      REASON="secret ${DIAG} manquant"
      return 1
    fi
  done

  # 1) Base64 → fichier. On tolère les retours à la ligne et les en-têtes « -----BEGIN … » (certutil sous Windows).
  printf '%s' "$KS_B64" | tr -d '\r' | grep -v -- '-----' | tr -d ' \n\t' > "$KS_FILE.b64"
  if ! base64 -d "$KS_FILE.b64" > "$KS_FILE" 2>/dev/null || [ ! -s "$KS_FILE" ]; then
    DIAG="ANDROID_KEYSTORE_BASE64"
    REASON="ANDROID_KEYSTORE_BASE64 n'est pas du base64 valide (refaire : base64 -w0 fichier.keystore, ou certutil -encode puis coller tout le texte)"
    return 1
  fi
  rm -f "$KS_FILE.b64"
  local magic size kind
  magic="$(head -c 4 "$KS_FILE" | od -An -tx1 | tr -d ' \n')"
  size="$(wc -c < "$KS_FILE" | tr -d ' ')"
  case "$magic" in
    feedfeed) kind="JKS" ;;
    cececece) kind="JCEKS" ;;
    30*) kind="PKCS12" ;;
    *) kind="inconnu" ;;
  esac
  say "  Keystore décodé : ${size} octets, format ${kind}."
  if [ "$kind" = "inconnu" ]; then
    DIAG="ANDROID_KEYSTORE_BASE64"
    REASON="ANDROID_KEYSTORE_BASE64 se décode, mais ce n'est pas un keystore (format inconnu, ${size} octets) : avez-vous encodé le bon fichier (.keystore / .jks) ?"
    return 1
  fi

  # 2) Mot de passe du keystore (on essaie aussi sans espaces ni retour à la ligne parasites).
  local out pass_ok=""
  for candidate in "$KS_PASS" "$(trim "$KS_PASS")"; do
    if out="$(keytool -list -keystore "$KS_FILE" -storepass "$candidate" 2>&1)"; then
      pass_ok="$candidate"
      break
    fi
  done
  if [ -z "$pass_ok" ]; then
    DIAG="ANDROID_STORE_PASSWORD"
    REASON="ANDROID_STORE_PASSWORD n'ouvre pas le keystore (keytool : $(printf '%s' "$out" | grep -i 'error\|exception' | head -1 | sed 's/^.*Exception: //'))"
    return 1
  fi
  if [ "$pass_ok" != "$KS_PASS" ]; then
    warn "ANDROID_STORE_PASSWORD contient des espaces ou un retour à la ligne en trop : corrigé automatiquement, mais pensez à le recoller proprement."
  fi
  KS_PASS="$pass_ok"

  # 3) Alias.
  local aliases alias_ok=""
  aliases="$(keytool -list -v -keystore "$KS_FILE" -storepass "$KS_PASS" 2>/dev/null | sed -n 's/^Alias name: //p; s/^Nom d.alias : //p')"
  for candidate in "$KS_ALIAS" "$(trim "$KS_ALIAS")"; do
    if keytool -list -keystore "$KS_FILE" -storepass "$KS_PASS" -alias "$candidate" > /dev/null 2>&1; then
      alias_ok="$candidate"
      break
    fi
  done
  if [ -z "$alias_ok" ]; then
    DIAG="ANDROID_KEY_ALIAS"
    REASON="ANDROID_KEY_ALIAS ne correspond à aucune clé du keystore. Alias présents : $(echo "$aliases" | paste -sd ',' - | sed 's/,/, /g')"
    return 1
  fi
  if [ "$alias_ok" != "$KS_ALIAS" ]; then
    warn "ANDROID_KEY_ALIAS contient des espaces ou un retour à la ligne en trop : corrigé automatiquement."
  fi
  KS_ALIAS="$alias_ok"

  # 4) Mot de passe de la clé : Godot n'en utilise qu'un, on aligne la clé sur le keystore (copie temporaire).
  if ! check_key "$KS_PASS"; then
    local fixed=""
    for candidate in "${KEY_PASS:-}" "$(trim "${KEY_PASS:-}")"; do
      [ -z "$candidate" ] && continue
      rm -f "$KS_FILE.new"
      if keytool -importkeystore -srckeystore "$KS_FILE" -srcstorepass "$KS_PASS" -srcalias "$KS_ALIAS" \
           -srckeypass "$candidate" -destkeystore "$KS_FILE.new" -deststoretype PKCS12 \
           -deststorepass "$KS_PASS" -destkeypass "$KS_PASS" -destalias "$KS_ALIAS" -noprompt > /dev/null 2>&1; then
        mv "$KS_FILE.new" "$KS_FILE"
        fixed="yes"
        break
      fi
      rm -f "$KS_FILE.new"
    done
    if [ -z "$fixed" ]; then
      DIAG="ANDROID_KEY_PASSWORD"
      if [ "$kind" = "PKCS12" ]; then
        REASON="ANDROID_KEY_PASSWORD incorrect : dans un keystore PKCS12 la clé a en général le même mot de passe que le keystore"
      else
        REASON="ANDROID_KEY_PASSWORD incorrect (ou absent alors que la clé a son propre mot de passe)"
      fi
      return 1
    fi
    say "  Mot de passe de clé aligné sur celui du keystore (copie temporaire, votre fichier n'est pas modifié)."
  fi
  say "  Tous les secrets sont valides."
  return 0
}

# Vrai si la clé s'ouvre avec ce mot de passe (export de la clé privée vers un PKCS12 jetable).
check_key() {
  local tmp="$KS_FILE.check.p12"
  rm -f "$tmp"
  keytool -importkeystore -srckeystore "$KS_FILE" -srcstorepass "$KS_PASS" -srcalias "$KS_ALIAS" \
    -srckeypass "$1" -destkeystore "$tmp" -deststoretype PKCS12 -deststorepass "tmp-check-pass" \
    -destkeypass "tmp-check-pass" -noprompt > /dev/null 2>&1
  local rc=$?
  rm -f "$tmp"
  return $rc
}

if try_secrets; then
  MODE="secrets"
  ALIAS="$KS_ALIAS"
  PASS="$KS_PASS"
  say "Signature avec la clé des secrets du dépôt."
else
  [ -n "$DIAG" ] && warn "Secret en cause : ${DIAG} — ${REASON}. Une clé temporaire est utilisée à la place."
  rm -f "$KS_FILE"
  ALIAS="aszimut"
  PASS="aszimut-ci"
  keytool -genkeypair -keystore "$KS_FILE" -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$PASS" -keypass "$PASS" -dname "CN=AsZimut,O=WildZimut,C=FR" > /dev/null 2>&1
  say "::notice::Signature avec une clé temporaire (${REASON}). Désinstaller l'ancienne version avant d'installer celle-ci."
fi

echo "GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$KS_FILE"
echo "GODOT_ANDROID_KEYSTORE_RELEASE_USER=$ALIAS"
echo "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$PASS"
echo "SIGN_MODE=$MODE"
echo "SIGN_ISSUE=${DIAG}"
echo "SIGN_REASON=${REASON}"
