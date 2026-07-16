Write-Host "Running flutter clean..." -ForegroundColor Cyan
flutter clean
if ($LASTEXITCODE -ne 0) {
  Write-Host "flutter clean failed." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host "Running flutter pub get..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) {
  Write-Host "flutter pub get failed." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host "Running flutter analyze..." -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) {
  Write-Host "flutter analyze failed." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host "Running flutter test..." -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) {
  Write-Host "flutter test failed." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host "Building debug APK..." -ForegroundColor Cyan
flutter build apk --debug
if ($LASTEXITCODE -ne 0) {
  Write-Host "Debug APK build failed." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host "Preflight passed (clean + get + analyze + test + debug build)." -ForegroundColor Green
