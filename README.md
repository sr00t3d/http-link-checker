# HTTP Link Checker (`link-checker.sh`)

🇺🇸 **English** | 🇧🇷 [Português (BR)](README-ptbr.md) | 🇪🇸 [Español](README-es.md)

[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/http-link-checker/releases) [![Shell](https://img.shields.io/badge/bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)

`link-checker.sh` is a bounded Bash CLI crawler for auditing website HTTP response codes, detecting broken links (`4xx`/`5xx`), and inspecting redirects (`3xx`) — designed for post-deploy verification, technical SEO audits, and CI/CD pipelines.

> **Historical Credits:** Refactored from the original `checker.sh` utility by **Percio Andrade (Percio Castelo)**, upgraded with bounded crawl depth, `robots.txt` compliance by default, exact broken/redirect URL reporting, CI exit codes, and structured `table`/`json`/`csv` outputs.

## Key Features

- **Safe Bounded Crawling:** enforces `--depth` (default `2`), `--timeout`, `--tries`, optional polite `--wait`, respects `robots.txt` by default (`--ignore-robots` opt-in), and stores temporary spider logs in a `chmod 600` `mktemp` file cleaned automatically via `trap EXIT`.
- **Full Diagnostics:** summarizes all HTTP status codes by frequency **and** lists exact broken URLs (`4xx`/`5xx`) plus optional redirects (`--show-redirects`).
- **CI/CD Ready:** `--exit-code` exits with status `2` whenever broken links are detected; supports `-o table|json|csv`, `-q/--quiet`, `--no-color`, `--insecure`, and custom `--user-agent`.

## Installation

```bash
git clone https://github.com/sr00t3d/http-link-checker.git
cd http-link-checker
chmod +x link-checker.sh
sudo install -m 0755 link-checker.sh /usr/local/bin/link-checker
```

## Usage

```bash
# Default bounded crawl (depth 2, respects robots.txt)
link-checker https://example.com

# Include 3xx redirects and return exit code 2 on broken links
link-checker --depth 3 --show-redirects --exit-code https://example.com

# Structured JSON output for CI/CD pipelines
link-checker --depth 2 --show-redirects -o json https://staging.example.com

# CSV export for SEO spreadsheets
link-checker --depth 2 --show-redirects -o csv https://example.com
```

## Real Output Example

### Table Output (`link-checker.sh --depth 2 --ignore-robots --show-redirects --exit-code --no-color http://127.0.0.1:18999/`)

```text
=====================================================================
 link-checker.sh v2.0.0 | Target: http://127.0.0.1:18999/ (depth=2) | 2026-11-21T02:22:07Z
=====================================================================

HTTP Status Summary (total responses: 8):
  HTTP 200  : 6
  HTTP 301  : 1
  HTTP 404  : 1

[ERR] Broken URLs (4xx / 5xx — 1 found):
  [404] http://127.0.0.1:18999/missing.html

[!] Redirected URLs (3xx — 1 found):
  [301] http://127.0.0.1:18999/old
```

### Structured JSON Output (`link-checker.sh --depth 2 --show-redirects -o json http://127.0.0.1:18999/`)

```json
{
  "tool": "link-checker.sh",
  "version": "2.0.0",
  "timestamp": "2026-11-21T02:22:07Z",
  "target_url": "http://127.0.0.1:18999/",
  "depth": 2,
  "total_requests": 8,
  "broken_count": 1,
  "redirect_count": 1,
  "status_counts": { "200": 6, "301": 1, "404": 1 },
  "broken_urls": [{ "code": "404", "url": "http://127.0.0.1:18999/missing.html" }],
  "redirect_urls": [{ "code": "301", "url": "http://127.0.0.1:18999/old" }]
}
```

## License

Licensed under the [Apache License 2.0](LICENSE).
