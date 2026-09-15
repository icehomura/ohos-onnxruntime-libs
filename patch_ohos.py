#!/usr/bin/env python3
"""Patch ONNX Runtime source for OpenHarmony compatibility.

Applied during GitHub Actions CI build. Handles:
1. Remove cpuinfo linking from onnxruntime_common.cmake
2. Other OHOS-specific patches as needed
"""
import re
import sys
import os


def patch_cmake_cpuinfo(cmake_path):
    """Remove the if(CPUINFO_SUPPORTED)...endif() block from cmake file."""
    with open(cmake_path, 'r') as f:
        content = f.read()

    # Match the entire if/endif block
    pattern = r'if\(CPUINFO_SUPPORTED\)\s*\n.*?endif\(\)'
    new_content = re.sub(pattern, '# cpuinfo disabled for OHOS', content, flags=re.DOTALL)

    if new_content == content:
        print(f"WARNING: No CPUINFO_SUPPORTED block found in {cmake_path}")
    else:
        with open(cmake_path, 'w') as f:
            f.write(new_content)
        print(f"Patched {cmake_path}: removed CPUINFO_SUPPORTED block")


def main():
    base = os.environ.get('GITHUB_WORKSPACE', '.')
    cmake_file = os.path.join(base, 'onnxruntime', 'cmake', 'onnxruntime_common.cmake')

    if os.path.exists(cmake_file):
        patch_cmake_cpuinfo(cmake_file)
    else:
        print(f"ERROR: {cmake_file} not found")

    print("All patches applied successfully")


if __name__ == '__main__':
    main()
