# Import-FolderPermissions.ps1
# This script imports folder permissions from a CSV file and applies them to specified folders
# Usage: .\Import-FolderPermissions.ps1 -CsvFile "C:\Path\To\Permissions.csv" -TargetBasePath "C:\Target\Path"

param (
    [Parameter(Mandatory=$true)]
    [string]$CsvFile,
    
    [Parameter(Mandatory=$true)]
    [string]$TargetBasePath,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseLocalPrincipals,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSIDs,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipUsers,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipInheritedPermissions,
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateMissingGroups
)

# Set default values for switch parameters
if (-not $PSBoundParameters.ContainsKey('UseLocalPrincipals')) {
    $UseLocalPrincipals = $true
}

if (-not $PSBoundParameters.ContainsKey('SkipSIDs')) {
    $SkipSIDs = $true
}

if (-not $PSBoundParameters.ContainsKey('SkipUsers')) {
    $SkipUsers = $true
}

if (-not $PSBoundParameters.ContainsKey('SkipInheritedPermissions')) {
    $SkipInheritedPermissions = $true
}

if (-not $PSBoundParameters.ContainsKey('CreateMissingGroups')) {
    $CreateMissingGroups = $true
}

# Check if the CSV file exists
if (-not (Test-Path -Path $CsvFile)) {
    Write-Error "The specified CSV file does not exist: $CsvFile"
    exit 1
}

# Check if the target base path exists
if (-not (Test-Path -Path $TargetBasePath)) {
    Write-Error "The specified target base path does not exist: $TargetBasePath"
    exit 1
}

# Function to check if a string is a SID
function Test-IsSID {
    param (
        [string]$IdentityReference
    )
    
    # SID pattern: S-1-5-... (Security Identifier pattern)
    return $IdentityReference -match '^S-\d+-\d+(-\d+)*$'
}

# Function to check if an identity reference is a user account (not a group)
function Test-IsUserAccount {
    param (
        [string]$IdentityReference
    )
    
    # Skip if it's a SID
    if (Test-IsSID -IdentityReference $IdentityReference) {
        return $false
    }
    
    # Extract account name
    $accountName = Get-AccountNameFromIdentityReference -IdentityReference $IdentityReference
    
    # Well-known groups that should not be skipped
    $wellKnownGroups = @(
        'Everyone', 'SYSTEM', 'Administrators', 'Users', 'Authenticated Users',
        'Domain Users', 'Domain Admins', 'Enterprise Admins', 'Schema Admins',
        'Account Operators', 'Backup Operators', 'Print Operators', 'Server Operators',
        'Network Configuration Operators', 'Remote Desktop Users', 'Distributed COM Users',
        'Performance Log Users', 'Performance Monitor Users', 'Power Users',
        'Certificate Service DCOM Access', 'Cryptographic Operators', 'Event Log Readers',
        'IIS_IUSRS', 'Remote Management Users'
    )
    
    # If it's a well-known group, it's not a user account
    if ($wellKnownGroups -contains $accountName) {
        return $false
    }
    
    # Try to determine if it's a user or group based on naming convention
    # This is a heuristic approach and may not be 100% accurate
    
    # Check for common domain group patterns
    if ($IdentityReference -match '\\(Domain |Global |Universal |Security |Distribution )') {
        return $false  # Likely a domain group with a descriptor
    }
    
    # Check for common group prefixes and patterns (expanded list)
    if ($accountName -match '^(GRP_|G_|DG_|SG_|Role_|Group_|Team_|Dept_|Department_|Admin_|Admins_|APP_|APP-|SVC_|SVC-|Service_|Service-|DL_|DL-|Grp|Sec_|Sec-)') {
        return $false  # Likely a group
    }
    
    # Check for common group patterns with keywords in the name (expanded list)
    if ($accountName -match '(Users|Groups|Admins|Roles|Teams|Access|Permissions|Staff|Members|Accounts|Operators|Managers|Readers|Writers|Owners|Contributors|Developers|Support|Helpdesk|IT|HR|Finance|Sales|Marketing|Engineering|Operations|Security|Audit|Compliance|Project|Program|Service|Application|App|Resource|System)') {
        return $false  # Likely a group
    }
    
    # Check for patterns with multiple underscores or hyphens (common in group names)
    if ((($accountName.Split('_').Count -gt 1) -or ($accountName.Split('-').Count -gt 1)) -and ($accountName -notmatch '\.')) {
        return $false  # Likely a group with multiple segments
    }
    
    # Check for all caps names (often groups)
    if ($accountName -cmatch '^[A-Z0-9_-]+$' -and $accountName.Length -gt 3) {
        return $false  # Likely a group with all caps
    }
    
    # If it contains a dot, it's likely a user (firstname.lastname pattern)
    # But exclude common group patterns that might contain dots
    if ($accountName -match '\.' -and $accountName -notmatch '(service|app|grp|group|team|dept|role)\.') {
        return $true
    }
    
    # If the name is very short (1-2 chars), it's more likely to be a group code than a user
    if ($accountName.Length -le 2) {
        return $false
    }
    
    # Default to assuming it's a group if we're not sure
    # This is a change from the previous approach - better to create a group than skip
    return $false
}

