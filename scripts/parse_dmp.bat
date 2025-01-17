@echo off

if "%~2"=="" (
    echo Usage: %0 ^<dmp_file^> ^<symbols_dir^>
    exit /b 1
)

set DMP_FILE=%~1
set SYMBOLS_DIR=%~2

if "%ANDROID_NDK_HOME%"=="" (
    echo Error: ANDROID_NDK_HOME environment variable not set
    exit /b 1
)

python -c "from ndk_tools import NDKStackParser, Config; config = Config.from_env(); parser = NDKStackParser(config); print(parser.parse_dump_file('%DMP_FILE%'))" 