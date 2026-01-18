Param(
    [Parameter(Mandatory=$true)]
    [string]$FolderPath,  # The path containing the extracted/merged host folders
    [Parameter(Mandatory=$true)]
    [string]$IncidentName # The incident name to use with Cyber Triage
)

# Ensure running as Administrator.
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    exit
}

# Validate input paths.
if (!(Test-Path $FolderPath)) {
    Write-Error "The specified FolderPath '$FolderPath' does not exist."
    exit
}

# --- Step 0: Create the Incident ---
$cyberTriageExe = "C:\Program Files\Cyber Triage\bin\cybertriage64.exe"
if (!(Test-Path $cyberTriageExe)) {
    Write-Error "Cyber Triage executable not found at '$cyberTriageExe'."
    exit 1
}

Write-Host "Creating incident '$IncidentName'..."
$createProc = Start-Process -FilePath $cyberTriageExe -ArgumentList "--createIncident=`"$IncidentName`" --nogui --nosplash --console suppress" -PassThru
$createProc.WaitForExit()
# Ensure no lingering Cyber Triage processes remain.
while (Get-Process -Name "cybertriage64" -ErrorAction SilentlyContinue) {
    Start-Sleep -Seconds 2
}

# Validate the FolderPath exists.
Write-Host "Processing host folders under '$FolderPath'..."
$folders = Get-ChildItem -Path $FolderPath -Directory
foreach ($folder in $folders) {
    $imageFolderName = $folder.Name
    $imageFolderPath = $folder.FullName

    # Build the command-line arguments.
    $args = "--openIncident=`"$IncidentName`" --addHost=`"$($imageFolderName)`" --addHostType=`"KAPE`" --addHostPath=`"$imageFolderPath`" --addHostMalware=`"ImpHash`" --nogui --nosplash"
    
    Write-Host "Processing folder '$imageFolderPath' for incident '$IncidentName'..."
    
    # Start Cyber Triage for this folder.
    $proc = Start-Process -FilePath $cyberTriageExe -ArgumentList $args -PassThru
    
    # Wait until Cyber Triage exits.
    $proc.WaitForExit()
    
    # Ensure no lingering Cyber Triage processes remain.
    while (Get-Process -Name "cybertriage64" -ErrorAction SilentlyContinue) {
        Start-Sleep -Seconds 2
    }
    
    Write-Host "Completed processing folder '$imageFolderPath'."
}