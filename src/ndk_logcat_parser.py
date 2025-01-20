import re
import os
import subprocess
from typing import List, Optional, Dict, Tuple
from dataclasses import dataclass
import logging
import argparse
import sys

# 避免循环导入
if __name__ == '__main__':
    # 当作为主程序运行时，添加父目录到 Python 路径
    import os.path
    parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if parent_dir not in sys.path:
        sys.path.insert(0, parent_dir)

@dataclass
class CrashInfo:
    """Crash information extracted from logcat"""
    process: str
    signal: str
    stack_trace: List[str]
    
class LogcatParser:
    """Parser for native crashes in logcat output"""
    
    # Regular expressions for parsing logcat output
    _SIGNAL_PATTERN = re.compile(
        r'Fatal signal (?P<signal>\d+)\s+\((?P<signal_name>[^)]+)\).*?pid\s+(?P<pid>\d+)\s+\((?P<process>[^)]+)\)'
    )
    _CRASH_PATTERN = re.compile(
        r'DEBUG\s+(?:crash_dump64|pid-\d+)\s+A\s+Cmdline:\s*(?P<process>[^\n]+)'
    )
    _STACK_TRACE_START = re.compile(
        r'DEBUG\s+(?:crash_dump64|pid-\d+)\s+A\s+#00\s+pc'  # 堆栈开始标记
    )
    _FRAME_PATTERN = re.compile(
        r'DEBUG\s+(?:crash_dump64|pid-\d+)\s+A\s+#(?P<frame_num>\d+)\s+pc\s+(?P<addr>[0-9a-f]+)\s+'
        r'(?P<lib_path>(?:\[.*?\]|/[^ ]+))'  # 支持匿名映射和常规库路径
        r'(?:\s+\((?P<symbol>[^)]+)\))?'  # 可选的符号信息
        r'(?:\s+\(BuildId:\s+(?P<build_id>[a-f0-9]+)\))?'  # 可选的BuildId
    )
    _LIB_NAME_PATTERN = re.compile(
        r'/lib/[^/]+/(?P<lib_name>[^/\s]+)$'  # 从路径中提取库名
    )
    _PROCESS_INFO_PATTERN = re.compile(
        r'pid:\s*(?P<pid>\d+).*?name:\s*(?P<process>[^>]+?)\s*>>>'  # 进程信息格式
    )
    _PROCESS_START_PATTERN = re.compile(
        r'PROCESS STARTED.*?for package\s+(?P<package>[^\s]+)'
    )
    _PROCESS_END_PATTERN = re.compile(
        r'PROCESS ENDED.*?for package\s+(?P<package>[^\s]+)'
    )
    
    def __init__(self, symbols_dir: Optional[str] = None, ndk_path: Optional[str] = None, verbose: bool = False):
        self.symbols_dir = symbols_dir
        self.ndk_path = ndk_path
        self._addr2line_cache: Dict[Tuple[str, str], str] = {}
        self.current_build_id = None
        self.verbose = verbose or os.environ.get('VERBOSE') == '1'
        logging.info(f"Symbols directory: {self.symbols_dir}")
        logging.info(f"NDK path: {self.ndk_path}")
        logging.info(f"Verbose mode: {self.verbose}")
        # 检查是否已经配置过日志
        if not logging.getLogger().handlers:
            self._setup_logging()
    
    def _setup_logging(self):
        """设置日志级别和格式"""
        # 首先配置日志
        logging.basicConfig(
            level=logging.DEBUG if self.verbose else logging.INFO,
            format='[%(levelname)s] %(message)s'
        )
        
        # 然后记录日志级别
        level = logging.DEBUG if self.verbose else logging.INFO
        logging.info(f"Logging level set to: {logging.getLevelName(level)}")
    
    def _print_error(self, message: str):
        """Print error message in red"""
        logging.error(f"\033[91m{message}\033[0m")  # 红色文本
    
    def _get_lib_name(self, lib_path: str) -> Optional[str]:
        """Extract library name from path"""
        logging.debug(f"Extracting library name from path: {lib_path}")
        if '[anon:' in lib_path:  # Skip anonymous mappings
            logging.debug("Skipping anonymous mapping")
            return None
            
        match = self._LIB_NAME_PATTERN.search(lib_path)
        lib_name = match.group('lib_name') if match else None
        logging.debug(f"Extracted library name: {lib_name}")
        return match.group('lib_name') if match else None
    
    def _get_addr2line_path(self) -> str:
        """Get path to addr2line executable"""
        if not self.ndk_path:
            raise ValueError("NDK path not set")
            
        if os.name == 'nt':  # Windows
            addr2line = os.path.join(self.ndk_path, 'toolchains', 'llvm', 'prebuilt', 'windows-x86_64', 'bin', 'llvm-addr2line.exe')
        elif os.uname().sysname == 'Darwin':  # macOS
            addr2line = os.path.join(self.ndk_path, 'toolchains', 'llvm', 'prebuilt', 'darwin-x86_64', 'bin', 'llvm-addr2line')
        elif os.name == 'posix':  # Linux
            addr2line = os.path.join(self.ndk_path, 'toolchains', 'llvm', 'prebuilt', 'linux-x86_64', 'bin', 'llvm-addr2line')
        else:
            raise ValueError("Unsupported operating system")
            
        if not os.path.exists(addr2line):
            raise FileNotFoundError(f"addr2line not found at: {addr2line}")
        return addr2line
    
    def _extract_build_id(self, lib_path: str) -> Optional[str]:
        """Extract build ID from library file"""
        try:
            cmd = ['readelf', '-n', lib_path]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            for line in result.stdout.splitlines():
                if 'Build ID:' in line:
                    return line.split(':')[1].strip()
        except:
            pass
        return None
    
    def _get_lib_path(self, lib_name: str) -> Optional[str]:
        """Get path to library in symbols directory"""
        logging.debug(f"Looking for library {lib_name} in symbols directory: {self.symbols_dir}")
        if not self.symbols_dir:
            return None
            
        # Try different architectures
        for arch in ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86']:
            lib_path = os.path.join(self.symbols_dir, arch, lib_name)
            logging.debug(f"Trying path: {lib_path}")
            if os.path.exists(lib_path):
                # Verify build ID if available
                if self.current_build_id:
                    logging.debug(f"Verifying build ID: {self.current_build_id}")
                    build_id = self._extract_build_id(lib_path)
                    logging.debug(f"Found build ID: {build_id}")
                    if build_id and build_id != self.current_build_id:
                        logging.debug("Build ID mismatch, skipping")
                        continue
                logging.debug(f"Found matching library at: {lib_path}")
                return lib_path
        logging.debug("Library not found in any architecture directory")
        return None
    
    def _addr2line(self, lib_path: str, addr: str) -> str:
        """Run addr2line on an address"""
        logging.debug(f"Running addr2line on {lib_path} with address {addr}")
        cache_key = (lib_path, addr)
        if cache_key in self._addr2line_cache:
            return self._addr2line_cache[cache_key]
            
        try:
            cmd = [
                self._get_addr2line_path(),
                '-e', lib_path,
                '-f', '-C', '-p',  # Show function names, demangle, pretty print
                addr
            ]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True
            )
            
            output = result.stdout.strip()
            self._addr2line_cache[cache_key] = output
            return output
            
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            return f"Failed to symbolicate: {e}"
    
    def symbolicate_frame(self, frame: str) -> str:
        """Symbolicate a single stack frame"""
        logging.debug(f"\nSymbolicating frame: {frame}")
        if not (self.symbols_dir and self.ndk_path):
            logging.debug("Symbols or NDK path not set")
            return frame.strip()  # 去掉前后空格
        
        match = self._FRAME_PATTERN.search(frame)
        if not match:
            logging.debug("Frame pattern not matched")
            return frame.strip()
        
        addr = match.group('addr')
        lib_path = match.group('lib_path')
        self.current_build_id = match.group('build_id')
        logging.debug(f"Extracted: addr={addr}, lib_path={lib_path}, build_id={self.current_build_id}")
        
        # Skip Java frames and anonymous mappings
        if '[anon:' in lib_path or 'dalvik' in lib_path.lower():
            logging.debug("Skipping Java/anonymous frame")
            return frame.strip()
        
        lib_name = self._get_lib_name(lib_path)
        if not lib_name:
            logging.debug("Failed to extract library name")
            return frame.strip()
        
        symbol_lib = self._get_lib_path(lib_name)
        if not symbol_lib:
            logging.debug("Failed to find symbol file")
            return frame.strip()
        
        logging.debug(f"Running addr2line for {lib_name} at address {addr}")
        addr2line_output = self._addr2line(symbol_lib, addr)
        logging.debug(f"addr2line output: {addr2line_output}")
        return f"{frame.strip()}\n    {addr2line_output.strip()}"
    
    def parse_logcat_content(self, content: str) -> Optional[CrashInfo]:
        """Parse logcat content and extract native crash information"""
        logging.info("Parsing logcat content...")
        logging.debug(f"Content length: {len(content)} bytes")
        lines = content.splitlines()
        logging.debug(f"Found {len(lines)} lines in logcat")
        
        crash_info = None
        stack_trace = []
        collecting_stack = False
        current_package = None
        
        for line in lines:
            # Look for process start/end
            start_match = self._PROCESS_START_PATTERN.search(line)
            if start_match:
                current_package = start_match.group('package')
                logging.debug(f"Process started: {current_package}")
                continue
                
            end_match = self._PROCESS_END_PATTERN.search(line)
            if end_match and end_match.group('package') == current_package:
                logging.debug(f"Process ended: {current_package}")
                collecting_stack = False
                continue
                
            # Look for crash header
            match = self._SIGNAL_PATTERN.search(line)
            if match:
                logging.info(f"Found crash info: signal={match.group('signal')} ({match.group('signal_name')})")
                crash_info = CrashInfo(
                    process=match.group('process').strip(),
                    signal=f"{match.group('signal')} ({match.group('signal_name')})",
                    stack_trace=[]
                )
                continue
                
            # Look for crash cmdline
            match = self._CRASH_PATTERN.search(line)
            if match and not crash_info:
                logging.info(f"Found crash cmdline: {match.group('process')}")
                crash_info = CrashInfo(
                    process=match.group('process').strip(),
                    signal="",
                    stack_trace=[]
                )
                continue
                
            # Also look for process info
            match = self._PROCESS_INFO_PATTERN.search(line)
            if match and not crash_info:
                logging.info(f"Found process info: process={match.group('process').strip()}")
                crash_info = CrashInfo(
                    process=match.group('process').strip(),
                    signal="",
                    stack_trace=[]
                )
                continue
                
            # Start collecting stack trace after seeing stack trace marker
            if self._STACK_TRACE_START.search(line):
                logging.debug("Found start of stack trace")
                collecting_stack = True
                
            # Collect stack trace lines
            if collecting_stack and 'DEBUG' in line and ('crash_dump64' in line or 'pid-' in line) and '#' in line:
                logging.debug(f"\nProcessing stack frame: {line}")
                if self.symbols_dir and self.ndk_path:
                    frame_line = self.symbolicate_frame(line)
                else:
                    frame_line = line.split('A        ')[1].strip()
                logging.debug(f"Processed frame: {frame_line}")
                stack_trace.append(frame_line)
                
        if crash_info:
            crash_info.stack_trace = stack_trace
            
        return crash_info
    
    def parse_logcat_file(self, logcat_file: str) -> Optional[CrashInfo]:
        """Parse logcat file and extract native crash information"""
        logging.info(f"Starting to parse logcat file: {logcat_file}")
        if not os.path.exists(logcat_file):
            self._print_error(f"Logcat file not found: {logcat_file}")
            return None
        
        logging.debug("Reading logcat file content...")
        with open(logcat_file, 'r') as f:
            content = f.read()
        logging.debug(f"Read {len(content)} bytes from logcat file")
        return self.parse_logcat_content(content)
    
    def symbolicate_trace(self, stack_trace: List[str]) -> str:
        """Symbolicate stack trace using addr2line"""
        if not (self.symbols_dir and self.ndk_path):
            return '\n'.join(stack_trace)
            
        symbolicated_frames = []
        for frame in stack_trace:
            symbolicated_frame = self.symbolicate_frame(frame)
            symbolicated_frames.append(symbolicated_frame)
            
        return '\n'.join(symbolicated_frames)

