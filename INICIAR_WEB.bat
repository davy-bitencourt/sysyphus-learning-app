@echo off
setlocal
cd /d "%~dp0"
title Sysyphus Learning App - Flutter Web

echo.
echo =============================================
echo   SYSYPHUS LEARNING APP - CHROME
 echo =============================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo ERRO: O comando flutter nao foi encontrado.
  echo Adicione o Flutter SDK ao PATH e abra outro terminal.
  pause
  exit /b 1
)
where dart >nul 2>nul
if errorlevel 1 (
  echo ERRO: O comando dart nao foi encontrado.
  echo Verifique se o Dart SDK acompanha seu Flutter SDK.
  pause
  exit /b 1
)

echo [1/3] Verificando dependencias...
call flutter pub get
if errorlevel 1 goto setup_error

echo.
echo [2/3] Instalando worker e WebAssembly do SQLite...
call dart run sqflite_common_ffi_web:setup
if errorlevel 1 goto setup_error

if not exist "web\sqlite3.wasm" goto missing
if not exist "web\sqflite_sw.js" goto missing
for %%F in ("web\sqlite3.wasm" "web\sqflite_sw.js") do (
  if %%~zF LSS 1000 goto missing
)

echo.
echo [3/3] Abrindo Google Chrome na porta 7357...
echo Mantenha este terminal aberto enquanto estiver utilizando o aplicativo.
echo.
call flutter run -d chrome --web-port=7357
if errorlevel 1 goto run_error
exit /b 0

:missing
echo.
echo ERRO: Nao foi possivel gerar os arquivos web\sqlite3.wasm e web\sqflite_sw.js.
echo Tente manualmente: dart run sqflite_common_ffi_web:setup --force
pause
exit /b 1

:setup_error
echo.
echo ERRO: Dependencias ou binarios do SQLite nao puderam ser preparados.
echo Verifique sua conexao com a internet e o erro acima.
pause
exit /b 1

:run_error
echo.
echo ERRO: O Flutter nao conseguiu concluir a execucao.
echo Consulte a mensagem acima para identificar o problema.
pause
exit /b 1
