# Shared report operations. No hardware reads or UI side effects.
function Normalize-Snapshot($Report){
    $counts=@{}
    foreach($r in $Report.Rows){
        $key="$($r.Section)`t$($r.Name)"
        if(!$counts.ContainsKey($key)){$counts[$key]=0}
        $counts[$key]++
        if($counts[$key] -gt 1){$r.Section=[string]$r.Section+' [entry '+$counts[$key]+']'}
    }
    return $Report
}
function Read-Snapshot([string]$Path){
    $item=Get-Item -LiteralPath $Path -ErrorAction Stop
    if($item.Length -gt 20MB){throw 'Snapshot exceeds the 20 MB limit.'}
    $report=Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if($report.SchemaVersion -ne 1 -or !$report.Rows -or !$report.CapturedAt){throw 'Not a supported BIOS Viewer snapshot.'}
    $stamp=[datetime]::MinValue
    if(![datetime]::TryParse([string]$report.CapturedAt,[ref]$stamp)){throw 'Invalid snapshot date.'}
    foreach($r in $report.Rows){
        if(!$r.Section -or !$r.Name -or $null -eq $r.Value){throw 'Invalid snapshot row.'}
    }
    return (Normalize-Snapshot $report)
}
function Get-ReportRows($Current,$Baseline,[switch]$HideRoutine){
    $before=@{};$seen=@{}
    if($Baseline){foreach($r in $Baseline.Rows){$before["$($r.Section)`t$($r.Name)"]=$r}}
    foreach($r in $Current.Rows){
        if($HideRoutine -and ($r.Name -in @('Last boot','Free space (GiB)','Free space (%)','Temperature (C)','Power-on hours') -or $r.Section -in @('Diagnostics','Power'))){continue}
        $key="$($r.Section)`t$($r.Name)";$seen[$key]=$true;$previous='';$change=''
        if($Baseline){
            if(!$before.ContainsKey($key)){$change='Added'}
            else{$previous=[string]$before[$key].Value;if($previous -ne [string]$r.Value){$change='Changed'}}
        }
        [pscustomobject]@{Section=$r.Section;Name=$r.Name;Value=[string]$r.Value;Source=$r.Source;Previous=$previous;Change=$change}
    }
    if($Baseline){foreach($key in $before.Keys){
        $r=$before[$key]
        if($HideRoutine -and ($r.Name -in @('Last boot','Free space (GiB)','Free space (%)','Temperature (C)','Power-on hours') -or $r.Section -in @('Diagnostics','Power'))){continue}
        if(!$seen.ContainsKey($key)){
            [pscustomobject]@{Section=$r.Section;Name=$r.Name;Value='Not in current report';Source=$r.Source;Previous=[string]$r.Value;Change='Removed'}
        }
    }}
}
function Get-HistoryFiles([string]$Directory){
    if(Test-Path -LiteralPath $Directory){
        Get-ChildItem -LiteralPath $Directory -File -Filter 'auto-*.json' |
            Where-Object {$_.Name -match '^auto-\d{8}-\d{9}-[a-f0-9]{8}\.json$'} |
            Sort-Object Name -Descending
    }
}
function Save-AutoSnapshot($Report,[string]$Directory){
    [void][IO.Directory]::CreateDirectory($Directory)
    $name='auto-'+(Get-Date -Format 'yyyyMMdd-HHmmssfff')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)+'.json'
    [IO.File]::WriteAllText((Join-Path $Directory $name),($Report | ConvertTo-Json -Depth 8))
    # Only app-generated files with this exact naming pattern are subject to retention.
    @(Get-HistoryFiles $Directory) | Select-Object -Skip 30 | ForEach-Object {Remove-Item -LiteralPath $_.FullName -ErrorAction Stop}
}
function ConvertTo-ReportHtml($Report){
    $table=$Report.Rows | Select-Object Section,Name,Value,Source | ConvertTo-Html -Fragment
    $events=''
    if($Report.Events){$events='<h2>Events: last 7 days (up to 50 per category)</h2>'+($Report.Events | Select-Object Time,Type,Id,Level,Message | ConvertTo-Html -Fragment | Out-String)}
    $date=[System.Net.WebUtility]::HtmlEncode([string]$Report.CapturedAt)
    return @"
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>BIOS Viewer report</title>
<style>body{font:15px system-ui,sans-serif;margin:32px;background:#181b21;color:#e8ecf2}h1,a,.brand{color:#bf00ff}table{border-collapse:collapse;width:100%;margin:20px 0}td,th{padding:10px;text-align:left;border:1px solid #414956;white-space:pre-wrap;overflow-wrap:anywhere}th{background:#22272f}small{color:#bac3d0}</style></head><body>
<h1>BIOS Viewer</h1><p>Captured: $date</p><p>Windows-reported information. Unavailable does not mean disabled. Reported status and event logs do not constitute a complete hardware diagnosis.</p>
$($table -join "`n")$events
<p class="brand">Created by Purple Dragon Foundation Ltd</p><a href="https://www.purpledragonfoundationltd.xyz/">Foundation website</a> | <a href="https://identities.lol/kyleaustinhillier">Kyle Austin Hillier</a>
</body></html>
"@
}
