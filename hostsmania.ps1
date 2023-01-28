$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (!$IsAdmin) {
    Write-Warning "Script must be run as administrator, to be able to edits hosts file."
    $Relaunch = Read-Host -Prompt "Re-launch as administrator? (y/n)"
    if ($Relaunch -eq 'y') {
        $PowerExecutable = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $ScriptPath = $MyInvocation.MyCommand.Definition
        Write-Host $PowerExecutable
        Write-Host $ScriptPath
        Start-Process -FilePath $PowerExecutable -Verb 'runAs' -ArgumentList @("-File $ScriptPath")
    }
    exit
}

$HostsFile =  Join-Path -Path $env:SystemRoot -ChildPath 'System32\drivers\etc\hosts'
$HostsContent = Get-Content -Path $HostsFile
$HostsNoComments = $HostsContent | Where-Object {$_ -notmatch '^#' -and ![string]::IsNullOrEmpty($_)}

[System.Collections.ArrayList]$HostRecords = @()
foreach ($Line in $HostsNoComments) {
    $IpAddress, $DomainName = ($Line | Where-Object {$_ -notmatch '^#'}) -split ' '
    $null = $HostRecords.Add(@{$IpAddress = $DomainName})
}

Write-Host "Displaying existing records: `n"
foreach ($Record in $HostRecords) {
    Write-Host "$($Record.Keys) $($Record.Values)"
}

$DomainsToAdd = @('rutracker.org', 'rutracker.net')

[System.Collections.ArrayList]$DomainRecords = @()

foreach ($Domain in $DomainsToAdd) {
     $DomainRecords.AddRange(@((Resolve-DnsName -Server 8.8.8.8 -Name $Domain | Where-Object {$_.Type -eq 'A'})))
}

[System.Collections.ArrayList]$HostsFileContentToAdd = @()
foreach ($DomainRecord in $DomainRecords) {
   $null = $HostsFileContentToAdd.Add("$($DomainRecord.IPAddress)`t$($DomainRecord.Name)")
}

Write-Host "`nAdding following records to hosts file: `n"
Write-Host ($HostsFileContentToAdd -join "`n")

Add-Content -Path $HostsFile -Value $HostsFileContentToAdd -ErrorAction Stop

Read-Host -Prompt "Press any key to exit."
