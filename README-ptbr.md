# HTTP Link Checker (`link-checker.sh`)

🇺🇸 [English](README.md) | 🇧🇷 **Português (BR)** | 🇪🇸 [Español](README-es.md)

[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/http-link-checker/releases) [![Shell](https://img.shields.io/badge/bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)

![Capa HTTP Link Checker](http-link-checker-cover.webp)

`link-checker.sh` é um crawler CLI em Bash com profundidade controlada para auditar códigos de resposta HTTP, detectar links quebrados (`4xx`/`5xx`) e listar redirecionamentos (`3xx`) — ideal para validações pós-deploy, auditoria de SEO técnico e pipelines de CI/CD.

> **Créditos Históricos:** Refatorado do utilitário original `checker.sh` de **Percio Andrade (Percio Castelo)**, agora com limite de profundidade, respeito a `robots.txt` por padrão, listagem exata de URLs quebradas/redirecionadas, exit codes para CI e saídas estruturadas `table`/`json`/`csv`.

## Principais Recursos

- **Crawl Seguro e Limitado:** aplica `--depth` (padrão `2`), `--timeout`, `--tries`, `--wait` opcional, respeita `robots.txt` por padrão (`--ignore-robots` opt-in) e grava logs temporários em `mktemp` `chmod 600` removidos automaticamente via `trap EXIT`.
- **Diagnóstico Completo:** agrupa todos os códigos HTTP por frequência **e** lista as URLs exatas com erro (`4xx`/`5xx`) além de redirecionamentos (`--show-redirects`).
- **Pronto para CI/CD:** `--exit-code` retorna código `2` sempre que encontrar links quebrados; suporta `-o table|json|csv`, `-q/--quiet`, `--no-color`, `--insecure` e `--user-agent`.

## Instalação

```bash
git clone https://github.com/sr00t3d/http-link-checker.git
cd http-link-checker
chmod +x link-checker.sh
sudo install -m 0755 link-checker.sh /usr/local/bin/link-checker
```

## Uso

```bash
link-checker https://example.com
link-checker --depth 3 --show-redirects --exit-code https://example.com
link-checker --depth 2 --show-redirects -o json https://staging.example.com
link-checker --depth 2 --show-redirects -o csv https://example.com
```

## Execução Direta & Windows PowerShell

### Linux / macOS (Execução Direta)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/http-link-checker/main/link-checker.sh) https://example.com
```

### Windows (PowerShell `link-checker.ps1`)
Zero dependências externas — compatível com **Windows PowerShell 5.1+** e **PowerShell 7+**:

```powershell
# Execução direta (sem clonar)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/sr00t3d/http-link-checker/main/link-checker.ps1))) https://example.com

# Execução local
.\link-checker.ps1 https://example.com
.\link-checker.ps1 https://example.com -MaxDepth 2 -MaxUrls 100 -OnlyErrors -ExitCode
.\link-checker.ps1 https://example.com -Output json
```

## Exemplo de Saída Real

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

## Licença

Licenciado sob a [Apache License 2.0](LICENSE).