param(
    [Parameter(Mandatory = $true, HelpMessage = "Enter the full path to the source directory.")]
    [string]$Source,
    
    [Parameter(Mandatory = $true, HelpMessage = "Enter the full path to the destination directory.")]
    [string]$Destination
)

# Validate source directory.
if (-not (Test-Path $Source)) {
    Write-Error "Source folder not found: $Source"
    exit 1
}

# Create destination directory if it doesn't exist.
if (-not (Test-Path $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

# Remove any trailing backslash from the source.
if ($Source.EndsWith("\")) {
    $Source = $Source.TrimEnd("\")
}

# Recursively search for folders named "sru".
Get-ChildItem -Path $Source -Recurse -Directory | Where-Object { $_.Name -eq "sru" } | ForEach-Object {

    $sruFolderPath = $_.FullName

    # Compute the relative path from source to this "sru" folder.
    $fullRelativePath = $sruFolderPath.Substring($Source.Length).TrimStart("\")

    # Remove the trailing "sru" part to work only with its parent folder.
    $relativeParentPath = Split-Path $fullRelativePath -Parent

    # Split the parent's relative path into folder segments.
    $parts = $relativeParentPath -split "\\"

    # Determine the new relative path:
    # If there are 3 or more folder segments, take only the last three,
    # otherwise, keep the full relative parent path.
    if ($parts.Count -ge 3) {
        $trimmedParts = $parts[($parts.Count - 3)..($parts.Count - 1)]
        $newRelativePath = $trimmedParts -join "\"
    }
    else {
        $newRelativePath = $relativeParentPath
    }

    # Build the destination path by joining the destination base with the new relative path.
    $destinationParent = Join-Path $Destination $newRelativePath

    # Ensure the destination parent folder exists.
    if (-not (Test-Path $destinationParent)) {
        New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
    }

    Write-Output "Copying: $sruFolderPath to $destinationParent"

    # Copy the entire sru folder (with all its content) into the destination folder.
    Copy-Item -Path $sruFolderPath -Destination $destinationParent -Recurse -Force
}

Write-Output "Copy completed."