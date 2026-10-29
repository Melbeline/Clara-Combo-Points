# Clara Combo Points - synchro entre les comptes WoW (Windows ; PowerShell 5.1, celui de Windows, suffit).
#
# Le script surveille le fichier de sauvegarde de Clara de chaque compte :
#   <WoW Forever>\WTF\Account\<compte>\SavedVariables\ClaraComboPoints.lua
# Quand WoW en écrit un (déconnexion, /reload, fermeture), il met dans le fichier de chaque AUTRE
# compte une copie des listes de courrier et du stock de celui-ci (ClaraMailDB, ClaraCraftDB,
# ClaraSyncDB), sous le nom ClaraSyncIncoming. Clara la fusionne à la connexion suivante de ce compte
# (l'entrée la plus récente gagne) puis l'efface. Rien d'autre n'est touché : les réglages de la barre
# et des modules restent propres à chaque compte, et les fichiers des autres addons ne sont jamais ouverts.
#
# Les .bat à côté le lancent :
#   Installer.bat    -Install    copié dans %LOCALAPPDATA%\ClaraComboPoints-Synchro, lancé caché
#                                maintenant et à chaque ouverture de Windows
#   Tester.bat       -Once -Test un seul passage, sans rien écrire : ce qu'il ferait
#   Desinstaller.bat -Uninstall  arrêté, et plus lancé avec Windows
# Sans option : la surveillance (ce que lance le démarrage de Windows).
param(
  [string]$Wow = '',
  [switch]$Once,
  [switch]$Test,
  [switch]$Install,
  [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$FileName = 'ClaraComboPoints.lua'
$Shared = @('ClaraMailDB', 'ClaraCraftDB', 'ClaraSyncDB')
$Incoming = 'ClaraSyncIncoming'
$Wow = $Wow.Trim().Trim('"').TrimEnd('\')
$AccountRoot = if ($Wow -ne '') { Join-Path $Wow 'WTF\Account' } else { '' }
$Store = Join-Path $env:LOCALAPPDATA 'ClaraComboPoints-Synchro'
$LogFile = Join-Path $Store 'ClaraSync.log'
$BackupRoot = Join-Path $Store 'Sauvegardes'
$Installed = Join-Path $Store 'ClaraSync.ps1'
$Launcher = Join-Path $Store 'ClaraSync.vbs'
$Shortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'Clara Combo Points - Synchro.lnk'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
# Les fichiers de WoW lus et réécrits octet pour octet (Latin-1 : un caractère par octet), pour ne
# jamais abîmer ce qui ne nous regarde pas, quel que soit son encodage
$Bytes = [System.Text.Encoding]::GetEncoding(28591)
$script:retry = $false

function Write-Log([string]$Message) {
  if ($Test -or $Install -or $Uninstall -or $Once) { Write-Host $Message }
  if ($Test) { return }
  try {
    New-Item -ItemType Directory -Force -Path $Store | Out-Null
    # le journal garde ses 2000 dernières lignes
    if ((Test-Path -LiteralPath $LogFile) -and ((Get-Item -LiteralPath $LogFile).Length -gt 400KB)) {
      $keep = Get-Content -LiteralPath $LogFile -Encoding UTF8 | Select-Object -Last 2000
      [System.IO.File]::WriteAllLines($LogFile, [string[]]$keep, $Utf8)
    }
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    [System.IO.File]::AppendAllText($LogFile, $line + "`r`n", $Utf8)
  } catch { }
}

# Les comptes : chaque dossier de WTF\Account qui a un dossier SavedVariables
function Get-Accounts {
  if ($Wow -eq '' -or -not (Test-Path -LiteralPath $AccountRoot)) { return @() }
  return @(Get-ChildItem -LiteralPath $AccountRoot -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SavedVariables') } |
    Sort-Object Name |
    ForEach-Object { [pscustomobject]@{ Name = $_.Name; File = (Join-Path $_.FullName "SavedVariables\$FileName") } })
}

function Read-Text([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return '' }
  return [System.IO.File]::ReadAllText($Path, $Bytes)
}

# Le fichier découpé en ses variables : chacune commence en début de ligne par « Nom = »
# (WoW les écrit ainsi ; tout le reste est indenté, ou une accolade fermante).
function Split-Blocks([string]$Text) {
  $blocks = [ordered]@{}
  $found = [regex]::Matches($Text, '(?m)^([A-Za-z_][A-Za-z0-9_]*) = ')
  $start = if ($found.Count -gt 0) { $found[0].Index } else { $Text.Length }
  for ($i = 0; $i -lt $found.Count; $i++) {
    $from = $found[$i].Index
    $to = if ($i + 1 -lt $found.Count) { $found[$i + 1].Index } else { $Text.Length }
    $blocks[$found[$i].Groups[1].Value] = $Text.Substring($from, $to - $from)
  }
  return @{ Head = $Text.Substring(0, $start); Blocks = $blocks }
}

# La valeur d'une variable : ce qui suit « Nom = », sans les blancs de fin
function Get-Value([string]$Block) {
  return $Block.Substring($Block.IndexOf(' = ', [StringComparison]::Ordinal) + 3).TrimEnd()
}

function Lua-String([string]$Text) {
  return '"' + ($Text -replace '\\', '\\' -replace '"', '\"') + '"'
}

# Ce que le fichier d'un compte doit recevoir : les données partagées de chaque autre compte
function Build-Incoming([string]$Target, $Accounts, $Values) {
  $parts = New-Object System.Collections.Generic.List[string]
  foreach ($a in $Accounts) {
    if ($a.Name -eq $Target) { continue }
    $theirs = $Values[$a.Name]
    if ($theirs.Count -eq 0) { continue }
    $parts.Add('[' + (Lua-String $a.Name) + '] = {')
    foreach ($name in $Shared) {
      if ($theirs.Contains($name)) { $parts.Add('[' + (Lua-String $name) + '] = ' + $theirs[$name] + ',') }
    }
    $parts.Add('},')
  }
  if ($parts.Count -eq 0) { return '' }
  return "$Incoming = {`n" + ($parts -join "`n") + "`n}"
}

# Une copie par compte et par jour, avant la première écriture du jour ; les 7 derniers jours gardés
function Backup-File([string]$Account, [string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $dir = Join-Path (Join-Path $BackupRoot (Get-Date -Format 'yyyy-MM-dd')) $Account
  $copy = Join-Path $dir $FileName
  if (Test-Path -LiteralPath $copy) { return }
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  Copy-Item -LiteralPath $Path -Destination $copy -Force
  Get-ChildItem -LiteralPath $BackupRoot -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' } |
    Sort-Object Name -Descending | Select-Object -Skip 7 |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
}

# Le fichier remplacé d'un coup : jamais à moitié écrit (une copie par-dessus si le disque ne sait pas
# remplacer ; occupé par WoW : une erreur, et un nouvel essai au passage suivant)
function Write-Whole([string]$Path, [string]$Text) {
  $temp = $Path + '.clarasync'
  [System.IO.File]::WriteAllText($temp, $Text, $Bytes)
  try {
    if (-not (Test-Path -LiteralPath $Path)) {
      [System.IO.File]::Move($temp, $Path)
    } else {
      try { [System.IO.File]::Replace($temp, $Path, [NullString]::Value) }
      catch [System.PlatformNotSupportedException] { [System.IO.File]::Copy($temp, $Path, $true) }
    }
  } finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
  }
}

# Un passage : chaque compte reçoit ce qui lui manque ; rien n'est écrit s'il l'a déjà.
# (Ce qu'il reçoit ne vient que des données propres des autres, jamais de ce qu'ils ont reçu : un
# fichier écrit ici ne change pas ce que les autres doivent recevoir, donc pas de boucle.)
function Sync-All {
  $accounts = Get-Accounts
  $texts = @{}
  $values = @{}
  foreach ($a in $accounts) {
    $text = Read-Text $a.File
    $texts[$a.Name] = $text
    $mine = [ordered]@{}
    $split = Split-Blocks $text
    foreach ($name in $Shared) {
      if ($split.Blocks.Contains($name)) { $mine[$name] = Get-Value $split.Blocks[$name] }
    }
    $values[$a.Name] = $mine
  }
  if ($Test) {
    Write-Host ('Comptes trouvés dans {0} :' -f $AccountRoot)
    foreach ($a in $accounts) {
      $has = if ($values[$a.Name].Count -gt 0) { 'listes et stock de Clara présents' } else { 'Clara pas encore utilisé' }
      Write-Host ('  - {0} ({1})' -f $a.Name, $has)
    }
  }
  foreach ($t in $accounts) {
    $expected = Build-Incoming $t.Name $accounts $values
    $split = Split-Blocks $texts[$t.Name]
    $current = ''
    if ($split.Blocks.Contains($Incoming)) { $current = $split.Blocks[$Incoming].TrimEnd() }
    if ($current -ceq $expected) {
      if ($Test) { Write-Host ('{0} : déjà à jour' -f $t.Name) }
      continue
    }
    $out = New-Object System.Text.StringBuilder
    [void]$out.Append($split.Head)
    foreach ($name in $split.Blocks.Keys) {
      if ($name -eq $Incoming) { continue }
      $block = $split.Blocks[$name]
      [void]$out.Append($block)
      if (-not $block.EndsWith("`n")) { [void]$out.Append("`n") }
    }
    if ($expected -ne '') { [void]$out.Append($expected + "`n") }
    $from = @($accounts | Where-Object { $_.Name -ne $t.Name -and $values[$_.Name].Count -gt 0 } | ForEach-Object { $_.Name }) -join ', '
    if ($Test) {
      Write-Host ('{0} : recevrait les données de {1} (rien n''est écrit en test)' -f $t.Name, $from)
      continue
    }
    try {
      Backup-File $t.Name $t.File
      Write-Whole $t.File $out.ToString()
      Write-Log ('{0} : données de {1}' -f $t.Name, $from)
    } catch {
      Write-Log ('{0} : pas écrit cette fois ({1}), nouvel essai dans quelques secondes' -f $t.Name, $_.Exception.Message)
      $script:retry = $true
    }
  }
}

function Stop-Running {
  try {
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
      Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -match 'ClaraSync\.ps1' } |
      ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  } catch { }
}

function Install {
  $accounts = Get-Accounts
  if ($accounts.Count -lt 2) {
    Write-Host ('Moins de deux comptes trouvés dans {0} : rien à synchroniser, rien installé.' -f $AccountRoot)
    exit 1
  }
  Write-Host 'Comptes trouvés :'
  foreach ($a in $accounts) {
    $has = if (Test-Path -LiteralPath $a.File) { 'Clara déjà utilisé' } else { 'Clara pas encore utilisé' }
    Write-Host ('  - {0} ({1})' -f $a.Name, $has)
  }
  Stop-Running
  New-Item -ItemType Directory -Force -Path $Store | Out-Null
  # une copie de chaque fichier avant tout
  $saved = Join-Path $BackupRoot ('installation_' + (Get-Date -Format 'yyyy-MM-dd_HHmm'))
  foreach ($a in $accounts) {
    if (Test-Path -LiteralPath $a.File) {
      $dir = Join-Path $saved $a.Name
      New-Item -ItemType Directory -Force -Path $dir | Out-Null
      Copy-Item -LiteralPath $a.File -Destination (Join-Path $dir $FileName) -Force
    }
  }
  Write-Host ('Copie des fichiers actuels : {0}' -f $saved)
  # le script copié à demeure ; son lanceur caché (aucune fenêtre) ; le raccourci au démarrage de Windows
  if ($PSCommandPath -ne $Installed) { Copy-Item -LiteralPath $PSCommandPath -Destination $Installed -Force }
  $command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""' + $Installed + '"" -Wow ""' + $Wow + '""'
  $vbs = 'CreateObject("WScript.Shell").Run "' + $command + '", 0, False'
  [System.IO.File]::WriteAllText($Launcher, $vbs, (New-Object System.Text.UnicodeEncoding($false, $true)))
  $wscript = Join-Path $env:WINDIR 'System32\wscript.exe'
  $shell = New-Object -ComObject WScript.Shell
  $link = $shell.CreateShortcut($Shortcut)
  $link.TargetPath = $wscript
  $link.Arguments = '"' + $Launcher + '"'
  $link.WorkingDirectory = $Store
  $link.Description = 'Clara Combo Points : synchro entre les comptes WoW'
  $link.Save()
  Start-Process -FilePath $wscript -ArgumentList ('"' + $Launcher + '"')
  Write-Log ('Installé dans {0} : lancé maintenant, et à chaque ouverture de Windows.' -f $Store)
  Write-Host ('Journal : {0}' -f $LogFile)
}

function Uninstall {
  Stop-Running
  foreach ($f in @($Shortcut, $Launcher, $Installed)) {
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force }
  }
  Write-Log 'Désinstallé : arrêté, et plus lancé avec Windows. Les fichiers des comptes restent tels quels.'
  if (Test-Path -LiteralPath $BackupRoot) { Write-Host ('Les copies de sauvegarde restent dans {0}' -f $BackupRoot) }
}

if ($Uninstall) { Uninstall; exit 0 }
if ($Wow -eq '' -or -not (Test-Path -LiteralPath $AccountRoot)) {
  Write-Host ('Dossier introuvable : {0}' -f $AccountRoot)
  exit 1
}
if ($Install) { Install; exit 0 }
if ($Once -or $Test) { Sync-All; exit 0 }

# La surveillance : une seule à la fois ; un coup d'œil toutes les 2 secondes (la date et la taille des
# fichiers seulement) ; un passage quand l'un a changé, 2 secondes après (WoW a fini de l'écrire)
$mutex = New-Object System.Threading.Mutex($false, 'Local\ClaraComboPointsSync')
try { $alone = $mutex.WaitOne(0) } catch { $alone = $true } # (celle d'avant arrêtée net : libre)
if (-not $alone) { exit 0 }
Write-Log ('Surveillance lancée : {0}' -f $AccountRoot)
$seen = @{}
$script:retry = $true
while ($true) {
  try {
    $changed = $false
    foreach ($a in Get-Accounts) {
      $sign = ''
      $item = Get-Item -LiteralPath $a.File -ErrorAction SilentlyContinue
      if ($item) { $sign = '{0}-{1}' -f $item.LastWriteTimeUtc.Ticks, $item.Length }
      if ($seen[$a.Name] -ne $sign) { $seen[$a.Name] = $sign; $changed = $true }
    }
    if ($changed -or $script:retry) {
      $script:retry = $false
      Start-Sleep -Seconds 2
      Sync-All
    }
  } catch {
    Write-Log ('Passage interrompu : {0}' -f $_.Exception.Message)
    $script:retry = $true
  }
  Start-Sleep -Seconds 2
}
