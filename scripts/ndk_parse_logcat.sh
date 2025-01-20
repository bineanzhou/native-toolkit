#!/bin/bash

# Parse logcat file for native crashes
#
# This script parses Android logcat output to extract native crash information
# including process name, signal number, and stack trace.

# 设置日志函数
VERBOSE=0

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_debug() {
    if [ "${VERBOSE:-0}" = "1" ]; then
        echo "[DEBUG] $1"
    fi
}

log_detail() {
    if [ "${VERBOSE:-0}" = "1" ]; then
        echo "[DETAIL] $1"
    fi
}

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
  -v, --verbose        Enable verbose logging

Environment Variables:
  ANDROID_NDK_HOME    Path to Android NDK installation (required for symbolication)
  SYMBOLS_DIR         Alternative way to specify symbols directory

Examples:
  $0 app_crash.log                         # Basic parsing
  $0 -s /path/to/symbols app_crash.log     # Parse with symbols
  $0 -s /path/to/symbols -v app_crash.log  # Parse with verbose logging
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
        -v|--verbose)
            VERBOSE=1
            export DEBUG=1  # 设置 DEBUG 环境变量用于 Python 脚本
            log_debug "Verbose logging enabled"
            shift
            ;;
        -s|--symbols)
            if [ -z "$2" ]; then
                log_error "--symbols requires a directory argument"
                exit 1
            fi
            SYMBOLS_DIR="$2"
            log_debug "Symbols directory set to: $SYMBOLS_DIR"
            shift 2
            ;;
        *)
            if [ -z "$LOGCAT_FILE" ]; then
                LOGCAT_FILE="$1"
                log_debug "Logcat file set to: $LOGCAT_FILE"
            else
                log_error "Unknown option: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check required arguments
if [ -z "$LOGCAT_FILE" ]; then
    log_error "Logcat file is required"
    exit 1
fi

# Check if logcat file exists
if [ ! -f "$LOGCAT_FILE" ]; then
    log_error "Logcat file not found: $LOGCAT_FILE"
    exit 2
fi

log_info "Analyzing logcat file: $LOGCAT_FILE"

# Check if symbols directory exists when provided
if [ -n "$SYMBOLS_DIR" ] && [ ! -d "$SYMBOLS_DIR" ]; then
    log_error "Symbols directory not found: $SYMBOLS_DIR"
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

# 检查并更新 PATH
if [[ ! "$PATH" =~ "$SCRIPT_DIR" ]]; then
    export PATH="$SCRIPT_DIR:$PATH"
    log_info "Added $SCRIPT_DIR to PATH"
else
    log_debug "Scripts directory already in PATH"
fi

# Ensure PYTHONPATH is set correctly with absolute paths
if [ -z "${PYTHONPATH}" ]; then
    export PYTHONPATH="${PARENT_DIR}/src"
else
    export PYTHONPATH="${PARENT_DIR}/src:${PYTHONPATH}"
fi

# Check if the module directory exists
if [ ! -d "${PARENT_DIR}/src" ]; then
    echo "Error: Python module directory not found: ${PARENT_DIR}/src"
    exit 1
fi

# Run Python script
python3 -c "
import sys
sys.path.insert(0, '${PARENT_DIR}')
from src.ndk_logcat_parser import LogcatParser
from src.config import Config

def log_detail(msg):
    if ${VERBOSE:-0}:
        print(f'[DETAIL] {msg}')

config = Config(
    ndk_path='${ANDROID_NDK_HOME}',
    symbols_dir='${SYMBOLS_DIR}' if '${SYMBOLS_DIR}' else None
) if '${SYMBOLS_DIR}' else None

parser = LogcatParser(
    symbols_dir='${SYMBOLS_DIR}' if '${SYMBOLS_DIR}' else None,
    ndk_path='${ANDROID_NDK_HOME}' if '${SYMBOLS_DIR}' else None,
    verbose=${VERBOSE:-0}
)

crash_info = parser.parse_logcat_file('$LOGCAT_FILE')
if crash_info:
    log_detail('Found crash information')
    print(f'\nCrash Information:')
    print(f'Process: {crash_info.process}')
    print(f'Signal: {crash_info.signal}')
    print('\nStack Trace:')
    for line in crash_info.stack_trace:
        print(line.strip())
else:
    log_detail('No native crash found')
    print('No native crash found in logcat file')
" 