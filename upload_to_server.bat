@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

:: ============================================
:: Docker 文件自动上传脚本
:: 功能：将 Dockerfile 及相关文件上传到远程服务器
:: 版本：2.1.0
:: 最后更新：2026-06-02
:: ============================================

:: 从 .env 文件加载配置
set ENV_FILE=%~dp0.env
if not exist "%ENV_FILE%" (
    echo [ERROR] 未找到 .env 配置文件
    echo 请复制 .env.example 为 .env 并填写实际配置
    echo 按任意键退出...
    pause >nul
    exit /b 1
)

call :load_env

:: 远程服务器配置（从 .env 文件加载）
:: REMOTE_HOST, REMOTE_PORT, REMOTE_USER, REMOTE_PASSWORD, REMOTE_PATH

:: 本地项目根目录（脚本所在目录）
set LOCAL_DIR=%~dp0

:: 日志颜色定义
set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "RESET=[0m"

:: 上传文件列表
set FILES_TO_UPLOAD=Dockerfile docker-compose.yml entrypoint.sh go.mod go.sum main.go ip.txt ipv6.txt .dockerignore

:: 上传目录列表
set DIRS_TO_UPLOAD=task utils

:: 认证方式：1=使用Plink/Pscp自动密码，0=手动输入
set USE_AUTO_AUTH=0

:: ============================================
:: 主程序入口
:: ============================================
echo.
echo ============================================
echo   Docker 文件上传工具
echo ============================================
echo.

:: 步骤1：环境检查
call :log_info "步骤 1/5: 检查本地环境..."
call :check_environment
if !errorlevel! neq 0 (
    call :log_error "环境检查失败，脚本退出"
    echo 按任意键退出...
    pause >nul
    exit /b 1
)

:: 步骤2：文件完整性检查
call :log_info "步骤 2/5: 检查文件完整性..."
call :check_files
if !errorlevel! neq 0 (
    call :log_error "文件完整性检查失败，脚本退出"
    echo 按任意键退出...
    pause >nul
    exit /b 1
)

:: 步骤3：创建远程目录并上传文件（一次性认证）
call :log_info "步骤 3/4: 创建远程目录并上传文件..."
call :create_remote_dir_and_upload
if !errorlevel! neq 0 (
    call :log_error "文件上传失败，脚本退出"
    echo 按任意键退出...
    pause >nul
    exit /b 1
)

:: 步骤4：验证上传结果
call :log_info "步骤 4/4: 验证上传结果..."
call :verify_upload
if !errorlevel! neq 0 (
    call :log_error "上传验证失败，请检查远程服务器"
    echo 按任意键退出...
    pause >nul
    exit /b 1
)

:: 上传成功
echo.
echo ============================================
call :log_success "所有文件已成功上传到 %REMOTE_USER%@%REMOTE_HOST%:%REMOTE_PORT%%REMOTE_PATH%"
echo ============================================
echo.
echo 提示：您可以使用以下命令在远程服务器构建Docker镜像：
echo   ssh %REMOTE_USER%@%REMOTE_HOST% "cd %REMOTE_PATH% ^&^& docker build -t cfst:latest ."
echo.
echo 按任意键退出...
pause >nul

endlocal
exit /b 0

:: ============================================
:: 函数：从 .env 文件加载环境变量
:: ============================================
:load_env
for /f "tokens=* delims=" %%a in ('findstr /v "^#" "%ENV_FILE%" ^| findstr /v "^$"') do (
    set "%%a"
)
exit /b 0

:: ============================================
:: 函数：日志输出 - 信息
:: ============================================
:log_info
echo %GREEN%[INFO]%RESET% %~1
exit /b 0

:: ============================================
:: 函数：日志输出 - 错误
:: ============================================
:log_error
echo %RED%[ERROR]%RESET% %~1
exit /b 0

:: ============================================
:: 函数：日志输出 - 警告
:: ============================================
:log_warn
echo %YELLOW%[WARN]%RESET% %~1
exit /b 0

:: ============================================
:: 函数：日志输出 - 成功
:: ============================================
:log_success
echo %GREEN%[SUCCESS]%RESET% %~1
exit /b 0

