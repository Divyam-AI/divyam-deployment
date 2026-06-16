# shellcheck shell=bash
# SPDX-License-Identifier: Apache-2.0
# scripts/lib/cli.sh — shared CLI conventions for the divyam-deployment scripts.
#
# Sourced (not executed) by scripts/iac.sh, k8s.sh, bringup.sh, status.sh and the helper scripts.
# Holds the cross-cutting helpers: consistent error/status presentation, value resolution +
# enum validation, human-vs-agent detection, and the terminal UI (color + status glyphs + one
# spinner). The scripts keep their own hand-written `while/case` subcommand parsers and grep-based
# `--help` — this lib just unifies how they *present* and *fail*.
#
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$SCRIPT_DIR/lib/cli.sh"
#
# Human vs agent: cli::interactive is the single source of truth. A caller is "human" iff stdout
# AND stdin are TTYs, $CI is unset, and non-interactive mode wasn't requested via
# DIVYAM_NONINTERACTIVE=1. Agents (Claude tool shells), pipes, and CI are non-TTY -> automatically
# non-interactive: no color, no animation, plain greppable output. Color additionally honors the
# standard NO_COLOR opt-out (https://no-color.org).

# Idempotent source guard (scripts may source transitively).
[[ -n "${_CLI_SH_SOURCED:-}" ]] && return 0
_CLI_SH_SOURCED=1

# ------------------------------ Human vs agent --------------------------------------
cli::interactive() {
  [[ -t 1 && -t 0 ]]                            || return 1   # not a terminal (pipe / agent / CI capture)
  [[ -z "${CI:-}" ]]                            || return 1   # CI environments are non-interactive
  [[ "${DIVYAM_NONINTERACTIVE:-0}" != 1 ]]      || return 1   # explicit env override
  return 0
}

# ------------------------------ Color palette ---------------------------------------
# Resolved once at source time; emission is gated per-call by cli::_use_color so a non-interactive
# context (pipe/agent/CI/NO_COLOR) discovered after sourcing still suppresses color.
#
# Raw SGR escapes, NOT `tput`: `tput sgr0` emits a charset-reset before `ESC [ m` that some
# terminals mis-render and that corrupts copy/paste of aligned columns. Plain `\033[0m` resets
# cleanly, is universally understood, and is zero display width so alignment holds.
CLI_BOLD="" CLI_DIM="" CLI_RED="" CLI_GREEN="" CLI_YELLOW="" CLI_CYAN="" CLI_RESET=""
if { [[ -t 1 ]] || [[ -t 2 ]]; } && [[ "${TERM:-dumb}" != dumb ]]; then
  CLI_BOLD=$'\033[1m'
  CLI_DIM=$'\033[2m'
  CLI_RED=$'\033[31m'
  CLI_GREEN=$'\033[32m'
  CLI_YELLOW=$'\033[33m'
  CLI_CYAN=$'\033[36m'
  CLI_RESET=$'\033[0m'
fi

# Spinner frames: braille under a UTF-8 locale, ASCII otherwise (locale-safe slicing).
if [[ "${LC_ALL:-}${LC_CTYPE:-}${LANG:-}" == *[Uu][Tt][Ff]* ]]; then
  CLI_SPIN_FRAMES='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
else
  CLI_SPIN_FRAMES='|/-\'
fi

cli::_use_color() { [[ -n "$CLI_RESET" ]] && [[ -z "${NO_COLOR:-}" ]] && cli::interactive; }

# cli::_c <COLOR_VAR_NAME> <text> — wrap text in a color iff color is in play.
cli::_c() {
  if cli::_use_color; then printf '%s%s%s' "${!1}" "$2" "$CLI_RESET"; else printf '%s' "$2"; fi
}

# ------------------------------ Status lines ----------------------------------------
# All go to stderr (diagnostics) so stdout stays clean/parseable. Emoji + a single subtle color.
cli::ok()   { printf '%s %s\n' "✅" "$(cli::_c CLI_GREEN  "$*")" >&2; }
cli::warn() { printf '%s %s\n' "⚠️ " "$(cli::_c CLI_YELLOW "$*")" >&2; }
cli::err()  { printf '%s %s\n' "❌" "$(cli::_c CLI_RED    "$*")" >&2; }
cli::info() { printf '%s %s\n' "ℹ️ " "$(cli::_c CLI_DIM    "$*")" >&2; }
cli::step() { printf '%s %s\n' "$(cli::_c CLI_CYAN "▶")" "$*" >&2; }

