import re
from typing import List, Optional
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
        r'(?P<process>.*?) crashed with signal (?P<signal>\d+)'
    )
    _STACK_TRACE_START = "backtrace:"
    
    def parse_logcat_file(self, logcat_file: str) -> Optional[CrashInfo]:
        """Parse logcat file and extract native crash information"""
        with open(logcat_file, 'r') as f:
            content = f.read()
        return self.parse_logcat_content(content)
    
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
                    process=match.group('process'),
                    signal=match.group('signal'),
                    stack_trace=[]
                )
                continue
                
            # Start collecting stack trace after seeing "backtrace:"
            if self._STACK_TRACE_START in line:
                collecting_stack = True
                continue
                
            if collecting_stack and line.strip():
                stack_trace.append(line.strip())
                
        if crash_info:
            crash_info.stack_trace = stack_trace
            
        return crash_info 