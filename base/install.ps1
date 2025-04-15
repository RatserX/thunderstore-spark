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

# Process each dependency
foreach ($dependency in $dependencies) {
    $modFields = $dependency -split "-"
    $modAuthor = $modFields[0]
    $modName = $modFields[1]
    $modVersion = $modFields[2]

    $modInfo = "$modAuthor-$modName"
    $isBepInEx = $modInfo -eq "BepInEx-BepInExPack"

    # Define the plugin extract directory
    $pluginExtractPath = "$gamePath\BepInEx\plugins\$modInfo"
    Write-Output "Downloading mod: $modInfo-$modVersion."

    # Ensure the plugin extract directory exists
    if (!(Test-Path -Path $pluginExtractPath)) {
        New-Item -ItemType Directory -Path $pluginExtractPath | Out-Null
    }

    # Download the mod
    $modUri = "https://thunderstore.io/package/download/$modAuthor/$modName/$modVersion/"
    $pluginZipPath = "$pluginExtractPath\$modInfo.zip"
    Invoke-WebRequest -Uri $modUri -OutFile $pluginZipPath

    # Extract the mod
    Expand-Archive -Path $pluginZipPath -DestinationPath $pluginExtractPath -Force
    Remove-Item -Force -Path $pluginZipPath

    # Check for "BepInExPack" directory inside the extracted plugin
    $pluginBepInExPackPath = Join-Path -Path $pluginExtractPath -ChildPath "BepInExPack"
    if (Test-Path -Path $pluginBepInExPackPath) {
        Get-ChildItem -Path $pluginBepInExPackPath -File -Depth 1 | Move-Item -Destination $gamePath -Force
        Get-ChildItem -Path $pluginBepInExPackPath -Recurse | Move-Item -Destination $pluginExtractPath -Force
        Remove-Item -Recurse -Force -Path $pluginBepInExPackPath
    }

    # Check for "BepInEx" directory inside the extracted plugin
    $pluginBepInExPath = Join-Path -Path $pluginExtractPath -ChildPath "BepInEx"
    if (Test-Path -Path $pluginBepInExPath) {
        Get-ChildItem -Path $pluginBepInExPath -Recurse | Move-Item -Destination $pluginExtractPath -Force
        Remove-Item -Recurse -Force -Path $pluginBepInExPath
    }

    # Check for other directories and move their contents
    Get-ChildItem -Path $pluginExtractPath -Directory | ForEach-Object {
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
        $modPath = "$gamePath\BepInEx\$bepInExDirectory"
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

    # Delete empty directory
    $pluginItemsCount = Get-ChildItem -Path $pluginExtractPath -Recurse | Measure-Object -Property Length -Sum
    if ($isBepInEx -or $pluginItemsCount -eq 0) {
        Remove-Item -Recurse -Force -Path $pluginExtractPath
    }
}

Write-Output "$modpackAuthor-$modpackName-$modpackVersion has been successfully installed to $gamePath."
