# Define global variables
$gameDirectory = "GAME_DIRECTORY"
$modpackAuthor = "MODPACK_AUTHOR"
$modpackName = "MODPACK_NAME"
$modpackVersion = "MODPACK_VERSION"

# Change preference variables
$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

function Install-Base {
    param (
        [string]$GameDirectory,
        [string]$ModpackAuthor,
        [string]$ModpackName,
        [string]$ModpackVersion
    )

    # Prompt the user to select or enter the game path
    $initialPath = Find-GamePath -GameDirectory $GameDirectory
    $gamePath = Get-GamePath -InitialPath $initialPath

    # Confirm the selected game path with the user
    $isValidGamePath = Confirm-GamePath -GamePath $gamePath
    if ($isValidGamePath -eq $false) {
        Write-Information "Confirmation failed. Exiting..."
        exit
    }

    # Define the modpack info
    $modpackInfo = "$ModpackAuthor-$ModpackName-$ModpackVersion"
    Write-Information "Installing modpack: $modpackInfo."

    # Download the modpack archive
    $modpackUri = "https://thunderstore.io/package/download/$ModpackAuthor/$ModpackName/$ModpackVersion/"
    $modpackZipPath = "$gamePath\$modpackInfo.zip"
    Invoke-WebRequest -Uri $modpackUri -OutFile $modpackZipPath
    Expand-Archive -Path $modpackZipPath -DestinationPath $gamePath -Force

    # Check for the manifest.json file
    $manifestJsonPath = Join-Path -Path $gamePath -ChildPath "manifest.json"
    if (!(Test-Path -Path $manifestJsonPath)) {
        Write-Information "Manifest not found. Exiting..."
        exit
    }

    # Parse manifest.json
    $manifestJson = Get-Content -Path $manifestJsonPath | ConvertFrom-Json
    $dependencies = $manifestJson.dependencies

    # Determine the mod loader type and relevant paths
    $modLoaderType, $modLoaderPath, $modContainerPath, $modLoaderKey, $modLoaderVersion = Find-ModLoader -GamePath $gamePath -Dependencies $dependencies
    $modLoaderInfo = "$modLoaderKey-$modLoaderVersion"

    # Ensure mod loader directory exist
    if (!(Test-Path -Path $modLoaderPath)) {
        New-Item -ItemType Directory -Path $modLoaderPath | Out-Null
    }

    # Ensure mod container directory exist
    if (!(Test-Path -Path $modContainerPath)) {
        New-Item -ItemType Directory -Path $modContainerPath | Out-Null
    }

    # Clean up the game directory
    Clear-GamePath -GamePath $gamePath -ModLoaderKey $modLoaderKey
    Expand-Archive -Path $modpackZipPath -DestinationPath $gamePath -Force
    Remove-Item -Force -Path $modpackZipPath
    Write-Information "Installing mod loader: $modLoaderInfo."

    # Download and install each mod
    foreach ($dependency in $dependencies) {
        $modFields = $dependency -split "-"
        $modAuthor, $modName, $modVersion = $modFields
        $modKey = "$modAuthor-$modName"
        $modInfo = "$modKey-$modVersion"

        # Define the mod path
        $modPath = "$modContainerPath\$modKey"
        Write-Information "Installing mod: $modInfo."

        # Ensure mod path directory exist
        if (!(Test-Path -Path $modPath)) {
            New-Item -ItemType Directory -Path $modPath | Out-Null
        }

        # Download the mod
        $modUri = "https://thunderstore.io/package/download/$modAuthor/$modName/$modVersion/"
        $modZipPath = "$modPath.zip"
        Invoke-WebRequest -Uri $modUri -OutFile $modZipPath

        # Extract the mod
        Expand-Archive -Path $modZipPath -DestinationPath $modPath -Force
        Remove-Item -Force -Path $modZipPath

        # Initialize the mod or mod loader as needed
        switch ($modLoaderType) {
            1 {
                Initialize-BepInExPackModLoader -ModPath $modPath -GamePath $gamePath -ModLoaderKey $modLoaderKey
                Initialize-BepInExPackMod -ModPath $modPath -ModLoaderPath $modLoaderPath -ModLoaderKey $modLoaderKey
            }  
        }
    }

    Write-Information "$modpackInfo has been successfully installed to $gamePath."   
}

function Clear-GamePath {
    param (
        [string]$GamePath,
        [string]$ModLoaderKey = "Base-Spark"
    )

    $modLoaders = @{
        "Base-Spark" = @("Spark", "Spark\mods")
        "BepInEx-BepInExPack" = @("BepInEx", "doorstop_config.ini", "winhttp.dll")
        "LavaGang-MelonLoader" = @("_state", "MelonLoader", "Mods", "Plugins", "UserData", "UserLibs", "version.dll")
    }

    $gameInternalRelativePaths = $modLoaders[$ModLoaderKey] + @("CHANGELOG.md", "icon.png", "manifest.json", "README.md")
    Write-Information "Removing mod loader: $ModLoaderKey."

    foreach ($gameInternalRelativePath in $gameInternalRelativePaths) {
        $gameInternalPath = Join-Path -Path $GamePath -ChildPath $gameInternalRelativePath

        try {
            Remove-Item -Recurse -Force -Path $gameInternalPath -ErrorAction SilentlyContinue
        } catch [System.IO.IOException] {
            Write-Information "Unable to remove $gameInternalPath."
        } catch {
            Write-Information "An error occurred that could not be resolved."
            Write-Information $_
        }
    }
}

