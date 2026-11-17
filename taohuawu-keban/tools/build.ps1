param([ValidateSet('debug','release')][string]$BuildMode='debug')
$ErrorActionPreference='Stop'
$appRoot=Join-Path $PSScriptRoot '../app'
$logRoot=Join-Path $PSScriptRoot '../docs/validation/build'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$env:JAVA_HOME='D:\DevEco Studio\jbr'
$env:DEVECO_SDK_HOME='D:\DevEco Studio\sdk'
$logPath=Join-Path $logRoot "build-$BuildMode.log"
Push-Location $appRoot
try {
  # Windows PowerShell wraps native stderr warnings as ErrorRecords; keep the real exit code authoritative.
  $ErrorActionPreference='Continue'
  & 'D:\DevEco Studio\tools\node\node.exe' 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.js' --mode module -p product=default -p module=entry@default -p "buildMode=$BuildMode" assembleHap --no-daemon 2>&1 | Tee-Object -FilePath $logPath
  $buildExit=$LASTEXITCODE
} finally { Pop-Location }
exit $buildExit
