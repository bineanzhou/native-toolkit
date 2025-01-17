#!/bin/bash

# Parse logcat file for native crashes
#
# This script parses Android logcat output to extract native crash information
# including process name, signal number, and stack trace.
#
# Usage:
#   ./parse_logcat.sh <logcat_file>
#
# Arguments:
#   logcat_file    Path to the logcat output file containing native crash information
#
# Examples:
#   ./parse_logcat.sh app_crash.log
#   ./parse_logcat.sh /path/to/logcat.txt
#
# Output format:
#   Crash Information:
#   Process: <process_name>
#   Signal: <signal_number>
#
#   Stack Trace:
#   <stack_trace_lines>
#
# Exit codes:
#   0   Success
#   1   Invalid arguments
#   2   File not found

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <logcat_file>"
    echo "Example: $0 app_crash.log"
    exit 1
fi

LOGCAT_FILE=$1

# Check if file exists
if [ ! -f "$LOGCAT_FILE" ]; then
    echo "Error: Logcat file not found: $LOGCAT_FILE"
    exit 2
fi

# Run Python script
python3 -c "
from ndk_tools import LogcatParser
parser = LogcatParser()
crash_info = parser.parse_logcat_file('$LOGCAT_FILE')
if crash_info:
    print(f'\nCrash Information:')
    print(f'Process: {crash_info.process}')
    print(f'Signal: {crash_info.signal}')
    print('\nStack Trace:')
    for line in crash_info.stack_trace:
        print(line)
else:
    print('No native crash found in logcat file')
" 