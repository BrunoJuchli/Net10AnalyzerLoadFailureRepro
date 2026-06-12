param(
    [Parameter(Mandatory = $true)]
    [string]$netSdkVersionTool,

    [Parameter(Mandatory = $true)]
    [string]$netSdkVersionSolutionToAnalyze
)

function Set-SdkVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GlobalJsonPath,

        [Parameter(Mandatory = $true)]
        [string]$SdkVersion
    )

    if (-not (Test-Path -LiteralPath $GlobalJsonPath)) {
        throw "Missing global.json at '$GlobalJsonPath' while updating SDK version to '$SdkVersion'."
    }

    try {
        $globalJson = Get-Content -Raw -LiteralPath $GlobalJsonPath | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse '$GlobalJsonPath' as JSON while updating SDK version to '$SdkVersion'. $($_.Exception.Message)"
    }

    if ($null -eq $globalJson.sdk) {
        $globalJson | Add-Member -NotePropertyName sdk -NotePropertyValue ([pscustomobject]@{})
    }

    $globalJson.sdk.version = $SdkVersion
    $globalJson | ConvertTo-Json -Depth 100 | Set-Content -Encoding utf8NoBOM -LiteralPath $GlobalJsonPath
}

function Invoke-Dotnet {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & dotnet @Arguments
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "dotnet $($Arguments -join ' ') failed with exit code $exitCode."
    }
}

$toolPath = Join-Path $PSScriptRoot 'Tool'
$solutionPath = Join-Path $PSScriptRoot 'SolutionToAnalyze'
$packedPath = Join-Path $PSScriptRoot 'packed'
$packedReleasePath = Join-Path (Join-Path $packedPath 'package') 'release'

$toolProjectPath = Join-Path $toolPath 'Tool.csproj'
$toolProject = [xml](Get-Content -Raw -LiteralPath $toolProjectPath)
$toolPackageId = $toolProject.Project.PropertyGroup.PackageId
if ([string]::IsNullOrWhiteSpace($toolPackageId)) {
    $toolPackageId = [System.IO.Path]::GetFileNameWithoutExtension($toolProjectPath)
}

$solutionFiles = Get-ChildItem -File -Path $solutionPath -Filter '*.slnx'
if ($solutionFiles.Count -ne 1) {
    throw "Expected exactly one solution file in '$solutionPath' but found $($solutionFiles.Count)."
}

$solutionFileName = $solutionFiles[0].Name

Push-Location $toolPath
try {
    Set-SdkVersion -GlobalJsonPath (Join-Path $toolPath 'global.json') -SdkVersion $netSdkVersionTool
    Invoke-Dotnet @('pack', '--artifacts-path', $packedPath)
}
finally {
    Pop-Location
}

Push-Location $solutionPath
try {
    Set-SdkVersion -GlobalJsonPath (Join-Path $solutionPath 'global.json') -SdkVersion $netSdkVersionSolutionToAnalyze
    Invoke-Dotnet @('tool', 'execute', '--prerelease', '--source', $packedReleasePath, $toolPackageId, $solutionFileName)
}
finally {
    Pop-Location
}
