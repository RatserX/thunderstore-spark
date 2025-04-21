# Define global variables
$gameDirectory = "GAME_DIRECTORY"
$modpackAuthor = "MODPACK_AUTHOR"
$modpackName = "MODPACK_NAME"
$modpackVersion = "MODPACK_VERSION"

# Change preference variables
$ErrorActionPreference = "Stop"

# Ask the user for the game path
$gamePath = ""
if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
    Add-Type -AssemblyName System.Windows.Forms

    $defaultGamePath = "$([Environment]::GetFolderPath("ProgramFilesX86"))\Steam\steamapps\common\$gameDirectory"
    $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
        Description = "Select the game folder"
        SelectedPath = $defaultGamePath
    }

    $null = [System.Windows.Forms.Application]::EnableVisualStyles()
    $folderBrowserOwner = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true }
    if ($folderBrowserDialog.ShowDialog($folderBrowserOwner) -eq [System.Windows.Forms.DialogResult]::OK) {
        $gamePath = $folderBrowserDialog.SelectedPath
    }

    $folderBrowserDialog.Dispose()
    $folderBrowserOwner.Dispose()
} else {
    $defaultGamePath = "$([Environment]::GetFolderPath("LocalApplicationData"))\Steam\steamapps\common\$gameDirectory"
    $gamePath = Read-Host "Enter the game path (Default: $defaultGamePath)"
    if ([string]::IsNullOrWhiteSpace($gamePath)) {
        $gamePath = $defaultGamePath
    }
}

# Ask the user to confirm the game path
$gamePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($gamePath)
$gamePathConfirmation = Read-Host "Game path: $gamePath. Is this correct? (y/n)"
if ($gamePathConfirmation -notmatch "^(y|Y)$") {
    Write-Output "Confirmation failed. Exiting..."
    exit
}

# Ensure the game directory exists
if (!(Test-Path -Path $gamePath)) {
    New-Item -ItemType Directory -Path $gamePath | Out-Null
}

# Delete the "BepInEx" directory inside the game path
$gameBepInExPath = Join-Path -Path $gamePath -ChildPath "BepInEx"
if (Test-Path -Path $gameBepInExPath) {
    Remove-Item -Recurse -Force -Path $gameBepInExPath
}

# Download the modpack
$modpackUri = "https://thunderstore.io/package/download/$modpackAuthor/$modpackName/$modpackVersion/"
$modpackZipPath = "$gamePath\$modpackAuthor-$modpackName.zip"
Invoke-WebRequest -Uri $modpackUri -OutFile $modpackZipPath

# Extract the modpack
Expand-Archive -Path $modpackZipPath -DestinationPath $gamePath -Force
Remove-Item -Force -Path $modpackZipPath

# Read the manifest.json file
$manifestJsonPath = Join-Path -Path $gamePath -ChildPath "manifest.json"
$manifestJson = Get-Content -Path $manifestJsonPath | ConvertFrom-Json
$dependencies = $manifestJson.dependencies

# Check the mod loader
$isBepInExPack = $false
$isMelonLoader = $false
$modLoaderPath = "$gamePath\Spark"
$dependencyPath = "$modLoaderPath\mods"
foreach ($dependency in $dependencies) {
    $modLoaderFields = $dependency -split "-"
    $modLoaderAuthor = $modLoaderFields[0]
    $modLoaderName = $modLoaderFields[1]
    $modLoaderVersion = $modLoaderFields[2]

    if ($modLoaderAuthor -eq "BepInEx" -and $modLoaderName -eq "BepInExPack") {
        $isBepInExPack = $true
        $modLoaderPath = "$gamePath\BepInEx"
        $dependencyPath = "$modLoaderPath\plugins"
    } elseif ($modLoaderAuthor -eq "LavaGang" -and $modLoaderName -eq "MelonLoader") {
        $isMelonLoader = $true
        $modLoaderPath = "$gamePath\MelonLoader"
        $dependencyPath = "$gamePath\Mods"
    }

    if ($isBepInExPack -or $isMelonLoader) {
        Write-Output "Mod loader found: $modLoaderAuthor-$modLoaderName-$modLoaderVersion."
        break
    }
}

# Ensure the mod loader directory exists
if (!(Test-Path -Path $modLoaderPath)) {
    New-Item -ItemType Directory -Path $modLoaderPath | Out-Null
}

# Ensure the dependency directory exists
if (!(Test-Path -Path $dependencyPath)) {
    New-Item -ItemType Directory -Path $dependencyPath | Out-Null
}

