# Define parameters
param (
    [string]$BasePath,
    [string]$DocsPath,
    [string]$ModpacksPath,
    [string]$OutputPath,
    [string]$ReleaseUri
)

# Change preference variables
$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

# Import modules
Import-Module powershell-yaml

# Ensure docs directory exist
if (!(Test-Path -Path $DocsPath)) {
    New-Item -ItemType Directory -Path $DocsPath | Out-Null
} else {
    Get-ChildItem -Path $DocsPath -Exclude ".gitkeep" | Remove-Item -Recurse -Force
}

# Ensure output directory exist
if (!(Test-Path -Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

# Process each modpack YAML file
Get-ChildItem -Path $ModpacksPath -Filter "*.yml" | ForEach-Object {
    $modpackYamlPath = $_.FullName

    # Parse .yml
    $modpackYaml = Get-Content -Path $modpackYamlPath | ConvertFrom-Yaml
    $game = $modpackYaml.game
    $gameDescription = $game.description
    $gameDirectory = $game.directory
    $gameName = $game.name

    # Define the readme content
    $readmeContent = "# $gameName`n"
    $readmeContent += "`n"
    $readmeContent += "$gameDescription`n"
    $readmeContent += "`n"
    $readmeContent += "## Modpacks`n"
    $readmeContent += "`n"

    # Process each modpack entry
    $modpackYaml.modpacks | ForEach-Object {
        $modpackAuthor = $_.author
        $modpackName = $_.name
        $modpackUri = $_.uri
        $modpackVersion = $_.version

        $readmeContent += "### [$modpackName $modpackVersion (By $modpackAuthor)]($modpackUri)`n"
        $readmeContent += "`n"

        # Process each PowerShell script
        Get-ChildItem -Path $BasePath -Filter "*.ps1" | ForEach-Object {
            $scriptName = $scriptName = (Get-Culture).TextInfo.ToTitleCase($_.BaseName)
            $scriptPath = $_.FullName
            $scriptContent = Get-Content -Path $scriptPath

            # Replace placeholders
            $scriptContent = $scriptContent -replace "GAME_DIRECTORY", $gameDirectory
            $scriptContent = $scriptContent -replace "MODPACK_AUTHOR", $modpackAuthor
            $scriptContent = $scriptContent -replace "MODPACK_NAME", $modpackName
            $scriptContent = $scriptContent -replace "MODPACK_VERSION", $modpackVersion

            # Save the generated script
            $outputPwshFile = "$gameDirectory-$modpackAuthor-$modpackName-$scriptName.ps1"
            $outputPwshPath = Join-Path -Path $OutputPath -ChildPath $outputPwshFile
            Set-Content -Path $outputPwshPath -Value $scriptContent
            Write-Information "$outputPwshFile has been successfully generated to $OutputPath."

            # Define the usage block for this script
            $scriptUri = "$ReleaseUri/$outputPwshFile"
            $readmeContent += "#### $scriptName Command`n"
            $readmeContent += "`n"
            $readmeContent += "`````````ps1`n"
            $readmeContent += "irm `"$scriptUri`" | iex`n"
            $readmeContent += "````````` `n"
            $readmeContent += "`n"
        }

        $readmeContent += "---`n"
        $readmeContent += "`n"
    }

    # Save the generated Markdown documentation
    $readmeMarkdownFileName = "$gameDirectory".ToUpper().Trim()
    $readmeMarkdownFile = "$readmeMarkdownFileName.md"
    $readmeMarkdownPath = Join-Path -Path $DocsPath -ChildPath $readmeMarkdownFile
    Set-Content -Path $readmeMarkdownPath -Value $readmeContent
    Write-Information "$readmeMarkdownFile has been successfully generated to $DocsPath."
}
