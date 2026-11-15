$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter não encontrado. Instale o SDK Flutter e adicione-o ao PATH.'
}
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get falhou.' }
dart run sqflite_common_ffi_web:setup
if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar os binários do SQLite Web.' }
if (!(Test-Path 'web/sqlite3.wasm') -or !(Test-Path 'web/sqflite_sw.js')) {
  throw 'Arquivos web/sqlite3.wasm ou web/sqflite_sw.js não foram gerados.'
}
Write-Host 'Preparação concluída. Execute: flutter run -d chrome --web-port=7357'
