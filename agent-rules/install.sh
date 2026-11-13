#!/usr/bin/env bash
# Install the programming-convention rules for Claude Code.
#
# Copies agent-rules/rules/*.md to $CLAUDE_CONFIG_DIR/rules/ (default ~/.claude)
# and appends agent-rules/CLAUDE-block.md to $CLAUDE_CONFIG_DIR/CLAUDE.md.
# Existing files are never overwritten unless --force is given.
# Running it again is safe: identical files and an already-present block are skipped.
#
# Requires: Bash 3.2 or newer (the stock macOS shell).

if ((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] < 302)); then
  printf '%s: requires Bash 3.2 or newer (found %s)\n' \
    "${0##*/}" "${BASH_VERSION}" >&2
  exit 1
fi

set -euo pipefail
# inherit_errexit is Bash 4.4 and later; on 3.2 the option is unavailable.
shopt -s inherit_errexit 2>/dev/null || true

readonly PROGRAM="${0##*/}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly RULES_SRC="${SCRIPT_DIR}/rules"
readonly BLOCK_SRC="${SCRIPT_DIR}/CLAUDE-block.md"
readonly CONFIG_DIR="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
readonly RULES_DEST="${CONFIG_DIR}/rules"
readonly CLAUDE_MD="${CONFIG_DIR}/CLAUDE.md"
readonly BLOCK_HEADING='## Programming conventions'

force=false
dry_run=false

# usage [stream]
# Prints the help text to stdout, or to stderr when a stream is not given.
usage() {
  cat <<'EOF'
Usage: install.sh [-n|--dry-run] [-f|--force] [-h|--help]

  -n, --dry-run  Show what would change; write nothing.
  -f, --force    Overwrite rule files that differ from the repository copy.
  -h, --help     Show this help.

Environment:
  CLAUDE_CONFIG_DIR  Target folder (default: ~/.claude).
EOF
}

# log message...
# Prints a progress line to stdout.
log() {
  printf '%s\n' "$*"
}

# warn message...
# Prints a warning to stderr, prefixed with the program name.
warn() {
  printf '%s: warning: %s\n' "${PROGRAM}" "$*" >&2
}

# err message...
# Prints an error to stderr, prefixed with the program name.
err() {
  printf '%s: error: %s\n' "${PROGRAM}" "$*" >&2
}

# die message...
# Prints an error to stderr and exits with status 1.
die() {
  err "$@"
  exit 1
}

# parse_args [arg...]
# Sets force and dry_run from the command line. Exits 0 for --help and 2 for
# unknown options.
parse_args() {
  while (($#)); do
    case "$1" in
      -n | --dry-run) dry_run=true ;;
      -f | --force) force=true ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        err "unknown option: $1"
        usage >&2
        exit 2
        ;;
    esac
    shift
  done
}

# check_sources
# Exits with status 1 unless the rule files and the index block exist.
check_sources() {
  [[ -d "${RULES_SRC}" ]] || die "missing folder: ${RULES_SRC}"
  [[ -f "${BLOCK_SRC}" ]] || die "missing file: ${BLOCK_SRC}"
  compgen -G "${RULES_SRC}/*.md" >/dev/null || die "no rule files in ${RULES_SRC}"
}

# mkdir_if_needed dir
# Creates dir unless this is a dry run.
mkdir_if_needed() {
  if [[ "${dry_run}" == true ]]; then
    return
  fi
  mkdir -p -- "$1"
}

# copy_file src dest verb
# Copies src to dest and logs verb, or only logs what would happen in a dry run.
copy_file() {
  local src="$1" dest="$2" verb="$3"
  if [[ "${dry_run}" == true ]]; then
    log "would write ${dest}"
    return
  fi
  cp -- "${src}" "${dest}"
  log "${verb}  ${dest}"
}

# install_rules
# Copies each rule file that is missing, and replaces differing ones only with
# --force. Identical files are left alone.
install_rules() {
  local src name dest
  mkdir_if_needed "${RULES_DEST}"

  for src in "${RULES_SRC}"/*.md; do
    name="${src##*/}"
    dest="${RULES_DEST}/${name}"

    if [[ ! -e "${dest}" ]]; then
      copy_file "${src}" "${dest}" installed
    elif cmp -s -- "${src}" "${dest}"; then
      log "unchanged  ${dest}"
    elif [[ "${force}" == true ]]; then
      copy_file "${src}" "${dest}" overwrote
    else
      warn "skipped ${dest}: it differs from the repository copy (use --force to replace it)"
    fi
  done
}

# install_block
# Appends the index block to CLAUDE.md unless its heading is already there.
install_block() {
  if [[ -f "${CLAUDE_MD}" ]] && grep -qxF -- "${BLOCK_HEADING}" "${CLAUDE_MD}"; then
    log "unchanged  ${CLAUDE_MD} (block already present)"
    return
  fi

  if [[ "${dry_run}" == true ]]; then
    log "would append block to ${CLAUDE_MD}"
    return
  fi

  mkdir_if_needed "${CONFIG_DIR}"
  if [[ -s "${CLAUDE_MD}" ]]; then
    printf '\n' >>"${CLAUDE_MD}"
  fi
  cat -- "${BLOCK_SRC}" >>"${CLAUDE_MD}"
  log "appended   block to ${CLAUDE_MD}"
}

# main [arg...]
# Entry point: parses options, checks the sources, then installs.
main() {
  parse_args "$@"
  check_sources

  if [[ "${dry_run}" == true ]]; then
    log "dry run: nothing will be written"
  fi

  install_rules
  install_block

  log ""
  log "Done. Start a new Claude Code session to load the rules."
}

main "$@"
