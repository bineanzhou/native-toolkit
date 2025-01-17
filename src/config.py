import os
from dataclasses import dataclass
from typing import Optional

@dataclass
class Config:
    """Configuration for NDK tools"""
    ndk_path: str
    symbols_dir: str
    output_dir: Optional[str] = None
    
    @classmethod
    def from_env(cls) -> 'Config':
        """Create config from environment variables"""
        ndk_path = os.getenv('ANDROID_NDK_HOME')
        if not ndk_path:
            raise ValueError("ANDROID_NDK_HOME environment variable not set")
        
        symbols_dir = os.getenv('SYMBOLS_DIR')
        if not symbols_dir:
            raise ValueError("SYMBOLS_DIR environment variable not set")
            
        output_dir = os.getenv('OUTPUT_DIR')
        
        return cls(
            ndk_path=ndk_path,
            symbols_dir=symbols_dir,
            output_dir=output_dir
        )
    
    def validate(self) -> None:
        """Validate configuration"""
        if not os.path.exists(self.ndk_path):
            raise ValueError(f"NDK path does not exist: {self.ndk_path}")
        if not os.path.exists(self.symbols_dir):
            raise ValueError(f"Symbols directory does not exist: {self.symbols_dir}")
        if self.output_dir and not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir) 