Param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Output
)

# Resolve absolute paths for the input and output directories.
$absPath = (Resolve-Path $Path).Path
$absOutput = (Resolve-Path $Output).Path

# Path to the Artifast executable.
$artiFastExe = "C:\Program Files\Forensafe\ArtiFast\Suite\v6.5.0\bin\Artifast-Suite.exe"

# Iterate over each subfolder in the input directory.
Get-ChildItem -Path $absPath -Directory | ForEach-Object {
    $subfolder = $_
    Write-Host "Processing folder: $($subfolder.FullName)"
    $target_image = (Resolve-Path $subfolder.FullName).Path
    # Build the command arguments using the current subfolder as the directory.
    $arguments = "export --json --directory=`"$($target_image)`" --output=`"$absOutput`""
    Write-Host "Running command: $artiFastExe $arguments"
    
    # Execute the Artifast export command.
    & "$artiFastExe" export --json --directory="$($target_image)" --output="$absOutput"
    
    # Define the path to the generated timeline.json.
    $originalFile = Join-Path $absOutput "timeline.json"
    if (Test-Path $originalFile) {
        # Rename the file to the current subfolder's name with a .json extension.
        $newFileName = "$($subfolder.Name).json"
        $newFilePath = Join-Path $absOutput $newFileName
        Write-Host "Renaming timeline.json to $newFileName"
        Rename-Item -Path $originalFile -NewName $newFileName
    }
    else {
        Write-Host "timeline.json was not found in $absOutput for folder $($subfolder.Name)"
    }
}