# cli::die <msg...> [code] — error line then exit. The exit code DEFAULTS TO 2 in this repo (the
# manual parsers front both arg-parse and semantic errors through one die(), and status.sh
# documents a 0/1/2 contract — 2 preserves every existing exit code). If the LAST argument is a
# bare integer it's used as the exit code; otherwise all args form the message.
cli::die() {
  local code=2
  if [[ $# -gt 1 && "${!#}" =~ ^[0-9]+$ ]]; then code="${!#}"; set -- "${@:1:$#-1}"; fi
  cli::err "$*"; exit "$code"
}

# cli::need_tool <tool> [hint] — assert a command exists.
cli::need_tool() {
  command -v "$1" >/dev/null 2>&1 || cli::die "'$1' not found — ${2:-install it and retry}" 1
}

# cli::usage <script-file> — print the script's own comment header as help. Only the LEADING
# comment block is used (parsing stops at the first non-comment line, i.e. `set -euo pipefail`), so
# mid-file `#` comments — section dividers, `# shellcheck …` directives — never leak into --help.
# The shebang and SPDX lines are dropped; a leading "# " (with optional single space) is stripped.
cli::usage() {
  awk '
    !/^#/            { exit }                       # first code line ends the header
    /^#!/            { next }                        # shebang
    /^#[[:space:]]*SPDX-/ { next }                   # SPDX tag
    { sub(/^#[[:space:]]?/, ""); print }
  ' "$1"
}

# ------------------------------ Spinner ---------------------------------------------
# cli::run "<message>" <cmd> [args...] — run cmd; at a terminal show one subtle spinner while it
# blocks, then a final ✅/❌ line. Non-interactive: announce, run, report — no control chars.
# Returns the command's exit code. Use for genuinely long, QUIET steps only: at a TTY the command
# runs in the BACKGROUND so the spinner can animate, which hides any prompt/streamed output. For
# commands that prompt or stream (terragrunt/helmfile), call them directly instead.
cli::run() {
  local msg="$1"; shift
  local rc=0 _e=0; case $- in *e*) _e=1;; esac   # remember caller's errexit
  if ! cli::interactive; then
    cli::step "$msg"
    set +e; "$@"; rc=$?; [[ $_e -eq 1 ]] && set -e
    if [[ $rc -eq 0 ]]; then cli::ok "$msg"; else cli::err "$msg (exit $rc)"; fi
    return $rc
  fi
  "$@" &
  local pid=$! i=0 n="${#CLI_SPIN_FRAMES}"
  tput civis 2>/dev/null || true
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r%s %s' "$(cli::_c CLI_CYAN "${CLI_SPIN_FRAMES:$((i++ % n)):1}")" "$msg" >&2
    sleep 0.1
  done
  set +e; wait "$pid"; rc=$?; [[ $_e -eq 1 ]] && set -e
  tput cnorm 2>/dev/null || true
  printf '\r\033[K' >&2                       # clear the spinner line
  if [[ $rc -eq 0 ]]; then cli::ok "$msg"; else cli::err "$msg (exit $rc)"; fi
  return $rc
}

# ------------------------------ Value resolution ------------------------------------
# cli::pick <flag> <env> <conf> <default> — first non-empty of flag/env/conf, else default.
# (4-way precedence: CLI flag > shell env > .conf value > built-in default. No prompting.)
cli::pick() {
  [[ -n "$1" ]] && { printf '%s' "$1"; return; }
  [[ -n "$2" ]] && { printf '%s' "$2"; return; }
  [[ -n "$3" ]] && { printf '%s' "$3"; return; }
  printf '%s' "$4"
}

# cli::validate_enum <name> <value> <choice...> — die (exit 2) unless value is one of the choices.
cli::validate_enum() {
  local name="$1" val="$2"; shift 2
  local c
  for c in "$@"; do [[ "$val" == "$c" ]] && return 0; done
  cli::die "$name must be one of: $* (got: '$val')"
}
