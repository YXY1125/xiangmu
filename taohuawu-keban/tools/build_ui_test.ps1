param()
$ErrorActionPreference='Stop'
$env:JAVA_HOME='D:\DevEco Studio\jbr'
$env:DEVECO_SDK_HOME='D:\DevEco Studio\sdk'
Push-Location (Join-Path $PSScriptRoot '../app')
try {
  $ErrorActionPreference='Continue'
  & 'D:\DevEco Studio\tools\node\node.exe' 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.js' --mode module -p product=default -p module=entry@ohosTest -p buildMode=debug assembleHap --no-daemon 2>&1 | Tee-Object -FilePath (Join-Path $PSScriptRoot '../docs/validation/build/build-ui-test.log')
  $thwkbTestExit=$LASTEXITCODE
} finally { Pop-Location }
exit $thwkbTestExit