function Confirm-GamePath {
    param (
        [string]$GamePath
    )

    $gamePathChoices = @(
        [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Proceed")
        [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Exit")
    )

    $gamePathChoice = $host.UI.PromptForChoice("Game path: $GamePath.", "Is this correct?", $gamePathChoices, -1)
    return ![System.Convert]::ToBoolean($gamePathChoice)
}

function Find-GamePath {
    param (
        [string]$GameDirectory
    )

    $driveLetters = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
    $gameUnqualifiedPaths = @(
        "\$GameDirectory",
        "\steamapps\common\$GameDirectory"
    )

    $storeUnqualifiedPaths = @(
        $(Split-Path -Path "$([Environment]::GetFolderPath("LocalApplicationData"))\EpicGames" -NoQualifier),
        $(Split-Path -Path "$([Environment]::GetFolderPath("LocalApplicationData"))\Steam" -NoQualifier),
        $(Split-Path -Path "$([Environment]::GetFolderPath("ProgramFilesX86"))\Epic Games" -NoQualifier),
        $(Split-Path -Path "$([Environment]::GetFolderPath("ProgramFilesX86"))\Steam" -NoQualifier),
        "\SteamLibrary"
    )

    $resolvedGamePath = Resolve-Path -Path "."
    foreach ($driveLetter in $driveLetters) {
        foreach ($storeUnqualifiedPath in $storeUnqualifiedPaths) {
            $storePath = Join-Path -Path $driveLetter -ChildPath $storeUnqualifiedPath
            foreach ($gameUnqualifiedPath in $gameUnqualifiedPaths) {
                $gamePath = Join-Path -Path $storePath -ChildPath $gameUnqualifiedPath
                if (Test-Path -Path $gamePath) {
                    $resolvedGamePath = Resolve-Path -Path $gamePath
                    return $resolvedGamePath
                }
            }
        }
    }

    return $resolvedGamePath
}

function Get-GamePath {
    param (
        [string]$InitialPath = ""
    )

    $isFormsAvailable = $true
    $selectedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InitialPath)
    $gamePath = $selectedPath

    try {
        Add-Type -AssemblyName System.Windows.Forms
    }
    catch {
        $isFormsAvailable = $false
    }

    if ($isFormsAvailable) {
        $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
            Description  = "Select the game folder"
            SelectedPath = $selectedPath
        }

        $null = [System.Windows.Forms.Application]::EnableVisualStyles()
        $folderBrowserOwner = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true }
        if ($folderBrowserDialog.ShowDialog($folderBrowserOwner) -eq [System.Windows.Forms.DialogResult]::OK) {
            $gamePath = $folderBrowserDialog.SelectedPath
        }

        $folderBrowserDialog.Dispose()
        $folderBrowserOwner.Dispose()
    }
    else {
        while ($true) {
            $gamePath = Read-Host "Enter the game path (Default: $selectedPath)"
            if ([string]::IsNullOrWhiteSpace($gamePath)) {
                $gamePath = $selectedPath
            }

            if (Test-Path -Path $gamePath) { break }
        }
    }

    $resolvedGamePath = Resolve-Path -Path $gamePath
    return $resolvedGamePath
}

function Find-ModLoader {
    param (
        [string]$GamePath,
        [string[]]$Dependencies
    )

    $defaultModLoaderKey = "Base-Spark"
    $modLoaders = @{
        $defaultModLoaderKey = @(0, "$GamePath\Spark", "$GamePath\Spark\mods", "Pixelomega-Spark-0.0.0")
        "BepInEx-BepInExPack" = @(1, "$GamePath\BepInEx", "$GamePath\BepInEx\plugins")
        "LavaGang-MelonLoader" = @(2, "$GamePath\MelonLoader", "$GamePath\Mods")
    }

    foreach ($dependency in $Dependencies) {
        $modLoaderAuthor, $modLoaderName, $modLoaderVersion = $dependency -split "-"
        $modLoaderKey = "$modLoaderAuthor-$modLoaderName"

        if ($modLoaders.ContainsKey($modLoaderKey)) {
            $modLoader = $modLoaders[$modLoaderKey]
            $modLoader += @($modLoaderKey, $modLoaderVersion)

            Write-Information "Mod loader found. Using: $modLoaderKey."
            return $modLoader
        }
    }

    Write-Information "Mod loader not found. Using: $defaultModLoaderKey."
    return $modLoaders[$defaultModLoaderKey]
}

