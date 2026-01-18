# Ingestors

A collection of PowerShell scripts designed to transform raw forensic data into formats suitable for analysis in digital forensics investigations.

## Overview

This repository contains specialized PowerShell scripts that automate the processing of forensic artifacts collected from various sources. These tools streamline the ingestion workflow by handling common tasks such as extraction, normalization, and preparation of forensic data for analysis with different forensic platforms.

## Scripts

### 1. Ingestor.ps1

**Purpose**: Main ingestion script that processes forensic image collections from zip archives or directories, normalizes folder structures, and prepares data for analysis.

**Key Features**:
- Extracts zip files containing forensic collections using 7-Zip
- Automatically renames folders based on collection naming patterns (e.g., `Collection-WIN-*`)
- Decodes URL-encoded file and folder names (e.g., `%3A`, `%5C`)
- Processes "uploads" folders containing NTFS/auto-collected data
- Extracts hostname from Windows Event Logs (Application.evtx)
- Organizes output by hostname for easier analysis

**Parameters**:
- `-Path` (Mandatory): Path to the "extracted_images" folder containing zip files or collection directories
- `-Output` (Mandatory): Desired output directory for the processed forensic data

**Prerequisites**:
- 7-Zip installed at `C:\Program Files\7-Zip\7z.exe`
- PowerShell 5.1 or later
- Windows Event Log access for hostname extraction

**Usage Example**:
```powershell
.\Ingestor.ps1 -Path "C:\Forensics\RawCollections" -Output "C:\Forensics\ProcessedData"
```

**Workflow**:
1. Scans the input path for zip files
2. Extracts each zip file using 7-Zip
3. Renames the extracted folder based on collection patterns
4. Decodes URL-encoded file and directory names
5. Processes "uploads" folders (ntfs/auto subdirectories)
6. Merges drive-specific data into organized folders
7. Extracts hostname from Application.evtx
8. Moves processed data to output directory named by hostname

---

### 2. artifast_ingestor.ps1

**Purpose**: Automates the export of forensic artifacts using ArtiFast Suite, processing multiple forensic images in batch mode.

**Key Features**:
- Batch processes multiple forensic image directories
- Exports artifacts to JSON format using ArtiFast Suite
- Automatically renames output files to match source folder names
- Supports directory-based forensic image analysis

**Parameters**:
- `-Path` (Mandatory): Path to directory containing forensic image subfolders
- `-Output` (Mandatory): Output directory for exported JSON files

**Prerequisites**:
- ArtiFast Suite v6.5.0 installed at `C:\Program Files\Forensafe\ArtiFast\Suite\v6.5.0\bin\Artifast-Suite.exe`
- Valid ArtiFast license
- PowerShell 5.1 or later

**Usage Example**:
```powershell
.\artifast_ingestor.ps1 -Path "C:\Forensics\ProcessedData" -Output "C:\Forensics\ArtiFast_Output"
```

**Workflow**:
1. Iterates through each subfolder in the input directory
2. Executes ArtiFast export command with JSON output format
3. Processes the forensic image directory
4. Renames the generated `timeline.json` to match the subfolder name

---

### 3. cybertriage_kape_ingestor.ps1

**Purpose**: Automates the ingestion of KAPE-collected forensic data into Cyber Triage for incident analysis.

**Key Features**:
- Creates a new Cyber Triage incident
- Processes multiple host folders in batch mode
- Configures hosts with KAPE data type
- Enables ImpHash-based malware scanning
- Ensures clean process execution (no lingering processes)

**Parameters**:
- `-FolderPath` (Mandatory): Path containing extracted/merged host folders
- `-IncidentName` (Mandatory): Name for the Cyber Triage incident

**Prerequisites**:
- Cyber Triage installed at `C:\Program Files\Cyber Triage\bin\cybertriage64.exe`
- Administrator privileges (required for Cyber Triage operations)
- Valid Cyber Triage license
- PowerShell 5.1 or later

**Usage Example**:
```powershell
# Run as Administrator
.\cybertriage_kape_ingestor.ps1 -FolderPath "C:\Forensics\ProcessedData" -IncidentName "Investigation_2024_001"
```

**Workflow**:
1. Validates administrator privileges
2. Creates a new incident in Cyber Triage
3. Iterates through each host folder
4. Adds each host to the incident with KAPE data type
5. Configures ImpHash malware detection
6. Ensures process cleanup between operations

---

### 4. hayabusa_ingestor.ps1

**Purpose**: Processes Windows Event Logs using Hayabusa for timeline analysis and threat hunting.

**Key Features**:
- Updates Hayabusa detection rules before processing
- Batch processes multiple event log directories
- Generates CSV timeline outputs with detailed logging
- Supports multi-threaded processing for performance
- Uses proven detection rules for reliable results

