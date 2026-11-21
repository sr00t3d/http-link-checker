<#
.SYNOPSIS
    link-checker.ps1 — Bounded HTTP/HTTPS Link Crawler & Broken Link Auditor (PowerShell)

.DESCRIPTION
    Crawls a target website up to a bounded depth and URL limit using native .NET
    HttpClient, classifying HTTP 2xx, 3xx, 4xx, 5xx and connection errors, with
    table/json/csv outputs and CI/CD exit code 2 when broken links are found.

    Author  : Percio Castelo (Percio Andrade) <percio@perciocastelo.com.br>
    Website : https://perciocastelo.com.br
    Project : https://perciocastelo.com.br/projetos/en/http-link-checker.html
    Repo    : https://github.com/sr00t3d/http-link-checker
    License : Apache-2.0
    Version : 2.1.0

.EXAMPLE
    .\link-checker.ps1 https://example.com
    .\link-checker.ps1 https://example.com -MaxDepth 2 -MaxUrls 100 -OnlyErrors -ExitCode
    .\link-checker.ps1 https://example.com -Output json
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [Alias('u')]
    [string]$Url,

    [Alias('d')]
    [int]$MaxDepth = 2,

    [Alias('n')]
    [int]$MaxUrls = 100,

    [int]$Timeout = 10,

    [switch]$OnlyErrors,
    [switch]$ExitCode,

    [Alias('o')]
    [ValidateSet('table', 'json', 'csv')]
    [string]$Output = 'table',

    [Alias('q')]
    [switch]$Quiet,

    [switch]$NoColor,

    [Alias('V')]
    [switch]$Version,

    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptName = 'link-checker.ps1'
$ScriptVersion = '2.1.0'
$TimestampUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

function Show-Help {
@"
$ScriptName v$ScriptVersion — Bounded HTTP/HTTPS Broken Link Crawler (PowerShell)

Usage:
  .\link-checker.ps1 <url> [options]

Options:
  -MaxDepth, -d <n>          Maximum crawl depth (default: 2)
  -MaxUrls, -n <n>           Maximum URLs to check (default: 100)
  -Timeout <sec>             HTTP timeout per request in seconds (default: 10)
  -OnlyErrors                Show only broken (4xx/5xx/ERR) links in table output
  -ExitCode                  Exit with code 2 if any broken links are detected (CI/CD)
  -Output, -o <fmt>          Output format: table (default), json, csv
  -Quiet, -q                 Suppress banner header and summary
  -NoColor                   Disable colored output
  -Version, -V               Show version and exit
  -Help, -h                  Show this help and exit
"@ | Write-Output
}

function Write-ColorLine {
    param([string]$Text, [ConsoleColor]$Color = [ConsoleColor]::Gray)
    if ($NoColor -or $env:NO_COLOR -or $Output -ne 'table') {
        Write-Output $Text
    } else {
        Write-Host $Text -ForegroundColor $Color
    }
}

if ($Help) { Show-Help; exit 0 }
if ($Version) { Write-Output "$ScriptName $ScriptVersion"; exit 0 }
if (-not $Url) { Show-Help; exit 1 }

if ($Url -notmatch '^https?://') { $Url = "https://$Url" }
$StartUri = [System.Uri]$Url
$BaseHost = $StartUri.Host.ToLowerInvariant()

# Native HttpClient (disable auto-redirect so we can see 3xx accurately)
$handler = New-Object System.Net.Http.HttpClientHandler
$handler.AllowAutoRedirect = $false
$client = New-Object System.Net.Http.HttpClient($handler)
$client.Timeout = [TimeSpan]::FromSeconds($Timeout)
$client.DefaultRequestHeaders.UserAgent.ParseAdd("http-link-checker/$ScriptVersion (+https://github.com/sr00t3d/http-link-checker)")

$Visited = New-Object 'System.Collections.Generic.HashSet[string]'
$Queue = New-Object 'System.Collections.Generic.Queue[object]'
$Results = New-Object System.Collections.Generic.List[object]

$Queue.Enqueue([PSCustomObject]@{ Url = $StartUri.AbsoluteUri; Depth = 0 })
[void]$Visited.Add($StartUri.AbsoluteUri)

$OkCount = 0; $RedirCount = 0; $BrokenCount = 0

