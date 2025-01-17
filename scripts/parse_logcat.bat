@echo off
setlocal enabledelayedexpansion

:: Parse logcat file for native crashes
::
:: This script parses Android logcat output to extract native crash information
:: including process name, signal number, and stack trace.
::
:: Usage:
::   parse_logcat.bat <logcat_file>
::
:: Arguments:
::   logcat_file    Path to the logcat output file containing native crash information
::
:: Examples:
::   parse_logcat.bat app_crash.log
::   parse_logcat.bat C:\logs\logcat.txt
::
:: Output format:
::   Crash Information:
::   Process: <process_name>
::   Signal: <signal_number>
::
::   Stack Trace:
::   <stack_trace_lines>
::
:: Exit codes:
::   0   Success
::   1   Invalid arguments
::   2   File not found

if "%~1"=="" (
    echo Usage: %~nx0 ^<logcat_file^>
    echo Example: %~nx0 app_crash.log
    exit /b 1
)

set "LOGCAT_FILE=%~1"

if not exist "!LOGCAT_FILE!" (
    echo Error: Logcat file not found: !LOGCAT_FILE!
    exit /b 2
)

python -c "from ndk_tools import LogcatParser; parser = LogcatParser(); crash_info = parser.parse_logcat_file('%LOGCAT_FILE%'); print(f'\nCrash Information:' if crash_info else '\nNo native crash found in logcat file'); print(f'Process: {crash_info.process}\nSignal: {crash_info.signal}\n\nStack Trace:' if crash_info else ''); [print(line) for line in (crash_info.stack_trace if crash_info else [])]"

endlocal 