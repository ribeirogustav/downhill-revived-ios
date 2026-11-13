#!/usr/bin/env python3
"""Gera os IPAs público e pessoal do Downhill Revived para iOS."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent / 'port' / 'ios'))

from build_ios import cli


if __name__ == '__main__':
    sys.exit(cli(['--both', '--rebuild-core', *sys.argv[1:]], prompt_team=True))
