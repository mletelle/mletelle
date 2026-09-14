#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="contrib-drawing"
START_FILE="$TARGET_DIR/mauro-start-date.txt"
PROGRESS_FILE="$TARGET_DIR/mauro-progress.txt"
DATA_FILE="$TARGET_DIR/mauro-record.txt"
BACKFILL_FILE="$TARGET_DIR/mauro-backfill-v2.txt"
BACKFILL_END="2026-09-13"

mkdir -p "$TARGET_DIR"

today=$(date -u +%Y-%m-%d)

if [ ! -f "$START_FILE" ]; then
  dow=$(date -u -d "$today" +%w)
  start_date=$(date -u -d "$today -${dow} days" +%Y-%m-%d)
  echo "$start_date" > "$START_FILE"
else
  start_date=$(cat "$START_FILE")
fi

# 7 rows (Sun-Sat). Each character is 5 weeks wide, letters are separated
# by one blank week, and the final zero adds a blank week before MAURO
# starts again. The complete 30-week pattern repeats indefinitely.
rows=(
  "100010011100100010111000011100"
  "110110100010100010100100100010"
  "101010100010100010100100100010"
  "100010111110100010111000100010"
  "100010100010100010101000100010"
  "100010100010100010100100100010"
  "100010100010011100100010011100"
)

if [ ${#rows[@]} -ne 7 ]; then
  echo "Pattern definition is invalid."
  exit 1
fi

week_count=${#rows[0]}
for row in "${rows[@]}"; do
  if [ ${#row} -ne "$week_count" ]; then
    echo "Pattern rows must all have the same width."
    exit 1
  fi
done

pixel_for_date() {
  local target_date="$1"
  local start_ts target_ts offset_days week dow row

  start_ts=$(date -u -d "$start_date" +%s)
  target_ts=$(date -u -d "$target_date" +%s)
  offset_days=$(( (target_ts - start_ts) / 86400 ))

  if [ "$offset_days" -lt 0 ]; then
    return 1
  fi

  # Wrap the week index so the 30-week MAURO pattern never ends.
  week=$(( (offset_days / 7) % week_count ))
  dow=$(( offset_days % 7 ))
  row="${rows[$dow]}"

  [ "${row:$week:1}" = "1" ]
}

# One-time repair of the historical pixels created with the old,
# non-associated Git author email. July 20 already has a real
# mletelle contribution from the setup commit, so it is intentionally skipped.
if [ ! -f "$BACKFILL_FILE" ]; then
  repair_date="$start_date"

  while [ "$(date -u -d "$repair_date" +%s)" -le "$(date -u -d "$BACKFILL_END" +%s)" ]; do
    if [ "$repair_date" != "2026-07-20" ] && pixel_for_date "$repair_date"; then
      printf '%s\n' "$repair_date" >> "$BACKFILL_FILE"

      export GIT_AUTHOR_DATE="${repair_date}T12:00:00Z"
      export GIT_COMMITTER_DATE="${repair_date}T12:00:00Z"

      git add "$BACKFILL_FILE"
      git commit -m "MAURO contributions: repair pixel for $repair_date" --date "${repair_date}T12:00:00Z"
    fi

    repair_date=$(date -u -d "$repair_date +1 day" +%Y-%m-%d)
  done

  if [ -f "$BACKFILL_FILE" ]; then
    echo "Historical MAURO pixels repaired through $BACKFILL_END."
  fi
fi

if ! pixel_for_date "$today"; then
  echo "No MAURO pixel for $today. No daily commit created."
  exit 0
fi

if [ -f "$PROGRESS_FILE" ] && grep -qx "$today" "$PROGRESS_FILE"; then
  echo "MAURO pixel for $today already recorded."
  exit 0
fi

start_ts=$(date -u -d "$start_date" +%s)
today_ts=$(date -u -d "$today" +%s)
offset_days=$(( (today_ts - start_ts) / 86400 ))
week=$(( offset_days / 7 ))
dow=$(( offset_days % 7 ))

printf 'date: %s\nweek: %s\nday: %s\n' "$today" "$week" "$dow" >> "$DATA_FILE"
echo "$today" >> "$PROGRESS_FILE"

export GIT_AUTHOR_DATE="${today}T12:00:00Z"
export GIT_COMMITTER_DATE="${today}T12:00:00Z"

git add "$TARGET_DIR"
git commit -m "MAURO contributions: add pixel for $today" --date "${today}T12:00:00Z"

echo "Committed MAURO pixel for $today."
