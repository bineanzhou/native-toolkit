import re
import os
import subprocess
from typing import List, Optional, Dict, Tuple
from dataclasses import dataclass

@dataclass
class CrashInfo:
    """Crash information extracted from logcat"""
    process: str
    signal: str
    stack_trace: List[str]
    
class LogcatParser:
    """Parser for native crashes in logcat output"""
    
    # Regular expressions for parsing logcat output
    _CRASH_PATTERN = re.compile(
        r'pid:\s*(?P<pid>\d+).*?name:\s*(?P<process>[^>]+?)\s*>>>'  # 进程信息格式
    )
    _STACK_TRACE_START = re.compile(
        r'DEBUG\s+crash_dump64\s+A\s+#00\s+pc'  # 堆栈开始标记
    )
    _FRAME_PATTERN = re.compile(
        r'DEBUG\s+crash_dump64\s+A\s+#(?P<frame_num>\d+)\s+pc\s+(?P<addr>[0-9a-f]+)\s+'
        r'(?P<lib_path>(?:\[.*?\]|/[^ ]+))'  # 支持匿名映射和常规库路径
        r'(?:\s+\((?P<symbol>[^)]+)\))?'  # 可选的符号信息
        r'(?:\s+\(BuildId:\s+(?P<build_id>[a-f0-9]+)\))?'  # 可选的BuildId
    )
    _LIB_NAME_PATTERN = re.compile(
        r'/lib/[^/]+/(?P<lib_name>[^/\s]+)$'  # 从路径中提取库名
    )
    
    def __init__(self, symbols_dir: Optional[str] = None, ndk_path: Optional[str] = None):
        self.symbols_dir = symbols_dir
        self.ndk_path = ndk_path
        self._addr2line_cache: Dict[Tuple[str, str], str] = {}
        self.current_build_id = None
    
    def _get_lib_name(self, lib_path: str) -> Optional[str]:
        """Extract library name from path"""
        if '[anon:' in lib_path:  # Skip anonymous mappings
            return None
            
        match = self._LIB_NAME_PATTERN.search(lib_path)
        return match.group('lib_name') if match else None
    
    def _get_addr2line_path(self) -> str:
        """Get path to addr2line executable"""
        if not self.ndk_path:
            raise ValueError("NDK path not set")
            
        if os.name == 'nt':  # Windows
            addr2line = os.path.join(self.ndk_path, 'toolchains', 'llvm', 'prebuilt', 'windows-x86_64', 'bin', 'llvm-addr2line.exe')
        else:  # Linux/MacOS
            addr2line = os.path.join(self.ndk_path, 'toolchains', 'llvm', 'prebuilt', 'linux-x86_64', 'bin', 'llvm-addr2line')
            
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
        if not self.symbols_dir:
            return None
            
        # Try different architectures
        for arch in ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86']:
            lib_path = os.path.join(self.symbols_dir, arch, lib_name)
            if os.path.exists(lib_path):
                # Verify build ID if available
                if self.current_build_id:
                    build_id = self._extract_build_id(lib_path)
                    if build_id and build_id != self.current_build_id:
                        continue
                return lib_path
        return None
    
    def _addr2line(self, lib_path: str, addr: str) -> str:
        """Run addr2line on an address"""
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
        if not (self.symbols_dir and self.ndk_path):
            return frame
            
        match = self._FRAME_PATTERN.search(frame)
        if not match:
            return frame
            
        addr = match.group('addr')
        lib_path = match.group('lib_path')
        self.current_build_id = match.group('build_id')
        
        # Skip Java frames and anonymous mappings
        if '[anon:' in lib_path or 'dalvik' in lib_path.lower():
            return frame
            
        lib_name = self._get_lib_name(lib_path)
        if not lib_name:
            return frame
            
        symbol_lib = self._get_lib_path(lib_name)
        if not symbol_lib:
            return frame
            
        addr2line_output = self._addr2line(symbol_lib, addr)
        return f"{frame}\n    {addr2line_output}"
    
    def parse_logcat_content(self, content: str) -> Optional[CrashInfo]:
        """Parse logcat content and extract native crash information"""
        lines = content.splitlines()
        
        crash_info = None
        stack_trace = []
        collecting_stack = False
        
        for line in lines:
            # Look for crash header
            match = self._CRASH_PATTERN.search(line)
            if match:
                crash_info = CrashInfo(
                    process=match.group('process').strip(),
                    signal="",  # Signal might not be available in this format
                    stack_trace=[]
                )
                continue
                
            # Start collecting stack trace after seeing stack trace marker
            if self._STACK_TRACE_START.search(line):
                collecting_stack = True
                
            # Collect stack trace lines
            if collecting_stack and 'DEBUG' in line and 'crash_dump64' in line:
                if self.symbols_dir and self.ndk_path:
                    frame_line = self.symbolicate_frame(line)
                else:
                    frame_line = line.split('A        ')[1].strip()
                stack_trace.append(frame_line)
                
        if crash_info:
            crash_info.stack_trace = stack_trace
            
        return crash_info
    
    def parse_logcat_file(self, logcat_file: str) -> Optional[CrashInfo]:
        """Parse logcat file and extract native crash information"""
        with open(logcat_file, 'r') as f:
            content = f.read()
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