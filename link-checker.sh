#!/usr/bin/env bash
# ==============================================================================
#  link-checker.sh — Bounded HTTP Link & Status Code Crawler CLI
# ==============================================================================
#  Author  : Percio Castelo (Percio Andrade) <percio@perciocastelo.com.br>
#  Website : https://perciocastelo.com.br
#  Project : https://perciocastelo.com.br/projetos/en/http-link-checker.html
#  Repo    : https://github.com/sr00t3d/http-link-checker
#  License : Apache-2.0
#  Version : 2.0.0
# ==============================================================================

set -uo pipefail

readonly SCRIPT_NAME="link-checker.sh"
readonly SCRIPT_VERSION="2.0.0"

# Runtime options
TARGET_URL=""
DEPTH=2
TIMEOUT=10
TRIES=1
WAIT_SEC=0
IGNORE_ROBOTS=0
INSECURE_TLS=0
SHOW_REDIRECTS=0
EXIT_CODE_MODE=0
USER_AGENT="http-link-checker/${SCRIPT_VERSION} (+https://github.com/sr00t3d/http-link-checker)"
FORMAT="table"
QUIET=0
NO_COLOR=0

# Internal state
LOG_TMP=""
TIMESTAMP_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
TOTAL_REQUESTS=0
BROKEN_COUNT=0
REDIRECT_COUNT=0
CODE_SUMMARY=""      # lines: count|code
BROKEN_ROWS=""       # lines: code|url
REDIRECT_ROWS=""     # lines: code|url

# Colors
RED="" GREEN="" YELLOW="" CYAN="" BOLD="" RESET=""
OK="[OK]" ATT="[!]" FAIL="[ERR]"

cleanup() {
  [[ -n "$LOG_TMP" && -f "$LOG_TMP" ]] && rm -f "$LOG_TMP"
}
trap cleanup EXIT

init_colors() {
  if [[ "$NO_COLOR" -eq 0 && -t 1 && -z "${NO_COLOR:-}" && "$FORMAT" == "table" ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    CYAN=$'\033[0;36m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
    OK="${GREEN}[OK]${RESET}"
    ATT="${YELLOW}[!]${RESET}"
    FAIL="${RED}[ERR]${RESET}"
  else
    RED="" GREEN="" YELLOW="" CYAN="" BOLD="" RESET=""
    OK="[OK]" ATT="[!]" FAIL="[ERR]"
  fi
}

show_help() {
  cat <<'USAGE'
link-checker.sh v2.0.0 — Bounded HTTP Link & Status Code Crawler CLI

Usage:
  link-checker.sh [options] <url>

Crawl Options:
  -l, --depth <N>            Max recursive crawl depth (default: 2)
  -t, --timeout <sec>        Network timeout per request in seconds (default: 10)
  --tries <N>                Retries per URL (default: 1)
  --wait <sec>               Delay in seconds between requests (default: 0)
  --ignore-robots            Ignore robots.txt (respects robots.txt by default)
  --insecure                 Skip TLS certificate verification (for local/dev labs)
  --user-agent <ua>          Custom HTTP User-Agent string
  --show-redirects           Also list 3xx redirected URLs in output

Output & CI Options:
  -o, --output <fmt>         Output format: table (default), json, csv
  --exit-code                Exit with code 2 if any 4xx/5xx broken URLs are found
  -q, --quiet                Suppress banner header
  --no-color                 Disable ANSI colors
  -V, --version              Show version and exit
  -h, --help                 Show this help and exit

Examples:
  link-checker.sh https://example.com
  link-checker.sh --depth 3 --show-redirects https://example.com
  link-checker.sh --depth 2 -o json --exit-code https://staging.example.com
  link-checker.sh --depth 1 --ignore-robots -o csv http://127.0.0.1:8080/
USAGE
}

need_cmd() {
  local missing=0 cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf '[ERR] Missing required command: %s\n' "$cmd" >&2
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]] || exit 1
}

validate_url() {
  if [[ -z "$TARGET_URL" ]] || ! printf '%s' "$TARGET_URL" | grep -Eq '^https?://[A-Za-z0-9._:-]+(/.*)?$'; then
    printf '%s Invalid URL (must start with http:// or https://): %s\n' "$FAIL" "${TARGET_URL:-<empty>}" >&2
    exit 1
  fi
}

