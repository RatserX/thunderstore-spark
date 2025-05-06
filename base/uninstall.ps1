# Define global variables
$gameDirectory = "GAME_DIRECTORY"
$modpackAuthor = "MODPACK_AUTHOR"
$modpackName = "MODPACK_NAME"
$modpackVersion = "MODPACK_VERSION"

# Change preference variables
$ErrorActionPreference = "Stop"

function Uninstall-Base {
    param (
        [string]$GameDirectory,
        [string]$ModpackAuthor,
        [string]$ModpackName,
        [string]$ModpackVersion
    )

    $itemsToDelete = @(
        "BepInEx",
        "CHANGELOG.md",
        "icon.png",
        "manifest.json",
        "README.md"
        # "doorstop_config.ini",
        # "winhttp.dll",
        "_state",
        "MelonLoader",
        "Mods",
        "Plugins",
        "UserData",
        "UserLibs",
        "version.dll"
    )

    # Ask the user for the game path
    $selectedPath = Find-GamePath -GameDirectory $GameDirectory
    $gamePath = Get-GamePath -SelectedPath $selectedPath

    # Ask the user to confirm the game path
    $isValidGamePath = Confirm-GamePath -GamePath $gamePath
    if ($isValidGamePath -eq $false) {
        Write-Output "Confirmation failed. Exiting..."
        exit
    }

    # Read the manifest.json file
    $manifestJsonPath = Join-Path -Path $gamePath -ChildPath "manifest.json"
    $manifestJson = Get-Content -Path $manifestJsonPath | ConvertFrom-Json
    $name = $manifestJson.name
    $versionNumber = $manifestJson.version_number
    
    if ($name -ne $modpackName -or $versionNumber -ne $modpackVersion) {
        Write-Output "Manifest validation failed. Expected: $modpackName-$modpackVersion. Found name: $name-$versionNumber. Exiting..."
        exit
    }
    
    # Delete the modpack
    foreach ($itemToDelete in $itemsToDelete) {
        $itemPath = Join-Path -Path $gamePath -ChildPath $itemToDelete
    
        try {
            Remove-Item -Recurse -Force -Path $itemPath -ErrorAction SilentlyContinue
        } catch [System.IO.IOException] {
            Write-Output "Unable to remove $itemPath."
        } catch {
            Write-Output "An error occurred that could not be resolved."
            Write-Output $_
        }
    }
    
    Write-Output "$modpackAuthor-$modpackName-$modpackVersion has been successfully uninstalled from $gamePath."
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

            if (Test-Path -Path $gamePath) {
                break
            }
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

    $modLoaders = @{
        "Base-Spark" = @(0, "$GamePath\Spark", "$GamePath\Spark\mods", "0.0.0")
        "BepInEx-BepInExPack" = @(1, "$GamePath\BepInEx", "$GamePath\BepInEx\plugins")
        "LavaGang-MelonLoader" = @(2, "$GamePath\MelonLoader", "$GamePath\Mods")
    }

    foreach ($dependency in $Dependencies) {
        $modLoaderAuthor, $modLoaderName, $modLoaderVersion = $dependency -split "-"
        $modLoaderKey = "$modLoaderAuthor-$modLoaderName"

        if ($modLoaders.ContainsKey($modLoaderKey)) {
            $modLoaderInfo = "$modLoaderKey-$modLoaderVersion"
            $modLoader = $modLoaders[$modLoaderKey]
            $modLoader += $modLoaderInfo
            return $modLoader
        }
    }

    return $modLoaders["Base-Spark"]
}

Uninstall-Base -GameDirectory $gameDirectory -ModpackAuthor $modpackAuthor -ModpackName $modpackName -ModpackVersion $modpackVersion
