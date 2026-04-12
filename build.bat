@echo off
setlocal enabledelayedexpansion

set "version=v2.3.4"

echo ============================================
echo  CloudflareSpeedTest Cross Compile Script
echo  Version: %version%
echo ============================================
echo.

if not exist "Releases\windows_amd64" mkdir "Releases\windows_amd64"
if not exist "Releases\linux_amd64" mkdir "Releases\linux_amd64"

echo [1/2] Compiling Windows amd64...
set "GOOS=windows"
set "GOARCH=amd64"
set "LDFLAGS=-s -w -X main.version=%version%"
go build -o "Releases\windows_amd64\cfst.exe" -ldflags "%LDFLAGS%"
if !errorlevel! neq 0 (
    echo [ERROR] Windows build failed!
    goto :cleanup
)
echo [1/2] Windows amd64 done.
echo.

echo [2/2] Compiling Linux amd64...
set "GOOS=linux"
set "GOARCH=amd64"
set "LDFLAGS=-s -w -X main.version=%version%"
go build -o "Releases\linux_amd64\cfst" -ldflags "%LDFLAGS%"
if !errorlevel! neq 0 (
    echo [ERROR] Linux build failed!
    goto :cleanup
)
echo [2/2] Linux amd64 done.
echo.

copy /y ip.txt "Releases\windows_amd64\" >nul 2>&1
copy /y ipv6.txt "Releases\windows_amd64\" >nul 2>&1
copy /y ip.txt "Releases\linux_amd64\" >nul 2>&1
copy /y ipv6.txt "Releases\linux_amd64\" >nul 2>&1

echo ============================================
echo  Build complete! Output:
echo    Windows: Releases\windows_amd64\
echo    Linux:   Releases\linux_amd64\
echo ============================================

:cleanup
set "GOOS="
set "GOARCH="
set "LDFLAGS="

endlocal
pause
