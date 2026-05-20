#!/usr/bin/env bash
# play-dialog.sh — replay a dialog script with streamed terminal output.
#
# Designed to be driven by VHS for the conference demo videos. Single-pane:
# student/agent lines stream like real typing, and `wiki` directives clear
# the screen and render a wiki page via glow for the audience to read.
#
# Dialog file format (one directive per line; `|` is the separator):
#   ;comment              — ignored
#   >system|Message       — magenta system text (setup overlays, scene labels)
#   >student|Message      — cyan, char-by-char (simulates a student typing)
#   >assistant|Message    — green, char-by-char (Video 1: generic LLM reply)
#   >tutor|Message        — yellow, char-by-char (Video 2: course-aware tutor)
#   >instructor|Message   — bold red (the diagnostic question)
#   >caption|Message      — boxed centered caption
#   >code|line            — monospaced code line (literal, no streaming)
#   >code-block|...~~...  — multiple code lines separated by `~~`
#   >pause|N              — sleep N seconds (decimals allowed)
#   >clear                — clear the screen
#   >wiki|Page-Name       — print an inline GitHub URL pointing at the wiki page;
#                           the tutor's prose has already quoted the relevant
#                           section, so this is a reference, not a takeover.
#                           Override base URL via WIKI_URL_BASE env var.
#   >bell                 — terminal bell (audio cue for editing markers)
#
# Speeds can be overridden via env:
#   STUDENT_DELAY=0.025 TUTOR_DELAY=0.012 ASSISTANT_DELAY=0.010 WIKI_HOLD=6

set -euo pipefail

dialog_file="${1:-}"
if [[ -z "$dialog_file" ]]; then
  echo "usage: $0 <dialog-file>" >&2
  exit 1
fi

