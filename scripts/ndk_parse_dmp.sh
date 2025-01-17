#!/bin/bash

# Parse DMP file using NDK tools
if [ "$#" -ne 2 ]; then
    echo "Error: Invalid number of arguments"
    echo "Usage: $0 <dmp_file> <symbols_dir>"
    echo "Example: $0 crash.dmp /path/to/symbols"
    exit 1
fi

DMP_FILE=$1
SYMBOLS_DIR=$2

# Check if DMP file exists
if [ ! -f "$DMP_FILE" ]; then
    echo "Error: DMP file not found: $DMP_FILE"
    exit 2
fi

# Check if symbols directory exists
if [ ! -d "$SYMBOLS_DIR" ]; then
    echo "Error: Symbols directory not found: $SYMBOLS_DIR"
    exit 3
fi

# Check if ANDROID_NDK_HOME is set
if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "Error: ANDROID_NDK_HOME environment variable not set"
    exit 1
fi

# Export required environment variables
export SYMBOLS_DIR=$SYMBOLS_DIR

# Add parent directory to Python path to find ndk_tools module
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( dirname "$SCRIPT_DIR" )"
export PYTHONPATH="${PARENT_DIR}:${PYTHONPATH:-}"

# Run Python script
python3 -c "
from ndk_tools import NDKStackParser, Config
config = Config.from_env()
parser = NDKStackParser(config)
print(parser.parse_dump_file('$DMP_FILE'))
" 