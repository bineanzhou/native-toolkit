@echo off

if "%~2"=="" (
    echo Error: Invalid number of arguments
    echo Usage: %0 ^<dmp_file^> ^<symbols_dir^>
    echo Example: %0 crash.dmp C:\path\to\symbols
    exit /b 1
)

set DMP_FILE=%~1
set SYMBOLS_DIR=%~2

if not exist "%DMP_FILE%" (
    echo Error: DMP file not found: %DMP_FILE%
    exit /b 2
)

if not exist "%SYMBOLS_DIR%" (
    echo Error: Symbols directory not found: %SYMBOLS_DIR%
    exit /b 3
)

if "%ANDROID_NDK_HOME%"=="" (
    echo Error: ANDROID_NDK_HOME environment variable not set
    exit /b 1
)

:: Add parent directory to Python path to find ndk_tools module
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PARENT_DIR=%%~fI"
set "PYTHONPATH=%PARENT_DIR%;%PYTHONPATH%"

python -c "from ndk_tools import NDKStackParser, Config; config = Config.from_env(); parser = NDKStackParser(config); print(parser.parse_dump_file('%DMP_FILE%'))" 