function Move-ModLoaderItem {
    param (
        [string]$FromPath,
        [string]$ToPath
    )

    try {
        $parsedFromPath = Get-Item -Path $FromPath
        if ($parsedFromPath.PSIsContainer -and !(Test-Path -Path $toPath)) {
            New-Item -ItemType Directory -Path $toPath | Out-Null
        }

        if (!$parsedFromPath.PSIsContainer) {
            Move-Item -Path $parsedFromPath -Destination $ToPath
        }
    }
    catch [System.IO.IOException] {
        Write-Information "Unable to move $FromPath to $ToPath."
    }
    catch {
        Write-Information "An error occurred that could not be resolved."
        Write-Information $_
    }
}

function Initialize-BepInExPackMod {
    param (
        [string]$ModPath,
        [string]$ModLoaderPath,
        [string]$ModLoaderKey = "BepInEx-BepInExPack"
    )

    $modKey = Split-Path -Path $ModPath -Leaf
    if ($modKey -eq $ModLoaderKey) { return }

    $modLoaderDirectory = Split-Path -Path $ModLoaderPath -Leaf
    $modSpecialRelativePaths = @($modLoaderDirectory)
    Write-Information "Configuring mod: $ModPath."

    foreach ($modSpecialRelativePath in $modSpecialRelativePaths) {
        $modInternalPath = Join-Path -Path $ModPath -ChildPath $modSpecialRelativePath
        if (!(Test-Path -Path $modInternalPath)) { continue }

        Get-ChildItem -Path $modInternalPath -Recurse | ForEach-Object {
            $fromPath = $_.FullName
            $relativeFromPath = $fromPath -replace "^$([regex]::Escape($modInternalPath))"
            $toPath = Join-Path -Path $ModPath -ChildPath $relativeFromPath
            Move-ModLoaderItem -FromPath $fromPath -ToPath $toPath
        }

        Remove-Item -Recurse -Force -Path $modInternalPath
    }

    $modLoaderReferencePaths = @(
        @("cache", "cache"),
        @("config", "config"),
        @("core", "core"),
        @("patchers", "patchers/$modKey"),
        @("plugins", "plugins/$modKey")
    )

    foreach ($modLoaderReferencePath in $modLoaderReferencePaths) {
        $modInternalPath = Join-Path -Path $ModPath -ChildPath $modLoaderReferencePath[0]
        $modLoaderInternalPath = Join-Path -Path $ModLoaderPath -ChildPath $modLoaderReferencePath[1]
        if (!(Test-Path -Path $modInternalPath)) { continue }

        Get-ChildItem -Path $modInternalPath -Recurse | ForEach-Object {
            $fromPath = $_.FullName
            $relativeFromPath = $fromPath -replace "^$([regex]::Escape($modInternalPath))"
            $toPath = Join-Path -Path $modLoaderInternalPath -ChildPath $relativeFromPath
            Move-ModLoaderItem -FromPath $fromPath -ToPath $toPath
        }

        Remove-Item -Recurse -Force -Path $modInternalPath
    }
}

function Initialize-BepInExPackModLoader {
    param (
        [string]$ModPath,
        [string]$GamePath,
        [string]$ModLoaderKey = "BepInEx-BepInExPack"
    )

    $modKey = Split-Path -Path $ModPath -Leaf
    if ($modKey -ne $ModLoaderKey) { return }

    Write-Information "Configuring mod loader: $ModPath."
    $modLoaderReferencePaths = @(
        @("manifest.json", "manifest.json"),
        @("BepInExPack/BepInEx", "BepInEx"),
        @("BepInExPack/doorstop_config.ini", "doorstop_config.ini"),
        @("BepInExPack/winhttp.dll", "winhttp.dll")
    )

    foreach ($modLoaderReferencePath in $modLoaderReferencePaths) {
        $modInternalPath = Join-Path -Path $ModPath -ChildPath $modLoaderReferencePath[0]
        $gameInternalPath = Join-Path -Path $GamePath -ChildPath $modLoaderReferencePath[1]
        if (!(Test-Path -Path $modInternalPath)) { continue }

        $parsedModInternalPath = Get-Item -Path $modInternalPath
        if ($parsedModInternalPath.PSIsContainer) {
            Get-ChildItem -Path $modInternalPath -Recurse | ForEach-Object {
                $fromPath = $_.FullName
                $relativeFromPath = $fromPath -replace "^$([regex]::Escape($modInternalPath))"
                $toPath = Join-Path -Path $gameInternalPath -ChildPath $relativeFromPath
                Move-ModLoaderItem -FromPath $fromPath -ToPath $toPath
            }
        } else {
            Move-ModLoaderItem -FromPath $modInternalPath -ToPath $gameInternalPath
        }
    }

    Remove-Item -Recurse -Force -Path $ModPath
}

Install-Base -GameDirectory $gameDirectory -ModpackAuthor $modpackAuthor -ModpackName $modpackName -ModpackVersion $modpackVersion
