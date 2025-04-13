# Change the ErrorActionPreference to 'Stop'
$ErrorActionPreference = 'Stop'

# Define global variables
$modpackAuthor = "MODPACK_AUTHOR"
$modpackName = "MODPACK_NAME"
$modpackVersion = "MODPACK_VERSION"

# Ask the user for the modpack folder path
$defaultModpackPath = "${Env:ProgramFiles(x86)}\Steam\steamapps\common"
$modpackPath = Read-Host "Enter the modpack folder path (Default: $defaultModpackPath)"
if ([string]::IsNullOrWhiteSpace($modpackPath)) {
    $modpackPath = $defaultModpackPath
}

# Ask the user to confirm the modpack folder path
$modpackPathConfirmation = Read-Host "Modpack folder path: $modpackPath. Is this correct? (y/n)"
if ($modpackPathConfirmation -notmatch '^(y|Y)$') {
    Write-Output "Exiting..."
    exit
}

# Delete the "BepInEx" folder inside the modpack folder path
$modpackBepInExPath = Join-Path -Path $modpackPath -ChildPath "BepInEx"
if (Test-Path -Path $modpackBepInExPath) {
    Remove-Item -Recurse -Force -Path $modpackBepInExPath
}

# Ensure the modpack folder path exists
if (!(Test-Path -Path $modpackPath)) {
    New-Item -ItemType Directory -Path $modpackPath | Out-Null
}

# Download the modpack
$modpackUri = "https://thunderstore.io/package/download/$modpackAuthor/$modpackName/$modpackVersion/"
$modpackZipPath = "$modpackPath\$modpackAuthor-$modpackName.zip"
Invoke-WebRequest -Uri $modpackUri -OutFile $modpackZipPath

# Extract the modpack
Expand-Archive -Path $modpackZipPath -DestinationPath $modpackPath -Force
Remove-Item -Force -Path $modpackZipPath

# Read the manifest.json file
$manifestJsonPath = Join-Path -Path $modpackPath -ChildPath "manifest.json"
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

    # Define the mod extract folder path
    $pluginExtractPath = "$modpackPath\BepInEx\plugins\$modInfo"
    Write-Output "Downloading mod: $modInfo-$modVersion."

    # Ensure the mod extract folder path exists
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

    # Check for "BepInExPack" folder inside the extracted folder
    $pluginBepInExPackPath = Join-Path -Path $pluginExtractPath -ChildPath "BepInExPack"
    if (Test-Path -Path $pluginBepInExPackPath) {
        Get-ChildItem -Path $pluginBepInExPackPath -File -Depth 1 | Move-Item -Destination $modpackPath -Force
        Get-ChildItem -Path $pluginBepInExPackPath -Recurse | Move-Item -Destination $pluginExtractPath -Force
        Remove-Item -Recurse -Force -Path $pluginBepInExPackPath
    }

    # Check for "BepInEx" folder inside the extracted folder
    $pluginBepInExPath = Join-Path -Path $pluginExtractPath -ChildPath "BepInEx"
    if (Test-Path -Path $pluginBepInExPath) {
        Get-ChildItem -Path $pluginBepInExPath -Recurse | Move-Item -Destination $pluginExtractPath -Force
        Remove-Item -Recurse -Force -Path $pluginBepInExPath
    }

    # Check for other folders and move their contents
    Get-ChildItem -Path $pluginExtractPath -Directory | ForEach-Object {
        $bepInExDirectory = $_.Name
        $bepInExPath = $_.FullName

        # Skip folders named the same as the mod
        if ($bepInExDirectory -eq $modName) {
            return
        }

        # Define the list of special folders
        $specialDirectories = @("patchers", "plugins")
        $isSpecialDirectory = $specialDirectories -contains $bepInExDirectory

        # Define the mod folder path
        $modPath = "$modpackPath\BepInEx\$bepInExDirectory"
        if ($isSpecialDirectory) {
            $modPath = "$modPath\$modInfo"
        }

        Write-Output "Installing mod: $modPath."

        # Ensure the mod folder path exists
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

    # Delete empty folders
    $pluginItemsCount = Get-ChildItem -Path $pluginExtractPath -Recurse | Measure-Object -Property Length -Sum
    if ($isBepInEx -or $pluginItemsCount -eq 0) {
        Remove-Item -Recurse -Force -Path $pluginExtractPath
    }
}

Write-Output "$modpackAuthor-$modpackName-$modpackVersion has been successfully installed to $modpackPath."
