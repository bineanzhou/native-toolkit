@echo off
setlocal enabledelayedexpansion

:: 设置日志函数
:log_info
echo [INFO] %*
exit /b 0

:log_error
echo [ERROR] %* 1>&2
exit /b 0

:log_debug
if "%DEBUG%"=="1" echo [DEBUG] %*
exit /b 0

:: 显示帮助信息的函数
:show_help
echo Usage: setup_env.bat [options]
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
echo   setup_env.bat -n C:\Android\Sdk\ndk\25.1.8937393 -s C:\symbols -o C:\output
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
call :log_error "Try 'setup_env.bat --help' for more information"
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