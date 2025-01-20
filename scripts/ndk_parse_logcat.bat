@echo off
setlocal enabledelayedexpansion

:: 检查并更新 PATH
call :check_and_update_path "%~dp0"

:: 设置日志变量
set "VERBOSE=0"

:: 设置日志函数
:log_info
echo [INFO] %*
exit /b 0

:log_error
echo [ERROR] %* 1>&2
exit /b 0

:log_debug
if "%VERBOSE%"=="1" echo [DEBUG] %*
exit /b 0

:log_detail
if "%VERBOSE%"=="1" echo [DETAIL] %*
exit /b 0

:: Function to show help message
:show_help
echo Usage: %~nx0 [options] ^<logcat_file^>
echo.
echo Parse Android logcat output to extract and analyze native crash information.
echo.
echo Arguments:
echo   logcat_file    Path to the logcat output file containing native crash information
echo.
echo Options:
echo   -h, --help            Show this help message and exit
echo   -s, --symbols ^<dir^>   Path to the directory containing symbol files
echo                        If not provided, will use SYMBOLS_DIR environment variable
echo   -v, --verbose        Enable verbose logging
echo.
echo Environment Variables:
echo   ANDROID_NDK_HOME    Path to Android NDK installation (required for symbolication)
echo   SYMBOLS_DIR         Alternative way to specify symbols directory
echo.
echo Examples:
echo   %~nx0 app_crash.log                         # Basic parsing
echo   %~nx0 -s C:\path\to\symbols app_crash.log   # Parse with symbols
echo   %~nx0 -s C:\path\to\symbols -v app_crash.log # Parse with verbose logging
echo   set SYMBOLS_DIR=C:\symbols ^&^& %~nx0 app_crash.log
echo.
echo Output Format:
echo   Crash Information:
echo     Process: ^<process_name^>
echo     Signal: ^<signal_number^>
echo.
echo   Stack Trace:
echo     ^<stack_trace_lines^>
echo.
echo   Symbolicated Stack Trace: (if symbols provided)
echo     ^<symbolicated_stack_trace^>
echo.
echo Exit Codes:
echo   0   Success
echo   1   Invalid arguments
echo   2   File not found
echo   3   Symbols directory not found
goto :eof

:: Parse command line options
:parse_args
if "%~1"=="" (
    echo Error: Logcat file is required
    echo Try '%~nx0 --help' for more information
    exit /b 1
)

if "%~1"=="-h" (
    call :show_help
    exit /b 0
)

if "%~1"=="--help" (
    call :show_help
    exit /b 0
)

if "%~1"=="-v" (
    set "VERBOSE=1"
    set "DEBUG=1"
    call :log_debug "Verbose logging enabled"
    shift
    goto :parse_args
)

if "%~1"=="--verbose" (
    set "VERBOSE=1"
    set "DEBUG=1"
    call :log_debug "Verbose logging enabled"
    shift
    goto :parse_args
)

if "%~1"=="-s" (
    if "%~2"=="" (
        call :log_error "--symbols requires a directory argument"
        exit /b 1
    )
    set "SYMBOLS_DIR=%~2"
    call :log_debug "Symbols directory set to: %SYMBOLS_DIR%"
    shift /2
    goto :parse_args
)

if "%~1"=="--symbols" (
    if "%~2"=="" (
        echo Error: --symbols requires a directory argument
        exit /b 1
    )
    set "SYMBOLS_DIR=%~2"
    shift /2
    goto :parse_args
)

set "LOGCAT_FILE=%~1"

if not exist "!LOGCAT_FILE!" (
    echo Error: Logcat file not found: !LOGCAT_FILE!
    exit /b 2
)

if defined SYMBOLS_DIR (
    if not exist "!SYMBOLS_DIR!" (
        echo Error: Symbols directory not found: !SYMBOLS_DIR!
        exit /b 3
    )
)

# Check if ANDROID_NDK_HOME is set when symbols are provided
if defined SYMBOLS_DIR (
    if not defined ANDROID_NDK_HOME (
        echo Error: ANDROID_NDK_HOME environment variable not set (required for symbolication)
        exit /b 1
    )
)

:: Add parent directory to Python path to find ndk_tools module
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PARENT_DIR=%%~fI"

:: Ensure PYTHONPATH is set correctly with absolute paths
if defined PYTHONPATH (
    set "PYTHONPATH=%PARENT_DIR%;%PYTHONPATH%"
) else (
    set "PYTHONPATH=%PARENT_DIR%"
)

:: Debug information
echo Using PYTHONPATH: %PYTHONPATH%

:: Check if the module directory exists
if not exist "%PARENT_DIR%\src" (
    echo Error: Python module directory not found: %PARENT_DIR%\src
    exit /b 1
)

:: 设置环境变量
if "%VERBOSE%"=="1" (
    set "VERBOSE=1"
)

:: 获取输入文件的绝对路径
set "ARGS="
:parse_path
if "%~1"=="" goto :run_script

:: 如果是文件参数，转换为绝对路径
if "%~x1"==".log" (
    set "ARGS=!ARGS! "%~f1""
) else if "%~x1"==".txt" (
    set "ARGS=!ARGS! "%~f1""
) else if "%~1"=="-s" (
    set "ARGS=!ARGS! -s"
    if not "%~2"=="" (
        set "ARGS=!ARGS! "%~f2""
        shift
    )
) else if "%~1"=="--symbols" (
    set "ARGS=!ARGS! --symbols"
    if not "%~2"=="" (
        set "ARGS=!ARGS! "%~f2""
        shift
    )
) else (
    set "ARGS=!ARGS! %1"
)
shift
goto :parse_path

:run_script
:: 直接调用 Python 脚本
set "PYTHONPATH=%PARENT_DIR%" && python "%PARENT_DIR%\src\ndk_logcat_parser.py" %ARGS%

endlocal 

:check_and_update_path
setlocal
set "script_dir=%~1"
echo %PATH% | findstr /i /c:"%script_dir%" >nul
if errorlevel 1 (
    set "PATH=%script_dir%;%PATH%"
    echo [INFO] Added %script_dir% to PATH
) else (
    echo [DEBUG] Scripts directory already in PATH
)
endlocal & set "PATH=%PATH%"
goto :eof 