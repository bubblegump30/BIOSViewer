param([string]$OutputPath, [switch]$LiveOnly)
$ErrorActionPreference = 'Stop'
if($LiveOnly){
    $cpu=$null;$used=$null;$total=$null;$uptime=$null;$errors=@()
    try{$cpu=(Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -OperationTimeoutSec 8).PercentProcessorTime}catch{$errors+='CPU usage unavailable'}
    try{
        $os=Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 8
        $total=[math]::Round($os.TotalVisibleMemorySize/1MB,2)
        $used=[math]::Round(($os.TotalVisibleMemorySize-$os.FreePhysicalMemory)/1MB,2)
        $uptime=[math]::Round(((Get-Date)-$os.LastBootUpTime).TotalHours,1)
    }catch{$errors+='Memory and uptime unavailable'}
    [pscustomobject]@{CapturedAt=(Get-Date).ToString('o');CpuPercent=$cpu;UsedGiB=$used;TotalGiB=$total;UptimeHours=$uptime;Errors=$errors} | ConvertTo-Json -Depth 4
    exit
}
$rows = [System.Collections.Generic.List[object]]::new()
function Add-Value($Section, $Name, $Value, $Source) {
    if ($null -eq $Value -or "$Value" -eq '') { $Value = 'Not reported' }
    $rows.Add([pscustomobject]@{Section=$Section; Name=$Name; Value=[string]$Value; Source=$Source})
}
function Read-Class($Class, $Section, [scriptblock]$Read) {
    try { Get-CimInstance -ClassName $Class -OperationTimeoutSec 12 | ForEach-Object { & $Read $_ } }
    catch { Add-Value $Section 'Query status' ('Unavailable: ' + $_.Exception.Message) $Class }
}
Read-Class Win32_BaseBoard Motherboard {
    param($x)
    Add-Value Motherboard Manufacturer $x.Manufacturer SMBIOS
    Add-Value Motherboard Model $x.Product SMBIOS
    Add-Value Motherboard Revision $x.Version SMBIOS
}
Read-Class Win32_BIOS Firmware {
    param($x)
    Add-Value Firmware Vendor $x.Manufacturer SMBIOS
    Add-Value Firmware Version $x.SMBIOSBIOSVersion SMBIOS
    Add-Value Firmware 'Release date' $(if($x.ReleaseDate){$x.ReleaseDate.ToString('yyyy-MM-dd')}) SMBIOS
    Add-Value Firmware 'SMBIOS version' "$($x.SMBIOSMajorVersion).$($x.SMBIOSMinorVersion)" SMBIOS
}
Read-Class Win32_ComputerSystem System {
    param($x)
    Add-Value System Manufacturer $x.Manufacturer Windows
    Add-Value System Model $x.Model Windows
    Add-Value System 'Installed RAM (GiB)' ([math]::Round($x.TotalPhysicalMemory/1GB,2)) Windows
    Add-Value Virtualization 'Hypervisor present' $x.HypervisorPresent Windows
}
Read-Class Win32_Processor CPU {
    param($x)
    $s = 'CPU ' + $x.DeviceID
    Add-Value $s Model $x.Name Windows
    Add-Value $s Cores $x.NumberOfCores Windows
    Add-Value $s 'Logical processors' $x.NumberOfLogicalProcessors Windows
    Add-Value $s 'Reported maximum clock (MHz)' $x.MaxClockSpeed 'Windows; not a live boost measurement'
    Add-Value $s 'Virtualization enabled in firmware' $x.VirtualizationFirmwareEnabled Windows
    Add-Value $s 'Second level address translation' $x.SecondLevelAddressTranslationExtensions Windows
}
Read-Class Win32_PhysicalMemory Memory {
    param($x)
    $s = 'Memory ' + $x.DeviceLocator
    Add-Value $s Manufacturer $x.Manufacturer SMBIOS
    Add-Value $s 'Part number' ([string]$x.PartNumber).Trim() SMBIOS
    Add-Value $s 'Capacity (GiB)' ([math]::Round($x.Capacity/1GB,2)) SMBIOS
    Add-Value $s 'Configured memory speed (SMBIOS)' $x.ConfiguredClockSpeed 'SMBIOS; not XMP profile status'
    Add-Value $s 'Rated speed (SMBIOS)' $x.Speed SMBIOS
}
Read-Class Win32_DiskDrive Storage {
    param($x)
    $s = 'Disk ' + $x.Index
    Add-Value $s Model $x.Model Windows
    Add-Value $s 'Capacity (GiB)' ([math]::Round($x.Size/1GB,2)) Windows
    Add-Value $s Interface $x.InterfaceType 'Windows driver reporting'
    Add-Value $s 'Reported status' $x.Status 'Windows; not a full SMART diagnosis'
}
Read-Class Win32_VideoController Graphics {
    param($x)
    Add-Value ('Graphics ' + $x.DeviceID) Model $x.Name Windows
    Add-Value ('Graphics ' + $x.DeviceID) 'Driver version' $x.DriverVersion Windows
}
Read-Class Win32_OperatingSystem Windows {
    param($x)
    Add-Value Windows Edition $x.Caption Windows
    Add-Value Windows Build $x.BuildNumber Windows
    Add-Value Windows 'Last boot' $x.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss') Windows
}
try {
    $v = Get-ItemPropertyValue 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' UEFISecureBootEnabled
    Add-Value Security 'Secure Boot (Windows registry)' $(if($v -eq 1){'Enabled'}else{'Disabled'}) 'Windows cached state'
} catch { Add-Value Security 'Secure Boot (Windows registry)' 'Unavailable' 'Windows cached state' }
try { Add-Value Security 'Secure Boot (firmware query)' (Confirm-SecureBootUEFI) 'UEFI; administrator may be required' }
catch { Add-Value Security 'Secure Boot (firmware query)' ('Unavailable: ' + $_.Exception.Message) UEFI }
try {
    $t = Get-Tpm
    Add-Value Security 'TPM present' $t.TpmPresent Windows
    Add-Value Security 'TPM ready' $t.TpmReady Windows
    Add-Value Security 'TPM enabled' $t.TpmEnabled Windows
} catch { Add-Value Security TPM ('Unavailable: ' + $_.Exception.Message) Windows }
foreach($name in @('BIOS boot priority','XMP / A-XMP profile','PBO / CPU overclock settings','Fan curves and RPM','CPU temperature and voltage','Resizable BAR / CSM / SATA mode')) {
    Add-Value 'Firmware-only / unavailable' $name 'Not collected; inspect firmware or a supported vendor utility' 'No supported reader included'
}
Read-Class Win32_LogicalDisk Volumes {
    param($x)
    if($x.DriveType -ne 3){return}
    Add-Value ('Volume '+$x.DeviceID) 'File system' $x.FileSystem Windows
    Add-Value ('Volume '+$x.DeviceID) 'Capacity (GiB)' ([math]::Round($x.Size/1GB,1)) Windows
    Add-Value ('Volume '+$x.DeviceID) 'Free space (GiB)' ([math]::Round($x.FreeSpace/1GB,1)) Windows
    if($x.Size -gt 0){Add-Value ('Volume '+$x.DeviceID) 'Free space (%)' ([math]::Round(100*$x.FreeSpace/$x.Size,1)) Windows}
}
try{
    $disks=@(Get-PhysicalDisk -ErrorAction Stop)
    if(!$disks.Count){Add-Value 'Drive health' Status 'No drives returned' 'Windows Storage provider'}
    foreach($disk in $disks){
        $s='Drive health '+$disk.DeviceId
        Add-Value $s Model $disk.FriendlyName 'Windows Storage provider'
        Add-Value $s 'Health status' $disk.HealthStatus 'Reported status; not a complete diagnosis'
        Add-Value $s 'Operational status' ($disk.OperationalStatus -join ', ') 'Windows Storage provider'
        Add-Value $s 'Media type' $disk.MediaType 'Windows Storage provider'
        try{
            $c=$disk | Get-StorageReliabilityCounter -ErrorAction Stop
            if(!$c){throw 'No reliability counters returned'}
            Add-Value $s 'Temperature (C)' $c.Temperature 'Device-reported; zero may mean unsupported'
            Add-Value $s 'Wear (%)' $c.Wear 'Device-reported; 100 means estimated wear limit reached'
            Add-Value $s 'Power-on hours' $c.PowerOnHours 'Device-reported'
            Add-Value $s 'Uncorrected read errors' $c.ReadErrorsUncorrected 'Device-reported'
            Add-Value $s 'Uncorrected write errors' $c.WriteErrorsUncorrected 'Device-reported'
        }catch{Add-Value $s 'Reliability counters' ('Unavailable: '+$_.Exception.Message) 'May require administrator or a compatible controller'}
    }
}catch{Add-Value 'Drive health' Status ('Unavailable: '+$_.Exception.Message) 'Windows Storage provider'}
$events=[System.Collections.Generic.List[object]]::new()
$since=(Get-Date).AddDays(-7)
foreach($query in @(
    @{Label='Hardware errors (WHEA)';Filter=@{LogName='System';ProviderName='Microsoft-Windows-WHEA-Logger';StartTime=$since}},
    @{Label='Unexpected shutdowns';Filter=@{LogName='System';ProviderName='Microsoft-Windows-Kernel-Power';Id=41;StartTime=$since}}
)){
    try{
        $found=@(Get-WinEvent -FilterHashtable $query.Filter -MaxEvents 50 -ErrorAction Stop)
        foreach($e in $found){
            $events.Add([pscustomobject]@{Time=$e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss');Type=$query.Label;Id=$e.Id;Level=$e.LevelDisplayName;Message=$e.Message})
        }
        Add-Value Diagnostics $query.Label ($found.Count.ToString()+' returned (maximum 50; last 7 days)') 'Windows System event log; events are not a component diagnosis'
    }catch{
        if($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*'){
            Add-Value Diagnostics $query.Label 'No matching events in the last 7 days' 'Windows System event log; not proof of fault-free hardware'
        }else{Add-Value Diagnostics $query.Label ('Unavailable: '+$_.Exception.Message) 'Windows System event log'}
    }
}
foreach($power in @(@{Name='Available sleep states';Arg='/a'},@{Name='Last wake source';Arg='/lastwake'})){
    try{
        $text=(& "$env:SystemRoot\System32\powercfg.exe" $power.Arg 2>&1 | Out-String).Trim()
        if($LASTEXITCODE -ne 0){throw $text}
        Add-Value Power $power.Name $text 'Windows powercfg; read-only query'
    }catch{Add-Value Power $power.Name ('Unavailable: '+$_.Exception.Message) powercfg}
}
$result = [pscustomobject]@{SchemaVersion=1; CapturedAt=(Get-Date).ToString('o'); Rows=@($rows.ToArray()); Events=@($events.ToArray())}
. (Join-Path $PSScriptRoot 'Reports.ps1')
$result=Normalize-Snapshot $result
$json = $result | ConvertTo-Json -Depth 6
if($OutputPath){[IO.File]::WriteAllText($OutputPath,$json)}else{$json}
