# Define global variables
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

# Change the ErrorActionPreference to 'Stop'
$ErrorActionPreference = 'Stop'

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

# Read the manifest.json file
$manifestJsonPath = Join-Path -Path $modpackPath -ChildPath "manifest.json"
$manifestJson = Get-Content -Path $manifestJsonPath | ConvertFrom-Json
$name = $manifestJson.name
$versionNumber = $manifestJson.version_number

if ($name -ne $modpackName -or $versionNumber -ne $modpackVersion) {
    Write-Output "Manifest validation failed. Expected: $modpackName-$modpackVersion. Found name: $name-$versionNumber."
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
