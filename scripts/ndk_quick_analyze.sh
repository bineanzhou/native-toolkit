#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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

# 显示帮助信息的函数
show_help() {
    cat << EOF
Usage: ndk_quick_analyze.sh [options] <crash_file>

Quickly analyze Android native crash files (logcat or dmp)

Options:
  -h, --help            Show this help message and exit
  -s, --symbols <dir>   Specify symbols directory
  -n, --ndk <path>     Specify Android NDK path
  -o, --output <dir>    Specify output directory
  -v, --verbose        Enable verbose logging

Environment Variables (if options not provided):
  ANDROID_NDK_HOME    Android NDK installation path
  SYMBOLS_DIR         Symbols directory path
  OUTPUT_DIR          Output directory path

Example:
  ./ndk_quick_analyze.sh -n ~/Android/Sdk/ndk/25.1.8937393 -s ~/symbols -v crash.log
EOF
}

# 处理错误的函数
handle_error() {
    echo "Error: $1"
    show_help
    exit 1
}

# 解析命令行参数的函数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--symbols)
                SYMBOLS_DIR="$2"
                shift 2
                ;;
            -n|--ndk)
                ANDROID_NDK_HOME="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=1
                log_debug "Verbose logging enabled"
                shift
                ;;
            *)
                CRASH_FILE="$1"
                shift
                ;;
        esac
    done
}

# 检查必要的参数
check_required_args() {
    if [ -z "$CRASH_FILE" ]; then
        handle_error "No crash file specified"
    fi
}

# 解析文件并调用相应的解析脚本
analyze_file() {
    if [[ "$CRASH_FILE" == *.dmp ]]; then
        if [ -z "$SYMBOLS_DIR" ]; then
            handle_error "Symbols directory is required for DMP files"
        fi
        log_info "Processing dump file: $CRASH_FILE"
        if [ "${VERBOSE}" = "1" ]; then
            export DEBUG=1
        fi
        "$SCRIPT_DIR/ndk_parse_dmp.sh" "$CRASH_FILE" "$SYMBOLS_DIR"
    else
        ARGS=()
        if [ -n "$SYMBOLS_DIR" ]; then
            ARGS+=("-s" "$SYMBOLS_DIR")
        fi
        if [ -n "$OUTPUT_DIR" ]; then
            ARGS+=("-o" "$OUTPUT_DIR")
        fi  
        if [ "$VERBOSE" = "1" ]; then
            ARGS+=("-v")
        fi
        ARGS+=("$CRASH_FILE")
        "$SCRIPT_DIR/ndk_parse_logcat.sh" "${ARGS[@]}"
        # if [ -n "$SYMBOLS_DIR" ]; then            
        #     "$SCRIPT_DIR/ndk_parse_logcat.sh" -s "$SYMBOLS_DIR" "$CRASH_FILE"
        # else
        #     "$SCRIPT_DIR/ndk_parse_logcat.sh" "$CRASH_FILE"
        # fi
    fi
}

# 主程序逻辑
parse_args "$@"
check_required_args
analyze_file

# 检查执行结果
if [ $? -eq 0 ]; then
    log_info "Analysis completed successfully"
    log_detail "Output saved to: $OUTPUT_DIR"
else
    log_error "Analysis failed"
    exit 1
fi
