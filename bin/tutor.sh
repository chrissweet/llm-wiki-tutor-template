#!/usr/bin/env bash
# tutor.sh — launch a course tutor session against the microelectronics wiki.
#
# Wraps `claude` with the course-tutor system prompt from
# bin/lib/tutor-prompt.md so a fresh git clone can run one command and
# get a reproducible tutor demo: course-aware, Socratic, never delivers
# the answer.
#
# Usage:
#   bin/tutor.sh                  # interactive tutor session
#   bin/tutor.sh "Lab 1 question" # one-shot non-interactive response
#
# The system prompt is appended to Claude Code's default (i.e., CLAUDE.md
# still loads), so wiki access via Read/Glob/Grep works as usual.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

TUTOR_PROMPT_FILE="bin/lib/tutor-prompt.md"
if [[ ! -f "$TUTOR_PROMPT_FILE" ]]; then
  echo "missing $TUTOR_PROMPT_FILE — run this script from the repo root" >&2
  exit 1
fi

TUTOR_PROMPT="$(cat "$TUTOR_PROMPT_FILE")"

if [[ $# -gt 0 ]]; then
  # One-shot mode — handy for piping or quick tests
  exec claude -p "$*" \
    --append-system-prompt "$TUTOR_PROMPT" \
    --allowedTools "Read" "Glob" "Grep" \
    --dangerously-skip-permissions
else
  # Interactive mode — full Claude Code experience with the tutor overlay.
  # No --dangerously-skip-permissions; the user keeps the permission gate.
  exec claude \
    --append-system-prompt "$TUTOR_PROMPT" \
    --name "course tutor"
fi
