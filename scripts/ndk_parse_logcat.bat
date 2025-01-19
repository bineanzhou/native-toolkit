@echo off
setlocal enabledelayedexpansion

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
echo.
echo Environment Variables:
echo   ANDROID_NDK_HOME    Path to Android NDK installation (required for symbolication)
echo   SYMBOLS_DIR         Alternative way to specify symbols directory
echo.
echo Examples:
echo   %~nx0 app_crash.log                         # Basic parsing
echo   %~nx0 -s C:\path\to\symbols app_crash.log   # Parse with symbols
echo   %~nx0 --symbols C:\path\to\symbols app_crash.log
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

if "%~1"=="-s" (
    if "%~2"=="" (
        echo Error: --symbols requires a directory argument
        exit /b 1
    )
    set "SYMBOLS_DIR=%~2"
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
    set "PYTHONPATH=%PARENT_DIR%\src;%PYTHONPATH%"
) else (
    set "PYTHONPATH=%PARENT_DIR%\src"
)

:: Debug information
echo Using PYTHONPATH: %PYTHONPATH%

:: Check if the module directory exists
if not exist "%PARENT_DIR%\src" (
    echo Error: Python module directory not found: %PARENT_DIR%\src
    exit /b 1
)

python -c "
import sys
sys.path.insert(0, r'%PARENT_DIR%')
from src.ndk_logcat_parser import LogcatParser
from src.config import Config

config = Config(
    ndk_path=r'%ANDROID_NDK_HOME%',
    symbols_dir=r'%SYMBOLS_DIR%' if '%SYMBOLS_DIR%' else None
) if '%SYMBOLS_DIR%' else None

parser = LogcatParser()
crash_info = parser.parse_logcat_file(r'%LOGCAT_FILE%')
if crash_info:
    print(f'\nCrash Information:')
    print(f'Process: {crash_info.process}')
    print(f'Signal: {crash_info.signal}')
    print('\nStack Trace:')
    for line in crash_info.stack_trace:
        print(line)
    
    # Try to symbolicate if symbols are available
    if config and config.symbols_dir:
        try:
            from src.ndk_stack_parser import NDKStackParser
            stack_parser = NDKStackParser(config)
            print('\nSymbolicated Stack Trace:')
            print(stack_parser.symbolicate_trace(crash_info.stack_trace))
        except Exception as e:
            print(f'\nFailed to symbolicate: {e}')
else:
    print('No native crash found in logcat file')
"

endlocal 