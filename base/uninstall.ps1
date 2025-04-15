# Define global variables
$gameDirectory = "GAME_DIRECTORY"
$modpackAuthor = "MODPACK_AUTHOR"
$modpackName = "MODPACK_NAME"
$modpackVersion = "MODPACK_VERSION"

$itemsToDelete = @(
    "BepInEx",
    "CHANGELOG.md",
    "icon.png",
    "manifest.json",
    "README.md"
    # "doorstop_config.ini",
    # "winhttp.dll"
)

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
        Remove-Item -Recurse -Force -Path $itemPath
    } catch [System.IO.IOException] {
        Write-Output "Unable to remove $itemPath."
    } catch {
        Write-Output "An error occurred that could not be resolved."
        Write-Output $_
    }
}

Write-Output "$modpackAuthor-$modpackName-$modpackVersion has been successfully uninstalled from $gamePath."
