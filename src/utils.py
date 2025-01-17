import os
import platform
from typing import Optional

def get_platform() -> str:
    """Get current platform name"""
    system = platform.system().lower()
    if system == 'darwin':
        return 'macos'
    return system

def find_ndk_path() -> Optional[str]:
    """Try to find NDK path from common locations"""
    common_locations = {
        'windows': [
            r'C:\Android\sdk\ndk',
            os.path.expanduser('~/AppData/Local/Android/sdk/ndk'),
        ],
        'linux': [
            '/opt/android-sdk/ndk',
            os.path.expanduser('~/Android/Sdk/ndk'),
        ],
        'macos': [
            '/usr/local/share/android-sdk/ndk',
            os.path.expanduser('~/Library/Android/sdk/ndk'),
        ]
    }
    
    platform_name = get_platform()
    locations = common_locations.get(platform_name, [])
    
    for location in locations:
        if os.path.exists(location):
            # Find the latest NDK version
            versions = [d for d in os.listdir(location) 
                       if os.path.isdir(os.path.join(location, d))]
            if versions:
                latest = sorted(versions)[-1]
                return os.path.join(location, latest)
    
    return None 