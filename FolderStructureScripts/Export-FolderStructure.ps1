<#
.SYNOPSIS
    Exports folder structure to CSV with depth control
.DESCRIPTION
    Recursively scans a directory and exports its structure to CSV with specified depth
.PARAMETER Path
    Root directory path (e.g. 'E:')
.PARAMETER OutputFile
    Path to output CSV file
.PARAMETER Depth
    Maximum folder depth to scan (1=root only, 2=root+subfolders, etc.)
.EXAMPLE
    .\Export-FolderStructure.ps1 -Path 'E:' -OutputFile 'structure.csv' -Depth 3
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputFile,
    
    [Parameter(Mandatory=$false)]
    [int]$Depth = 0
)

$results = [System.Collections.ArrayList]@()

function Get-FolderStructure {
    param(
        [string]$currentPath,
        [int]$currentDepth
    )
    
    if ($Depth -gt 0 -and $currentDepth -gt $Depth) {
        return
    }
    
    Write-Host "Scanning: $currentPath (Depth $currentDepth)"
    $folders = Get-ChildItem -Path $currentPath -Directory -ErrorAction SilentlyContinue
    
    if (-not $folders) {
        Write-Host "No subfolders found in $currentPath"
        return
    }
    
    $count = 0
    foreach ($folder in $folders) {
        $count++
        Write-Progress -Activity "Exporting Folder Structure" -Status "Processing $currentPath" -CurrentOperation $folder.Name -PercentComplete (($count/$folders.Count)*100)
        $result = [PSCustomObject]@{
            Layer = $currentDepth
            Path = $folder.FullName
            Name = $folder.Name
            Parent = $folder.Parent.FullName
        }
        
        $null = $results.Add($result)
        
        Get-FolderStructure -currentPath $folder.FullName -currentDepth ($currentDepth + 1)
    }
}

Write-Host "Starting folder structure export from $Path"
Get-FolderStructure -currentPath $Path -currentDepth 1
Write-Progress -Activity "Exporting Folder Structure" -Completed
$results | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Host "Folder structure exported to $OutputFile"
