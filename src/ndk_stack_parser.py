import os
import subprocess
from typing import Optional
from .config import Config
import logging

class NDKStackParser:
    """Parser for NDK crash dumps using ndk-stack tool"""
    
    def __init__(self, config: Config):
        self.config = config
        self.config.validate()
        self._ndk_stack_path = self._get_ndk_stack_path()
        self.verbose = os.environ.get('VERBOSE') == '1'
        
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
        logging.debug(f"Logging level set to: {logging.getLevelName(level)}")
    
    def _get_ndk_stack_path(self) -> str:
        """Get path to ndk-stack executable"""
        if os.name == 'nt':  # Windows
            ndk_stack = os.path.join(self.config.ndk_path, 'ndk-stack.exe')
        else:  # Linux/MacOS
            ndk_stack = os.path.join(self.config.ndk_path, 'ndk-stack')
            
        if not os.path.exists(ndk_stack):
            logging.error(f"ndk-stack not found at: {ndk_stack}")
            raise FileNotFoundError(f"ndk-stack not found at: {ndk_stack}")
        return ndk_stack
    
    def _get_addr2line_path(self) -> str:
        """Get path to addr2line executable"""
        if not self.config.ndk_path:
            raise ValueError("NDK path not set")
            
        if os.name == 'nt':  # Windows
            addr2line = os.path.join(self.config.ndk_path, 'toolchains', 'llvm', 'prebuilt', 'windows-x86_64', 'bin', 'llvm-addr2line.exe')
        elif os.uname().sysname == 'Darwin':  # macOS
            addr2line = os.path.join(self.config.ndk_path, 'toolchains', 'llvm', 'prebuilt', 'darwin-x86_64', 'bin', 'llvm-addr2line')
        elif os.name == 'posix':  # Linux
            addr2line = os.path.join(self.config.ndk_path, 'toolchains', 'llvm', 'prebuilt', 'linux-x86_64', 'bin', 'llvm-addr2line')
        else:
            raise ValueError("Unsupported operating system")
            
        if not os.path.exists(addr2line):
            raise FileNotFoundError(f"addr2line not found at: {addr2line}")
        return addr2line
    
    def _print_error(self, message: str):
        """Print error message in red"""
        logging.error(f"\033[91m{message}\033[0m")  # 红色文本
    
    def parse_dump_file(self, dump_file: str, output_file: Optional[str] = None) -> str:
        """Parse a .dmp file and return symbolicated stack trace"""
        logging.info(f"Starting to parse dump file: {dump_file}")
        if not os.path.exists(dump_file):
            self._print_error(f"Dump file not found: {dump_file}")
            raise FileNotFoundError(f"Dump file not found: {dump_file}")
            
        logging.debug(f"Using ndk-stack path: {self._ndk_stack_path}")
        logging.debug(f"Using symbols directory: {self.config.symbols_dir}")
        cmd = [
            self._ndk_stack_path,
            '-sym', self.config.symbols_dir,
            '-dump', dump_file
        ]
        
        try:
            logging.debug(f"Running command: {' '.join(cmd)}")
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True
            )
            
            symbolicated_trace = result.stdout
            logging.debug(f"Symbolication successful, output length: {len(symbolicated_trace)}")
            
            if output_file:
                logging.info(f"Writing output to file: {output_file}")
                with open(output_file, 'w') as f:
                    f.write(symbolicated_trace)
                    
            return symbolicated_trace
            
        except subprocess.CalledProcessError as e:
            logging.error(f"Failed to parse dump file: {e.stderr}")
            raise RuntimeError(f"Failed to parse dump file: {e.stderr}") 