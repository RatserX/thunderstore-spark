# Define parameters
param (
    [string]$BasePath,
    [string]$DocsPath,
    [string]$ModpacksPath,
    [string]$OutputPath,
    [string]$ReleaseUri
)

# Change the ErrorActionPreference to 'Stop'
$ErrorActionPreference = 'Stop'

# Import modules
Import-Module powershell-yaml

# Ensure the docs folder path exists
if (Test-Path -Path $DocsPath) {
    Get-ChildItem -Path $DocsPath -Exclude ".gitkeep" | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $DocsPath | Out-Null
}

# Ensure the output folder path exists
if (!(Test-Path -Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

# Process each modpack
Get-ChildItem -Path $ModpacksPath -Filter "*.yml" | ForEach-Object {
    $modpackYamlPath = $_.FullName

    # Read the .yml file
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

    $modpackYaml.modpacks | ForEach-Object {
        $modpackAuthor = $_.author
        $modpackName = $_.name
        $modpackUri = $_.uri
        $modpackVersion = $_.version

        $readmeContent += "### [$modpackName $modpackVersion (By $modpackAuthor)]($modpackUri)`n"
        $readmeContent += "`n"

        # Loop through each PowerShell script in the base folder
        Get-ChildItem -Path $BasePath -Filter "*.ps1" | ForEach-Object {
            $scriptName = $scriptName = (Get-Culture).TextInfo.ToTitleCase($_.BaseName)
            $scriptPath = $_.FullName
            $scriptContent = Get-Content -Path $scriptPath

            # Replace placeholders
            $scriptContent = $scriptContent -replace "GAME_DIRECTORY", $gameDirectory
            $scriptContent = $scriptContent -replace "MODPACK_AUTHOR", $modpackAuthor
            $scriptContent = $scriptContent -replace "MODPACK_NAME", $modpackName
            $scriptContent = $scriptContent -replace "MODPACK_VERSION", $modpackVersion

            # Save the output file
            $outputPwshFile = "$gameDirectory-$modpackAuthor-$modpackName-$scriptName.ps1"
            $outputPwshPath = Join-Path -Path $OutputPath -ChildPath $outputPwshFile
            Set-Content -Path $outputPwshPath -Value $scriptContent
            Write-Output "$outputPwshFile has been successfully generated to $OutputPath."

            $scriptUri = "$ReleaseUri/$outputPwshFile"
            $readmeContent += "#### $scriptName Command`n"
            $readmeContent += "`n"
            $readmeContent += "`````````ps1`n"
            $readmeContent += "irm '$scriptUri' | iex`n"
            $readmeContent += "````````` `n"
            $readmeContent += "`n"
        }

        $readmeContent += "---`n"
        $readmeContent += "`n"
    }

    # Save the doc file
    $readmeMarkdownFileName = "$gameDirectory".ToUpper()
    $readmeMarkdownFile = "$readmeMarkdownFileName.md"
    $readmeMarkdownPath = Join-Path -Path $DocsPath -ChildPath $readmeMarkdownFile
    Set-Content -Path $readmeMarkdownPath -Value $readmeContent
    Write-Output "$readmeMarkdownFile has been successfully generated to $DocsPath."
}