run_spider() {
  LOG_TMP="$(mktemp /tmp/link-checker.XXXXXX)"
  chmod 600 "$LOG_TMP"

  local -a wargs=(
    --spider
    --recursive
    --level="$DEPTH"
    --no-directories
    --delete-after
    --timeout="$TIMEOUT"
    --tries="$TRIES"
    --user-agent="$USER_AGENT"
    --server-response
  )

  [[ "$WAIT_SEC" != "0" ]] && wargs+=(--wait="$WAIT_SEC")
  [[ "$IGNORE_ROBOTS" -eq 1 ]] && wargs+=(-e robots=off)
  [[ "$INSECURE_TLS" -eq 1 ]] && wargs+=(--no-check-certificate)

  # Run wget spider (non-zero exit is normal when broken links exist)
  wget "${wargs[@]}" "$TARGET_URL" > "$LOG_TMP" 2>&1 || true
}

parse_spider_log() {
  local parsed
  parsed="$(awk '
    /^--[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
      url = $3
      sub(/^--/, "", url)
      next
    }
    /^[[:space:]]*HTTP\/[0-9.]+[[:space:]]+[0-9]{3}/ {
      code = $2
      if (url != "") {
        last_code[url] = code
        if (!(url in seen)) {
          seen[url] = 1
          order[++n] = url
        }
        counts[code]++
        total++
      }
    }
    END {
      printf "TOTAL|%d\n", total
      for (c in counts) {
        printf "CODE|%d|%s\n", counts[c], c
      }
      for (i = 1; i <= n; i++) {
        u = order[i]
        c = last_code[u]
        if (c ~ /^[45][0-9][0-9]$/) {
          printf "BROKEN|%s|%s\n", c, u
        } else if (c ~ /^3[0-9][0-9]$/) {
          printf "REDIRECT|%s|%s\n", c, u
        }
      }
    }
  ' "$LOG_TMP")"

  TOTAL_REQUESTS="$(printf '%s\n' "$parsed" | awk -F'|' '$1=="TOTAL" {print $2; exit}')"
  TOTAL_REQUESTS="${TOTAL_REQUESTS:-0}"

  CODE_SUMMARY="$(printf '%s\n' "$parsed" | awk -F'|' '$1=="CODE" {print $2 "|" $3}' | sort -t'|' -k1,1nr || true)"
  BROKEN_ROWS="$(printf '%s\n' "$parsed" | awk -F'|' '$1=="BROKEN" {print $2 "|" $3}' | sort -u || true)"
  REDIRECT_ROWS="$(printf '%s\n' "$parsed" | awk -F'|' '$1=="REDIRECT" {print $2 "|" $3}' | sort -u || true)"

  [[ -n "$BROKEN_ROWS" ]] && BROKEN_COUNT="$(printf '%s\n' "$BROKEN_ROWS" | wc -l | tr -d ' ')" || BROKEN_COUNT=0
  [[ -n "$REDIRECT_ROWS" ]] && REDIRECT_COUNT="$(printf '%s\n' "$REDIRECT_ROWS" | wc -l | tr -d ' ')" || REDIRECT_COUNT=0
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  printf '%s' "$s"
}

csv_escape() {
  local s="$1"
  s="${s//$'\n'/ ; }"
  s="${s//$'\r'/}"
  s="${s//\"/\"\"}"
  printf '"%s"' "$s"
}

