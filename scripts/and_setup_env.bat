@echo off
setlocal enabledelayedexpansion

:: 设置颜色代码
set "INFO=[32m"    :: 绿色
set "ERROR=[31m"   :: 红色
set "DEBUG=[36m"   :: 青色
set "RESET=[0m"

:: 设置日志函数
:log_info
echo %INFO%[INFO]%RESET% %*
exit /b 0

:log_error
echo %ERROR%[ERROR]%RESET% %* 1>&2
exit /b 0

:log_debug
if "%DEBUG%"=="1" echo %DEBUG%[DEBUG]%RESET% %*
exit /b 0

:: 显示帮助信息的函数
:show_help
echo Usage: and_setup_env.bat [options]
echo.
echo Set up environment variables for NDK tools.
echo.
echo Options:
echo   -h, --help            Show this help message and exit
echo   -n, --ndk ^<path^>     Specify Android NDK path (required)
echo   -s, --symbols ^<dir^>   Specify symbols directory
echo   -o, --output ^<dir^>    Specify output directory
echo   -d, --debug          Enable debug logging
echo.
echo Environment Variables (if options not provided):
echo   ANDROID_NDK_HOME    Android NDK installation path
echo   SYMBOLS_DIR         Symbols directory path
echo   OUTPUT_DIR          Output directory path
echo   DEBUG              Set to 1 to enable debug logging
echo.
echo Example:
echo   and_setup_env.bat -n C:\Android\Sdk\ndk\25.1.8937393 -s C:\symbols -o C:\output
exit /b 0

:: 主程序开始
if "%~1"=="-h" (
    call :show_help
    goto :end
)
if "%~1"=="--help" (
    call :show_help
    goto :end
)

call :log_debug "Starting environment setup..."

:: 解析命令行参数
:parse_args
if "%~1"=="" goto :main
if "%~1"=="-d" (
    set "DEBUG=1"
    call :log_debug "Debug logging enabled"
    shift
    goto :parse_args
)
if "%~1"=="-n" (
    if "%~2"=="" (
        call :log_error "--ndk requires a path argument"
        goto :error
    )
    set "NDK_PATH=%~2"
    call :log_debug "NDK path set to: %NDK_PATH%"
    shift /2
    goto :parse_args
)
if "%~1"=="--ndk" (
    if "%~2"=="" (
        call :log_error "--ndk requires a path argument"
        goto :error
    )
    set "NDK_PATH=%~2"
    call :log_debug "NDK path set to: %NDK_PATH%"
    shift /2
    goto :parse_args
)
if "%~1"=="-s" (
    if "%~2"=="" (
        call :log_error "--symbols requires a directory argument"
        goto :error
    )
    set "SYMBOLS_PATH=%~2"
    call :log_debug "Symbols path set to: %SYMBOLS_PATH%"
    shift /2
    goto :parse_args
)
if "%~1"=="--symbols" (
    if "%~2"=="" (
        call :log_error "--symbols requires a directory argument"
        goto :error
    )
    set "SYMBOLS_PATH=%~2"
    call :log_debug "Symbols path set to: %SYMBOLS_PATH%"
    shift /2
    goto :parse_args
)
if "%~1"=="-o" (
    if "%~2"=="" (
        call :log_error "--output requires a directory argument"
        goto :error
    )
    set "OUTPUT_PATH=%~2"
    call :log_debug "Output path set to: %OUTPUT_PATH%"
    shift /2
    goto :parse_args
)
if "%~1"=="--output" (
    if "%~2"=="" (
        call :log_error "--output requires a directory argument"
        goto :error
    )
    set "OUTPUT_PATH=%~2"
    call :log_debug "Output path set to: %OUTPUT_PATH%"
    shift /2
    goto :parse_args
)
call :log_error "Unknown option: %1"
call :log_error "Try 'and_setup_env.bat --help' for more information"
goto :error

:main
:: 检查必要的参数
if "%NDK_PATH%"=="" (
    if "%ANDROID_NDK_HOME%"=="" (
        call :log_error "NDK path is required. Use -n option or set ANDROID_NDK_HOME"
        goto :error
    ) else (
        set "NDK_PATH=%ANDROID_NDK_HOME%"
        call :log_debug "Using NDK path from environment: %NDK_PATH%"
    )
)

:: 设置 NDK 路径
set "ANDROID_NDK_HOME=%NDK_PATH%"
call :log_info "Setting ANDROID_NDK_HOME=%ANDROID_NDK_HOME%"

:: 检查 NDK 路径是否存在
if not exist "%ANDROID_NDK_HOME%" (
    call :log_error "NDK path does not exist: %ANDROID_NDK_HOME%"
    goto :error
)

:: 设置符号表目录（如果提供）
if not "%SYMBOLS_PATH%"=="" (
    set "SYMBOLS_DIR=%SYMBOLS_PATH%"
    call :log_info "Setting SYMBOLS_DIR=%SYMBOLS_DIR%"
    :: 如果目录不存在则创建
    if not exist "%SYMBOLS_DIR%" (
        call :log_debug "Creating symbols directory: %SYMBOLS_DIR%"
        mkdir "%SYMBOLS_DIR%"
    )
)

:: 设置输出目录（如果提供）
if not "%OUTPUT_PATH%"=="" (
    set "OUTPUT_DIR=%OUTPUT_PATH%"
    call :log_info "Setting OUTPUT_DIR=%OUTPUT_DIR%"
    :: 如果目录不存在则创建
    if not exist "%OUTPUT_DIR%" (
        call :log_debug "Creating output directory: %OUTPUT_DIR%"
        mkdir "%OUTPUT_DIR%"
    )
)

