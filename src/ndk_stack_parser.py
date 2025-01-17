import os
import subprocess
from typing import Optional
from .config import Config

class NDKStackParser:
    """Parser for NDK crash dumps using ndk-stack tool"""
    
    def __init__(self, config: Config):
        self.config = config
        self.config.validate()
        self._ndk_stack_path = self._get_ndk_stack_path()
    
    def _get_ndk_stack_path(self) -> str:
        """Get path to ndk-stack executable"""
        if os.name == 'nt':  # Windows
            ndk_stack = os.path.join(self.config.ndk_path, 'ndk-stack.exe')
        else:  # Linux/MacOS
            ndk_stack = os.path.join(self.config.ndk_path, 'ndk-stack')
            
        if not os.path.exists(ndk_stack):
            raise FileNotFoundError(f"ndk-stack not found at: {ndk_stack}")
        return ndk_stack
    
    def parse_dump_file(self, dump_file: str, output_file: Optional[str] = None) -> str:
        """Parse a .dmp file and return symbolicated stack trace"""
        if not os.path.exists(dump_file):
            raise FileNotFoundError(f"Dump file not found: {dump_file}")
            
        cmd = [
            self._ndk_stack_path,
            '-sym', self.config.symbols_dir,
            '-dump', dump_file
        ]
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True
            )
            
            symbolicated_trace = result.stdout
            
            if output_file:
                with open(output_file, 'w') as f:
                    f.write(symbolicated_trace)
                    
            return symbolicated_trace
            
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Failed to parse dump file: {e.stderr}") 