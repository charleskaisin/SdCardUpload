#!/bin/bash

# Prépare la carte SD CK sans la reformater.
# Efface tous les éléments, copie une vidéo, vérifie la copie,
# supprime les fichiers invisibles de macOS et éjecte la carte.

set -u
shopt -s nullglob dotglob

VOLUME_NAME="CK"
VOLUME="/Volumes/$VOLUME_NAME"
DEFAULT_VIDEO="$HOME/Downloads/love.mov"
MARKER_SPOTLIGHT="$VOLUME/.metadata_never_index"
MARKER_FSEVENTS="$VOLUME/.fseventsd"
MARKER_TRASH="$VOLUME/.Trashes"
TOOL_VERSION="8"
DELETE_PERMISSION_DENIED=0

pause_before_close() {
  printf '\nAppuyez sur la touche Entrée pour fermer cette fenêtre.'
  if /usr/bin/tty -s; then
    IFS= read -r _unused </dev/tty || true
  fi
}

fail() {
  printf '\n\nERREUR : %s\n' "$1" >&2
  pause_before_close
  exit 1
}

run_with_elapsed_time() {
  local label="$1"
  shift
  local seconds=0
  local minutes=0
  local remainder=0
  local command_pid
  local result

  "$@" &
  command_pid=$!

  while /bin/kill -0 "$command_pid" >/dev/null 2>&1; do
    minutes=$((seconds / 60))
    remainder=$((seconds % 60))
    printf '\r%s — %02d:%02d écoulées' "$label" "$minutes" "$remainder"
    /bin/sleep 1
    seconds=$((seconds + 1))
  done

  wait "$command_pid"
  result=$?
  minutes=$((seconds / 60))
  remainder=$((seconds % 60))
  printf '\r%s — terminé en %02d:%02d%20s\n' "$label" "$minutes" "$remainder" ""
  return "$result"
}

