@echo off
setlocal enabledelayedexpansion

:: 显示帮助信息的函数
:show_help
echo Usage: ndk_quick_analyze.bat [options] ^<crash_file^>
echo.
echo Quickly analyze Android native crash files (logcat or dmp)
echo.
echo Options:
echo   -h, --help            Show this help message and exit
echo   -s, --symbols ^<dir^>   Specify symbols directory
echo   -n, --ndk ^<path^>     Specify Android NDK path
echo   -o, --output ^<dir^>   Specify output directory
echo.
echo Environment Variables (if options not provided):
echo   ANDROID_NDK_HOME    Android NDK installation path
echo   SYMBOLS_DIR         Symbols directory path
echo   OUTPUT_DIR          Output directory path
echo.
echo Example:
echo   ndk_quick_analyze.bat -n C:\Android\Sdk\ndk\25.1.8937393 -s C:\symbols crash.log
goto :eof 