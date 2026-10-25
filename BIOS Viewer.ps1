param([switch]$SmokeTest,[string]$PreviewPath,[string]$FixturePath)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'Reports.ps1')
[Windows.Forms.Application]::EnableVisualStyles()
$script:current=$null;$script:baseline=$null;$script:job=$null;$script:liveJob=$null
$script:jobStarted=Get-Date;$script:liveStarted=Get-Date;$script:nextLive=Get-Date
$script:loading=$true;$script:historyFiles=@();$script:lastSample=$null
$script:dataPath=Join-Path $PSScriptRoot 'data'
$script:historyPath=Join-Path $script:dataPath 'history'
$script:settingsPath=Join-Path $script:dataPath 'preferences.json'
$script:prefs=@{DarkMode=$true;AutoHistory=$true;Live=$true;Width=1260;Height=860}
if(!$SmokeTest -and !$PreviewPath -and (Test-Path -LiteralPath $script:settingsPath)){
    try{
        $saved=Get-Content -LiteralPath $script:settingsPath -Raw | ConvertFrom-Json
        foreach($key in @('DarkMode','AutoHistory','Live')){if($saved.$key -is [bool]){$script:prefs[$key]=$saved.$key}}
        if($saved.Width -ge 1000 -and $saved.Width -le 4000){$script:prefs.Width=[int]$saved.Width}
        if($saved.Height -ge 700 -and $saved.Height -le 2500){$script:prefs.Height=[int]$saved.Height}
    }catch{}
}
function Open-Target([string]$Target,[string]$Arguments=''){
    try{$p=New-Object Diagnostics.ProcessStartInfo;$p.FileName=$Target;$p.Arguments=$Arguments;$p.UseShellExecute=$true;[void][Diagnostics.Process]::Start($p)}
    catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Cannot open item')}
}
function New-Label([string]$Text,[int]$Size=10,[switch]$Bold){
    $c=New-Object Windows.Forms.Label;$c.Text=$Text;$c.UseMnemonic=$false;$c.AutoSize=$true;$c.Margin=New-Object Windows.Forms.Padding(8)
    $weight=[Drawing.FontStyle]::Regular;if($Bold){$weight=[Drawing.FontStyle]::Bold}
    $c.Font=New-Object Drawing.Font('Segoe UI',$Size,$weight);return $c
}
function New-Button($Parent,[string]$Text,[scriptblock]$Action){
    $b=New-Object Windows.Forms.Button;$b.Text=$Text;$b.AutoSize=$true;$b.Height=32
    $b.Margin=New-Object Windows.Forms.Padding(4);$b.FlatStyle='Flat'
    $b.Add_Click($Action);$Parent.Controls.Add($b);return $b
}
function New-Check($Parent,[string]$Text,[bool]$Checked){
    $c=New-Object Windows.Forms.CheckBox;$c.Text=$Text;$c.Checked=$Checked;$c.AutoSize=$true
    $c.Margin=New-Object Windows.Forms.Padding(8,10,8,0);$Parent.Controls.Add($c);return $c
}
function New-Grid($Parent,$Columns){
    $g=New-Object Windows.Forms.DataGridView;$g.Dock='Fill';$g.ReadOnly=$true
    $g.AllowUserToAddRows=$false;$g.AllowUserToDeleteRows=$false;$g.RowHeadersVisible=$false
    $g.AutoSizeColumnsMode='Fill';$g.AutoSizeRowsMode='AllCells';$g.SelectionMode='FullRowSelect'
    $g.DefaultCellStyle.WrapMode='True';$g.BorderStyle='None';$g.EnableHeadersVisualStyles=$false
    foreach($c in $Columns){[void]$g.Columns.Add($c,$c)}
    $Parent.Controls.Add($g);return $g
}
function New-Page([string]$Name){
    $p=New-Object Windows.Forms.TabPage;$p.Text=$Name;$p.Padding=New-Object Windows.Forms.Padding(8)
    $tabs.TabPages.Add($p);return $p
}
function Save-Preferences {
    if($SmokeTest -or $PreviewPath){return}
    try{
        [void][IO.Directory]::CreateDirectory($script:dataPath)
        $size=$form.Size;if($form.WindowState -ne 'Normal'){$size=$form.RestoreBounds.Size}
        $values=@{DarkMode=$theme.Checked;AutoHistory=$autoHistory.Checked;Live=$live.Checked;Width=$size.Width;Height=$size.Height}
        $temp=$script:settingsPath+'.tmp'
        [IO.File]::WriteAllText($temp,($values | ConvertTo-Json))
        Move-Item -LiteralPath $temp -Destination $script:settingsPath -Force
    }catch{$status.Text='Could not save preferences: '+$_.Exception.Message}
}
$form=New-Object Windows.Forms.Form
$form.Text='BIOS Viewer | Purple Dragon Foundation Ltd'
$form.Size=New-Object Drawing.Size($script:prefs.Width,$script:prefs.Height)
$form.MinimumSize=New-Object Drawing.Size(1000,700);$form.StartPosition='CenterScreen'
$form.Font=New-Object Drawing.Font('Segoe UI',10)
$root=New-Object Windows.Forms.TableLayoutPanel;$root.Dock='Fill';$root.ColumnCount=1;$root.RowCount=6
foreach($height in @(60,40,50,0,40,90)){
    $s=New-Object Windows.Forms.RowStyle
    if($height){$s.SizeType='Absolute';$s.Height=$height}else{$s.SizeType='Percent';$s.Height=100}
    [void]$root.RowStyles.Add($s)
}
$form.Controls.Add($root)
$title=New-Label 'BIOS Viewer' 25 -Bold;$root.Controls.Add($title,0,0)
$subtitle=New-Label 'Hardware, firmware and troubleshooting in one place. Windows-reported values; unavailable does not mean disabled.'
$root.Controls.Add($subtitle,0,1)
$toolbar=New-Object Windows.Forms.FlowLayoutPanel;$toolbar.Dock='Fill';$toolbar.WrapContents=$false;$toolbar.AutoScroll=$true
$root.Controls.Add($toolbar,0,2)
$refresh=New-Button $toolbar 'Refresh report' {Start-Collection}
$save=New-Button $toolbar 'Save snapshot' {Save-Report 'json'}
$export=New-Button $toolbar 'Export HTML' {Save-Report 'html'}
$copy=New-Button $toolbar 'Copy report' {
    if($script:current){try{[Windows.Forms.Clipboard]::SetText(($script:current.Rows | Format-Table -AutoSize -Wrap | Out-String -Width 180));$status.Text='Report copied to clipboard.'}catch{$status.Text=$_.Exception.Message}}
}
$theme=New-Check $toolbar 'Dark Mode' $script:prefs.DarkMode
$tabs=New-Object Windows.Forms.TabControl;$tabs.Dock='Fill';$root.Controls.Add($tabs,0,3)
$overviewPage=New-Page 'Overview'
$detailsPage=New-Page 'All details'
$changesPage=New-Page 'What changed?'
$drivesPage=New-Page 'Drives'
$eventsPage=New-Page 'Events'
$historyPage=New-Page 'History'
$toolsPage=New-Page 'Tools & settings'
$overview=New-Object Windows.Forms.TableLayoutPanel;$overview.Dock='Fill';$overview.ColumnCount=2;$overview.RowCount=3
for($i=0;$i -lt 2;$i++){[void]$overview.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',50)))}
for($i=0;$i -lt 3;$i++){[void]$overview.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',33.333)))}
$overviewPage.Controls.Add($overview)
$cards=@{}
$cardNames=@('Motherboard & BIOS','Processor & memory','Security & virtualization','Live usage','Collection status','Tracking & diagnostics')
for($i=0;$i -lt $cardNames.Count;$i++){
    $panel=New-Object Windows.Forms.Panel;$panel.Dock='Fill';$panel.Padding=New-Object Windows.Forms.Padding(10)
    $panel.Margin=New-Object Windows.Forms.Padding(6);$panel.BorderStyle='FixedSingle';$panel.AutoScroll=$true
    $heading=New-Label $cardNames[$i] 12 -Bold;$heading.Dock='Top';$heading.AutoSize=$false;$heading.Height=30
    $body=New-Object Windows.Forms.Label;$body.Dock='Fill';$body.AutoSize=$false;$body.Padding=New-Object Windows.Forms.Padding(8,4,8,4)
    $body.Text='Waiting for first report...';$panel.Controls.Add($body);$panel.Controls.Add($heading)
    $overview.Controls.Add($panel,($i%2),[math]::Floor($i/2));$cards[$cardNames[$i]]=$body
}
$detailLayout=New-Object Windows.Forms.TableLayoutPanel;$detailLayout.Dock='Fill';$detailLayout.RowCount=2;$detailLayout.ColumnCount=1
[void]$detailLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',44)))
[void]$detailLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',100)))
$detailsPage.Controls.Add($detailLayout)
$filterBar=New-Object Windows.Forms.FlowLayoutPanel;$filterBar.Dock='Fill';$detailLayout.Controls.Add($filterBar,0,0)
$filterBar.Controls.Add((New-Label 'Search:'))
$search=New-Object Windows.Forms.TextBox;$search.Width=280;$search.Margin=New-Object Windows.Forms.Padding(4,6,4,0);$filterBar.Controls.Add($search)
$section=New-Object Windows.Forms.ComboBox;$section.Width=225;$section.DropDownStyle='DropDownList'
$section.Margin=New-Object Windows.Forms.Padding(4,6,4,0);[void]$section.Items.Add('All sections');$section.SelectedIndex=0;$filterBar.Controls.Add($section)
$reset=New-Button $filterBar 'Clear filters' {$search.Clear();$section.SelectedIndex=0}
$details=New-Grid $detailLayout @('Section','Setting / information','Value','Source / meaning');$detailLayout.SetRow($details,1)
$changeLayout=New-Object Windows.Forms.TableLayoutPanel;$changeLayout.Dock='Fill';$changeLayout.ColumnCount=1;$changeLayout.RowCount=3
foreach($h in @(44,40,0)){$s=New-Object Windows.Forms.RowStyle;if($h){$s.SizeType='Absolute';$s.Height=$h}else{$s.SizeType='Percent';$s.Height=100};[void]$changeLayout.RowStyles.Add($s)}
$changesPage.Controls.Add($changeLayout)
$changeBar=New-Object Windows.Forms.FlowLayoutPanel;$changeBar.Dock='Fill';$changeLayout.Controls.Add($changeBar,0,0)
$choose=New-Button $changeBar 'Compare snapshot...' {Choose-Baseline}
$previous=New-Button $changeBar 'Use latest history' {Use-LatestHistory;Render-Report}
$hideRoutine=New-Check $changeBar 'Hide routine changes' $true
$changeInfo=New-Label 'Save a snapshot or collect history to start comparing.';$changeInfo.Dock='Fill';$changeLayout.Controls.Add($changeInfo,0,1)
$changes=New-Grid $changeLayout @('Change','Section','Setting','Current value','Previous value');$changeLayout.SetRow($changes,2)
$drives=New-Grid $drivesPage @('Section','Setting','Value','Source / meaning')
$eventLayout=New-Object Windows.Forms.TableLayoutPanel;$eventLayout.Dock='Fill';$eventLayout.ColumnCount=1;$eventLayout.RowCount=2
[void]$eventLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',70)))
[void]$eventLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',100)))
$eventsPage.Controls.Add($eventLayout)
$eventInfo=New-Label 'Last 7 days; up to 50 events per category. WHEA reports hardware errors. Kernel-Power 41 records an unexpected shutdown, not its cause. Double-click a row for its full message.'
$eventInfo.Dock='Fill';$eventLayout.Controls.Add($eventInfo,0,0)
$events=New-Grid $eventLayout @('Time','Category','Event ID','Level','Message');$eventLayout.SetRow($events,1)
$events.Columns[4].FillWeight=240
$events.DefaultCellStyle.WrapMode='False';$events.AutoSizeRowsMode='None';$events.RowTemplate.Height=30
$events.Add_CellDoubleClick({param($sender,$e)
    if($e.RowIndex -ge 0){[void][Windows.Forms.MessageBox]::Show([string]$events.Rows[$e.RowIndex].Cells[4].Value,'Windows event message')}
})
$historyLayout=New-Object Windows.Forms.TableLayoutPanel;$historyLayout.Dock='Fill';$historyLayout.ColumnCount=1;$historyLayout.RowCount=2
[void]$historyLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',48)))
[void]$historyLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',100)))
$historyPage.Controls.Add($historyLayout)
$historyBar=New-Object Windows.Forms.FlowLayoutPanel;$historyBar.Dock='Fill';$historyLayout.Controls.Add($historyBar,0,0)
$historyCompare=New-Button $historyBar 'Compare selected' {
    if($historyGrid.SelectedRows.Count){try{
        $path=[string]$historyGrid.SelectedRows[0].Tag;$script:baseline=Read-Snapshot $path
        Render-Report;$tabs.SelectedTab=$changesPage
    }catch{$status.Text=$_.Exception.Message}}
}
$historyOpen=New-Button $historyBar 'Open history folder' {
    try{[void][IO.Directory]::CreateDirectory($script:historyPath);Open-Target $script:historyPath}catch{$status.Text=$_.Exception.Message}
}
$historyBar.Controls.Add((New-Label 'Keeps the newest 30 automatic snapshots.'))
$historyGrid=New-Grid $historyLayout @('Saved locally','File','Size (KiB)');$historyLayout.SetRow($historyGrid,1)
$tools=New-Object Windows.Forms.FlowLayoutPanel;$tools.Dock='Fill';$tools.FlowDirection='TopDown';$tools.WrapContents=$false;$tools.AutoScroll=$true
$toolsPage.Controls.Add($tools)
$tools.Controls.Add((New-Label 'Preferences' 13 -Bold))
$autoHistory=New-Check $tools 'Save an automatic snapshot after each full refresh (maximum 30)' $script:prefs.AutoHistory
$live=New-Check $tools 'Update CPU and memory usage while this window is open (about every 5 seconds)' $script:prefs.Live
$tools.Controls.Add((New-Label 'Windows troubleshooting shortcuts' 13 -Bold))
$toolButtons=New-Object Windows.Forms.FlowLayoutPanel;$toolButtons.AutoSize=$true;$toolButtons.Width=850;$toolButtons.Height=100;$tools.Controls.Add($toolButtons)
$null=New-Button $toolButtons 'System Information' {Open-Target 'msinfo32.exe'}
$null=New-Button $toolButtons 'Device Manager' {Open-Target 'devmgmt.msc'}
$null=New-Button $toolButtons 'Event Viewer' {Open-Target 'eventvwr.msc'}
$null=New-Button $toolButtons 'Reliability Monitor' {Open-Target 'perfmon.exe' '/rel'}
$null=New-Button $toolButtons 'Windows Security' {Open-Target 'windowsdefender:'}
$null=New-Button $toolButtons 'Power settings' {Open-Target 'ms-settings:powersleep'}
$null=New-Button $toolButtons 'Storage settings' {Open-Target 'ms-settings:storagesense'}
$tools.Controls.Add((New-Label 'What this tool can tell you' 13 -Bold))
$help=New-Label "All details includes firmware, hardware, virtualization, storage, and power/sleep information.`r`nDrives shows Windows-reported health and reliability counters when supported.`r`nEvents shows a bounded seven-day history, not a diagnosis or a full event-log audit.`r`nMissing or denied values are unknown, not disabled. Zero-valued drive sensors may be unsupported.`r`nBIOS A-XMP, PBO, fan curves, CPU temperature and voltages are not available here.`r`nSnapshots and exports may contain hardware details and event messages. Everything stays local unless you share it.`r`nSome queries need administrator permissions. This app never requests elevation automatically."
$help.MaximumSize=New-Object Drawing.Size(1000,0);$tools.Controls.Add($help)
$tools.Controls.Add((New-Label 'Saved preferences and automatic reports are in the data folder next to the app.'))
$status=New-Label 'Ready';$status.Dock='Fill';$root.Controls.Add($status,0,4)
$footer=New-Object Windows.Forms.FlowLayoutPanel;$footer.Dock='Fill';$footer.FlowDirection='TopDown';$footer.WrapContents=$false
$footer.Padding=New-Object Windows.Forms.Padding(8,0,0,0)
$credit=New-Label 'Created by Purple Dragon Foundation Ltd' 10 -Bold;$credit.Margin=New-Object Windows.Forms.Padding(0,2,0,3)
$footer.Controls.Add($credit)
function New-Link($Text,$Url){
    $l=New-Object Windows.Forms.LinkLabel;$l.Text=$Text;$l.AutoSize=$true;$l.Margin=New-Object Windows.Forms.Padding(0,2,0,3)
    $l.Tag=$Url;$l.AccessibleName=$Text;$l.Add_LinkClicked({param($sender,$e) Open-Target ([string]$sender.Tag)})
    $footer.Controls.Add($l);return $l
}
$website=New-Link 'www.purpledragonfoundationltd.xyz' 'https://www.purpledragonfoundationltd.xyz/'
$profile=New-Link 'identities.lol/kyleaustinhillier' 'https://identities.lol/kyleaustinhillier'
$root.Controls.Add($footer,0,5)
function Set-ControlTheme($Control){
    $Control.BackColor=$script:bg;$Control.ForeColor=$script:fg
    if($Control -is [Windows.Forms.Button]){
        $Control.UseVisualStyleBackColor=$false;$Control.BackColor=$script:surface;$Control.FlatAppearance.BorderColor=$script:border
    }elseif($Control -is [Windows.Forms.TextBox] -or $Control -is [Windows.Forms.ComboBox]){$Control.BackColor=$script:surface}
    if($Control -is [Windows.Forms.DataGridView]){
        $Control.BackgroundColor=$script:surface;$Control.GridColor=$script:border
        foreach($s in @($Control.DefaultCellStyle,$Control.RowsDefaultCellStyle,$Control.AlternatingRowsDefaultCellStyle,$Control.ColumnHeadersDefaultCellStyle)){
            $s.BackColor=$script:surface;$s.ForeColor=$script:fg;$s.SelectionBackColor=[Drawing.Color]::FromArgb(64,62,125);$s.SelectionForeColor=[Drawing.Color]::White
        }
        return
    }
    foreach($child in $Control.Controls){Set-ControlTheme $child}
}
function Apply-Theme {
    if($theme.Checked){
        $script:bg=[Drawing.Color]::FromArgb(24,27,33);$script:surface=[Drawing.Color]::FromArgb(34,39,47)
        $script:fg=[Drawing.Color]::FromArgb(232,236,242);$script:border=[Drawing.Color]::FromArgb(65,73,86)
        $script:changed=[Drawing.Color]::FromArgb(91,71,24)
    }else{
        $script:bg=[Drawing.Color]::FromArgb(242,245,250);$script:surface=[Drawing.Color]::White
        $script:fg=[Drawing.Color]::FromArgb(25,30,38);$script:border=[Drawing.Color]::FromArgb(205,211,220)
        $script:changed=[Drawing.Color]::LightGoldenrodYellow
    }
    Set-ControlTheme $form
    $purple=[Drawing.Color]::FromArgb(191,0,255);$credit.ForeColor=$purple
    foreach($l in @($website,$profile)){$l.LinkColor=$purple;$l.VisitedLinkColor=$purple;$l.ActiveLinkColor=[Drawing.Color]::FromArgb(222,128,255)}
    if(!$script:loading){Render-Report;Save-Preferences}
}
function Find-Value($Section,$Name){
    $r=@($script:current.Rows | Where-Object {$_.Section -like $Section -and $_.Name -eq $Name})
    if(!$r.Count){return 'Not reported'}
    return (($r | ForEach-Object {$_.Value} | Select-Object -Unique) -join ', ')
}
function Refresh-History {
    $script:historyFiles=@(Get-HistoryFiles $script:historyPath);$historyGrid.Rows.Clear()
    foreach($file in $script:historyFiles){$i=$historyGrid.Rows.Add($file.LastWriteTime.ToString('g'),$file.Name,[math]::Round($file.Length/1KB,1));$historyGrid.Rows[$i].Tag=$file.FullName}
}
function Use-LatestHistory {
    Refresh-History
    $script:baseline=$null
    foreach($file in $script:historyFiles){
        try{
            $candidate=Read-Snapshot $file.FullName
            if(!$script:current -or $candidate.CapturedAt -ne $script:current.CapturedAt){$script:baseline=$candidate;break}
        }catch{}
    }
}
function Render-Report {
    if(!$script:current){return}
    $details.Rows.Clear();$drives.Rows.Clear();$changes.Rows.Clear();$events.Rows.Clear()
    $q=$search.Text
    foreach($r in $script:current.Rows){
        if(($section.SelectedItem -eq 'All sections' -or $section.SelectedItem -eq $r.Section) -and (!$q -or ($r.Section+' '+$r.Name+' '+$r.Value+' '+$r.Source).IndexOf($q,[StringComparison]::OrdinalIgnoreCase) -ge 0)){
            [void]$details.Rows.Add($r.Section,$r.Name,$r.Value,$r.Source)
        }
        if($r.Section -match '^(Disk |Drive health|Volume )'){[void]$drives.Rows.Add($r.Section,$r.Name,$r.Value,$r.Source)}
    }
    if($script:baseline){
        foreach($r in @(Get-ReportRows $script:current $script:baseline -HideRoutine:$hideRoutine.Checked)){
            if($r.Change){$i=$changes.Rows.Add($r.Change,$r.Section,$r.Name,$r.Value,$r.Previous);$changes.Rows[$i].DefaultCellStyle.BackColor=$script:changed}
        }
        $changeInfo.Text=$changes.Rows.Count.ToString()+' differences vs '+([datetime]$script:baseline.CapturedAt).ToString('g')+' | Differences may reflect permissions or query availability.'
    }else{$changeInfo.Text='No comparison selected. Choose a saved snapshot or collect a second report.'}
    foreach($e in @($script:current.Events | Sort-Object Time -Descending)){if($e){[void]$events.Rows.Add($e.Time,$e.Type,$e.Id,$e.Level,$e.Message)}}
    $cards['Motherboard & BIOS'].Text=(Find-Value Motherboard Model)+"`r`nBIOS: "+(Find-Value Firmware Version)+"`r`nReleased: "+(Find-Value Firmware 'Release date')
    $cards['Processor & memory'].Text=(Find-Value 'CPU *' Model)+"`r`nInstalled RAM: "+(Find-Value System 'Installed RAM (GiB)')+" GiB`r`nConfigured memory speed: "+(Find-Value 'Memory *' 'Configured memory speed (SMBIOS)')+' (SMBIOS)'
    $cards['Security & virtualization'].Text='Secure Boot (cached): '+(Find-Value Security 'Secure Boot (Windows registry)')+"`r`nTPM ready: "+(Find-Value Security 'TPM ready')+"`r`nFirmware virtualization: "+(Find-Value 'CPU *' 'Virtualization enabled in firmware')
    $unavailable=@($script:current.Rows | Where-Object {$_.Value -match '^(Unavailable|Not reported|Not collected)'})
    $cards['Collection status'].Text='Captured: '+([datetime]$script:current.CapturedAt).ToString('g')+"`r`n"+$script:current.Rows.Count+' fields | '+$unavailable.Count+" unavailable / not reported`r`nUnknown values are not evidence that a feature is disabled."
    $cards['Tracking & diagnostics'].Text=$script:historyFiles.Count.ToString()+" automatic snapshots saved`r`n"+$events.Rows.Count+" recent events returned`r`nSee Events for query status and Drives for reported health."
    $queryStatus=@($script:current.Rows | Where-Object {$_.Section -eq 'Diagnostics'} | ForEach-Object {$_.Name+': '+$_.Value})
    $eventInfo.Text="Last 7 days, max 50/category. Double-click an event for the full message. Kernel-Power 41 does not identify the cause.`r`n"+($queryStatus -join ' | ')
}
function Accept-Report($Report){
    $script:current=$Report
    $selected=[string]$section.SelectedItem;$section.Items.Clear();[void]$section.Items.Add('All sections')
    foreach($s in @($Report.Rows.Section | Sort-Object -Unique)){[void]$section.Items.Add($s)}
    if($section.Items.Contains($selected)){$section.SelectedItem=$selected}else{$section.SelectedIndex=0}
    if($autoHistory.Checked -and !$SmokeTest -and !$PreviewPath){Save-AutoSnapshot $Report $script:historyPath}
    Refresh-History;Render-Report
}
function Choose-Baseline {
    $d=New-Object Windows.Forms.OpenFileDialog;$d.Filter='BIOS snapshot (*.json)|*.json'
    try{if($d.ShowDialog() -eq 'OK'){$script:baseline=Read-Snapshot $d.FileName;Render-Report}}
    catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Cannot compare snapshot')}
    finally{$d.Dispose()}
}
function Save-Report([string]$Kind){
    if(!$script:current){return}
    $d=New-Object Windows.Forms.SaveFileDialog
    $d.Filter=if($Kind -eq 'html'){'HTML report (*.html)|*.html'}else{'BIOS snapshot (*.json)|*.json'}
    $d.FileName='BIOS-'+(Get-Date -Format yyyy-MM-dd-HHmmss)+'.'+$Kind
    try{
        if($d.ShowDialog() -eq 'OK'){
            $content=if($Kind -eq 'html'){ConvertTo-ReportHtml $script:current}else{$script:current | ConvertTo-Json -Depth 8}
            [IO.File]::WriteAllText($d.FileName,$content);$status.Text='Saved: '+$d.FileName
        }
    }catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Export failed')}
    finally{$d.Dispose()}
}
function Start-Collection {
    if($script:job){return}
    $refresh.Enabled=$false;$status.Text='Collecting hardware, drives, events and power information...'
    $script:jobStarted=Get-Date
    try{$script:job=Start-Job -ScriptBlock {param($path) & $path} -ArgumentList (Join-Path $PSScriptRoot 'Collect.ps1')}
    catch{$status.Text=$_.Exception.Message;$refresh.Enabled=$true}
}
function Start-LiveSample {
    if($script:liveJob -or !$live.Checked -or $form.WindowState -eq 'Minimized'){return}
    $script:liveStarted=Get-Date
    $script:liveJob=Start-Job -ScriptBlock {param($path) & $path -LiveOnly} -ArgumentList (Join-Path $PSScriptRoot 'Collect.ps1')
}
$timer=New-Object Windows.Forms.Timer;$timer.Interval=500
$timer.Add_Tick({
    if($script:job){
        if(((Get-Date)-$script:jobStarted).TotalSeconds -gt 120){Stop-Job $script:job}
        if($script:job.State -in @('Completed','Failed','Stopped')){
            try{
                if($script:job.State -ne 'Completed'){throw 'Collection failed or exceeded 120 seconds. Previous report retained; try Refresh.'}
                $report=((Receive-Job $script:job -ErrorAction Stop) -join "`n") | ConvertFrom-Json
                if(!$report.Rows){throw 'Collector returned no report.'}
                Accept-Report $report;$status.Text='Updated '+([datetime]$report.CapturedAt).ToString('g')+' | '+$report.Rows.Count+' fields | All reports stay local.'
            }catch{$status.Text=$_.Exception.Message}
            finally{Remove-Job $script:job -Force;$script:job=$null;$refresh.Enabled=$true}
        }
    }
    if($script:liveJob){
        if(((Get-Date)-$script:liveStarted).TotalSeconds -gt 25){Stop-Job $script:liveJob}
        if($script:liveJob.State -in @('Completed','Failed','Stopped')){
            try{
                if($script:liveJob.State -ne 'Completed'){throw 'Live sample unavailable.'}
                $sample=((Receive-Job $script:liveJob -ErrorAction Stop) -join "`n") | ConvertFrom-Json
                $script:lastSample=$sample
                $cpu='Unavailable';$ram='Unavailable';$uptime='Unavailable'
                if($null -ne $sample.CpuPercent){$cpu=[string]$sample.CpuPercent+'%'}
                if($null -ne $sample.UsedGiB){$ram=[string]$sample.UsedGiB+' / '+$sample.TotalGiB+' GiB'}
                if($null -ne $sample.UptimeHours){$uptime=[string]$sample.UptimeHours+' hours'}
                $cards['Live usage'].Text='CPU: '+$cpu+"`r`nRAM used: "+$ram+"`r`nUptime: "+$uptime+"`r`nSample: "+([datetime]$sample.CapturedAt).ToString('T')
            }catch{$cards['Live usage'].Text='Live usage unavailable. '+$_.Exception.Message}
            finally{Remove-Job $script:liveJob -Force;$script:liveJob=$null;$script:nextLive=(Get-Date).AddSeconds(5)}
        }
    }elseif($live.Checked -and (Get-Date) -ge $script:nextLive){
        try{Start-LiveSample}catch{$cards['Live usage'].Text='Live sampling unavailable.';$script:nextLive=(Get-Date).AddSeconds(15)}
    }
})
$theme.Add_CheckedChanged({Apply-Theme})
$search.Add_TextChanged({if(!$script:loading){Render-Report}})
$section.Add_SelectedIndexChanged({if(!$script:loading){Render-Report}})
$hideRoutine.Add_CheckedChanged({Render-Report})
$autoHistory.Add_CheckedChanged({Save-Preferences})
$live.Add_CheckedChanged({
    if(!$live.Checked){$cards['Live usage'].Text='Live monitoring paused.';if($script:liveJob){Stop-Job $script:liveJob;Remove-Job $script:liveJob -Force;$script:liveJob=$null}}
    else{$script:nextLive=Get-Date};Save-Preferences
})
$form.Add_FormClosing({Save-Preferences;$timer.Stop()
    foreach($j in @($script:job,$script:liveJob)){if($j){Stop-Job $j;Remove-Job $j -Force}}
})
Apply-Theme;$script:loading=$false
if($SmokeTest -or $PreviewPath){
    $fixture=if($FixturePath){Read-Snapshot $FixturePath}else{[pscustomobject]@{SchemaVersion=1;CapturedAt=(Get-Date).ToString('o');Rows=@([pscustomobject]@{Section='Motherboard';Name='Model';Value='Test board';Source='Fixture'});Events=@()}}
    Accept-Report $fixture
    $script:baseline=[pscustomobject]@{Rows=@([pscustomobject]@{Section='Motherboard';Name='Model';Value='Previous board';Source='Fixture'}) ;CapturedAt=(Get-Date).AddDays(-1).ToString('o')}
    Render-Report
    if($details.Rows.Count -ne $fixture.Rows.Count -or $changes.Rows.Count -lt 1){throw 'Report or comparison rendering failed'}
    $search.Text='__no_match_fixture__';if($details.Rows.Count -ne 0){throw 'Search failed'};$search.Clear()
    foreach($dark in @($true,$false)){$theme.Checked=$dark;Apply-Theme;if($theme.Checked -ne $dark){throw 'Theme switch failed'}}
    $theme.Checked=$true;Apply-Theme
    if($PreviewPath){
        $form.Show();[Windows.Forms.Application]::DoEvents()
        foreach($page in $tabs.TabPages){
            $tabs.SelectedTab=$page;[Windows.Forms.Application]::DoEvents()
            $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
            $form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)))
            $name=[IO.Path]::GetFileNameWithoutExtension($PreviewPath)+'-'+$page.TabIndex+'.png'
            $bitmap.Save((Join-Path ([IO.Path]::GetDirectoryName($PreviewPath)) $name),[Drawing.Imaging.ImageFormat]::Png);$bitmap.Dispose()
        }
        $tabs.SelectedTab=$overviewPage;$theme.Checked=$false;Apply-Theme;[Windows.Forms.Application]::DoEvents()
        $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
        $form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)))
        $bitmap.Save($PreviewPath,[Drawing.Imaging.ImageFormat]::Png);$bitmap.Dispose();$form.Hide()
    }
    $form.Dispose();'UI smoke checks passed';exit
}
Refresh-History;Use-LatestHistory
$form.Add_Shown({Start-Collection;if(!$live.Checked){$cards['Live usage'].Text='Live monitoring paused.'}})
$timer.Start();[void]$form.ShowDialog();$timer.Dispose();$form.Dispose()
