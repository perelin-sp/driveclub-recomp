param(
    [Parameter(Mandatory)][string]$Checkout,
    [ValidateSet('Client','Server')][string]$Component = 'Client',
    [string]$GameImage,
    [switch]$Apply
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 is required.' }
$Checkout = (Resolve-Path -LiteralPath $Checkout).Path
$top = git -C $Checkout rev-parse --show-toplevel
if ($LASTEXITCODE -or [IO.Path]::GetFullPath($top) -ne $Checkout) { throw 'Pass the root of a Git checkout.' }
$status = git -C $Checkout status --porcelain --untracked-files=all
if ($LASTEXITCODE -or $status) { throw 'Use a clean, dedicated checkout.' }
$base = git -C $Checkout rev-parse HEAD
if ($LASTEXITCODE) { throw 'Cannot identify checkout commit.' }
Write-Host "$Component checkout: $base"

if ($Component -eq 'Client' -and $GameImage) {
    $signature = '4C89FF4C89EE4889DAE886823B0085C0'
    $reader = [IO.BinaryReader]::new([IO.File]::OpenRead((Resolve-Path -LiteralPath $GameImage).Path))
    try {
        $magic = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(8))
        $size = $reader.ReadUInt64()
        if ($magic -notmatch '^BBPROBE[1-6]$' -or $size -le 0xb4a190 -or $size -gt $reader.BaseStream.Length - 16) {
            throw 'Unsupported prepared image.'
        }
        $reader.BaseStream.Position = $reader.BaseStream.Length - [long]$size + 0x791f05 - 9
        if ([Convert]::ToHexString($reader.ReadBytes(16)) -ne $signature) {
            throw 'Game image signature mismatch. Review the new conversion call site before applying the readback patch.'
        }
        Write-Host 'Game 1.28 call-site bytes match.'
    } finally {
        $reader.Dispose()
    }
} elseif ($Component -eq 'Client') {
    if ($Apply) { throw 'Pass -GameImage to verify the readback hook before applying.' }
    Write-Host 'Source check only. Pass -GameImage to check the hook signature.'
}

$pattern = if ($Component -eq 'Client') { '^0[123]-' } else { '^0[45]-' }
$patches = @(Get-ChildItem -LiteralPath "$PSScriptRoot/patches" -File | Where-Object Name -Match $pattern | Sort-Object Name)
$expected = if ($Component -eq 'Client') { 3 } else { 2 }
if ($patches.Count -ne $expected) { throw 'Patch set is incomplete.' }
$needed = foreach ($patch in $patches) {
    git -C $Checkout apply --reverse --check --index $patch.FullName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Already applied verbatim: $($patch.Name)"
        continue
    }
    git -C $Checkout apply --check --index $patch.FullName
    if ($LASTEXITCODE) {
        throw "Review $($patch.Name) manually. An equivalent upstream fix or conflicting changes may be present."
    }
    Write-Host "Applies cleanly: $($patch.Name)"
    $patch.FullName
}
if ($Apply -and $needed) {
    # These patches touch disjoint files. Check the whole set again and apply it in one operation.
    git -C $Checkout apply --check --index @needed
    if ($LASTEXITCODE) { throw 'Combined patch check failed.' }
    git -C $Checkout apply --index @needed
    if ($LASTEXITCODE) { throw 'Apply failed. Inspect the scratch checkout before proceeding.' }
    git -C $Checkout diff --cached --stat
}
