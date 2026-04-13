$ErrorActionPreference = 'Stop'

function Fix-DataFieldMember {
    param(
        [string[]]$Lines,
        [int]$MemberIdx
    )

    $line = $Lines[$MemberIdx]

    # Remove readonly for fields marked by DataField-like attributes.
    if ($line -match ';' -and $line -notmatch '\{' -and $line -match '\breadonly\b') {
        $Lines[$MemberIdx] = $line -replace '\breadonly\s+', ''
        $line = $Lines[$MemberIdx]
    }

    # Single-line property fixes.
    if ($line -match '\{' -and $line -match '\bget;' -and $line -notmatch '\bset;' -and $line -notmatch '\binit;') {
        $Lines[$MemberIdx] = $line -replace '\{\s*get;\s*\}', '{ get; set; }'
        $line = $Lines[$MemberIdx]
    }

    if ($line -match '\binit;') {
        $Lines[$MemberIdx] = $line -replace '\binit;', 'set;'
        $line = $Lines[$MemberIdx]
    }

    # Multi-line property block fixes.
    if ($line -match '\{' -or $line -match '\bclass\b|\bstruct\b|\brecord\b') {
        $end = [Math]::Min($Lines.Count - 1, $MemberIdx + 25)
        $hasGet = $false
        $hasSet = $false
        $hasInit = $false
        $getIdx = -1

        for ($k = $MemberIdx; $k -le $end; $k++) {
            $cur = $Lines[$k]
            if ($cur -match '\bget;') { $hasGet = $true; if ($getIdx -lt 0) { $getIdx = $k } }
            if ($cur -match '\bset;') { $hasSet = $true }
            if ($cur -match '\binit;') { $hasInit = $true }
            if ($cur -match '^\s*}\s*$') { break }
        }

        if ($hasInit) {
            for ($k = $MemberIdx; $k -le $end; $k++) {
                if ($Lines[$k] -match '\binit;') {
                    $Lines[$k] = $Lines[$k] -replace '\binit;', 'set;'
                }
                if ($Lines[$k] -match '^\s*}\s*$') { break }
            }
            $hasSet = $true
        }

        if ($hasGet -and -not $hasSet -and $getIdx -ge 0) {
            $indent = ''
            if ($Lines[$getIdx] -match '^(\s*)') { $indent = $Matches[1] }
            $insert = $indent + 'set;'
            $before = @()
            $after = @()
            if ($getIdx -gt 0) { $before = $Lines[0..$getIdx] } else { $before = @($Lines[0]) }
            if ($getIdx + 1 -le $Lines.Count - 1) { $after = $Lines[($getIdx + 1)..($Lines.Count - 1)] }
            $Lines = @($before + @($insert) + $after)
        }
    }

    return ,$Lines
}

# 1) Generic DataField pass across Content.Shared
$files = Get-ChildItem -Path 'Content.Shared' -Recurse -Filter '*.cs'
foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($c in $content) { [void]$lines.Add($c) }

    $changed = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '\[(.*DataField.*)\]') {
            $j = $i + 1
            while ($j -lt $lines.Count -and ($lines[$j] -match '^\s*$' -or $lines[$j] -match '^\s*\[' -or $lines[$j] -match '^\s*///' -or $lines[$j] -match '^\s*//')) {
                $j++
            }
            if ($j -lt $lines.Count) {
                $before = $lines.Count
                $newLines = Fix-DataFieldMember -Lines $lines.ToArray() -MemberIdx $j
                $lines = [System.Collections.Generic.List[string]]::new()
                foreach ($n in $newLines) { [void]$lines.Add($n) }
                if ($lines.Count -ne $before -or ($content -join "`n") -ne ($lines.ToArray() -join "`n")) {
                    $changed = $true
                    $content = $lines.ToArray()
                }
            }
        }
    }

    if ($changed) {
        Set-Content -LiteralPath $file.FullName -Value $lines.ToArray()
    }
}

# 2) Apply RA0017 partial fixes using build_errors.txt
$errLines = Get-Content -LiteralPath 'build_errors.txt'
$ra0017 = $errLines | Where-Object { $_ -match ': error RA0017:' }
foreach ($err in $ra0017) {
    if ($err -match '^(.*)\((\d+),(\d+)\): error RA0017: Type ([^ ]+) ') {
        $path = $Matches[1]
        $lineNo = [int]$Matches[2]
        if (-not (Test-Path -LiteralPath $path)) { continue }

        $lines = Get-Content -LiteralPath $path
        $idx = $lineNo - 1
        if ($idx -lt 0 -or $idx -ge $lines.Count) { continue }

        if ($lines[$idx] -notmatch '\bpartial\b' -and $lines[$idx] -match '\b(class|struct|record)\b') {
            $lines[$idx] = $lines[$idx] -replace '\b(class|struct|record)\b', 'partial $1'
            Set-Content -LiteralPath $path -Value $lines
        }
    }
}

# 3) Apply RA0019 readonly fixes by exact lines from build_errors.txt
$ra0019 = $errLines | Where-Object { $_ -match ': error RA0019:' }
foreach ($err in $ra0019) {
    if ($err -match '^(.*)\((\d+),(\d+)\): error RA0019:') {
        $path = $Matches[1]
        $lineNo = [int]$Matches[2]
        if (-not (Test-Path -LiteralPath $path)) { continue }

        $lines = Get-Content -LiteralPath $path
        $idx = $lineNo - 1
        if ($idx -ge 0 -and $idx -lt $lines.Count -and $lines[$idx] -match '\breadonly\b') {
            $lines[$idx] = $lines[$idx] -replace '\breadonly\s+', ''
            Set-Content -LiteralPath $path -Value $lines
        }
    }
}