try {
    while ($Queue.Count -gt 0 -and $Results.Count -lt $MaxUrls) {
        $item = $Queue.Dequeue()
        $curUrl = $item.Url
        $depth = $item.Depth
        $status = 0
        $state = 'ERR'
        $location = ''
        $body = ''
        $ctype = ''

        try {
            $resp = $client.GetAsync($curUrl).GetAwaiter().GetResult()
            $status = [int]$resp.StatusCode
            if ($resp.Headers.Location) { $location = $resp.Headers.Location.ToString() }
            if ($resp.Content.Headers.ContentType) { $ctype = $resp.Content.Headers.ContentType.MediaType }

            if ($status -ge 200 -and $status -lt 300) {
                $state = 'OK'
                $OkCount++
                if ($depth -lt $MaxDepth -and $ctype -like '*html*') {
                    $body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                }
            } elseif ($status -ge 300 -and $status -lt 400) {
                $state = 'REDIRECT'
                $RedirCount++
            } else {
                $state = 'BROKEN'
                $BrokenCount++
            }
            $resp.Dispose()
        } catch {
            $state = 'BROKEN'
            $BrokenCount++
        }

        $Results.Add([PSCustomObject]@{
            url      = $curUrl
            status   = $status
            state    = $state
            depth    = $depth
            redirect = $location
        })

        if ($body -and $Results.Count -lt $MaxUrls) {
            $curUri = [System.Uri]$curUrl
            $matches = [regex]::Matches($body, '(?i)href\s*=\s*["'']([^"'']+)["'']')
            foreach ($m in $matches) {
                $href = $m.Groups[1].Value.Trim()
                if (-not $href -or $href.StartsWith('#') -or $href -match '^(mailto:|tel:|javascript:|data:)') { continue }
                try {
                    $nextUri = New-Object System.Uri($curUri, $href)
                    if ($nextUri.Scheme -notin @('http', 'https')) { continue }
                    if ($nextUri.Host.ToLowerInvariant() -ne $BaseHost) { continue }
                    $cleanNext = $nextUri.GetLeftPart([System.UriPartial]::Query)
                    if (-not $Visited.Contains($cleanNext) -and ($Visited.Count -lt $MaxUrls)) {
                        [void]$Visited.Add($cleanNext)
                        $Queue.Enqueue([PSCustomObject]@{ Url = $cleanNext; Depth = ($depth + 1) })
                    }
                } catch { }
            }
        }
    }
} finally {
    $client.Dispose()
    $handler.Dispose()
}

switch ($Output) {
    'json' {
        [PSCustomObject]@{
            tool      = $ScriptName
            version   = $ScriptVersion
            timestamp = $TimestampUtc
            start_url = $StartUri.AbsoluteUri
            checked   = $Results.Count
            ok        = $OkCount
            redirects = $RedirCount
            broken    = $BrokenCount
            results   = $Results
        } | ConvertTo-Json -Depth 5 | Write-Output
    }
    'csv' {
        Write-Output 'url,status,state,depth,redirect'
        foreach ($r in $Results) {
            if ($OnlyErrors -and $r.state -ne 'BROKEN') { continue }
            $vals = @($r.url, $r.status, $r.state, $r.depth, $r.redirect) |
                ForEach-Object { '"' + ([string]$_ -replace '"', '""') + '"' }
            Write-Output ($vals -join ',')
        }
    }
    default {
        if (-not $Quiet) {
            Write-ColorLine ('=' * 80) ([ConsoleColor]::Cyan)
            Write-Output (" {0} v{1} | HTTP Link Checker | {2}" -f $ScriptName, $ScriptVersion, $TimestampUtc)
            Write-ColorLine ('=' * 80) ([ConsoleColor]::Cyan)
            Write-Output ("{0,-8} {1,-10} {2}" -f 'STATUS', 'STATE', 'URL')
            Write-Output ("{0,-8} {1,-10} {2}" -f '--------', '----------', ('-' * 58))
        }
        foreach ($r in $Results) {
            if ($OnlyErrors -and $r.state -ne 'BROKEN') { continue }
            $col = switch ($r.state) {
                'OK'       { [ConsoleColor]::Green }
                'REDIRECT' { [ConsoleColor]::Yellow }
                default    { [ConsoleColor]::Red }
            }
            $line = "{0,-8} {1,-10} {2}" -f $r.status, $r.state, $r.url
            if ($r.redirect) { $line += " -> $($r.redirect)" }
            Write-ColorLine $line $col
        }
        if (-not $Quiet) {
            Write-Output ''
            Write-Output ("Summary: {0} checked | {1} OK | {2} REDIRECT | {3} BROKEN" -f $Results.Count, $OkCount, $RedirCount, $BrokenCount)
        }
    }
}

if ($ExitCode -and $BrokenCount -gt 0) { exit 2 }
exit 0
