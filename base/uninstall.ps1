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

# Ask the user for the modpack path
$modpackPath = ""
if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
    Add-Type -AssemblyName System.Windows.Forms

    $defaultModpackPath = "${Env:ProgramFiles(x86)}\Steam\steamapps\common\$gameDirectory"
    $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
        Description = "Select the modpack folder"
        SelectedPath = $defaultModpackPath
    }

    $null = [System.Windows.Forms.Application]::EnableVisualStyles()
    $folderBrowserOwner = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true }
    if ($folderBrowserDialog.ShowDialog($folderBrowserOwner) -eq [System.Windows.Forms.DialogResult]::OK) {
        $modpackPath = $folderBrowserDialog.SelectedPath
    }

    $folderBrowserDialog.Dispose()
    $folderBrowserOwner.Dispose()
} else {
    $defaultModpackPath = "${[Environment]::GetFolderPath("LocalApplicationData")}\Steam\steamapps\common\$gameDirectory"
    $modpackPath = Read-Host "Enter the modpack path (Default: $defaultModpackPath)"
    if ([string]::IsNullOrWhiteSpace($modpackPath)) {
        $modpackPath = $defaultModpackPath
    }
}

# Ask the user to confirm the modpack path
$modpackPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($modpackPath)
$modpackPathConfirmation = Read-Host "Modpack path: $modpackPath. Is this correct? (y/n)"
if ($modpackPathConfirmation -notmatch "^(y|Y)$") {
    Write-Output "Confirmation failed. Exiting..."
    exit
}

# Read the manifest.json file
$manifestJsonPath = Join-Path -Path $modpackPath -ChildPath "manifest.json"
$manifestJson = Get-Content -Path $manifestJsonPath | ConvertFrom-Json
$name = $manifestJson.name
$versionNumber = $manifestJson.version_number

if ($name -ne $modpackName -or $versionNumber -ne $modpackVersion) {
    Write-Output "Manifest validation failed. Expected: $modpackName-$modpackVersion. Found name: $name-$versionNumber. Exiting..."
    exit
}

# Delete the modpack
foreach ($itemToDelete in $itemsToDelete) {
    $itemPath = Join-Path -Path $modpackPath -ChildPath $itemToDelete

    try {
        Remove-Item -Recurse -Force -Path $itemPath
    } catch [System.IO.IOException] {
        Write-Output "Unable to remove $itemPath."
    } catch {
        Write-Output "An error occurred that could not be resolved."
        Write-Output $_
    }
}

Write-Output "$modpackAuthor-$modpackName-$modpackVersion has been successfully uninstalled from $modpackPath."