# Process each dependency
foreach ($dependency in $dependencies) {
    $modFields = $dependency -split "-"
    $modAuthor = $modFields[0]
    $modName = $modFields[1]
    $modVersion = $modFields[2]
    $modInfo = "$modAuthor-$modName"

    # Define the dependency extract directory
    $dependencyExtractPath = "$dependencyPath\$modInfo"
    Write-Output "Downloading mod: $modInfo-$modVersion."

    # Ensure the dependency extract directory exists
    if (!(Test-Path -Path $dependencyExtractPath)) {
        New-Item -ItemType Directory -Path $dependencyExtractPath | Out-Null
    }

    # Download the mod
    $modUri = "https://thunderstore.io/package/download/$modAuthor/$modName/$modVersion/"
    $dependencyZipPath = "$dependencyExtractPath.zip"
    Invoke-WebRequest -Uri $modUri -OutFile $dependencyZipPath

    # Extract the mod
    Expand-Archive -Path $dependencyZipPath -DestinationPath $dependencyExtractPath -Force
    Remove-Item -Force -Path $dependencyZipPath

    # Check for "BepInExPack" directory inside the extracted dependency
    $bepInExPackPath = Join-Path -Path $dependencyExtractPath -ChildPath "BepInExPack"
    if (Test-Path -Path $bepInExPackPath) {
        Get-ChildItem -Path $bepInExPackPath -File -Depth 1 | Move-Item -Destination $gamePath -Force
        Get-ChildItem -Path $bepInExPackPath -Recurse | Move-Item -Destination $dependencyExtractPath -Force
        Remove-Item -Recurse -Force -Path $bepInExPackPath
    }

    # Check for "BepInEx" directory inside the extracted dependency
    $bepInExPath = Join-Path -Path $dependencyExtractPath -ChildPath "BepInEx"
    if (Test-Path -Path $bepInExPath) {
        Get-ChildItem -Path $bepInExPath -Recurse | Move-Item -Destination $dependencyExtractPath -Force
        Remove-Item -Recurse -Force -Path $bepInExPath
    }

    # Check for other directories and move their contents
    Get-ChildItem -Path $dependencyExtractPath -Directory | ForEach-Object {
        $bepInExDirectory = $_.Name
        $bepInExPath = $_.FullName

        # Skip directories named the same as the mod
        if ($bepInExDirectory -eq $modName) {
            return
        }

        # Define the list of special directories
        $specialDirectories = @("patchers", "plugins")
        $isSpecialDirectory = $specialDirectories -contains $bepInExDirectory

        # Define the mod directory
        $modPath = "$modLoaderPath\$bepInExDirectory"
        if ($isSpecialDirectory) {
            $modPath = "$modPath\$modInfo"
        }

        Write-Output "Installing mod: $modPath."

        # Ensure the mod directory exists
        if (!(Test-Path -Path $modPath)) {
            New-Item -ItemType Directory -Path $modPath | Out-Null
        }

        Get-ChildItem -Path $bepInExPath -Depth 1 | ForEach-Object {
            $isContainer = $_.PSIsContainer
            $item = $_.Name
            $itemPath = $_.FullName

            try {
                if ($isSpecialDirectory) {
                    Copy-Item -Path $itemPath -Destination $modPath -Recurse -Force
                    Remove-Item -Recurse -Force -Path $itemPath
                } elseif ($isContainer) {
                    Move-Item -Path $itemPath -Destination $modPath -Force
                } else {
                    Move-Item -Path $itemPath -Destination $modPath
                }
            } catch [System.IO.IOException] {
                Write-Output "Unable to move $item to $modPath."
            } catch {
                Write-Output "An error occurred that could not be resolved."
                Write-Output $_
            }
        }

        Remove-Item -Recurse -Force -Path $bepInExPath
    }

    # Cleanup the install directories
    $modLoaderDirectories = @("BepInEx-BepInExPack", "LavaGang-MelonLoader")
    $dependencyItemsCount = Get-ChildItem -Path $dependencyExtractPath -Recurse | Measure-Object -Property Length -Sum
    if ($modLoaderDirectories -contains $modInfo -or $dependencyItemsCount -eq 0) {
        Remove-Item -Recurse -Force -Path $dependencyExtractPath
    }
}

Write-Output "$modpackAuthor-$modpackName-$modpackVersion has been successfully installed to $gamePath."
