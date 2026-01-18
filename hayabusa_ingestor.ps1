param(
    [Parameter(Mandatory=$false)]
    [string]$HayabusaExePath = "C:\Path\To\hayabusa.exe",

    [Parameter(Mandatory=$false)]
    [string]$EventLogsPath = "C:\Path\To\EventLogs",

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\Path\To\Output"
)

# Resolve absolute paths.
$absEventLogsPath = (Resolve-Path $EventLogsPath).Path
$absOutputPath = (Resolve-Path $OutputPath).Path

$update_argument = @(
	"update-rules"
)

& $HayabusaExePath $update_argument

# Iterate over each subfolder in the EventLogs directory.
Get-ChildItem -Path $absEventLogsPath -Directory | ForEach-Object {
    $subfolder = $_
    Write-Host "Processing folder: $($subfolder.FullName)"
    
    # Create a unique output subfolder named after the current subfolder.
    $subOutputPath = Join-Path $absOutputPath $subfolder.Name
    
    # Build the argument array using the current subfolder as the input directory and the unique output folder.
    $arguments = @(
        "csv-timeline",
        "--no-wizard",
        "--multiline",
        "--recover-records",
        "--quiet-errors",
        "--quiet",
        "--no-summary",
        "--proven-rules",
        "--clobber",
        "--UTC",
        "--directory", $subfolder.FullName,
        "--output", $($subOutputPath + ".csv"),
        "--min-level", "informational",
        "--profile", "super-verbose",
        "--ISO-8601",
        "--threads", "4"
    )
    
    Write-Host "Running command: $HayabusaExePath $($arguments -join ' ')"
    & $HayabusaExePath @arguments
}