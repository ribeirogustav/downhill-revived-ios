#!/usr/bin/env python3
"""Gera os IPAs público e pessoal do Downhill Revived para iOS."""
import sys

from build_ios import cli


if __name__ == '__main__':
    sys.exit(cli(['--both', '--rebuild-core', *sys.argv[1:]], prompt_team=True))