STUDENT_DELAY="${STUDENT_DELAY:-0.022}"
TUTOR_DELAY="${TUTOR_DELAY:-0.012}"
ASSISTANT_DELAY="${ASSISTANT_DELAY:-0.010}"
INSTRUCTOR_DELAY="${INSTRUCTOR_DELAY:-0.020}"
WIKI_HOLD="${WIKI_HOLD:-6}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-discover the wiki location and URL from the repo's git structure,
# so this script works in any course-tutor project without hardcoded paths.
# Override either via env var if the auto-detection finds the wrong thing.
auto_wiki_dir() {
  local repo_root candidate
  repo_root=$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null) || return 1
  for candidate in "$repo_root"/wiki/*.wiki; do
    [[ -d "$candidate" ]] && { printf '%s' "$candidate"; return 0; }
  done
  return 1
}

auto_wiki_url() {
  local wiki="$1"
  [[ -d "$wiki" ]] || return 1
  git -C "$wiki" remote get-url origin 2>/dev/null | sed -E 's|\.git$||'
}

WIKI_DIR="${WIKI_DIR:-$(auto_wiki_dir || true)}"
WIKI_URL_BASE="${WIKI_URL_BASE:-$(auto_wiki_url "$WIKI_DIR" || true)}"

C_RESET=$'\033[0m'
C_DIM=$'\033[2m'
C_BOLD=$'\033[1m'
C_STUDENT=$'\033[1;36m'
C_TUTOR=$'\033[1;33m'
C_ASSISTANT=$'\033[1;32m'
C_SYSTEM=$'\033[1;35m'
C_INSTRUCTOR=$'\033[1;31m'
C_CAPTION=$'\033[1;37m'

# Discover wiki page names from the wiki directory, longest-first so longer
# names win over shorter substrings (e.g. "Current-Limiting-Resistor" before
# "Resistor"). Navigation / schema / home pages are excluded.
discover_wiki_pages() {
  local f name
  for f in "$WIKI_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    case "$name" in
      index_*|log_*|Home*|SCHEMA*) continue ;;
    esac
    printf '%s\n' "$name"
  done | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-
}

WIKI_PAGES=()
while IFS= read -r line; do
  [[ -n "$line" ]] && WIKI_PAGES+=("$line")
done < <(discover_wiki_pages)

stream() {
  # Stream char-by-char with per-char delay (the typing animation), but
  # when a known wiki page name occurs in the text, wrap it inline with
  # OSC 8 hyperlink + underline escape sequences. The hyperlink wrappers
  # are emitted instantly (no per-char delay) so only the visible page-
  # name characters slow-stream — the terminal still shows them appearing
  # one at a time, but they appear already styled as a clickable link.
  local raw="$1" delay="$2" text i len page plen j matched
  text="${raw//\\n/$'\n'}"
  len=${#text}
  i=0
  while (( i < len )); do
    matched=""
    for page in "${WIKI_PAGES[@]}"; do
      plen=${#page}
      if [[ "${text:$i:$plen}" == "$page" ]]; then
        matched="$page"
        break
      fi
    done
    if [[ -n "$matched" ]]; then
      plen=${#matched}
      # OSC 8 start + ANSI underline (no delay)
      printf '\033]8;;%s/%s\033\\\033[4m' "$WIKI_URL_BASE" "$matched"
      # Page name characters streamed at typing speed
      for (( j=0; j<plen; j++ )); do
        printf '%s' "${matched:$j:1}"
        sleep "$delay"
      done
      # End underline + OSC 8 end (no delay)
      printf '\033[24m\033]8;;\033\\'
      i=$((i + plen))
    else
      printf '%s' "${text:$i:1}"
      sleep "$delay"
      i=$((i + 1))
    fi
  done
  printf "\n"
}

play_caption() {
  local body="$1"
  local len=${#body}
  local pad
  pad=$(printf '─%.0s' $(seq 1 $(( len + 4 ))))
  printf "\n${C_CAPTION}┌%s┐${C_RESET}\n" "$pad"
  printf "${C_CAPTION}│  %s  │${C_RESET}\n" "$body"
  printf "${C_CAPTION}└%s┘${C_RESET}\n\n" "$pad"
}

play_wiki() {
  # No-op. Earlier versions of this script handled >wiki|Page directives by
  # printing a separate URL line beneath the tutor's reply (the "reference
  # link" pattern). That made the recording diverge from a real Claude Code
  # session, where references are inline in the tutor's prose as the page
  # names themselves. The stream() function now wraps page-name mentions
  # with OSC 8 hyperlink escapes inline, so the page names become clickable
  # in the conversation itself — same behavior in real use and in recording.
  # >wiki| directives in existing dialog files are kept for backward compat
  # but no longer render anything.
  :
}

play_line() {
  local kind="$1" body="${2-}"
  case "$kind" in
    system)
      printf "${C_SYSTEM}%s${C_RESET}\n" "$body"
      ;;
    student)
      if [[ -z "$body" ]]; then printf "\n"; else
        printf "${C_STUDENT}student${C_DIM} ❯${C_RESET} "
        stream "$body" "$STUDENT_DELAY"
        printf "\n"
      fi
      ;;
    assistant)
      if [[ -z "$body" ]]; then printf "\n"; else
        printf "${C_ASSISTANT}assistant${C_DIM} ❯${C_RESET} "
        stream "$body" "$ASSISTANT_DELAY"
        printf "\n"
      fi
      ;;
    tutor)
      if [[ -z "$body" ]]; then printf "\n"; else
        printf "${C_TUTOR}tutor${C_DIM} ❯${C_RESET} "
        stream "$body" "$TUTOR_DELAY"
        printf "\n"
      fi
      ;;
    instructor)
      if [[ -z "$body" ]]; then printf "\n"; else
        printf "${C_INSTRUCTOR}instructor${C_DIM} ❯${C_RESET} "
        stream "$body" "$INSTRUCTOR_DELAY"
        printf "\n"
      fi
      ;;
    code)
      printf "${C_DIM}  %s${C_RESET}\n" "$body"
      ;;
    code-block)
      local expanded="${body//~~/$'\n'}"
      while IFS= read -r part; do
        printf "${C_DIM}  %s${C_RESET}\n" "$part"
      done <<< "$expanded"
      ;;
    caption)
      play_caption "$body"
      ;;
    pause)
      sleep "$body"
      ;;
    clear)
      clear
      ;;
    wiki)
      play_wiki "$body"
      ;;
    bell)
      printf '\a'
      ;;
    *)
      printf "${C_INSTRUCTOR}[unknown directive: %s]${C_RESET}\n" "$kind"
      ;;
  esac
}

while IFS= read -r line <&9 || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*\; ]] && continue
  if [[ "$line" =~ ^\>([a-z-]+)\|(.*)$ ]]; then
    play_line "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  elif [[ "$line" =~ ^\>([a-z-]+)$ ]]; then
    play_line "${BASH_REMATCH[1]}"
  fi
done 9< "$dialog_file"
