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
        throw "Missing global.json at '$GlobalJsonPath'."
    }

    try {
        $globalJson = Get-Content -Raw -LiteralPath $GlobalJsonPath | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse '$GlobalJsonPath' as JSON. $($_.Exception.Message)"
    }

    $globalJson.sdk.version = $SdkVersion
    $globalJson | ConvertTo-Json -Depth 10 | Set-Content -Encoding utf8NoBOM -LiteralPath $GlobalJsonPath
}

function Invoke-Dotnet {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & dotnet @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "dotnet $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

$toolPath = Join-Path $PSScriptRoot 'Tool'
$solutionPath = Join-Path $PSScriptRoot 'SolutionToAnalyze'
$packedPath = Join-Path $PSScriptRoot 'packed'
$packedReleasePath = Join-Path (Join-Path $packedPath 'package') 'release'

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
    Invoke-Dotnet @('tool', 'execute', '--prerelease', '--source', $packedReleasePath, 'Tool', 'SolutionToAnalyze.slnx')
}
finally {
    Pop-Location
}