:: ============================================
:: 函数：检查环境
:: ============================================
:check_environment
:: 检查PowerShell是否可用
where powershell >nul 2>&1
if !errorlevel! neq 0 (
    call :log_error "未找到PowerShell，请确保Windows PowerShell可用"
    exit /b 1
)
call :log_info "PowerShell可用"

:: 检查SSH命令是否可用
where ssh >nul 2>&1
if !errorlevel! neq 0 (
    call :log_error "未找到SSH命令，请确保已安装OpenSSH客户端"
    exit /b 1
)
call :log_info "SSH命令可用"

:: 检查SCP命令是否可用
where scp >nul 2>&1
if !errorlevel! equ 0 (
    set HAS_SCP=1
    call :log_info "SCP命令可用"
) else (
    set HAS_SCP=0
    call :log_warn "SCP命令不可用，将使用PowerShell上传"
)

:: 检查网络连接
call :log_info "测试与 %REMOTE_HOST%:%REMOTE_PORT% 的网络连接..."
ping -n 1 -w 1000 %REMOTE_HOST% >nul 2>&1
if !errorlevel! neq 0 (
    call :log_error "无法连接到远程服务器 %REMOTE_HOST%"
    echo 请检查：
    echo   1. 服务器IP地址是否正确
    echo   2. 网络连接是否正常
    echo   3. 防火墙是否允许SSH连接
    exit /b 1
)
call :log_info "网络连接正常"

exit /b 0

:: ============================================
:: 函数：检查文件完整性
:: ============================================
:check_files
set MISSING_FILES=0

:: 检查必需文件
call :log_info "检查必需文件..."
for %%F in (%FILES_TO_UPLOAD%) do (
    if exist "%LOCAL_DIR%%%F" (
        call :log_info "  [OK] %%F"
    ) else (
        call :log_error "  [MISSING] %%F"
        set MISSING_FILES=1
    )
)

:: 检查必需目录
call :log_info "检查必需目录..."
for %%D in (%DIRS_TO_UPLOAD%) do (
    if exist "%LOCAL_DIR%%%D\" (
        call :log_info "  [OK] %%D/"
    ) else (
        call :log_error "  [MISSING] %%D/"
        set MISSING_FILES=1
    )
)

if !MISSING_FILES! equ 1 (
    call :log_error "存在缺失文件，请确保所有必需文件存在"
    exit /b 1
)

call :log_info "所有文件完整性检查通过"
exit /b 0

:: ============================================
:: 函数：创建远程目录并上传文件（一次性认证）
:: ============================================
:create_remote_dir_and_upload
call :log_info "正在连接远程服务器并上传文件..."

:: 检查是否存在SSH密钥
set SSH_KEY_PATH=%USERPROFILE%\.ssh\id_rsa
if not exist "%SSH_KEY_PATH%" (
    call :log_warn "未找到SSH密钥，正在生成..."
    ssh-keygen -t rsa -b 4096 -f "%SSH_KEY_PATH%" -N "" -q
    if !errorlevel! neq 0 (
        call :log_error "SSH密钥生成失败"
        exit /b 1
    )
    call :log_info "SSH密钥已生成"
)

:: 检查是否已配置远程服务器密钥
call :log_info "检查SSH密钥认证配置..."
ssh -o BatchMode=yes -o ConnectTimeout=5 -p %REMOTE_PORT% %REMOTE_USER%@%REMOTE_HOST% "echo OK" >nul 2>&1
if !errorlevel! equ 0 (
    call :log_info "SSH密钥认证已配置，开始上传..."
    set AUTH_METHOD=key
) else (
    call :log_warn "SSH密钥未配置到远程服务器"
    call :log_info "正在配置SSH密钥认证..."
    call :log_info "首次连接需要手动输入一次密码"
    
    :: 使用ssh-copy-id配置密钥（Windows可能不支持，使用手动方式）
    type "%SSH_KEY_PATH%.pub" | ssh -p %REMOTE_PORT% %REMOTE_USER%@%REMOTE_HOST% "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
    if !errorlevel! neq 0 (
        call :log_error "SSH密钥配置失败"
        echo.
        echo 请手动执行以下命令配置SSH密钥：
        echo   type "%SSH_KEY_PATH%.pub" ^| ssh -p %REMOTE_PORT% %REMOTE_USER%@%REMOTE_HOST% "mkdir -p ~/.ssh ^&^& cat ^>^> ~/.ssh/authorized_keys"
        echo.
        exit /b 1
    )
    call :log_info "SSH密钥配置成功"
    set AUTH_METHOD=key
)

