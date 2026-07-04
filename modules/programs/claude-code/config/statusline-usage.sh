#!/usr/bin/env bash
# Claude Code status line: real subscription usage, straight from Claude Code.
#
# Claude Code (>= 2.1.x) passes the live /usage rate-limit data to this script
# on stdin as JSON, for Claude.ai Pro/Max subscribers. We read it directly --
# no ccusage, no network call, no hardcoded caps. The numbers match what the
# /usage command shows:
#   session: current 5-hour rolling window, % consumed (+ reset countdown)
#   week:    current 7-day rolling window, % consumed (+ reset countdown)
#
# rate_limits is absent until the first API response of a session, and entirely
# absent for API-key (non-subscription) logins. To avoid showing "n/a" at the
# start of every session, we cache the last-seen rate_limits and fall back to it
# until the first live response refreshes the numbers. The cached values stay
# accurate because usage is account-wide and resets_at is an absolute timestamp;
# a cached window whose reset time has already passed means the new window is
# fresh, so we show "0% used" rather than "n/a". Only a genuinely absent
# used_percentage (e.g. API-key logins) renders as "n/a".
#
# /usr/bin is for jq; nothing else is needed.
export PATH="/usr/bin:/bin:$PATH"

CACHE="$HOME/.claude/.usage-cache.json"
input="$(cat)"

# --- Context window usage --------------------------------------------------
# The transcript records, per assistant message, how many tokens the model saw:
# input + cache_read + cache_creation = the live context window occupancy.
# We take the most recent main-chain (non-sidechain) assistant message and show
# it as a percentage of the model's context limit.
context_segment() {
  local transcript limit
  transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 0

  # 200k normally; 1M when the long-context beta is active for this session.
  if printf '%s' "$input" | jq -e '.exceeds_200k_tokens == true' >/dev/null 2>&1; then
    limit=1000000
  else
    limit=200000
  fi

  # Walk the transcript newest-first and use the first main-chain assistant
  # usage we find. macOS has `tail -r`, not `tac`.
  tail -r "$transcript" 2>/dev/null | jq -rj -s --argjson limit "$limit" '
    map(select(.isSidechain != true)
        | select(.message.role == "assistant")
        | .message.usage
        | select(. != null))
    | .[0]
    | select(. != null)
    | ((.input_tokens // 0)
       + (.cache_read_input_tokens // 0)
       + (.cache_creation_input_tokens // 0)) as $used
    | " | context: "
      + (($used / $limit * 100) | floor | tostring) + "% ("
      + (($used / 1000) | floor | tostring) + "k/"
      + (($limit / 1000) | floor | tostring) + "k)"
  ' 2>/dev/null
}

# Does the live payload actually carry usage numbers?
have_live() {
  printf '%s' "$input" | jq -e \
    '(.rate_limits.five_hour.used_percentage != null)
     or (.rate_limits.seven_day.used_percentage != null)' >/dev/null 2>&1
}

if have_live; then
  # Refresh the cache from the live payload, then render the live payload.
  printf '%s' "$input" | jq -c '{rate_limits}' > "$CACHE" 2>/dev/null
  payload="$input"
elif [ -f "$CACHE" ]; then
  # No live data yet (fresh session): fall back to the cached numbers.
  payload="$(cat "$CACHE")"
else
  payload='{}'
fi

printf '%s' "$payload" | jq -rj '
  def pct($p): ($p | floor | tostring) + "% used";
  def hm($s):  (if $s < 0 then 0 else $s end) as $s
             | (($s/3600)|floor|tostring) + "h " + ((($s%3600)/60)|floor|tostring) + "m";
  def dh($s):  (if $s < 0 then 0 else $s end) as $s
             | (($s/86400)|floor|tostring) + "d " + ((($s%86400)/3600)|floor|tostring) + "h";

  (now) as $now
  | .rate_limits.five_hour as $s
  | .rate_limits.seven_day as $w
  | ( if ($s.used_percentage == null) then "session: n/a"
        elif ($s.resets_at == null or $s.resets_at > $now)
        then "session: " + pct($s.used_percentage)
             + (if ($s.resets_at != null) then " · resets in " + hm($s.resets_at - $now) else "" end)
        else "session: " + pct(0) end )
  + " | "
  + ( if ($w.used_percentage == null) then "week: n/a"
        elif ($w.resets_at == null or $w.resets_at > $now)
        then "week: " + pct($w.used_percentage)
             + (if ($w.resets_at != null) then " · resets in " + dh($w.resets_at - $now) else "" end)
        else "week: " + pct(0) end )
'

context_segment