**Parameters**:
- `-HayabusaExePath` (Optional): Path to hayabusa.exe (default: `C:\Path\To\hayabusa.exe`)
- `-EventLogsPath` (Optional): Path to event logs directory (default: `C:\Path\To\EventLogs`)
- `-OutputPath` (Optional): Output directory for CSV files (default: `C:\Path\To\Output`)

**Prerequisites**:
- Hayabusa installed (https://github.com/Yamato-Security/hayabusa)
- PowerShell 5.1 or later
- Windows Event Log files (.evtx)

**Usage Example**:
```powershell
.\hayabusa_ingestor.ps1 -HayabusaExePath "C:\Tools\hayabusa.exe" `
                        -EventLogsPath "C:\Forensics\ProcessedData" `
                        -OutputPath "C:\Forensics\Hayabusa_Output"
```

**Workflow**:
1. Updates Hayabusa detection rules
2. Iterates through each subfolder containing event logs
3. Executes Hayabusa with comprehensive options:
   - CSV timeline output format
   - Multiline support
   - Record recovery enabled
   - Super-verbose profile
   - Proven rules only
   - UTC timestamps
   - ISO-8601 date format
   - 4 threads for processing
4. Generates a CSV file named after each processed subfolder

---

### 5. sru_ingestor.ps1

**Purpose**: Extracts and organizes System Resource Usage (SRU) database files from forensic collections for analysis.

**Key Features**:
- Recursively searches for SRU folders in forensic collections
- Maintains hierarchical folder structure (last 3 levels)
- Preserves complete SRU folder contents
- Creates organized output structure

**Parameters**:
- `-Source` (Mandatory): Full path to the source directory containing forensic data
- `-Destination` (Mandatory): Full path to the destination directory for SRU files

**Prerequisites**:
- PowerShell 5.1 or later
- Read access to source directory

**Usage Example**:
```powershell
.\sru_ingestor.ps1 -Source "C:\Forensics\ProcessedData" -Destination "C:\Forensics\SRU_Collection"
```

**Workflow**:
1. Validates source directory exists
2. Creates destination directory if needed
3. Recursively searches for folders named "sru"
4. Determines the relative path structure
5. Preserves the last 3 folder levels in the hierarchy
6. Copies entire SRU folder contents to organized destination

---

## Typical Forensic Workflow

Here's how these scripts work together in a typical digital forensics investigation:

```
Raw Forensic Collections (zip files)
    ↓
[1. Ingestor.ps1] - Extract, normalize, organize by hostname
    ↓
Processed Forensic Images (organized by hostname)
    ↓
    ├─→ [2. artifast_ingestor.ps1] - Extract artifacts to JSON
    ├─→ [3. cybertriage_kape_ingestor.ps1] - Create incident and analyze
    ├─→ [4. hayabusa_ingestor.ps1] - Timeline analysis of event logs
    └─→ [5. sru_ingestor.ps1] - Extract SRU databases for analysis
```

## Best Practices

1. **Run in Order**: Start with `Ingestor.ps1` to normalize your data before using specialized tools
2. **Administrator Rights**: Run `cybertriage_kape_ingestor.ps1` as Administrator
3. **Disk Space**: Ensure sufficient disk space for extraction and processing
4. **Backup**: Keep original data intact; work on copies when possible
5. **Logging**: Review console output for any errors or warnings during processing
6. **Path Validation**: Verify all tool paths in scripts match your installation locations

## Configuration

Before running these scripts, update the tool paths if your installations differ:

- **7-Zip**: `C:\Program Files\7-Zip\7z.exe`
- **ArtiFast Suite**: `C:\Program Files\Forensafe\ArtiFast\Suite\v6.5.0\bin\Artifast-Suite.exe`
- **Cyber Triage**: `C:\Program Files\Cyber Triage\bin\cybertriage64.exe`
- **Hayabusa**: Configure via `-HayabusaExePath` parameter

## Requirements

- Windows operating system
- PowerShell 5.1 or later
- Administrator privileges (for certain operations)
- Commercial/trial licenses for:
  - ArtiFast Suite
  - Cyber Triage
- Free tools:
  - 7-Zip
  - Hayabusa

## Support

For issues or questions about specific forensic tools, please refer to their official documentation:
- [ArtiFast](https://forensafe.com/artifast/)
- [Cyber Triage](https://www.cybertriage.com/)
- [Hayabusa](https://github.com/Yamato-Security/hayabusa)
- [KAPE](https://www.kroll.com/kape)

## License

Please ensure compliance with the licenses of all third-party tools used by these scripts.

## Contributing

Contributions are welcome! Please ensure any new scripts follow the existing patterns and include proper documentation.
