# install.ps1 -- bootstraps the deep-research skill's dependencies (Windows mirror of install.sh).
# Idempotent: safe to re-run. Skips anything already in place.
# PowerShell 5.1+ compatible (no &&, no ternary, no ?., no ??).
#
# Nothing here is vendored into this repo. Every dependency is fetched live
# from its own source at install time -- one companion skill from Hunter's
# GitHub, one package from PyPI, one MCP server cloned from its upstream
# author. See references/onboarding.md for what each one does and why.

$ErrorActionPreference = 'Stop'

# --- resolve paths -----------------------------------------------------------
$ScriptDir = $PSScriptRoot
$SkillRoot = (Resolve-Path (Join-Path $ScriptDir '..')).Path
$HomeDir   = $env:USERPROFILE
if ([string]::IsNullOrEmpty($HomeDir)) { $HomeDir = $HOME }
$HomeSkills = Join-Path $HomeDir '.claude\skills'
$DrHome     = Join-Path $HomeDir '.claude\deep-research'
$VendorDir  = Join-Path $DrHome 'vendor'

$ExaSearchRepo        = 'https://github.com/Huntehhh/exa-search.git'
$PerplexityServerRepo = 'https://github.com/wysh3/perplexity-mcp-zerver.git'

Write-Host "deep-research installer"
Write-Host "  ScriptDir: $ScriptDir"
Write-Host "  SkillRoot: $SkillRoot"
Write-Host ""

# --- tally for the final summary --------------------------------------------
$script:Installed = New-Object System.Collections.Generic.List[string]
$script:Skipped   = New-Object System.Collections.Generic.List[string]
$script:Missing   = New-Object System.Collections.Generic.List[string]
$script:NeedsKey  = New-Object System.Collections.Generic.List[string]

function Note-Installed($msg) { $script:Installed.Add($msg) | Out-Null }
function Note-Skipped($msg)   { $script:Skipped.Add($msg) | Out-Null }
function Note-Missing($msg)   { $script:Missing.Add($msg) | Out-Null }
function Note-NeedsKey($msg)  { $script:NeedsKey.Add($msg) | Out-Null }

function Have-Cmd($name) {
  $c = $null
  try { $c = Get-Command $name -ErrorAction Stop } catch { return $false }
  return $true
}

# --- prereq detection (informational, never fatal) --------------------------
Write-Host "[1/6] checking prerequisites"

$HasGit = $false
if (Have-Cmd 'git') {
  $HasGit = $true
  Write-Host "  git: present"
} else {
  Write-Host "  git: NOT FOUND -- install from https://git-scm.com/downloads"
  Note-Missing "git (skipped: exa-search + perplexity-server fetch)"
}

$HasBun = $false
if (Have-Cmd 'bun') {
  $HasBun = $true
  $BunVer = ''
  try { $BunVer = (& bun --version 2>$null | Select-Object -First 1) } catch {}
  Write-Host "  bun: $BunVer"
} else {
  Write-Host "  bun: NOT FOUND -- install from https://bun.sh (or 'irm bun.sh/install.ps1 | iex')"
  Note-Missing "bun (skipped: perplexity-server build)"
}

$HasPy = $false
$PyBin = $null
if (Have-Cmd 'python') {
  $PyBin = 'python'
  $HasPy = $true
} elseif (Have-Cmd 'py') {
  $PyBin = 'py'
  $HasPy = $true
} elseif (Have-Cmd 'python3') {
  $PyBin = 'python3'
  $HasPy = $true
}
if ($HasPy) {
  $PyVer = ''
  try { $PyVer = (& $PyBin -c "import sys; print('%d.%d' % sys.version_info[:2])" 2>$null) } catch {}
  Write-Host "  ${PyBin}: $PyVer"
  $PyMajor = 0; $PyMinor = 0
  try {
    $PyMajor = [int](& $PyBin -c "import sys; print(sys.version_info[0])" 2>$null)
    $PyMinor = [int](& $PyBin -c "import sys; print(sys.version_info[1])" 2>$null)
  } catch {}
  if ($PyMajor -lt 3 -or ($PyMajor -eq 3 -and $PyMinor -lt 10)) {
    Write-Host "  python: need >= 3.10 (have $PyVer) -- install from https://www.python.org/downloads/"
    Note-Missing "python >= 3.10 (skipped: paper-search-mcp install)"
    $HasPy = $false
  }
} else {
  Write-Host "  python: NOT FOUND -- install from https://www.python.org/downloads/"
  Note-Missing "python (skipped: paper-search-mcp install)"
}

