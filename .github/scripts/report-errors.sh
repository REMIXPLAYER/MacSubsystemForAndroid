#!/bin/bash
# Turn the interesting lines of a build log into one multi-line error annotation,
# so failures can be read from the run summary.
#
#   .github/scripts/report-errors.sh <log> [title] [pattern]
set -uo pipefail
LOG="$1"; TITLE="${2:-Build failed}"; PATTERN="${3:-}"
[ -f "$LOG" ] || exit 0
if [ -n "$PATTERN" ] && grep -qE "$PATTERN" "$LOG"; then
    LINES="$(grep -E "$PATTERN" "$LOG" | awk '!seen[$0]++' | head -80)"
else
    LINES="$(tail -n 60 "$LOG")"
fi
ESCAPED="$(printf '%s' "$LINES" | cut -c1-400 | sed 's/%/%25/g; s/\r/%0D/g' | awk 'BEGIN{ORS="%0A"} {print}')"
echo "::error title=${TITLE}::${ESCAPED}"