:: 创建远程目录
call :log_info "创建远程目录: %REMOTE_PATH%"
ssh -p %REMOTE_PORT% %REMOTE_USER%@%REMOTE_HOST% "mkdir -p %REMOTE_PATH%"
if !errorlevel! neq 0 (
    call :log_error "创建远程目录失败"
    exit /b 1
)

:: 上传文件
call :log_info "开始上传文件..."
for %%F in (%FILES_TO_UPLOAD%) do (
    if exist "%LOCAL_DIR%%%F" (
        call :log_info "  上传: %%F"
        scp -P %REMOTE_PORT% -o StrictHostKeyChecking=no "%LOCAL_DIR%%%F" %REMOTE_USER%@%REMOTE_HOST%:%REMOTE_PATH%/
        if !errorlevel! neq 0 (
            call :log_error "上传失败: %%F"
            exit /b 1
        )
    ) else (
        call :log_warn "  跳过(不存在): %%F"
    )
)

:: 上传目录
call :log_info "开始上传目录..."
for %%D in (%DIRS_TO_UPLOAD%) do (
    if exist "%LOCAL_DIR%%%D\" (
        call :log_info "  上传: %%D/"
        scp -P %REMOTE_PORT% -o StrictHostKeyChecking=no -r "%LOCAL_DIR%%%D" %REMOTE_USER%@%REMOTE_HOST%:%REMOTE_PATH%/
        if !errorlevel! neq 0 (
            call :log_error "上传失败: %%D"
            exit /b 1
        )
    ) else (
        call :log_warn "  跳过(不存在): %%D"
    )
)

call :log_info "文件上传完成"
exit /b 0

:: ============================================
:: 函数：验证上传结果
:: ============================================
:verify_upload
call :log_info "正在验证远程文件..."

:: 创建临时验证脚本
set TEMP_VERIFY_SCRIPT=%TEMP%\cfst_verify_%RANDOM%.sh
(
    echo #!/bin/bash
    echo cd %REMOTE_PATH%
    echo echo "=== 文件列表 ==="
    echo ls -la
    echo echo ""
    echo echo "=== 文件数量 ==="
    echo echo "文件数: $(find . -type f | wc -l)"
    echo echo "目录数: $(find . -type d | wc -l)"
    echo echo ""
    echo echo "=== 必需文件检查 ==="
) > "%TEMP_VERIFY_SCRIPT%"

:: 添加文件检查命令
for %%F in (%FILES_TO_UPLOAD%) do (
    echo [ -f "%REMOTE_PATH%/%%F" ] ^&^& echo "  [OK] %%F" ^|^| echo "  [MISSING] %%F" >> "%TEMP_VERIFY_SCRIPT%"
)

:: 添加目录检查命令
for %%D in (%DIRS_TO_UPLOAD%) do (
    echo [ -d "%REMOTE_PATH%/%%D" ] ^&^& echo "  [OK] %%D/" ^|^| echo "  [MISSING] %%D/" >> "%TEMP_VERIFY_SCRIPT%"
)

:: 执行验证
if !USE_SSHPASS! equ 1 (
    sshpass -p "%REMOTE_PASSWORD%" ssh -p %REMOTE_PORT% -o StrictHostKeyChecking=no %REMOTE_USER%@%REMOTE_HOST% "cd %REMOTE_PATH% && ls -la && echo '' && echo '文件数:' $(find . -type f ^| wc -l) && echo '目录数:' $(find . -type d ^| wc -l)"
) else (
    ssh -p %REMOTE_PORT% -o StrictHostKeyChecking=no %REMOTE_USER%@%REMOTE_HOST% "cd %REMOTE_PATH% && ls -la && echo '' && echo '文件数:' $(find . -type f ^| wc -l) && echo '目录数:' $(find . -type d ^| wc -l)"
)

if !errorlevel! neq 0 (
    call :log_error "验证失败，无法连接到远程服务器"
    del /f /q "%TEMP_VERIFY_SCRIPT%" >nul 2>&1
    exit /b 1
)

del /f /q "%TEMP_VERIFY_SCRIPT%" >nul 2>&1
call :log_info "文件验证完成"
exit /b 0