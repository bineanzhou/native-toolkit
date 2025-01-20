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

# 获取脚本目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TOOLS_DIR="$( dirname "$SCRIPT_DIR" )"

# 显示帮助信息的函数
show_help() {
    cat << EOF
Usage: source and_setup_env.sh [options]

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
  source and_setup_env.sh -n ~/Android/Sdk/ndk/25.1.8937393 -s ~/symbols -o ~/output
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
            log_error "Try 'source and_setup_env.sh --help' for more information"
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

# 更新 shell 配置文件
update_shell_config() {
    log_info "Updating shell configuration..."
    
    # 检测操作系统类型和 shell 配置文件
    local shell_config
    local os_type="$(uname -s)"

    # 根据操作系统和 shell 类型选择配置文件
    case "$SHELL" in
        */bash)
            case "$os_type" in
                Darwin*)  # macOS
                    shell_config="$HOME/.bash_profile"
                    ;;
                Linux*)   # Linux
                    shell_config="$HOME/.bashrc"
                    ;;
                *)
                    log_error "Unsupported operating system: $os_type"
                    return 1
                    ;;
            esac
            ;;
        */zsh)
            shell_config="$HOME/.zshrc"
            ;;
        *)
            log_error "Unsupported shell: $SHELL"
            return 1
            ;;
    esac

    log_debug "Using shell config file: $shell_config"
    
    # 检查现有环境变量
    local need_ndk=false
    local need_update=false
    local need_path=false

    # 检查环境变量是否已经定义且有值
    if [ -z "$ANDROID_NDK_HOME" ]; then
        need_ndk=true
        log_info "  - Will set ANDROID_NDK_HOME"
        need_update=true
    else
        log_debug "ANDROID_NDK_HOME already defined: $ANDROID_NDK_HOME"
        need_ndk=false
    fi

    # 检查 PATH 配置
    log_debug "Checking PATH configuration..."
    # 首先检查配置文件是否存在
    if [ ! -f "$shell_config" ]; then
        log_debug "Creating new shell config file: $shell_config"
        touch "$shell_config"
    fi

    # 检查是否存在被注释的 PATH 配置
    if grep -q "^[[:space:]]*#.*export.*PATH.*native-toolkit/scripts" "$shell_config" 2>/dev/null; then
        need_update=true
        need_path=true
        log_info "  - Will uncomment NDK Tools PATH"
        log_debug "Found commented PATH entry in $shell_config"
    # 检查是否存在未注释但路径不同的配置
    elif grep -q "^export.*PATH=.*native-toolkit/scripts" "$shell_config" 2>/dev/null; then
        need_update=true
        need_path=true
        log_info "  - Will update NDK Tools PATH to current location"
        log_debug "Found outdated PATH entry in $shell_config"
    # 检查当前 PATH 中是否包含脚本目录
    elif [[ ! "$PATH" =~ "$SCRIPT_DIR" ]]; then
        need_path=true
        log_info "  - Will add NDK Tools to PATH"
        log_debug "NDK Tools not found in PATH"
    else
        log_info "NDK Tools already in PATH: $SCRIPT_DIR"
    fi

    log_debug "Checking environment variables..."
    if [ ! -z "$SYMBOLS_DIR" ]; then
        log_debug "SYMBOLS_DIR is set to: $SYMBOLS_DIR"
        log_info "  - Will set SYMBOLS_DIR"
        need_update=true
    fi
    if [ ! -z "$OUTPUT_DIR" ]; then
        log_debug "OUTPUT_DIR is set to: $OUTPUT_DIR"
        log_info "  - Will set OUTPUT_DIR"
        need_update=true
    fi
    echo
    
    if ! $need_update; then
        log_info "No configuration updates needed"
        log_debug "Current environment is properly configured"
    else
        log_info "Configuration updates required"
    fi
    
    # 只在需要更新时才备份和添加注释
    if $need_update; then
        # 备份原配置文件
        local backup_file="${shell_config}.bak.$(date +%Y%m%d_%H%M%S)"
        if [ -f "$shell_config" ]; then
            log_info "Backing up $shell_config to $backup_file"
            cp "$shell_config" "$backup_file"
        fi

        # 添加环境变量配置
        cat << EOF >> "$shell_config"

# NDK Tools PATH
# Added by NDK Tools setup on $(date)
# Original config backed up to: $backup_file
EOF
    fi
    
    # 只在需要时添加 NDK_HOME
    if $need_ndk; then
        export ANDROID_NDK_HOME="$NDK_PATH"
        log_info "Set ANDROID_NDK_HOME=$ANDROID_NDK_HOME"
    fi

    if [ ! -z "$SYMBOLS_DIR" ]; then
        echo "export SYMBOLS_DIR=$SYMBOLS_DIR" >> "$shell_config"
    fi
    
    if [ ! -z "$OUTPUT_DIR" ]; then
        echo "export OUTPUT_DIR=$OUTPUT_DIR" >> "$shell_config"
    fi
    
    # 只在有更新时添加空行
    if $need_update; then
        echo "" >> "$shell_config"
    fi
    
    # 执行更新
    if $need_update; then
        if $need_path; then
            if grep -q "^[[:space:]]*#.*export.*PATH.*native-toolkit/scripts" "$shell_config"; then
                # 取消注释该行
                sed -i "s|^[[:space:]]*#.*export.*PATH.*native-toolkit/scripts.*|export PATH=$SCRIPT_DIR:\$PATH|" "$shell_config"
            elif grep -q "^export.*PATH=.*native-toolkit/scripts" "$shell_config"; then
                # 更新现有路径
                sed -i "s|^export.*PATH=.*native-toolkit/scripts.*|export PATH=$SCRIPT_DIR:\$PATH|" "$shell_config"
            else
                # 添加新的 PATH 配置
                echo "export PATH=$SCRIPT_DIR:\$PATH" >> "$shell_config"
            fi
            # 更新当前会话的 PATH
            export PATH="$SCRIPT_DIR:$PATH"
            log_info "Updated PATH with NDK Tools directory"
        fi
        
        if $need_update; then
            log_info "Updated $shell_config with NDK tools configuration"
            log_info "Backup saved to: $backup_file"
            log_info "Please run 'source $shell_config' to apply changes"
        fi

        # 验证更新
        if $need_update; then
            if grep -q "NDK Tools PATH" "$shell_config"; then
                log_debug "Configuration successfully updated"
            else
                log_error "Failed to update configuration"
                log_info "Please restore from backup: $backup_file"
                return 1
            fi
        fi
    fi
}

# 打印当前环境变量
print_env() {
    echo
    echo "Current Environment:"
    echo "==================="
    echo "PATH entries:"
    echo "$PATH" | tr ':' '\n' | sed 's/^/  /'
    echo
    echo "NDK Tools:"
    echo "  ANDROID_NDK_HOME=$ANDROID_NDK_HOME"
    if [ ! -z "$SYMBOLS_DIR" ]; then
        echo "  SYMBOLS_DIR=$SYMBOLS_DIR"
    fi
    if [ ! -z "$OUTPUT_DIR" ]; then
        echo "  OUTPUT_DIR=$OUTPUT_DIR"
    fi
    echo
    echo "Available Commands:"
    for cmd in "$SCRIPT_DIR"/*.sh; do
        if [ -x "$cmd" ]; then
            echo "  $(basename "$cmd")"
        fi
    done
    echo
}

# 更新shell配置
update_shell_config

# 打印环境信息
print_env

log_info "Environment setup complete" 