render_output() {
  local cnt code url
  case "$FORMAT" in
    json)
      local codes_json="" broken_json="" redir_json="" first
      first=1
      while IFS='|' read -r cnt code; do
        [[ -z "$code" ]] && continue
        [[ "$first" -eq 0 ]] && codes_json+=","
        first=0
        codes_json+="\"$(json_escape "$code")\":${cnt}"
      done <<<"$CODE_SUMMARY"

      first=1
      while IFS='|' read -r code url; do
        [[ -z "$url" ]] && continue
        [[ "$first" -eq 0 ]] && broken_json+=","
        first=0
        broken_json+="{\"code\":\"$(json_escape "$code")\",\"url\":\"$(json_escape "$url")\"}"
      done <<<"$BROKEN_ROWS"

      first=1
      if [[ "$SHOW_REDIRECTS" -eq 1 ]]; then
        while IFS='|' read -r code url; do
          [[ -z "$url" ]] && continue
          [[ "$first" -eq 0 ]] && redir_json+=","
          first=0
          redir_json+="{\"code\":\"$(json_escape "$code")\",\"url\":\"$(json_escape "$url")\"}"
        done <<<"$REDIRECT_ROWS"
      fi

      cat <<EOF
{
  "tool": "${SCRIPT_NAME}",
  "version": "${SCRIPT_VERSION}",
  "timestamp": "$(json_escape "$TIMESTAMP_UTC")",
  "target_url": "$(json_escape "$TARGET_URL")",
  "depth": ${DEPTH},
  "total_requests": ${TOTAL_REQUESTS},
  "broken_count": ${BROKEN_COUNT},
  "redirect_count": ${REDIRECT_COUNT},
  "status_counts": {${codes_json}},
  "broken_urls": [${broken_json}],
  "redirect_urls": [${redir_json}]
}
EOF
      ;;
    csv)
      printf 'category,http_code,url\n'
      while IFS='|' read -r code url; do
        [[ -z "$url" ]] && continue
        printf '"broken",%s,%s\n' "$(csv_escape "$code")" "$(csv_escape "$url")"
      done <<<"$BROKEN_ROWS"
      if [[ "$SHOW_REDIRECTS" -eq 1 ]]; then
        while IFS='|' read -r code url; do
          [[ -z "$url" ]] && continue
          printf '"redirect",%s,%s\n' "$(csv_escape "$code")" "$(csv_escape "$url")"
        done <<<"$REDIRECT_ROWS"
      fi
      ;;
    table)
      if [[ "$QUIET" -eq 0 ]]; then
        printf '%s=====================================================================%s\n' "$CYAN" "$RESET"
        printf ' %s%s v%s%s | Target: %s (depth=%d) | %s\n' "$BOLD" "$SCRIPT_NAME" "$SCRIPT_VERSION" "$RESET" "$TARGET_URL" "$DEPTH" "$TIMESTAMP_UTC"
        printf '%s=====================================================================%s\n' "$CYAN" "$RESET"
      fi

      printf '\nHTTP Status Summary (total responses: %d):\n' "$TOTAL_REQUESTS"
      if [[ -z "$CODE_SUMMARY" ]]; then
        printf '  %s No HTTP responses recorded (host unreachable or blocked).\n' "$ATT"
      else
        while IFS='|' read -r cnt code; do
          [[ -z "$code" ]] && continue
          printf '  HTTP %-4s : %s\n' "$code" "$cnt"
        done <<<"$CODE_SUMMARY"
      fi

      if [[ "$BROKEN_COUNT" -gt 0 ]]; then
        printf '\n%s Broken URLs (4xx / 5xx — %d found):\n' "$FAIL" "$BROKEN_COUNT"
        while IFS='|' read -r code url; do
          [[ -z "$url" ]] && continue
          printf '  [%s] %s\n' "$code" "$url"
        done <<<"$BROKEN_ROWS"
      else
        printf '\n%s No broken URLs (4xx / 5xx) detected.\n' "$OK"
      fi

      if [[ "$SHOW_REDIRECTS" -eq 1 && "$REDIRECT_COUNT" -gt 0 ]]; then
        printf '\n%s Redirected URLs (3xx — %d found):\n' "$ATT" "$REDIRECT_COUNT"
        while IFS='|' read -r code url; do
          [[ -z "$url" ]] && continue
          printf '  [%s] %s\n' "$code" "$url"
        done <<<"$REDIRECT_ROWS"
      fi
      ;;
  esac
}

main() {
  need_cmd wget awk sort grep

  [[ "$#" -eq 0 ]] && { show_help; exit 1; }

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -h|--help)         show_help; exit 0 ;;
      -V|--version)      printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
      -l|--depth)        DEPTH="${2:-2}"; shift 2 ;;
      -t|--timeout)      TIMEOUT="${2:-10}"; shift 2 ;;
      --tries)           TRIES="${2:-1}"; shift 2 ;;
      --wait)            WAIT_SEC="${2:-0}"; shift 2 ;;
      --ignore-robots)   IGNORE_ROBOTS=1; shift ;;
      --insecure)        INSECURE_TLS=1; shift ;;
      --user-agent)      USER_AGENT="${2:-$USER_AGENT}"; shift 2 ;;
      --show-redirects)  SHOW_REDIRECTS=1; shift ;;
      --exit-code)       EXIT_CODE_MODE=1; shift ;;
      -q|--quiet)        QUIET=1; shift ;;
      --no-color)        NO_COLOR=1; shift ;;
      -o|--output)       FORMAT="${2:-table}"; shift 2 ;;
      --output=*)        FORMAT="${1#*=}"; shift ;;
      --*)               printf '[ERR] Unknown option: %s (use -h for help)\n' "$1" >&2; exit 1 ;;
      *)                 TARGET_URL="$1"; shift ;;
    esac
  done

  case "$FORMAT" in
    table|json|csv) ;;
    *) printf '[ERR] Invalid output format: %s (expected table, json, or csv)\n' "$FORMAT" >&2; exit 1 ;;
  esac

  init_colors
  validate_url
  run_spider
  parse_spider_log
  render_output

  if [[ "$EXIT_CODE_MODE" -eq 1 && "$BROKEN_COUNT" -gt 0 ]]; then
    exit 2
  fi
  exit 0
}

main "$@"
