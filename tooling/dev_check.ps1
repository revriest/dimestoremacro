Write-Host "Running Flutter analyze..." -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) {
  Write-Host "Analyze failed." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host "Running Flutter tests..." -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) {
  Write-Host "Tests failed." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host "Dev check passed (analyze + test)." -ForegroundColor Green
