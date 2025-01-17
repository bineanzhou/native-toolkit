#!/bin/bash

# Parse DMP file using NDK tools
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <dmp_file> <symbols_dir>"
    exit 1
fi

DMP_FILE=$1
SYMBOLS_DIR=$2

# Check if ANDROID_NDK_HOME is set
if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "Error: ANDROID_NDK_HOME environment variable not set"
    exit 1
fi

# Export required environment variables
export SYMBOLS_DIR=$SYMBOLS_DIR

# Run Python script
python3 -c "
from ndk_tools import NDKStackParser, Config
config = Config.from_env()
parser = NDKStackParser(config)
print(parser.parse_dump_file('$DMP_FILE'))
" 