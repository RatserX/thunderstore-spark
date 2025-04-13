# Change the ErrorActionPreference to 'Stop'
$ErrorActionPreference = 'Stop'

# Define global variables
$modpackAuthor = "Pixelomega"
$modpackName = "VolcanoSauce"
$modpackVersion = "1.0.0"

$itemsToDelete = @(
    "BepInEx",
    "CHANGELOG.md",
    "icon.png",
    "manifest.json",
    "README.md",
    "doorstop_config.ini",
    "winhttp.dll"
)

# Ask the user for the modpack folder path
$defaultModpackFolderPath = "${Env:ProgramFiles(x86)}\Steam\steamapps\common\REPO"
$modpackFolderPath = Read-Host "Enter the modpack folder path (Default: $defaultModpackFolderPath)"
if ([string]::IsNullOrWhiteSpace($modpackFolderPath)) {
    $modpackFolderPath = $defaultModpackFolderPath
}

# Read the manifest.json file
$manifestFilePath = Join-Path -Path $modpackFolderPath -ChildPath "manifest.json"
$manifest = Get-Content -Path $manifestFilePath | ConvertFrom-Json
$name = $manifest.name
$versionNumber = $manifest.version_number

if ($name -ne $modpackName -or $versionNumber -ne $modpackVersion) {
    Write-Output "Manifest validation failed. Expected: $modpackName-$modpackVersion. Found name: $name-$versionNumber."
    exit
}

# Delete the modpack
foreach ($itemToDelete in $itemsToDelete) {
    $itemPath = Join-Path -Path $modpackFolderPath -ChildPath $itemToDelete

    try {
        Remove-Item -Recurse -Force -Path $itemPath
    } catch [System.IO.IOException] {
        Write-Output "Unable to remove $itemPath."
    } catch {
        Write-Output "An error occurred that could not be resolved."
        Write-Output $_
    }
}

Write-Output "$modpackAuthor-$modpackName-$modpackVersion has been successfully uninstalled from $modpackFolderPath."