def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description='Parse Android logcat output to extract and analyze native crash information.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
 Examples:
   %(prog)s app_crash.log                         # Basic parsing
   %(prog)s -s /path/to/symbols app_crash.log     # Parse with symbols
   %(prog)s -s /path/to/symbols -v app_crash.log  # Parse with verbose logging
   %(prog)s -n /path/to/ndk -s /path/to/symbols app_crash.log
 
 Environment Variables:
   ANDROID_NDK_HOME    Path to Android NDK installation (required for symbolication)
   SYMBOLS_DIR         Alternative way to specify symbols directory
   VERBOSE            Set to 1 to enable verbose logging
 
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
   4   NDK path not found
 '''
    )
    
    # 修改参数解析逻辑
    args = []
    i = 1
    while i < len(sys.argv):
        if sys.argv[i] == '-v' or sys.argv[i] == '--verbose':
            os.environ['VERBOSE'] = '1'
            i += 1
            continue
        args.append(sys.argv[i])
        i += 1
    
    parser.add_argument(
        'logcat_file',
        help='Path to the logcat output file containing native crash information'
    )
    parser.add_argument(
        '-s', '--symbols',
        help='Path to the directory containing symbol files. Required for symbolication.',
        metavar='DIR'
    )
    parser.add_argument(
        '-n', '--ndk',
        help='Path to Android NDK installation. Required for symbolication if ANDROID_NDK_HOME is not set.',
        metavar='PATH'
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Enable verbose logging'
    )
    parsed_args = parser.parse_args(args)
    # 确保 verbose 标志与环境变量同步
    parsed_args.verbose = os.environ.get('VERBOSE') == '1'
    return parsed_args

def main():
    """Main entry point"""
    print("Starting main function...")
    args = parse_args()
    print(f"Parsed arguments: {args}")  # 现在应该显示正确的 verbose 值
    
    parser = LogcatParser(
        symbols_dir=args.symbols,
        ndk_path=args.ndk or os.environ.get('ANDROID_NDK_HOME'),
        verbose=args.verbose or os.environ.get('VERBOSE') == '1'  # 确保两种方式都能设置 verbose
    )
    print("Created LogcatParser instance")  # 添加调试输出
    
    # 解析日志文件
    crash_info = parser.parse_logcat_file(args.logcat_file)
    
    # 输出结果
    if crash_info:
        if args.verbose:
            logging.debug('Found crash information')
        print(f'\nCrash Information:')
        print(f'Process: {crash_info.process}')
        print(f'Signal: {crash_info.signal}')
        print('\nStack Trace:')
        for line in crash_info.stack_trace:
            print(line.strip())
    else:
        if args.verbose:
            logging.debug('No native crash found')
        print('No native crash found in logcat file')

if __name__ == '__main__':
    main() 