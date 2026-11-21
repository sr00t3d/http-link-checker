# HTTP Link Checker (`link-checker.sh`)

🇺🇸 [English](README.md) | 🇧🇷 [Português (BR)](README-ptbr.md) | 🇪🇸 **Español**

[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/http-link-checker/releases) [![Shell](https://img.shields.io/badge/bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)

![Portada HTTP Link Checker](http-link-checker-cover.webp)

`link-checker.sh` es un crawler CLI en Bash con profundidad controlada para auditar códigos de respuesta HTTP, detectar enlaces rotos (`4xx`/`5xx`) y listar redirecciones (`3xx`) — diseñado para validaciones post-despliegue, auditorías de SEO técnico y pipelines CI/CD.

> **Créditos Históricos:** Refactorizado del script original `checker.sh` de **Percio Andrade (Percio Castelo)**.

## Uso

```bash
link-checker https://example.com
link-checker --depth 3 --show-redirects --exit-code https://example.com
link-checker --depth 2 --show-redirects -o json https://staging.example.com
link-checker --depth 2 --show-redirects -o csv https://example.com
```

## Licencia

Licenciado bajo la [Apache License 2.0](LICENSE).

## Windows (PowerShell `link-checker.ps1`)

Cero dependencias externas — usa `.NET HttpClient` nativo en **Windows PowerShell 5.1** y **PowerShell 7+**:

```powershell
.\link-checker.ps1 https://example.com
.\link-checker.ps1 https://example.com -MaxDepth 2 -MaxUrls 100 -OnlyErrors -ExitCode
.\link-checker.ps1 https://example.com -Output json
```
