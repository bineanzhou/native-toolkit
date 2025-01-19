#!/bin/bash

# 设置日志函数
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo "[DEBUG] $1"
    fi
}

# 显示帮助信息的函数
show_help() {
    cat << EOF
Usage: source setup_env.sh [options]

Set up environment variables for NDK tools.

Options:
  -h, --help            Show this help message and exit
  -n, --ndk <path>     Specify Android NDK path (required)
  -s, --symbols <dir>   Specify symbols directory
  -o, --output <dir>    Specify output directory
  -d, --debug          Enable debug logging

Environment Variables (if options not provided):
  ANDROID_NDK_HOME    Android NDK installation path
  SYMBOLS_DIR         Symbols directory path
  OUTPUT_DIR          Output directory path
  DEBUG              Set to 1 to enable debug logging

Example:
  source setup_env.sh -n ~/Android/Sdk/ndk/25.1.8937393 -s ~/symbols -o ~/output
EOF
}

# 检查是否只是显示帮助信息
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

log_debug "Starting environment setup..."

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--ndk)
            if [ -z "$2" ]; then
                log_error "--ndk requires a path argument"
                return 1
            fi
            NDK_PATH="$2"
            log_debug "NDK path set to: $NDK_PATH"
            shift 2
            ;;
        -s|--symbols)
            if [ -z "$2" ]; then
                log_error "--symbols requires a directory argument"
                return 1
            fi
            SYMBOLS_PATH="$2"
            log_debug "Symbols path set to: $SYMBOLS_PATH"
            shift 2
            ;;
        -o|--output)
            if [ -z "$2" ]; then
                log_error "--output requires a directory argument"
                return 1
            fi
            OUTPUT_PATH="$2"
            log_debug "Output path set to: $OUTPUT_PATH"
            shift 2
            ;;
        -d|--debug)
            DEBUG=1
            log_debug "Debug logging enabled"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            log_error "Try 'source setup_env.sh --help' for more information"
            exit 1
            ;;
    esac
done

# 检查必要的参数
if [ -z "$NDK_PATH" ]; then
    if [ -z "$ANDROID_NDK_HOME" ]; then
        log_error "NDK path is required. Use -n option or set ANDROID_NDK_HOME"
        return 1
    else
        NDK_PATH="$ANDROID_NDK_HOME"
        log_debug "Using NDK path from environment: $NDK_PATH"
    fi
fi

# 设置 NDK 路径
export ANDROID_NDK_HOME="$NDK_PATH"
log_info "Setting ANDROID_NDK_HOME=$ANDROID_NDK_HOME"

# 检查 NDK 路径是否存在
if [ ! -d "$ANDROID_NDK_HOME" ]; then
    log_error "NDK path does not exist: $ANDROID_NDK_HOME"
    return 1
fi

# 设置符号表目录（如果提供）
if [ ! -z "$SYMBOLS_PATH" ]; then
    export SYMBOLS_DIR="$SYMBOLS_PATH"
    log_info "Setting SYMBOLS_DIR=$SYMBOLS_DIR"
    # 如果目录不存在则创建
    if [ ! -d "$SYMBOLS_DIR" ]; then
        log_debug "Creating symbols directory: $SYMBOLS_DIR"
        mkdir -p "$SYMBOLS_DIR"
    fi
fi

# 设置输出目录（如果提供）
if [ ! -z "$OUTPUT_PATH" ]; then
    export OUTPUT_DIR="$OUTPUT_PATH"
    log_info "Setting OUTPUT_DIR=$OUTPUT_DIR"
    # 如果目录不存在则创建
    if [ ! -d "$OUTPUT_DIR" ]; then
        log_debug "Creating output directory: $OUTPUT_DIR"
        mkdir -p "$OUTPUT_DIR"
    fi
fi

# 添加脚本目录到 PATH
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export PATH="$SCRIPT_DIR:$PATH"
log_debug "Added $SCRIPT_DIR to PATH"

# 使脚本可执行
log_debug "Making scripts executable"
chmod +x "$SCRIPT_DIR"/*.sh

log_info "Environment setup complete"
log_debug "Final environment variables:"
log_debug "ANDROID_NDK_HOME=$ANDROID_NDK_HOME"
log_debug "SYMBOLS_DIR=${SYMBOLS_DIR:-not set}"
log_debug "OUTPUT_DIR=${OUTPUT_DIR:-not set}"
log_debug "PATH=$PATH" 