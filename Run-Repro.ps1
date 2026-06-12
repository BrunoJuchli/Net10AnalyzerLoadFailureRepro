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

    $globalJson = Get-Content -Raw -Path $GlobalJsonPath | ConvertFrom-Json
    $globalJson.sdk.version = $SdkVersion
    $globalJson | ConvertTo-Json -Depth 10 | Set-Content -Path $GlobalJsonPath
}

$toolPath = Join-Path $PSScriptRoot 'Tool'
$solutionPath = Join-Path $PSScriptRoot 'SolutionToAnalyze'

Push-Location $toolPath
try {
    Set-SdkVersion -GlobalJsonPath (Join-Path $toolPath 'global.json') -SdkVersion $netSdkVersionTool
    dotnet pack --artifacts-path ..\packed
}
finally {
    Pop-Location
}

Push-Location $solutionPath
try {
    Set-SdkVersion -GlobalJsonPath (Join-Path $solutionPath 'global.json') -SdkVersion $netSdkVersionSolutionToAnalyze
    dotnet tool exec Tool --prerelease --source ..\packed\package\release SolutionToAnalyze.slnx
}
finally {
    Pop-Location
}
