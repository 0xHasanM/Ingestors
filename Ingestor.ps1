Param(
    [Parameter(Mandatory = $true)]
    [string]$Path,    # The path to the "extracted_images" folder
    [Parameter(Mandatory = $true)]
    [string]$Output   # The desired output directory for the Artifast export
)

function Get-HostnameFromEvtx {
    param(
        [Parameter(Mandatory=$true)]
        [string]$EvtxPath
    )
    try {
        $tempFile = Join-Path $env:TEMP ("temp_evtx_" + (Get-Random) + ".evtx")
        Copy-Item -Path $EvtxPath -Destination $tempFile -Force

        $hostname = (Get-WinEvent -Path $tempFile -ErrorAction Stop | Select-Object -First 1 -ExpandProperty MachineName)
        $hostname = [string]::Join("", $hostname).Trim()

        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()

        try {
            Remove-Item -Path $tempFile -Force -ErrorAction Stop
        }
        catch {
            Write-Host "Warning: Could not remove temporary file '$tempFile'."
        }

        return $hostname
    }
    catch {
        Write-Error "Error reading evtx at '$EvtxPath': $($_.Exception.Message)"
        return $null
    }
}

# Helper function to transform drive folder names.
function Transform-DriveFolderName {
    param(
        [string]$name
    )
    $newName = $name
    # Handle double-encoded drive letters, with or without an extra dot.
    if ($newName -match '^(?:%5C%5C\.?([A-Z])%3A|%255C%255C\.?%255C?([A-Z])%253A)$') {
        if ($matches[1]) {
            $newName = $matches[1]
        }
        elseif ($matches[2]) {
            $newName = $matches[2]
        }
    }
    # Handle drive letter followed by %253A (double encoded colon).
    elseif ([regex]::IsMatch($newName, '^(?<drive>[A-Z])%253A$')) {
        $match = [regex]::Match($newName, '^(?<drive>[A-Z])%253A$')
        $newName = $match.Groups['drive'].Value
    }
    # Handle drive letter followed by %3A (single encoded colon).
    elseif ([regex]::IsMatch($newName, '^(?<drive>[A-Z])%3A$')) {
        $match = [regex]::Match($newName, '^(?<drive>[A-Z])%3A$')
        $newName = $match.Groups['drive'].Value
    }
    # Fallback: if any generic pattern with %3A exists, take what comes after.
    elseif ([regex]::IsMatch($newName, "^(.*?)%3A(.+)$")) {
        $match = [regex]::Match($newName, "^(.*?)%3A(.+)$")
        $newName = $match.Groups[2].Value
    }
    # Final cleanup: if any pattern like %5C%5C\.?%5C?([A-Z])%3A remains.
    if ([regex]::IsMatch($newName, '%5C%5C\.?%5C?([A-Z])%3A')) {
        $newName = [regex]::Replace($newName, '%5C%5C\.?%5C?([A-Z])%3A', '$1')
    }
    return $newName
}

# Validate input paths.
if (!(Test-Path $Path)) {
    Write-Error "The specified path '$Path' does not exist."
    exit
}
if (!(Test-Path $Output)) {
    Write-Host "The specified output path '$Output' does not exist. Creating it..."
    New-Item -ItemType Directory -Path $Output | Out-Null
}

# Define the path to the 7-Zip executable.
$sevenZipExe = "C:\Program Files\7-Zip\7z.exe"

# Process each zip file found in the specified folder (non-recursive).
$zipFiles = Get-ChildItem -Path $Path -Filter *.zip