:: 添加脚本目录到 PATH
set "SCRIPT_DIR=%~dp0"
set "PATH=%SCRIPT_DIR%;%PATH%"
call :log_debug "Added %SCRIPT_DIR% to PATH"

call :log_info "Environment setup complete"
call :log_debug "Final environment variables:"
call :log_debug "ANDROID_NDK_HOME=%ANDROID_NDK_HOME%"
if defined SYMBOLS_DIR call :log_debug "SYMBOLS_DIR=%SYMBOLS_DIR%"
if defined OUTPUT_DIR call :log_debug "OUTPUT_DIR=%OUTPUT_DIR%"
call :log_debug "PATH=%PATH%"

goto :success

:error
endlocal
exit /b 1

:success
endlocal & (
    set "ANDROID_NDK_HOME=%ANDROID_NDK_HOME%"
    if defined SYMBOLS_DIR set "SYMBOLS_DIR=%SYMBOLS_DIR%"
    if defined OUTPUT_DIR set "OUTPUT_DIR=%OUTPUT_DIR%"
    set "PATH=%PATH%"
)
exit /b 0

:end
endlocal
exit /b 0

:: 更新配置文件
:update_shell_config
call :log_info "Updating shell configuration..."
call :log_info "Changes to be made:"
call :log_info "  - Add NDK Tools to PATH"
call :log_info "  - Set ANDROID_NDK_HOME"
if defined SYMBOLS_DIR call :log_info "  - Set SYMBOLS_DIR"
if defined OUTPUT_DIR call :log_info "  - Set OUTPUT_DIR"
echo.

:: 检查用户配置文件
if exist "%USERPROFILE%\.bashrc" (
    set "shell_config=%USERPROFILE%\.bashrc"
) else if exist "%USERPROFILE%\.bash_profile" (
    set "shell_config=%USERPROFILE%\.bash_profile"
) else (
    set "shell_config=%USERPROFILE%\.bashrc"
)

:: 备份配置文件
set "backup_file=%shell_config%.bak.%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "backup_file=%backup_file: =0%"
if exist "%shell_config%" (
    call :log_info "Backing up %shell_config% to %backup_file%"
    copy "%shell_config%" "%backup_file%" >nul
)

:: 检查是否已存在配置
findstr /c:"# NDK Tools PATH" "%shell_config%" >nul 2>&1
if not errorlevel 1 (
    call :log_info "NDK Tools PATH already exists in %shell_config%"
    call :log_info "Updating existing configuration..."
    :: 创建临时文件
    set "temp_file=%TEMP%\ndk_tools_temp.txt"
    type nul > "%temp_file%"
    for /f "usebackq delims=" %%a in ("%shell_config%") do (
        echo %%a | findstr /c:"# NDK Tools PATH" >nul 2>&1
        if errorlevel 1 (
            echo %%a >> "%temp_file%"
        ) else (
            :: 跳过直到空行
            for /f "usebackq delims=" %%b in ("%shell_config%") do (
                if "%%b"=="" goto :continue_copy
            )
            :continue_copy
        )
    )
    move /y "%temp_file%" "%shell_config%" >nul
)

:: 添加新配置
(
    echo.
    echo # NDK Tools PATH
    echo # Added by NDK Tools setup on %date% %time%
    echo # Original config backed up to: %backup_file%
    echo :: Update PATH
    echo if not "%%PATH%%" == "%%PATH:%SCRIPT_DIR%=%%" goto skip_path
    echo set "PATH=%SCRIPT_DIR%;%%PATH%%"
    echo :skip_path
    
    echo :: Set NDK_HOME if not exists
    echo if not defined ANDROID_NDK_HOME (
    echo     set "ANDROID_NDK_HOME=%ANDROID_NDK_HOME%"
    echo )
    if defined SYMBOLS_DIR echo set "SYMBOLS_DIR=%SYMBOLS_DIR%"
    if defined OUTPUT_DIR echo set "OUTPUT_DIR=%OUTPUT_DIR%"
    echo.
) >> "%shell_config%"

call :log_info "Updated %shell_config% with NDK tools configuration"
call :log_info "Backup saved to: %backup_file%"
call :log_info "Please restart your terminal to apply changes"

:: 验证更新
findstr /c:"NDK Tools PATH" "%shell_config%" >nul 2>&1
if errorlevel 1 (
    call :log_error "Failed to update configuration"
    call :log_info "Please restore from backup: %backup_file%"
    exit /b 1
) else (
    call :log_debug "Configuration successfully updated"
)
exit /b 0

:: 打印环境信息
:print_env
echo.
echo Current Environment:
echo ===================
echo PATH entries:
for %%a in ("%PATH:;=" "%") do (
    echo   %%~a
)
echo.
echo NDK Tools:
echo   ANDROID_NDK_HOME=%ANDROID_NDK_HOME%
if defined SYMBOLS_DIR echo   SYMBOLS_DIR=%SYMBOLS_DIR%
if defined OUTPUT_DIR echo   OUTPUT_DIR=%OUTPUT_DIR%
echo.
echo Available Commands:
for %%f in ("%SCRIPT_DIR%\*.bat") do (
    echo   %%~nxf
)
echo.
exit /b 0 