$HasClaude = $false
if (Have-Cmd 'claude') {
  $HasClaude = $true
  Write-Host "  claude CLI: present"
} else {
  Write-Host "  claude CLI: NOT FOUND -- install from https://docs.anthropic.com/en/docs/claude-code"
  Note-Missing "claude CLI (skipped: MCP registration)"
}
Write-Host ""

# --- step 2: clone exa-search skill from GitHub ------------------------------
Write-Host "[2/6] installing exa-search skill (from $ExaSearchRepo)"
$ExaDst = Join-Path $HomeSkills 'exa-search'
if (Test-Path $ExaDst) {
  Write-Host "  $ExaDst already exists -- skipping (re-install: remove the folder, then re-run)"
  Note-Skipped "exa-search skill (already installed)"
} elseif ($HasGit) {
  if (-not (Test-Path $HomeSkills)) { New-Item -ItemType Directory -Path $HomeSkills -Force | Out-Null }
  try {
    & git clone --depth 1 $ExaSearchRepo $ExaDst *>$null
    if ($LASTEXITCODE -eq 0) {
      Remove-Item -Path (Join-Path $ExaDst '.git') -Recurse -Force -ErrorAction SilentlyContinue
      Write-Host "  cloned -> $ExaDst"
      Note-Installed "exa-search skill (cloned from GitHub)"
    } else {
      Write-Host "  clone failed -- clone manually: git clone $ExaSearchRepo $ExaDst"
      Note-Missing "exa-search skill (clone failed)"
    }
  } catch {
    Write-Host "  clone failed -- clone manually: git clone $ExaSearchRepo $ExaDst"
    Note-Missing "exa-search skill (clone failed)"
  }
} else {
  Write-Host "  skipped (git missing) -- clone manually: git clone $ExaSearchRepo $ExaDst"
  Note-Missing "exa-search skill (git missing)"
}
Write-Host ""

# --- step 3: install paper-search-mcp from PyPI ------------------------------
Write-Host "[3/6] installing paper-search-mcp (PyPI, MIT license)"
if ($HasPy) {
  try {
    & $PyBin -m pip install paper-search-mcp *>$null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "  installed from PyPI"
      Note-Installed "paper-search-mcp (PyPI)"
    } else {
      Write-Host "  pip install failed -- run manually: $PyBin -m pip install paper-search-mcp"
      Note-Missing "paper-search-mcp (pip install failed)"
    }
  } catch {
    Write-Host "  pip install failed -- run manually: $PyBin -m pip install paper-search-mcp"
    Note-Missing "paper-search-mcp (pip install failed)"
  }
} else {
  Write-Host "  skipped (python missing)"
}
Write-Host ""

# --- step 4: clone + build perplexity-server ---------------------------------
Write-Host "[4/6] installing perplexity-server (from $PerplexityServerRepo)"
Write-Host "  License: GPL-3.0-or-later (upstream, not this skill's license -- kept out-of-tree for that reason)."
Write-Host "  How it works: drives the free Perplexity web UI via Puppeteer, no API key. Review Perplexity's"
Write-Host "  Terms of Service before relying on this in a way you're not comfortable with; it is not an"
Write-Host "  officially sanctioned integration."
$PerpDir = Join-Path $VendorDir 'perplexity-mcp-zerver'
if (Test-Path $PerpDir) {
  Write-Host "  $PerpDir already exists -- skipping clone (re-install: remove the folder, then re-run)"
  Note-Skipped "perplexity-server source (already cloned)"
} elseif ($HasGit) {
  if (-not (Test-Path $VendorDir)) { New-Item -ItemType Directory -Path $VendorDir -Force | Out-Null }
  try {
    & git clone --depth 1 $PerplexityServerRepo $PerpDir *>$null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "  cloned -> $PerpDir"
    } else {
      Write-Host "  clone failed -- clone manually: git clone $PerplexityServerRepo $PerpDir"
      Note-Missing "perplexity-server source (clone failed)"
    }
  } catch {
    Write-Host "  clone failed -- clone manually: git clone $PerplexityServerRepo $PerpDir"
    Note-Missing "perplexity-server source (clone failed)"
  }
} else {
  Write-Host "  skipped (git missing) -- clone manually: git clone $PerplexityServerRepo $PerpDir"
  Note-Missing "perplexity-server source (git missing)"
}