collect_items_except() {
  local keep_path="$1"
  local keep_spotlight_marker="${2:-no}"
  local item

  EXTRA_ITEMS=()

  for item in "$VOLUME"/*; do
    [ -n "$keep_path" ] && [ "$item" = "$keep_path" ] && continue

    if [ "$keep_spotlight_marker" = "yes" ]; then
      [ "$item" = "$MARKER_SPOTLIGHT" ] && [ -f "$MARKER_SPOTLIGHT" ] && continue
      [ "$item" = "$MARKER_FSEVENTS" ] && [ -f "$MARKER_FSEVENTS/no_log" ] && continue
      [ "$item" = "$MARKER_TRASH" ] && [ -f "$MARKER_TRASH" ] && continue
    fi

    EXTRA_ITEMS+=("$item")
  done
}

remove_collected_items_normally() {
  local item
  local result=0

  for item in "${EXTRA_ITEMS[@]}"; do
    printf '  Suppression : %s\n' "$(/usr/bin/basename "$item")"
    /bin/rm -rf -- "$item" >/dev/null 2>&1 || result=1
  done

  return "$result"
}

remove_collected_items_as_admin() {
  [ "${#EXTRA_ITEMS[@]}" -gt 0 ] || return 0

  local admin_log="/tmp/preparer-carte-sd-admin-$$.log"
  local admin_result=0

  printf '\nmacOS protège encore %d élément(s), souvent un dossier Spotlight.\n' "${#EXTRA_ITEMS[@]}"
  printf 'Une fenêtre va demander le mot de passe de la session pour terminer le nettoyage.\n'

  /usr/bin/osascript - "$VOLUME" "${EXTRA_ITEMS[@]}" >"$admin_log" 2>&1 <<'APPLESCRIPT'
use scripting additions
on run argv
    set volumePath to item 1 of argv
    set itemPaths to items 2 thru -1 of argv
    set spotlightPath to volumePath & "/.Spotlight-V100"
    set containsSpotlight to false
    set repairCommand to "/bin/chflags -R nouchg,noschg"
    set aclCommand to "/bin/chmod -RN"
    set modeCommand to "/bin/chmod -R u+rwX"
    set xattrCommand to "/usr/bin/xattr -cr"
    set removeCommand to "/bin/rm -rf"
    set absentCommand to ""

    repeat with itemPath in itemPaths
        set quotedPath to quoted form of (contents of itemPath)
        set repairCommand to repairCommand & " " & quotedPath
        set aclCommand to aclCommand & " " & quotedPath
        set modeCommand to modeCommand & " " & quotedPath
        set xattrCommand to xattrCommand & " " & quotedPath
        set removeCommand to removeCommand & " " & quotedPath
        if absentCommand is not "" then set absentCommand to absentCommand & " && "
        set absentCommand to absentCommand & "/bin/test ! -e " & quotedPath

        if (contents of itemPath) is spotlightPath then
            set containsSpotlight to true
        end if
    end repeat

    set shellCommand to ""

    if containsSpotlight then
        -- mdutil is the supported way to remove a protected Spotlight index.
        -- Perl's alarm guarantees that it cannot hang for more than 12 seconds.
        set alarmProgram to "alarm 12; exec @ARGV"
        set shellCommand to "/usr/bin/perl -e " & quoted form of alarmProgram & ¬
            " /usr/bin/mdutil -i off " & quoted form of volumePath & ¬
            " >/dev/null 2>&1; /usr/bin/perl -e " & quoted form of alarmProgram & ¬
            " /usr/bin/mdutil -X " & quoted form of volumePath & ¬
            " >/dev/null 2>&1; "
    end if

    set shellCommand to shellCommand & repairCommand & " >/dev/null 2>&1; " & ¬
        aclCommand & " >/dev/null 2>&1; " & modeCommand & " >/dev/null 2>&1; " & ¬
        xattrCommand & " >/dev/null 2>&1; " & ¬
        "attempt=1; while /bin/test $attempt -le 3; do " & removeCommand & ¬
        "; " & absentCommand & " && exit 0; /bin/sleep 1; attempt=$((attempt + 1)); done; exit 1"
    do shell script shellCommand with administrator privileges
end run
APPLESCRIPT

  admin_result=$?
  [ -s "$admin_log" ] && /bin/cat "$admin_log" >&2

  if /usr/bin/grep -qi 'Operation not permitted' "$admin_log" 2>/dev/null; then
    DELETE_PERMISSION_DENIED=1
  fi

  /bin/rm -f -- "$admin_log" >/dev/null 2>&1 || true
  return "$admin_result"
}

disable_spotlight_temporarily() {
  # On pose d’abord le marqueur : Spotlight cesse ainsi de recréer son index
  # pendant que la carte est préparée. mdutil est borné à 12 secondes.
  /usr/bin/touch "$MARKER_SPOTLIGHT" 2>/dev/null || return 1
  /usr/bin/perl -e 'alarm 12; exec @ARGV' \
    /usr/bin/mdutil -i off "$VOLUME" >/dev/null 2>&1 || true
}

create_temporary_guards() {
  local attempt=1

  /bin/mkdir -p "$MARKER_FSEVENTS" 2>/dev/null || return 1
  /usr/bin/touch "$MARKER_FSEVENTS/no_log" "$MARKER_SPOTLIGHT" 2>/dev/null || return 1

  # Un simple fichier nommé .Trashes empêche macOS de recréer sa corbeille
  # pendant la copie. Il sera supprimé juste avant l’éjection.
  while [ "$attempt" -le 3 ]; do
    if [ -d "$MARKER_TRASH" ]; then
      EXTRA_ITEMS=("$MARKER_TRASH")
      remove_collected_items_normally || true
      [ ! -e "$MARKER_TRASH" ] || remove_collected_items_as_admin || return 1
    fi

    if [ ! -e "$MARKER_TRASH" ]; then
      /usr/bin/touch "$MARKER_TRASH" 2>/dev/null || true
    fi

    [ -f "$MARKER_TRASH" ] && return 0
    /bin/sleep 1
    attempt=$((attempt + 1))
  done

  return 1
}

show_permission_help() {
  printf '\nACCÈS BLOQUÉ PAR macOS\n'
  printf 'Le mot de passe administrateur ne peut pas contourner ce réglage de confidentialité.\n'
  printf 'Ouvrez Réglages Système > Confidentialité et sécurité > Fichiers et dossiers.\n'
  printf 'Pour Terminal, activez « Volumes amovibles », puis relancez cet outil.\n'
  printf 'Sur certaines versions de macOS, ce réglage se trouve dans Général > Stockage.\n'
  /usr/bin/open 'x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders' \
    >/dev/null 2>&1 || true
}

fail_cleaning() {
  [ "$DELETE_PERMISSION_DENIED" -eq 0 ] || show_permission_help
  fail "$1"
}

remove_items_except() {
  local keep_path="$1"
  local keep_markers="${2:-no}"

  collect_items_except "$keep_path" "$keep_markers"
  [ "${#EXTRA_ITEMS[@]}" -gt 0 ] || return 0

  remove_collected_items_normally || true
  collect_items_except "$keep_path" "$keep_markers"

  if [ "${#EXTRA_ITEMS[@]}" -gt 0 ]; then
    remove_collected_items_as_admin || return 1
  fi

  collect_items_except "$keep_path" "$keep_markers"
  [ "${#EXTRA_ITEMS[@]}" -eq 0 ]
}

eject_after_sync() {
  if ! run_with_elapsed_time "Synchronisation des données" /bin/sync; then
    return 1
  fi

  # Une éjection forcée empêche Spotlight de retenir la carte. À ce stade,
  # toutes les écritures sont terminées et synchronisées.
  run_with_elapsed_time "Éjection de la carte" /usr/sbin/diskutil eject force "$WHOLE_DISK"
}

copy_with_watchdog() {
  local source_path="$1"
  local destination_path="$2"
  local total_bytes="$3"
  local copy_log="/tmp/preparer-carte-sd-copy-$$.log"
  local copy_pid
  local copy_result
  local current_bytes=0
  local previous_bytes=0
  local elapsed_seconds=0
  local stalled_seconds=0
  local percent=0
  local current_mib=0
  local total_mib=$(((total_bytes + 1048575) / 1048576))
  local average_tenths=0
  local elapsed_minutes=0
  local elapsed_remainder=0

  COPYFILE_DISABLE=1 /usr/bin/rsync --inplace "$source_path" "$destination_path" \
    >"$copy_log" 2>&1 &
  copy_pid=$!

  while /bin/kill -0 "$copy_pid" >/dev/null 2>&1; do
    /bin/sleep 2
    elapsed_seconds=$((elapsed_seconds + 2))

    if [ -f "$destination_path" ]; then
      current_bytes="$(/usr/bin/stat -f '%z' "$destination_path" 2>/dev/null)" \
        || current_bytes="$previous_bytes"
    else
      current_bytes=0
    fi

    if [ "$current_bytes" -gt "$previous_bytes" ]; then
      stalled_seconds=0
    else
      stalled_seconds=$((stalled_seconds + 2))
    fi

    previous_bytes="$current_bytes"
    percent=$((current_bytes * 100 / total_bytes))
    [ "$percent" -le 100 ] || percent=100
    current_mib=$((current_bytes / 1048576))
    average_tenths=$((current_bytes * 10 / 1048576 / elapsed_seconds))
    elapsed_minutes=$((elapsed_seconds / 60))
    elapsed_remainder=$((elapsed_seconds % 60))

    printf '\rCopie unique : %3d%% — %d/%d Mio — %d.%d Mio/s — %02d:%02d' \
      "$percent" "$current_mib" "$total_mib" \
      "$((average_tenths / 10))" "$((average_tenths % 10))" \
      "$elapsed_minutes" "$elapsed_remainder"

    if [ "$stalled_seconds" -ge 90 ]; then
      printf '\nAucune progression détectée pendant 90 secondes. Arrêt de la copie…\n'
      /bin/kill -TERM "$copy_pid" >/dev/null 2>&1 || true
      /bin/sleep 3
      /bin/kill -KILL "$copy_pid" >/dev/null 2>&1 || true
      wait "$copy_pid" >/dev/null 2>&1 || true
      /bin/rm -f -- "$copy_log" >/dev/null 2>&1 || true
      return 124
    fi
  done

  wait "$copy_pid"
  copy_result=$?

  if [ "$copy_result" -eq 0 ] && [ -f "$destination_path" ]; then
    current_bytes="$(/usr/bin/stat -f '%z' "$destination_path" 2>/dev/null)" \
      || current_bytes=0
    current_mib=$((current_bytes / 1048576))
    printf '\rCopie unique : 100%% — %d/%d Mio — terminée%20s\n' \
      "$current_mib" "$total_mib" ""
  else
    printf '\n'
    /bin/cat "$copy_log" >&2 || true
  fi

  /bin/rm -f -- "$copy_log" >/dev/null 2>&1 || true
  return "$copy_result"
}

printf '\n=== PRÉPARATION DE LA CARTE SD DU PROJECTEUR — VERSION %s ===\n\n' "$TOOL_VERSION"
printf 'Cette version ne reformate jamais la carte.\n\n'

# Le fichier habituel est utilisé automatiquement. S’il manque, le Mac
# affiche une fenêtre permettant de choisir la vidéo.
if [ -f "$DEFAULT_VIDEO" ]; then
  SOURCE_VIDEO="$DEFAULT_VIDEO"
else
  printf 'Le fichier love.mov n’est pas dans Téléchargements.\n'
  printf 'Choisissez la vidéo dans la fenêtre qui va s’ouvrir.\n'

  SOURCE_VIDEO="$(/usr/bin/osascript -e 'POSIX path of (choose file with prompt "Choisissez la vidéo à copier sur la carte SD")' 2>/dev/null)" \
    || fail "Aucune vidéo n’a été choisie."
fi

[ -f "$SOURCE_VIDEO" ] || fail "La vidéo est introuvable."
[ -d "$VOLUME" ] \
  || fail "La carte SD nommée CK n’est pas insérée. Insérez-la puis relancez l’outil."

case "$SOURCE_VIDEO" in
  "$VOLUME"/*)
    fail "La vidéo source ne peut pas se trouver sur la carte qui va être effacée."
    ;;
esac

SOURCE_NAME="$(/usr/bin/basename "$SOURCE_VIDEO")"

case "$SOURCE_NAME" in
  *.*)
    EXTENSION="${SOURCE_NAME##*.}"
    ;;
  *)
    fail "La vidéo doit avoir une extension, par exemple .mov ou .mp4."
    ;;
esac

case "$EXTENSION" in
  *[!A-Za-z0-9]*)
    fail "L’extension du fichier vidéo n’est pas reconnue."
    ;;
esac

# Le fichier conserve son nom d’origine sur la carte.
DESTINATION_NAME="$SOURCE_NAME"
DESTINATION="$VOLUME/$DESTINATION_NAME"

VIDEO_SIZE="$(/usr/bin/stat -f '%z' "$SOURCE_VIDEO" 2>/dev/null)" \
  || fail "Impossible de lire la taille de la vidéo."

[ "$VIDEO_SIZE" -gt 0 ] \
  || fail "La vidéo est vide et ne peut pas être copiée."

DISK_INFO="$(/usr/sbin/diskutil info "$VOLUME" 2>/dev/null)" \
  || fail "Le Mac ne reconnaît pas correctement la carte CK."

MOUNT_POINT="$(printf '%s\n' "$DISK_INFO" | /usr/bin/awk -F ': *' '/Mount Point:/ { print $2; exit }')"
WHOLE_DISK="$(printf '%s\n' "$DISK_INFO" | /usr/bin/awk -F ': *' '/Part of Whole:/ { print $2; exit }')"
INTERNAL="$(printf '%s\n' "$DISK_INFO" | /usr/bin/awk -F ': *' '/Internal:/ { print $2; exit }')"
DEVICE_LOCATION="$(printf '%s\n' "$DISK_INFO" | /usr/bin/awk -F ': *' '/Device Location:/ { print $2; exit }')"
DISK_SIZE="$(printf '%s\n' "$DISK_INFO" | /usr/bin/awk -F ': *' '/Disk Size:/ { print $2; exit }')"

[ "$MOUNT_POINT" = "$VOLUME" ] \
  || fail "Le chemin CK n’est pas le point de montage attendu."

[ -n "$WHOLE_DISK" ] \
  || fail "Impossible d’identifier la carte SD en toute sécurité."

if [ "$INTERNAL" != "No" ] && [ "$DEVICE_LOCATION" != "External" ]; then
  fail "Sécurité activée : CK ne semble pas être une carte ou un disque externe."
fi

printf 'Vidéo : %s\n' "$SOURCE_VIDEO"
printf 'Carte : %s (%s)\n' "$VOLUME" "${DISK_SIZE:-taille inconnue}"
printf '\nATTENTION : tous les fichiers de la carte CK seront définitivement supprimés.\n'
printf 'La carte ne sera pas reformatée.\n'
printf 'Continuer ? Tapez OUI : '
IFS= read -r CONFIRMATION </dev/tty || fail "Réponse impossible à lire."

[ "$CONFIRMATION" = "OUI" ] \
  || fail "Opération annulée. Aucun changement n’a été effectué."

printf '\n[1/6] Suppression de tous les fichiers, y compris les fichiers invisibles…\n'

# Le marqueur Spotlight est posé avant le nettoyage afin que le dossier
# .Spotlight-V100 ne soit pas recréé pendant sa propre suppression.
disable_spotlight_temporarily \
  || fail_cleaning "Impossible de protéger temporairement la carte contre Spotlight."

remove_items_except "" "yes" \
  || fail_cleaning "Impossible de vider complètement la carte."

collect_items_except "" "yes"
[ "${#EXTRA_ITEMS[@]}" -eq 0 ] \
  || fail "La carte contient encore un élément après le nettoyage."

printf 'La carte et sa corbeille sont vides.\n'

# Ces trois protections temporaires empêchent Spotlight, FSEvents et la
# corbeille de la carte de se recréer pendant la copie.
create_temporary_guards \
  || fail_cleaning "Impossible d’empêcher la recréation des fichiers invisibles."

AVAILABLE_KB="$(/bin/df -k "$VOLUME" | /usr/bin/awk 'END { print $4 }')"
AVAILABLE_BYTES=$((AVAILABLE_KB * 1024))

if [ "$VIDEO_SIZE" -gt "$AVAILABLE_BYTES" ]; then
  /bin/rm -rf -- "$MARKER_FSEVENTS" "$MARKER_SPOTLIGHT" "$MARKER_TRASH" >/dev/null 2>&1 || true
  fail "La carte SD est trop petite pour contenir cette vidéo."
fi

printf '\n[2/6] Copie unique de %s sous le nom %s…\n' "$SOURCE_NAME" "$DESTINATION_NAME"

COPY_RESULT=0
copy_with_watchdog "$SOURCE_VIDEO" "$DESTINATION" "$VIDEO_SIZE" || COPY_RESULT=$?

if [ "$COPY_RESULT" -ne 0 ]; then
  run_with_elapsed_time "Éjection après erreur" /usr/sbin/diskutil eject force "$WHOLE_DISK" \
    >/dev/null 2>&1 || true

  if [ "$COPY_RESULT" -eq 124 ]; then
    fail "La copie n’avançait plus depuis 90 secondes. La carte SD, son adaptateur ou le lecteur a probablement un problème. Essayez un autre support."
  fi

  fail "Erreur d’écriture. La carte SD, son adaptateur ou le lecteur est probablement défectueux. Essayez une autre carte ou un autre lecteur."
fi

printf '\n[3/6] Vérification intégrale de la vidéo…\n'

if ! run_with_elapsed_time "Vérification en cours" /usr/bin/cmp -s "$SOURCE_VIDEO" "$DESTINATION"; then
  /bin/sync
  /usr/sbin/diskutil eject force "$WHOLE_DISK" >/dev/null 2>&1 || true
  fail "La copie ne correspond pas à l’original. N’utilisez pas cette carte dans le projecteur."
fi

printf '\n[4/6] Dernier nettoyage des fichiers macOS…\n'

# On conserve encore les deux protections pendant ce premier passage.
remove_items_except "$DESTINATION" "yes" \
  || fail_cleaning "Impossible de supprimer tous les fichiers macOS."

# La grosse synchronisation se fait pendant que les trois protections sont
# encore en place. Cela réduit la fenêtre pendant laquelle macOS peut recréer
# un dossier juste avant l’éjection.
run_with_elapsed_time "Synchronisation avant contrôle final" /bin/sync \
  || fail "La synchronisation de la carte a échoué."

printf 'Suppression des protections temporaires…\n'
/bin/rm -rf -- "$MARKER_FSEVENTS" "$MARKER_SPOTLIGHT" "$MARKER_TRASH" >/dev/null 2>&1 || true

# Contrôle final, avec autorisation administrateur uniquement si macOS a
# recréé ou protégé un élément au dernier moment.
remove_items_except "$DESTINATION" "no" \
  || fail_cleaning "Un fichier macOS résiste encore au nettoyage final."

printf '\n[5/6] Contrôle du contenu final…\n'
collect_items_except "$DESTINATION" "no"

[ "${#EXTRA_ITEMS[@]}" -eq 0 ] \
  || fail "La carte contient encore un fichier indésirable."

[ -f "$DESTINATION" ] \
  || fail "La vidéo a disparu pendant le nettoyage."

FINAL_SIZE="$(/usr/bin/stat -f '%z' "$DESTINATION" 2>/dev/null)" \
  || fail "Impossible de relire la vidéo finale."

[ "$FINAL_SIZE" -eq "$VIDEO_SIZE" ] \
  || fail "La taille de la vidéo finale est incorrecte."

printf 'Résultat : un seul fichier, %s. La corbeille de la carte est vide.\n' "$DESTINATION_NAME"

printf '\n[6/6] Synchronisation et éjection…\n'

eject_after_sync \
  || fail "Le Mac ne parvient pas à éjecter la carte. Fermez les fenêtres du Finder et réessayez."

printf '\nSUCCÈS : la carte ne contient que %s.\n' "$DESTINATION_NAME"
printf 'La copie a été vérifiée et la carte a été éjectée.\n'
printf 'Vous pouvez maintenant retirer la carte du Mac.\n'

pause_before_close
