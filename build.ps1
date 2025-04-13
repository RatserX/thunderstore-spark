# Change the ErrorActionPreference to 'Stop'
$ErrorActionPreference = 'Stop'

# Define parameters
param (
    [string]$BasePath,
    [string]$DocsPath,
    [string]$ModpacksPath,
    [string]$OutputPath,
    [string]$ReleaseUrl
)

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
    $modpackYamlFileName = $_.BaseName
    $modpackYamlPath = $_.FullName

    $gameName = $modpackYaml.game
    $modpackYaml = Get-Content -Path $modpackYamlPath | ConvertFrom-Yaml
    $readmeContent = "# $gameName`n"

    $modpackYaml.modpacks | ForEach-Object {
        $modpackAuthor = $_.author
        $modpackName = $_.name
        $modpackVersion = $_.version

        # Add a section for the modpack in the Markdown
        $readmeContent += "### $modpackAuthor-$modpackName-$modpackVersion`n"

        # Loop through each PowerShell script in the base folder
        Get-ChildItem -Path $BasePath -Filter "*.ps1" | ForEach-Object {
            $scriptName = $_.BaseName
            $scriptPath = $_.FullName
            $scriptContent = Get-Content -Path $scriptPath

            # Replace placeholders
            $scriptContent = $scriptContent -replace "MODPACK_AUTHOR", $modpackAuthor
            $scriptContent = $scriptContent -replace "MODPACK_NAME", $modpackName
            $scriptContent = $scriptContent -replace "MODPACK_VERSION", $modpackVersion

            # Save the output file
            $outputPwshFileName = "$gameName-$modpackAuthor-$modpackName-$scriptName.ps1"
            $outputPwshPath = Join-Path -Path $OutputPath -ChildPath $outputPwshFileName
            Set-Content -Path $outputPwshPath -Value $scriptContent

            $releaseUrl = "$ReleaseUrl/$outputPwshFileName"
            $readmeContent += "#### $scriptName`n"
            $readmeContent += "`\`\`ps1`n"
            $readmeContent += "irm '$releaseUrl' | iex`n"
            $readmeContent += "\`\`\``n"
            $readmeContent += "---`n"
        }
    }

    # Save the doc file
    $readmeMarkdownPath = Join-Path -Path $DocsPath -ChildPath "$modpackYamlFileName.md"
    Set-Content -Path $readmeMarkdownPath -Value $markdownContent
}
