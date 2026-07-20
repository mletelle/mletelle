#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="contrib-drawing"
START_FILE="$TARGET_DIR/mauro-start-date.txt"
PROGRESS_FILE="$TARGET_DIR/mauro-progress.txt"
DATA_FILE="$TARGET_DIR/mauro-record.txt"

mkdir -p "$TARGET_DIR"

today=$(date -u +%Y-%m-%d)

if [ ! -f "$START_FILE" ]; then
  dow=$(date -u -d "$today" +%w)
  start_date=$(date -u -d "$today -${dow} days" +%Y-%m-%d)
  echo "$start_date" > "$START_FILE"
else
  start_date=$(cat "$START_FILE")
fi

rows=(
  "10001001110010001011100001110"
  "11011010001010001010010010001"
  "10101010001010001010010010001"
  "10001011111010001011100010001"
  "10001010001010001010100010001"
  "10001010001010001010010010001"
  "10001010001001110010001001110"
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

start_ts=$(date -u -d "$start_date" +%s)
today_ts=$(date -u -d "$today" +%s)
offset_days=$(( (today_ts - start_ts) / 86400 ))

if [ "$offset_days" -lt 0 ] || [ "$offset_days" -ge $(( week_count * 7 )) ]; then
  echo "Date $today is outside the MAURO pattern window. No commit created."
  exit 0
fi

week=$(( offset_days / 7 ))
dow=$(( offset_days % 7 ))
row="${rows[$dow]}"
pixel="${row:$week:1}"

if [ "$pixel" != "1" ]; then
  echo "No MAURO pixel for $today (week $week, day $dow). No commit created."
  exit 0
fi

if [ -f "$PROGRESS_FILE" ] && grep -qx "$today" "$PROGRESS_FILE"; then
  echo "MAURO pixel for $today already recorded."
  exit 0
fi

printf 'date: %s\nweek: %s\nday: %s\n' "$today" "$week" "$dow" >> "$DATA_FILE"
echo "$today" >> "$PROGRESS_FILE"

export GIT_AUTHOR_DATE="${today}T12:00:00Z"
export GIT_COMMITTER_DATE="${today}T12:00:00Z"

git add "$TARGET_DIR"
git commit -m "MAURO contributions: add pixel for $today" --date "${today}T12:00:00Z"

echo "Committed MAURO pixel for $today."
