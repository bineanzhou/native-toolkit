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
    export PYTHONPATH="${PARENT_DIR}"
else
    export PYTHONPATH="${PARENT_DIR}:${PYTHONPATH}"
fi

# Check if the module directory exists
if [ ! -d "${PARENT_DIR}/src" ]; then
    echo "Error: Python module directory not found: ${PARENT_DIR}/src"
    exit 1
fi

# 设置环境变量
if [ "${VERBOSE}" = "1" ]; then
    export VERBOSE=1
fi

# 获取输入文件的绝对路径
ARGS=()
original_args=("$@")  # 保存原始参数

while [[ $# -gt 0 ]]; do
    log_debug "Processing parameter: $1"

    case "$1" in
        # 如果是文件参数，转换为绝对路径
        *.log|*.txt)
            log_debug "Converting log file path: $1"
            ARGS+=("$(cd "$(dirname "$1")" && pwd)/$(basename "$1")")
            ;;
        # 如果是符号目录参数，转换为绝对路径
        -s|--symbols)
            ARGS+=("$1")
            if [ -n "$2" ]; then
                log_debug "Converting symbols directory path: $2"
                ARGS+=("$(cd "$(dirname "$2")" && pwd)/$(basename "$2")")
                shift
            fi
            ;;
        # 处理输出目录参数
        -o|--output)
            ARGS+=("$1")
            if [ -n "$2" ]; then
                OUTPUT_DIR="$2"  # 设置输出目录
                log_debug "Setting OUTPUT_DIR to: $OUTPUT_DIR"
                ARGS+=("$(cd "$(dirname "$2")" && pwd)/$(basename "$2")")
                shift
            else
                log_error "Output directory not specified after -o"
                exit 1
            fi
            ;;
        # 处理 verbose 参数
        -v|--verbose)
            log_debug "Setting verbose mode"
            ARGS+=("$1")
            VERBOSE=1
            export VERBOSE=1
            ;;
        # 其他参数保持不变
        *)
            log_debug "Adding other parameter: $1"
            ARGS+=("$1")
            ;;
    esac
    shift
done

# 设置默认输出目录
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$(pwd)/output"
    log_info "Setting default OUTPUT_DIR to: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"  # 创建输出目录
fi

# 直接调用 Python 脚本
log_debug "Executing Python script with arguments: ${ARGS[*]}"
PYTHONPATH="${PARENT_DIR}" 
python3 "${PARENT_DIR}/src/ndk_logcat_parser.py" "${ARGS[@]}" 