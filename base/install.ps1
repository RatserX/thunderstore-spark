# Change the ErrorActionPreference to 'Stop'
$ErrorActionPreference = 'Stop'

# Define global variables
$modpackAuthor = "Pixelomega"
$modpackName = "VolcanoSauce"
$modpackVersion = "1.0.0"

# Ask the user for the modpack folder path
$defaultModpackFolderPath = "${Env:USERPROFILE}\Downloads\REPOtest" #"${Env:ProgramFiles(x86)}\Steam\steamapps\common\REPO"
$modpackFolderPath = Read-Host "Enter the modpack folder path (Default: $defaultModpackFolderPath)"
if ([string]::IsNullOrWhiteSpace($modpackFolderPath)) {
    $modpackFolderPath = $defaultModpackFolderPath
}

# Delete the "BepInEx" folder inside the modpack folder path
$modpackBepInExFolderPath = Join-Path -Path $modpackFolderPath -ChildPath "BepInEx"
if (Test-Path -Path $modpackBepInExFolderPath) {
    Remove-Item -Recurse -Force -Path $modpackBepInExFolderPath
}

# Ensure the modpack folder path exists
if (!(Test-Path -Path $modpackFolderPath)) {
    New-Item -ItemType Directory -Path $modpackFolderPath | Out-Null
}

# Download the modpack
$modpackUri = "https://thunderstore.io/package/download/$modpackAuthor/$modpackName/$modpackVersion/"
$modpackZipFilePath = "$modpackFolderPath\$modpackAuthor-$modpackName.zip"
Invoke-WebRequest -Uri $modpackUri -OutFile $modpackZipFilePath

# Extract the modpack
Expand-Archive -Path $modpackZipFilePath -DestinationPath $modpackFolderPath -Force
Remove-Item -Force -Path $modpackZipFilePath

# Read the manifest.json file
$manifestFilePath = Join-Path -Path $modpackFolderPath -ChildPath "manifest.json"
$manifest = Get-Content -Path $manifestFilePath | ConvertFrom-Json
$dependencies = $manifest.dependencies

# Process each dependency
foreach ($dependency in $dependencies) {
    $dependencyFields = $dependency -split "-"
    $modAuthor = $dependencyFields[0]
    $modName = $dependencyFields[1]
    $modVersion = $dependencyFields[2]

    $modInfo = "$modAuthor-$modName"
    $isBepInEx = $modInfo -eq "BepInEx-BepInExPack"

    # Define the mod extract folder path
    $pluginExtractFolderPath = "$modpackFolderPath\BepInEx\plugins\$modInfo"
    Write-Output "Downloading mod: $modInfo-$modVersion."

    # Ensure the mod extract folder path exists
    if (!(Test-Path -Path $pluginExtractFolderPath)) {
        New-Item -ItemType Directory -Path $pluginExtractFolderPath | Out-Null
    }

    # Download the mod
    $modUri = "https://thunderstore.io/package/download/$modAuthor/$modName/$modVersion/"
    $pluginZipFilePath = "$pluginExtractFolderPath\$modInfo.zip"
    Invoke-WebRequest -Uri $modUri -OutFile $pluginZipFilePath

    # Extract the mod
    Expand-Archive -Path $pluginZipFilePath -DestinationPath $pluginExtractFolderPath -Force
    Remove-Item -Force -Path $pluginZipFilePath

    # Check for "BepInExPack" folder inside the extracted folder
    $pluginBepInExPackFolderPath = Join-Path -Path $pluginExtractFolderPath -ChildPath "BepInExPack"
    if (Test-Path -Path $pluginBepInExPackFolderPath) {
        Get-ChildItem -Path $pluginBepInExPackFolderPath -File -Depth 1 | Move-Item -Destination $modpackFolderPath -Force
        Get-ChildItem -Path $pluginBepInExPackFolderPath -Recurse | Move-Item -Destination $pluginExtractFolderPath -Force
        Remove-Item -Recurse -Force -Path $pluginBepInExPackFolderPath
    }

    # Check for "BepInEx" folder inside the extracted folder
    $pluginBepInExFolderPath = Join-Path -Path $pluginExtractFolderPath -ChildPath "BepInEx"
    if (Test-Path -Path $pluginBepInExFolderPath) {
        Get-ChildItem -Path $pluginBepInExFolderPath -Recurse | Move-Item -Destination $pluginExtractFolderPath -Force
        Remove-Item -Recurse -Force -Path $pluginBepInExFolderPath
    }

    # Check for other folders and move their contents
    Get-ChildItem -Path $pluginExtractFolderPath -Directory | ForEach-Object {
        $bepInExFolder = $_.Name
        $bepInExFolderPath = $_.FullName

        # Skip folders named the same as the mod
        if ($bepInExFolder -eq $modName) {
            return
        }

        # Define the list of special folders
        $specialFolders = @("patchers", "plugins")
        $isSpecialFolder = $specialFolders -contains $bepInExFolder

        # Define the mod folder path
        $modFolderPath = "$modpackFolderPath\BepInEx\$bepInExFolder"
        if ($isSpecialFolder) {
            $modFolderPath = "$modFolderPath\$modInfo"
        }

        Write-Output "Installing mod: $modFolderPath."

        # Ensure the mod folder path exists
        if (!(Test-Path -Path $modFolderPath)) {
            New-Item -ItemType Directory -Path $modFolderPath | Out-Null
        }

        Get-ChildItem -Path $bepInExFolderPath -Depth 1 | ForEach-Object {
            $isContainer = $_.PSIsContainer
            $item = $_.Name
            $itemPath = $_.FullName

            try {
                if ($isSpecialFolder) {
                    Copy-Item -Path $itemPath -Destination $modFolderPath -Recurse -Force
                    Remove-Item -Recurse -Force -Path $itemPath
                } elseif ($isContainer) {
                    Move-Item -Path $itemPath -Destination $modFolderPath -Force
                } else {
                    Move-Item -Path $itemPath -Destination $modFolderPath
                }
            } catch [System.IO.IOException] {
                Write-Output "Unable to move $item to $modFolderPath."
            } catch {
                Write-Output "An error occurred that could not be resolved."
                Write-Output $_
            }
        }

        Remove-Item -Recurse -Force -Path $bepInExFolderPath
    }

    # Delete empty folders
    $pluginItemsCount = Get-ChildItem -Path $pluginExtractFolderPath -Recurse | Measure-Object -Property Length -Sum
    if ($isBepInEx -or $pluginItemsCount -eq 0) {
        Remove-Item -Recurse -Force -Path $pluginExtractFolderPath
    }
}

Write-Output "$modpackAuthor-$modpackName-$modpackVersion has been successfully installed to $modpackFolderPath."
