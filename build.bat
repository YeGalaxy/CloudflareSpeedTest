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
if not exist "Releases\linux_arm64" mkdir "Releases\linux_arm64"

echo [1/3] Compiling Windows amd64...
set "GOOS=windows"
set "GOARCH=amd64"
set "CGO_ENABLED=0"
set "LDFLAGS=-s -w -buildid= -X main.version=%version%"
go build -trimpath -tags netgo -ldflags "%LDFLAGS%" -o "Releases\windows_amd64\cfst.exe"
if !errorlevel! neq 0 (
    echo [ERROR] Windows build failed!
    goto :cleanup
)
echo [1/3] Windows amd64 done.
echo.

echo [2/3] Compiling Linux amd64...
set "GOOS=linux"
set "GOARCH=amd64"
set "CGO_ENABLED=0"
set "LDFLAGS=-s -w -buildid= -extldflags '-static' -X main.version=%version%"
go build -trimpath -tags netgo -ldflags "%LDFLAGS%" -o "Releases\linux_amd64\cfst"
if !errorlevel! neq 0 (
    echo [ERROR] Linux amd64 build failed!
    goto :cleanup
)
echo [2/3] Linux amd64 done.
echo.

echo [3/3] Compiling Linux arm64...
set "GOOS=linux"
set "GOARCH=arm64"
set "CGO_ENABLED=0"
set "LDFLAGS=-s -w -buildid= -extldflags '-static' -X main.version=%version%"
go build -trimpath -tags netgo -ldflags "%LDFLAGS%" -o "Releases\linux_arm64\cfst"
if !errorlevel! neq 0 (
    echo [ERROR] Linux arm64 build failed!
    goto :cleanup
)
echo [3/3] Linux arm64 done.
echo.

copy /y ip.txt "Releases\windows_amd64\" >nul 2>&1
copy /y ipv6.txt "Releases\windows_amd64\" >nul 2>&1
copy /y ip.txt "Releases\linux_amd64\" >nul 2>&1
copy /y ipv6.txt "Releases\linux_amd64\" >nul 2>&1
copy /y ip.txt "Releases\linux_arm64\" >nul 2>&1
copy /y ipv6.txt "Releases\linux_arm64\" >nul 2>&1

echo ============================================
echo  Build complete! Output:
echo    Windows:  Releases\windows_amd64\
echo    Linux:    Releases\linux_amd64\
echo    ARM64:    Releases\linux_arm64\
echo ============================================

:cleanup
set "GOOS="
set "GOARCH="
set "CGO_ENABLED="
set "LDFLAGS="

endlocal
pause