if ($zipFiles) {
    foreach ($zip in $zipFiles) {

        # Extraction folder is based on the zip file’s name.
        $destination = Join-Path -Path $zip.DirectoryName -ChildPath $zip.BaseName
        if (!(Test-Path $destination)) {
            New-Item -ItemType Directory -Path $destination | Out-Null
        }
        Write-Host "Extracting '$($zip.FullName)' to '$destination' using 7-Zip..."
        & $sevenZipExe x $zip.FullName -o"$destination" -y

        # Step 2: Rename the decompressed folder based on naming patterns.
        $folderName = Split-Path $destination -Leaf
        if ($folderName -match '^Collection-(WIN-[^_]+)') {
            $newName = $matches[1]
            $parentPath = Split-Path $destination -Parent
            $newFolderPath = Join-Path -Path $parentPath -ChildPath $newName
            Write-Host "Renaming folder '$destination' to '$newFolderPath'"
            Rename-Item -Path $destination -NewName $newName -Force
            $destination = $newFolderPath
        }
        elseif ($folderName -match '^(?<base>[^-]+-[^-]+)-[A-Z]\..+$') {
            $newName = $matches['base']
            $parentPath = Split-Path $destination -Parent
            $newFolderPath = Join-Path -Path $parentPath -ChildPath $newName
            Write-Host "Renaming folder '$destination' to '$newFolderPath'"
            Rename-Item -Path $destination -NewName $newName -Force
            $destination = $newFolderPath
        }

        # Step 3a: Rename files within the decompressed folder.
        $files = Get-ChildItem -Path $destination -Recurse -File
        foreach ($file in $files) {
            $originalName = $file.Name
            $newName = $originalName
            $match = [regex]::Match($newName, "^(.*?)%3A(.*)$")
            if ($match.Success) {
                $newName = $match.Groups[2].Value
            }
            if ([regex]::IsMatch($newName, '%5C%5C\.%5C([A-Z])%3A')) {
                $newName = [regex]::Replace($newName, '%5C%5C\.%5C([A-Z])%3A', '$1')
            }
            if ($newName -ne $originalName) {
                $newFilePath = Join-Path -Path $file.DirectoryName -ChildPath $newName
                Write-Host "Renaming file '$($file.FullName)' to '$newFilePath'"
                Rename-Item -Path $file.FullName -NewName $newName -Force
            }
        }

        # Step 3b: Rename directories within the decompressed folder.
        $directories = Get-ChildItem -Path $destination -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending
        foreach ($dir in $directories) {
            $origDirName = $dir.Name
            $newDirName = $origDirName

            if ($newDirName -match '^(?:%5C%5C\.([A-Z])%3A|%255C%255C\.%255C([A-Z])%253A)$') {
                if ($matches[1]) {
                    $newDirName = $matches[1]
                }
                elseif ($matches[2]) {
                    $newDirName = $matches[2]
                }
            }
            elseif ([regex]::IsMatch($newDirName, '^(?<drive>[A-Z])%3A$')) {
                $match = [regex]::Match($newDirName, '^(?<drive>[A-Z])%3A$')
                $newDirName = $match.Groups['drive'].Value
            }
            elseif ([regex]::IsMatch($newDirName, "^(.*?)%3A(.+)$")) {
                $match = [regex]::Match($newDirName, "^(.*?)%3A(.+)$")
                $newDirName = $match.Groups[2].Value
            }
            if ([regex]::IsMatch($newDirName, '%5C%5C\.%5C([A-Z])%3A')) {
                $newDirName = [regex]::Replace($newDirName, '%5C%5C\.%5C([A-Z])%3A', '$1')
            }

            if ($newDirName -ne $origDirName) {
                $newDirPath = Join-Path -Path $dir.Parent.FullName -ChildPath $newDirName
                Write-Host "Renaming folder '$($dir.FullName)' to '$newDirPath'"
                Rename-Item -Path $dir.FullName -NewName $newDirName -Force
            }
        }

        # Step 5: Process all "uploads" folders under the decompressed folder.
        $uploadsFolders = Get-ChildItem -Path $destination -Recurse -Directory | Where-Object { $_.Name -ieq "uploads" }
        foreach ($uploads in $uploadsFolders) {
            foreach ($sub in @("ntfs", "auto")) {
                $subPath = Join-Path -Path $uploads.FullName -ChildPath $sub
                if (Test-Path $subPath) {
                    Get-ChildItem -Path $subPath -Directory | ForEach-Object {
                        $driveFolder = $_
                        $rawDriveName = $driveFolder.Name
                        $driveLetter = Transform-DriveFolderName -name $rawDriveName
                        $uploadsParent = (Split-Path $uploads.FullName -Parent | Split-Path -Leaf)
                        $targetName = "${uploadsParent}_$driveLetter"
                        $targetDir = Join-Path -Path (Split-Path $destination) -ChildPath $targetName
                        if (!(Test-Path $targetDir)) {
                            New-Item -ItemType Directory -Path $targetDir | Out-Null
                        }
                        Write-Host "Merging contents of '$($driveFolder.FullName)' into '$targetDir'"
                        Copy-Item -Path (Join-Path $driveFolder.FullName "*") -Destination $targetDir -Recurse -Force

                        $evtxPath = Join-Path -Path $targetDir -ChildPath "Windows\System32\winevt\Logs\Application.evtx"
                        if (Test-Path $evtxPath) {
                            $machineName = Get-HostnameFromEvtx -EvtxPath $evtxPath
                            $machineName = $machineName.Trim()
                            $machineName = [System.IO.Path]::GetFileName($machineName)
                            # Split on the dot and take the first element
                            $machineName = $machineName.Split('.')[0]
                            if ($machineName -and $machineName -ne "") {
                                $baseFinalPath = Join-Path -Path $Output -ChildPath $machineName
                                $newFinalPath = $baseFinalPath
                                $i = 1
                                while (Test-Path $newFinalPath) {
                                    $newFinalPath = $baseFinalPath + "_" + $i
                                    $i++
                                }
                                Write-Host "Moving merged folder '$targetDir' to '$newFinalPath'"
                                try {
                                    Move-Item -Path $targetDir -Destination $newFinalPath -Force
                                    $targetDir = $newFinalPath
                                }
                                catch {
                                    Write-Error "Failed to move folder '$targetDir' to '$machineName': $($_.Exception.Message)"
                                }
                            }
                        }
                    }
                }
            }
            Remove-Item -Path $uploads.FullName -Recurse -Force
        }

        # Clean up by removing the entire decompressed folder.
        Remove-Item -Path $destination -Recurse -Force
    }
}
else {
    Write-Host "No zip files found in '$Path'. Proceeding to look for uploads folders in the provided path..."
    $destination = $Path

    # --- New: Rename files logic for no zip branch ---
    $files = Get-ChildItem -Path $destination -Recurse -File
    foreach ($file in $files) {
        $originalName = $file.Name
        $newName = $originalName
        $match = [regex]::Match($newName, "^(.*?)%3A(.*)$")
        if ($match.Success) {
            $newName = $match.Groups[2].Value
        }
        $match = [regex]::Match($newName, '^(.*?)%253A(.*)$')
        if ($match.Success) {
            $newName = $match.Groups[2].Value
        }
        if ([regex]::IsMatch($newName, '%5C%5C\.%5C([A-Z])%3A')) {
            $newName = [regex]::Replace($newName, '%5C%5C\.%5C([A-Z])%3A', '$1')
        }
        if ($newName -ne $originalName) {
            $newFilePath = Join-Path -Path $file.DirectoryName -ChildPath $newName
            Write-Host "Renaming file '$($file.FullName)' to '$newFilePath'"
            Rename-Item -Path $file.FullName -NewName $newName -Force
        }
    }
    # --- End of rename files logic for no zip branch ---

    $uploadsFolders = Get-ChildItem -Path $destination -Recurse -Directory | Where-Object { $_.Name -ieq "uploads" }
    foreach ($uploads in $uploadsFolders) {
        foreach ($sub in @("ntfs", "auto")) {
            $subPath = Join-Path -Path $uploads.FullName -ChildPath $sub
            if (Test-Path $subPath) {
                Get-ChildItem -Path $subPath -Directory | ForEach-Object {
                    $driveFolder = $_
                    $rawDriveName = $driveFolder.Name
                    $driveLetter = Transform-DriveFolderName -name $rawDriveName
                    $uploadsParent = (Split-Path $uploads.FullName -Parent | Split-Path -Leaf)
                    $targetName = "${uploadsParent}_$driveLetter"
                    $targetDir = Join-Path -Path (Split-Path $destination) -ChildPath $targetName
                    if (!(Test-Path $targetDir)) {
                        New-Item -ItemType Directory -Path $targetDir | Out-Null
                    }
                    Write-Host "Merging contents of '$($driveFolder.FullName)' into '$targetDir'"
                    Copy-Item -Path (Join-Path $driveFolder.FullName "*") -Destination $targetDir -Recurse -Force

                    $evtxPath = Join-Path -Path $targetDir -ChildPath "Windows\System32\winevt\Logs\Application.evtx"
                    if (Test-Path $evtxPath) {
                        $machineName = Get-HostnameFromEvtx -EvtxPath $evtxPath
                        $machineName = $machineName.Trim()
                        $machineName = [System.IO.Path]::GetFileName($machineName)
                        # Split on the dot and take the first element
                        $machineName = $machineName.Split('.')[0]
                        if ($machineName -and $machineName -ne "") {
                            $baseFinalPath = Join-Path -Path $Output -ChildPath $machineName
                            $newFinalPath = $baseFinalPath
                            $i = 1
                            while (Test-Path $newFinalPath) {
                                $newFinalPath = $baseFinalPath + "_" + $i
                                $i++
                            }
                            Write-Host "Moving merged folder '$targetDir' to '$newFinalPath'"
                            try {
                                Move-Item -Path $targetDir -Destination $newFinalPath -Force
                                $targetDir = $newFinalPath
                            }
                            catch {
                                Write-Error "Failed to move folder '$targetDir' to '$machineName': $($_.Exception.Message)"
                            }
                        }
                    }
                }
            }
        }
        Remove-Item -Path $uploads.FullName -Recurse -Force
    }
}