if ($HasBun -and (Test-Path $PerpDir)) {
  Push-Location $PerpDir
  $BuildOk = $true
  try {
    Write-Host "  bun install"
    & bun install *>$null
    if ($LASTEXITCODE -ne 0) { $BuildOk = $false }
    if ($BuildOk) {
      Write-Host "  bun run build"
      & bun run build *>$null
      if ($LASTEXITCODE -ne 0) { $BuildOk = $false }
    }
  } catch { $BuildOk = $false }
  Pop-Location
  if ($BuildOk) {
    Write-Host "  built: $PerpDir\build\main.js"
    Note-Installed "perplexity-server (cloned + built)"
  } else {
    Write-Host "  build failed"
    Note-Missing "perplexity-server (build failed)"
  }
} elseif (-not $HasBun) {
  Write-Host "  skipped build (bun missing)"
}
Write-Host ""

# --- step 5: register MCPs at user scope (idempotent) -----------------------
Write-Host "[5/6] registering MCPs (claude mcp add --scope user)"
if ($HasClaude) {
  # paper-search
  $PaperReg = $false
  try { & claude mcp get paper-search *>$null; if ($LASTEXITCODE -eq 0) { $PaperReg = $true } } catch {}
  if ($PaperReg) {
    Write-Host "  paper-search: already registered -- skipping"
    Note-Skipped "paper-search MCP (already registered)"
  } else {
    if ($HasPy) {
      try {
        & claude mcp add --scope user paper-search -- $PyBin -m paper_search_mcp.server *>$null
        if ($LASTEXITCODE -eq 0) {
          Write-Host "  paper-search: registered"
          Note-Installed "paper-search MCP registration"
        } else {
          Write-Host "  paper-search: registration failed -- run manually:"
          Write-Host "    claude mcp add --scope user paper-search -- $PyBin -m paper_search_mcp.server"
          Note-Missing "paper-search MCP registration"
        }
      } catch {
        Write-Host "  paper-search: registration error"
        Note-Missing "paper-search MCP registration"
      }
    } else {
      Write-Host "  paper-search: skipped (python missing)"
    }
  }

  # perplexity-server -- no API key needed, ever (it drives the free web UI).
  $PerpReg = $false
  try { & claude mcp get perplexity-server *>$null; if ($LASTEXITCODE -eq 0) { $PerpReg = $true } } catch {}
  if ($PerpReg) {
    Write-Host "  perplexity-server: already registered -- skipping"
    Note-Skipped "perplexity-server MCP (already registered)"
  } else {
    $BuiltMain = Join-Path $PerpDir 'build\main.js'
    if ($HasBun -and (Test-Path $BuiltMain)) {
      try {
        & claude mcp add --scope user perplexity-server -- bun $BuiltMain *>$null
        if ($LASTEXITCODE -eq 0) {
          Write-Host "  perplexity-server: registered (no API key required)"
          Note-Installed "perplexity-server MCP registration"
        } else {
          Write-Host "  perplexity-server: registration failed -- run manually:"
          Write-Host "    claude mcp add --scope user perplexity-server -- bun $BuiltMain"
          Note-Missing "perplexity-server MCP registration"
        }
      } catch {
        Write-Host "  perplexity-server: registration error"
        Note-Missing "perplexity-server MCP registration"
      }
    } else {
      Write-Host "  perplexity-server: skipped (bun or built artifact missing)"
    }
  }
} else {
  Write-Host "  skipped (claude CLI missing)"
}
Write-Host ""

# --- step 6: print Firecrawl manual line ------------------------------------
Write-Host "[6/6] Firecrawl MCP -- manual step (needs your API key)"
Write-Host "  Get a key: https://www.firecrawl.dev/app/api-keys"
Write-Host "  Then run:"
Write-Host "    claude mcp add --transport http --scope user firecrawl https://mcp.firecrawl.dev/<FIRECRAWL_API_KEY>/v2/mcp"
Note-NeedsKey "Firecrawl MCP -- run the printed 'claude mcp add' after you have a key"
Write-Host ""

# --- final summary ----------------------------------------------------------
Write-Host "============================================================"
Write-Host "deep-research install summary"
Write-Host "============================================================"
if ($script:Installed.Count -gt 0) {
  Write-Host "Installed:"
  foreach ($m in $script:Installed) { Write-Host "  - $m" }
}
if ($script:Skipped.Count -gt 0) {
  Write-Host "Skipped (already present):"
  foreach ($m in $script:Skipped) { Write-Host "  - $m" }
}
if ($script:Missing.Count -gt 0) {
  Write-Host "Not installed (prereq missing or step failed):"
  foreach ($m in $script:Missing) { Write-Host "  - $m" }
}
if ($script:NeedsKey.Count -gt 0) {
  Write-Host "Needs an API key:"
  foreach ($m in $script:NeedsKey) { Write-Host "  - $m" }
}
Write-Host ""
Write-Host "Next: 'claude mcp list' to verify, then trigger the skill with a research query."
Write-Host "Onboarding: the skill will prompt you for category selection + key setup on first use."
