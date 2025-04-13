# Define parameters
param (
    [string]$BasePath,
    [string]$DocsPath,
    [string]$ModpacksPath,
    [string]$OutputPath,
    [string]$ReleaseUrl
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
    $modpackYamlFileName = $_.BaseName
    $modpackYamlPath = $_.FullName

    $modpackYaml = Get-Content -Path $modpackYamlPath | ConvertFrom-Yaml
    $gameName = $modpackYaml.game

    $readmeContent = "# $gameName`n"
    $readmeContent = "`n"

    $modpackYaml.modpacks | ForEach-Object {
        $modpackAuthor = $_.author
        $modpackName = $_.name
        $modpackVersion = $_.version

        # Add a section for the modpack in the Markdown
        $readmeContent += "### $modpackAuthor-$modpackName-$modpackVersion`n"

        # Loop through each PowerShell script in the base folder
        Get-ChildItem -Path $BasePath -Filter "*.ps1" | ForEach-Object {
            $scriptName = (Get-Culture).TextInfo.ToTitleCase($_.BaseName)
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
            Write-Output "$outputPwshFileName has been successfully generated to $OutputPath."

            $releaseUrl = "$ReleaseUrl/$outputPwshFileName"
            $readmeContent += "#### $scriptName`n"
            $readmeContent += "`\`\`ps1`n"
            $readmeContent += "irm '$releaseUrl' | iex`n"
            $readmeContent += "\`\`\``n"
            $readmeContent += "---`n"
        }
    }

    # Save the doc file
    $readmeMarkdownFileName = "$modpackYamlFileName.md"
    $readmeMarkdownPath = Join-Path -Path $DocsPath -ChildPath $readmeMarkdownFileName
    Set-Content -Path $readmeMarkdownPath -Value $markdownContent
    Write-Output "$readmeMarkdownFileName has been successfully generated to $DocsPath."
}
