#!/bin/bash

# Parse logcat file for native crashes
#
# This script parses Android logcat output to extract native crash information
# including process name, signal number, and stack trace.

# Function to show help message
show_help() {
    cat << EOF
Usage: $0 [options] <logcat_file>

Parse Android logcat output to extract and analyze native crash information.

Arguments:
  logcat_file    Path to the logcat output file containing native crash information

Options:
  -h, --help            Show this help message and exit
  -s, --symbols <dir>   Path to the directory containing symbol files
                       If not provided, will use SYMBOLS_DIR environment variable

Environment Variables:
  ANDROID_NDK_HOME    Path to Android NDK installation (required for symbolication)
  SYMBOLS_DIR         Alternative way to specify symbols directory

Examples:
  $0 app_crash.log                         # Basic parsing
  $0 -s /path/to/symbols app_crash.log     # Parse with symbols
  $0 --symbols /path/to/symbols app_crash.log
  SYMBOLS_DIR=/path/to/symbols $0 app_crash.log

Output Format:
  Crash Information:
    Process: <process_name>
    Signal: <signal_number>

  Stack Trace:
    <stack_trace_lines>

  Symbolicated Stack Trace: (if symbols provided)
    <symbolicated_stack_trace>

Exit Codes:
  0   Success
  1   Invalid arguments
  2   File not found
  3   Symbols directory not found
EOF
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--symbols)
            if [ -z "$2" ]; then
                echo "Error: --symbols requires a directory argument"
                echo "Try '$0 --help' for more information"
                exit 1
            fi
            SYMBOLS_DIR="$2"
            shift 2
            ;;
        *)
            if [ -z "$LOGCAT_FILE" ]; then
                LOGCAT_FILE="$1"
            else
                echo "Error: Too many arguments"
                echo "Try '$0 --help' for more information"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check required arguments
if [ -z "$LOGCAT_FILE" ]; then
    echo "Error: Logcat file is required"
    echo "Try '$0 --help' for more information"
    exit 1
fi

# Check if logcat file exists
if [ ! -f "$LOGCAT_FILE" ]; then
    echo "Error: Logcat file not found: $LOGCAT_FILE"
    exit 2
fi

# Check if symbols directory exists when provided
if [ -n "$SYMBOLS_DIR" ] && [ ! -d "$SYMBOLS_DIR" ]; then
    echo "Error: Symbols directory not found: $SYMBOLS_DIR"
    exit 3
fi

# Check if ANDROID_NDK_HOME is set when symbols are provided
if [ -n "$SYMBOLS_DIR" ] && [ -z "$ANDROID_NDK_HOME" ]; then
    echo "Error: ANDROID_NDK_HOME environment variable not set (required for symbolication)"
    exit 1
fi

# Add parent directory to Python path to find ndk_tools module
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( dirname "$SCRIPT_DIR" )"
export PYTHONPATH="${PARENT_DIR}:${PYTHONPATH:-}"

# Run Python script
python3 -c "
from ndk_tools import LogcatParser, Config
config = Config(
    ndk_path='${ANDROID_NDK_HOME}',
    symbols_dir='${SYMBOLS_DIR}' if '${SYMBOLS_DIR}' else None
) if '${SYMBOLS_DIR}' else None

parser = LogcatParser()
crash_info = parser.parse_logcat_file('$LOGCAT_FILE')
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
            from ndk_tools import NDKStackParser
            stack_parser = NDKStackParser(config)
            print('\nSymbolicated Stack Trace:')
            print(stack_parser.symbolicate_trace(crash_info.stack_trace))
        except Exception as e:
            print(f'\nFailed to symbolicate: {e}')
else:
    print('No native crash found in logcat file')
" 