# NDK Tools Library

一个Python工具库，用于简化Android NDK崩溃分析。该库通过封装NDK工具来简化操作，支持解析.dmp文件和logcat崩溃日志，并支持灵活配置参数。支持多平台（Linux、Windows、macOS），并提供Shell和Batch脚本便于使用。

## 功能特性

- 解析.dmp文件：使用ndk-stack工具解析崩溃堆栈
- 解析原生崩溃日志：从logcat输出中提取原生崩溃信息
- 支持灵活配置：配置符号表目录、日志文件路径、NDK路径等
- 跨平台支持：支持Linux、Windows和macOS
- 简化指令：提供Shell和Batch脚本，简化用户操作

## 项目结构

```
ndk_tools/
├── src/
│   ├── __init__.py              # 初始化模块
│   ├── ndk_stack_parser.py      # NDK堆栈解析模块
│   ├── logcat_parser.py         # logcat崩溃日志解析模块
│   ├── config.py                # 配置文件
│   └── utils.py                 # 工具类
├── scripts/               
│   ├── parse_dmp.sh             # 解析.dmp文件的Shell脚本
│   ├── parse_logcat.sh          # 解析logcat崩溃日志的Shell脚本
│   ├── parse_dmp.bat            # 解析.dmp文件的Batch脚本
│   └── parse_logcat.bat         # 解析logcat崩溃日志的Batch脚本
```

## 安装要求

- Python 3.7+
- Android NDK (需要设置ANDROID_NDK_HOME环境变量)

## 使用方法

### 1. 使用Python API

```python
from ndk_tools import NDKStackParser, LogcatParser, Config

# 创建配置
config = Config(
    ndk_path="/path/to/ndk",
    symbols_dir="/path/to/symbols"
)

# 解析DMP文件
parser = NDKStackParser(config)
stack_trace = parser.parse_dump_file("crash.dmp")
print(stack_trace)

# 解析Logcat日志
logcat_parser = LogcatParser()
crash_info = logcat_parser.parse_logcat_file("logcat.txt")
if crash_info:
    print(f"Process: {crash_info.process}")
    print(f"Signal: {crash_info.signal}")
    print("Stack trace:")
    for line in crash_info.stack_trace:
        print(line)
```

### 2. 使用命令行脚本

在Linux/macOS上：
```bash
# 设置环境变量
export ANDROID_NDK_HOME=/path/to/ndk
export SYMBOLS_DIR=/path/to/symbols

# 解析DMP文件
./scripts/parse_dmp.sh crash.dmp $SYMBOLS_DIR
```

在Windows上：
```batch
# 设置环境变量
set ANDROID_NDK_HOME=C:\path\to\ndk
set SYMBOLS_DIR=C:\path\to\symbols

# 解析DMP文件
scripts\parse_dmp.bat crash.dmp %SYMBOLS_DIR%
```

## 环境变量配置

工具库使用以下环境变量：

- `ANDROID_NDK_HOME`: Android NDK的安装路径（必需）
- `SYMBOLS_DIR`: 符号表目录的路径（必需）
- `OUTPUT_DIR`: 输出文件的目录路径（可选）

## 错误处理

工具库会在以下情况抛出异常：

- 环境变量未设置
- NDK路径不存在
- 符号表目录不存在
- DMP文件不存在或无法解析
- ndk-stack工具执行失败

## 贡献指南

1. Fork本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启Pull Request

## 许可证

本项目采用MIT许可证 - 详见 [LICENSE](LICENSE) 文件