# Function to extract account name from identity reference
function Get-AccountNameFromIdentityReference {
    param (
        [string]$IdentityReference
    )
    
    # Check if the identity reference is a SID
    if (Test-IsSID -IdentityReference $IdentityReference) {
        return $IdentityReference
    }
    
    # Check if the identity reference contains a domain or computer name
    if ($IdentityReference -match '\\') {
        # Extract just the account name (after the backslash)
        return $IdentityReference.Split('\\')[-1]
    }
    
    # If no domain/computer prefix, return as is
    return $IdentityReference
}

# Function to extract computer name and account name from an identity reference
function Split-IdentityReference {
    param (
        [string]$IdentityReference
    )
    
    if ($IdentityReference -match '\\') {
        $parts = $IdentityReference.Split('\')
        return @{
            ComputerName = $parts[0]
            AccountName = $parts[1]
        }
    } else {
        return @{
            ComputerName = $null
            AccountName = $IdentityReference
        }
    }
}

# Function to check if a local group exists
function Test-LocalGroupExists {
    param (
        [string]$GroupName
    )
    
    # Remove any computer/domain prefix if present
    if ($GroupName -match '\\') {
        $GroupName = ($GroupName -split '\\')[1]
    }
    
    try {
        $group = Get-LocalGroup -Name $GroupName -ErrorAction SilentlyContinue
        return ($null -ne $group)
    }
    catch {
        return $false
    }
}

# Function to create a local group if it doesn't exist
function New-LocalGroupIfNotExists {
    param (
        [string]$GroupName,
        [bool]$WhatIf
    )
    
    # Remove any computer/domain prefix if present
    $originalGroupName = $GroupName
    if ($GroupName -match '\\') {
        $GroupName = ($GroupName -split '\\')[1]
    }
    
    if (-not (Test-LocalGroupExists -GroupName $GroupName)) {
        if ($WhatIf) {
            Write-Host "WhatIf: Would create local group: $GroupName" -ForegroundColor Cyan
            return $true
        } else {
            try {
                New-LocalGroup -Name $GroupName -ErrorAction Stop | Out-Null
                Write-Host "Created local group: $GroupName (from $originalGroupName)" -ForegroundColor Green
                return $true
            }
            catch {
                Write-Warning "Failed to create local group '$GroupName': $_"
                return $false
            }
        }
    }
    
    return $true
}

# Function to check if a permission already exists as inherited
function Test-PermissionExistsAsInherited {
    param (
        [string]$FolderPath,
        [string]$IdentityReference,
        [System.Security.AccessControl.AccessControlType]$AccessControlType,
        [System.Security.AccessControl.FileSystemRights]$FileSystemRights,
        [System.Security.AccessControl.InheritanceFlags]$InheritanceFlags,
        [System.Security.AccessControl.PropagationFlags]$PropagationFlags
    )
    
    try {
        # Get the current ACL
        $acl = Get-Acl -Path $FolderPath
        
        # Get the account name from the identity reference
        $accountName = Get-AccountNameFromIdentityReference -IdentityReference $IdentityReference
        
        # Check each access rule
        foreach ($rule in $acl.Access) {
            # Skip if not inherited
            if (-not $rule.IsInherited) {
                continue
            }
            
            # Get the account name from the rule's identity reference
            $ruleAccountName = Get-AccountNameFromIdentityReference -IdentityReference $rule.IdentityReference.Value
            
            # Check if the identity, rights, and control type match
            if (($ruleAccountName -eq $accountName) -and 
                ($rule.FileSystemRights -eq $FileSystemRights) -and 
                ($rule.AccessControlType -eq $AccessControlType) -and 
                ($rule.InheritanceFlags -eq $InheritanceFlags) -and 
                ($rule.PropagationFlags -eq $PropagationFlags)) {
                return $true
            }
        }
        
        return $false
    }
    catch {
        Write-Warning "Error checking existing permissions: $_"
        return $false
    }
}

# Function to apply permissions to a folder
function Set-FolderPermission {
    param (
        [string]$OriginalPath,
        [string]$TargetBasePath,
        [string]$IdentityReference,
        [string]$AccessControlType,
        [string]$FileSystemRights,
        [bool]$IsInherited,
        [string]$InheritanceFlags,
        [string]$PropagationFlags,
        [bool]$WhatIf,
        [bool]$UseLocalPrincipals,
        [bool]$SkipSIDs,
        [bool]$SkipUsers,
        [bool]$SkipInheritedPermissions
    )
    
    # Validate input paths
    if ([string]::IsNullOrWhiteSpace($OriginalPath)) {
        Write-Warning "Original path is empty or null"
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($TargetBasePath)) {
        Write-Warning "Target base path is empty or null"
        return
    }
    
    # Determine the relative path from the original base path
    $originalBasePath = Split-Path -Path $OriginalPath -Parent
    $folderName = Split-Path -Path $OriginalPath -Leaf
    
    # If it's a root folder (no parent), use the folder name directly
    if ([string]::IsNullOrEmpty($folderName)) {
        $folderName = $originalBasePath
    }
    
    # Validate folder name
    if ([string]::IsNullOrWhiteSpace($folderName)) {
        Write-Warning "Could not determine folder name from path: $OriginalPath"
        return
    }
    
    # Construct the new target path
    $targetPath = Join-Path -Path $TargetBasePath -ChildPath $folderName
    
    # Check if the target folder exists
    if (-not (Test-Path -Path $targetPath)) {
        Write-Warning "Target folder does not exist: $targetPath"
        return
    }
    
    # Check if the identity reference is a SID and skip if requested
    if ($SkipSIDs -and (Test-IsSID -IdentityReference $IdentityReference)) {
        Write-Host "Skipping SID: $IdentityReference for folder: $targetPath" -ForegroundColor Yellow
        return
    }
    
    # Check if the identity reference is a user account and skip if requested
    if ($SkipUsers -and (Test-IsUserAccount -IdentityReference $IdentityReference)) {
        Write-Host "Skipping user account: $IdentityReference for folder: $targetPath" -ForegroundColor Yellow
        return
    }
    
    try {
        # Create a new FileSystemAccessRule
        $accessControlType = [System.Security.AccessControl.AccessControlType]::$AccessControlType
        $fileSystemRights = [System.Security.AccessControl.FileSystemRights]$FileSystemRights
        $inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]$InheritanceFlags
        $propagationFlags = [System.Security.AccessControl.PropagationFlags]$PropagationFlags
        
        # Determine the identity reference to use
        $identityToUse = $IdentityReference
        
        # Parse the identity reference to get computer name and account name
        $identityParts = Split-IdentityReference -IdentityReference $IdentityReference
        $accountName = $identityParts.AccountName
        $specifiedComputer = $identityParts.ComputerName
        
        # For well-known SIDs like 'Everyone', 'SYSTEM', etc., use them as is
        $wellKnownAccounts = @('Everyone', 'SYSTEM', 'Administrators', 'Users', 'Authenticated Users')
        
        if ($wellKnownAccounts -contains $accountName) {
            # Use the account name directly for well-known accounts
            $identityToUse = $accountName
        } 
        # If UseLocalPrincipals is true and it's not a well-known account
        elseif ($UseLocalPrincipals) {
            # Use the local computer name with the account
            $computerName = $env:COMPUTERNAME
            $identityToUse = "$computerName\$accountName"
        }
        # If not using local principals, respect the specified computer name in the CSV
        # This allows manually edited CSV files to work correctly
        else {
            # Keep the identity as specified in the CSV
            $identityToUse = $IdentityReference
        }
        
        # Check if this permission already exists as inherited and if we should skip it
        if ($SkipInheritedPermissions) {
            $permissionExistsAsInherited = Test-PermissionExistsAsInherited -FolderPath $targetPath `
                -IdentityReference $identityToUse `
                -AccessControlType $accessControlType `
                -FileSystemRights $fileSystemRights `
                -InheritanceFlags $inheritanceFlags `
                -PropagationFlags $propagationFlags
                
            if ($permissionExistsAsInherited) {
                Write-Host "Skipping inherited permission for $identityToUse on folder: $targetPath (already exists via inheritance)" -ForegroundColor Cyan
                return
            }
        }
        
        # Try to create the access rule with the appropriate identity
        try {
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $identityToUse,
                $fileSystemRights,
                $inheritanceFlags,
                $propagationFlags,
                $accessControlType
            )
        }
        catch [System.Security.Principal.IdentityNotMappedException] {
            # If CreateMissingGroups is enabled, try to create the group
            if ($CreateMissingGroups) {
                # Get the identity parts
                $identityParts = Split-IdentityReference -IdentityReference $identityToUse
                $groupAccountName = $identityParts.AccountName
                
                # Check if this is likely a group
                $isLikelyGroup = -not (Test-IsUserAccount -IdentityReference $groupAccountName)
                
                if ($isLikelyGroup) {
                    Write-Host "Attempting to create missing group: $identityToUse" -ForegroundColor Cyan
                    
                    # Try to create the group (the function will handle removing the prefix if needed)
                    $groupCreated = New-LocalGroupIfNotExists -GroupName $identityToUse -WhatIf $WhatIf
                    
                    if ($groupCreated -and -not $WhatIf) {
                        # Try again with the newly created group
                        try {
                            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                                $identityToUse,
                                $fileSystemRights,
                                $inheritanceFlags,
                                $propagationFlags,
                                $accessControlType
                            )
                        }
                        catch {
                            $exception = $_.Exception
                            Write-Warning ("Error creating access rule for newly created group {0}: {1}" -f $identityToUse, $exception.Message)
                            return
                        }
                    } else {
                        # If in WhatIf mode or group creation failed
                        if ($WhatIf) {
                            Write-Host "WhatIf: Would create access rule for new group $identityToUse" -ForegroundColor Cyan
                        } else {
                            Write-Host "Skipping unmappable identity after failed group creation: $identityToUse for folder: $targetPath" -ForegroundColor Yellow
                        }
                        return
                    }
                } else {
                    Write-Host "Skipping unmappable identity (not likely a group): $identityToUse for folder: $targetPath" -ForegroundColor Yellow
                    return
                }
            } else {
                Write-Host "Skipping unmappable identity (group creation disabled): $identityToUse for folder: $targetPath" -ForegroundColor Yellow
                return
            }
        }
        catch {
            Write-Warning "Error creating access rule for $identityToUse (original: $IdentityReference): $_"
            return
        }
        
        if ($WhatIf) {
            if ($UseLocalPrincipals -and ($identityToUse -ne $IdentityReference)) {
                Write-Host "WhatIf: Would apply permission to $targetPath for $identityToUse (original: $IdentityReference)"
            } else {
                Write-Host "WhatIf: Would apply permission to $targetPath for $identityToUse"
            }
        } else {
            try {
                # Get the current ACL
                $acl = Get-Acl -Path $targetPath
                
                # Add the new rule
                $acl.AddAccessRule($accessRule)
                
                # Apply the ACL to the folder
                Set-Acl -Path $targetPath -AclObject $acl
                
                if ($UseLocalPrincipals -and ($identityToUse -ne $IdentityReference)) {
                    Write-Host "Applied permission to $targetPath for $identityToUse (original: $IdentityReference)"
                } else {
                    Write-Host "Applied permission to $targetPath for $identityToUse"
                }
            }
            catch [System.Security.Principal.IdentityNotMappedException] {
                # This should rarely happen since we've already handled identity mapping above
                Write-Host "Cannot apply permission: Identity '$identityToUse' could not be mapped on this system for folder: $targetPath" -ForegroundColor Yellow
            }
            catch {
                $errorMessage = $_.Exception.Message
                Write-Error "Error applying permission to $targetPath : $errorMessage"
            }
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Error applying permission to $targetPath : $errorMessage"
    }
}

try {
    # Import the CSV file with better error handling
    try {
        $permissions = Import-Csv -Path $CsvFile -ErrorAction Stop
        
        if ($null -eq $permissions -or $permissions.Count -eq 0) {
            Write-Error "The CSV file is empty or contains no valid permission entries."
            exit 1
        }
        
        # Validate CSV structure
        $requiredColumns = @('FolderPath', 'IdentityReference', 'AccessControlType', 'FileSystemRights', 'InheritanceFlags', 'PropagationFlags', 'IsInherited')
        $firstRow = $permissions[0]
        $missingColumns = $requiredColumns | Where-Object { -not $firstRow.PSObject.Properties.Name.Contains($_) }
        
        if ($missingColumns.Count -gt 0) {
            Write-Error "CSV file is missing required columns: $($missingColumns -join ', ')"
            exit 1
        }
        
        Write-Host "Imported $($permissions.Count) permission entries from $CsvFile"
    }
    catch {
        Write-Error "Failed to import CSV file: $($_.Exception.Message)"
        exit 1
    }
    
    # Process each permission entry
    foreach ($permission in $permissions) {
        # Skip entries with empty folder paths
        if ([string]::IsNullOrWhiteSpace($permission.FolderPath)) {
            Write-Warning "Skipping entry with empty folder path"
            continue
        }
        
        Write-Host "Processing permission for folder: $($permission.FolderPath)"
        
        Set-FolderPermission `
            -OriginalPath $permission.FolderPath `
            -TargetBasePath $TargetBasePath `
            -IdentityReference $permission.IdentityReference `
            -AccessControlType $permission.AccessControlType `
            -FileSystemRights $permission.FileSystemRights `
            -IsInherited ([System.Convert]::ToBoolean($permission.IsInherited)) `
            -InheritanceFlags $permission.InheritanceFlags `
            -PropagationFlags $permission.PropagationFlags `
            -WhatIf $WhatIf `
            -UseLocalPrincipals $UseLocalPrincipals `
            -SkipSIDs $SkipSIDs `
            -SkipUsers $SkipUsers `
            -SkipInheritedPermissions $SkipInheritedPermissions
    }
    
    Write-Host "Permission import completed."
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
