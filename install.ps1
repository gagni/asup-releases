# Installs aSup and every add-on of the signed catalog into one folder (Windows x86_64):
#   <dir>\asup.exe, <dir>\extensions\<id>\ (read beside the program, no profile entry needed),
#   and a Start menu shortcut. Rerun it to update.
#   install.bat [-Dir DIR] [-NoAddons]
param([string]$Dir = "$env:LOCALAPPDATA\Programs\asup", [switch]$NoAddons)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$repo = 'https://raw.githubusercontent.com/gagni/asup-releases/main'
$work = Join-Path $env:TEMP ("asup-install-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force $work, "$Dir\extensions" | Out-Null
function Get-Verified($url, $sha) {
    $file = Join-Path $work ([IO.Path]::GetFileName($url))
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $file
    if ((Get-FileHash -Algorithm SHA256 $file).Hash.ToLower() -ne $sha) { throw "checksum mismatch: $url" }
    $file
}
try {
    $catalog = Invoke-RestMethod -UseBasicParsing "$repo/catalog.json"
    foreach ($c in $catalog.components) {
        foreach ($a in $c.assets) {
            if ($a.os -ne 'windows' -or $a.arch -notin 'x86_64', 'any') { continue }
            $version = if ($a.version) { $a.version } else { $c.version }
            if ($c.kind -eq 'app') {
                Write-Host "aSup $version"
                $zip = Get-Verified $a.url $a.sha256
                tar -xf $zip -C $work
                if ($LASTEXITCODE) { throw "cannot unpack $zip" }
                $exe = Get-ChildItem $work -Recurse -Filter asup.exe | Select-Object -First 1
                Copy-Item -Force $exe.FullName "$Dir\asup.exe"
            } elseif (-not $NoAddons) {
                Write-Host "add-on $($c.id) $version"
                $pack = Get-Verified $a.url $a.sha256
                $target = "$Dir\extensions\$($c.id)"
                Remove-Item -Recurse -Force "$target.new" -ErrorAction SilentlyContinue
                New-Item -ItemType Directory "$target.new" | Out-Null
                tar -xf $pack -C "$target.new"
                if ($LASTEXITCODE) { throw "cannot unpack $pack" }
                Remove-Item -Recurse -Force $target -ErrorAction SilentlyContinue
                Rename-Item "$target.new" $target
                Remove-Item $pack
            }
        }
    }
    $link = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\aSup.lnk"
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($link)
    $shortcut.TargetPath = "$Dir\asup.exe"
    $shortcut.Save()
    & "$Dir\asup.exe" --version
    Write-Host "Installed in $Dir (Start menu: aSup)"
} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
