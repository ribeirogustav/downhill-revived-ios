#!/usr/bin/env python3
"""Build Downhill Revived for Nintendo Switch (.nro Homebrew).

Usage:
    python port/switch/build_switch.py [--wasm build/wasm/dhd_core.wasm] [--jobs 4]

Requirements:
    devkitPro with devkitA64, libnx, switch-sdl2, switch-mesa, switch-tools.
"""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / 'build' / 'switch'

DEVKITPRO = Path(os.environ.get('DEVKITPRO') or '/opt/devkitpro')
DEVKITA64 = DEVKITPRO / 'devkitA64'
PORTLIBS = DEVKITPRO / 'portlibs' / 'switch'
LIBNX = DEVKITPRO / 'libnx'


def check_toolchain():
    if not DEVKITPRO.is_dir():
        raise RuntimeError(f"devkitPro directory not found at: {DEVKITPRO}\n"
                           f"Install it with: sudo installer -pkg /tmp/devkitpro-pacman-installer.pkg -target /")
    
    tools = [
        DEVKITA64 / 'bin' / 'aarch64-none-elf-gcc',
        DEVKITA64 / 'bin' / 'aarch64-none-elf-g++',
        DEVKITPRO / 'tools' / 'bin' / 'elf2nro',
        DEVKITPRO / 'tools' / 'bin' / 'nacptool',
    ]
    missing = [str(t) for t in tools if not t.is_file()]
    if missing:
        raise RuntimeError(f"Missing Switch build tools: {', '.join(missing)}\n"
                           f"Install with: sudo dkp-pacman -S switch-dev switch-sdl2 switch-mesa switch-tools")


def prepare_native_core(wasm=None, jobs=4):
    """Rebuild the core and host archive for Nintendo Switch (libdhd_switch.a)."""
    default_wasm = ROOT / 'build' / 'wasm' / 'dhd_core.wasm'
    wasm_path = Path(wasm).resolve() if wasm else default_wasm
    if not wasm_path.is_file():
        raise FileNotFoundError(f"wasm module not found: {wasm_path}. Build it first with build_wasm.py.")

    print(f"switch: building host core (libdhd_switch.a) from {wasm_path.name}...")
    env = dict(os.environ, DEVKITPRO=str(DEVKITPRO))
    cmd = [
        sys.executable, str(ROOT / 'port/tools/build_host64.py'),
        str(wasm_path), '--target', 'switch-arm64', '--jobs', str(jobs),
        '--num-outputs', '8'
    ]
    subprocess.run(cmd, cwd=ROOT, env=env, check=True)
    core_lib = ROOT / 'build' / 'host64-switch' / 'libdhd_switch.a'
    if not core_lib.is_file():
        raise RuntimeError("Core compilation failed to produce libdhd_switch.a")
    print(f"switch: core archive ready: {core_lib.name} ({core_lib.stat().st_size / (1024*1024):.1f} MB)")
    return core_lib


def compile_switch_main(env):
    cc = DEVKITA64 / 'bin' / 'aarch64-none-elf-gcc'
    src = HERE / 'host' / 'switch_main.c'
    obj = OUT / 'switch_main.o'
    OUT.mkdir(parents=True, exist_ok=True)

    cmd = [
        str(cc), '-c', str(src), '-o', str(obj),
        '-specs=' + str(LIBNX / 'switch.specs'),
        '-march=armv8-a', '-mtune=cortex-a57', '-fPIE', '-D__SWITCH__',
        '-O3',
        f'-I{LIBNX / "include"}',
        f'-I{PORTLIBS / "include"}',
        f'-I{ROOT / "port/host"}',
        f'-I{ROOT / "port/include"}',
    ]
    subprocess.run(cmd, env=env, check=True)
    return obj


def link_elf(main_obj: Path, core_lib: Path, env):
    gxx = DEVKITA64 / 'bin' / 'aarch64-none-elf-g++'
    elf = OUT / 'DownhillRevived.elf'

    print("switch: linking DownhillRevived.elf...")
    cmd = [
        str(gxx), '-specs=' + str(LIBNX / 'switch.specs'),
        '-march=armv8-a', '-mtune=cortex-a57', '-fPIE', '-D__SWITCH__',
        '-O3',
        str(main_obj), str(core_lib),
        f'-L{PORTLIBS / "lib"}',
        f'-L{LIBNX / "lib"}',
        '-lSDL2', '-lEGL', '-lglapi', '-ldrm_nouveau', '-lnx', '-lstdc++', '-lm',
        '-o', str(elf)
    ]
    subprocess.run(cmd, env=env, check=True)
    return elf


def generate_nacp(nacp_path: Path):
    nacptool = DEVKITPRO / 'tools' / 'bin' / 'nacptool'
    cmd = [
        str(nacptool), '--create',
        'Downhill Revived',        # Application Title
        'Skuza / Community',      # Author
        '0.7.12',                 # Version
        str(nacp_path)
    ]
    subprocess.run(cmd, check=True)


def build_nro(elf_path: Path, nro_path: Path, icon_path: Path = None, romfs_dir: Path = None):
    elf2nro = DEVKITPRO / 'tools' / 'bin' / 'elf2nro'
    nacp_path = elf_path.with_suffix('.nacp')
    generate_nacp(nacp_path)

    cmd = [str(elf2nro), str(elf_path), str(nro_path), f'--nacp={nacp_path}']
    if icon_path and icon_path.is_file():
        cmd.append(f'--icon={icon_path}')
    if romfs_dir and romfs_dir.is_dir():
        cmd.append(f'--romfsdir={romfs_dir}')

    print(f"switch: packaging {nro_path.name}...")
    subprocess.run(cmd, check=True)
    print(f"\n============================================================")
    print(f"  NINTENDO SWITCH BUILD SUCCESSFUL")
    print(f"============================================================")
    print(f"  NRO:     {nro_path}")
    print(f"  Size:    {nro_path.stat().st_size / (1024*1024):.2f} MB")
    print(f"============================================================")
    print(f"Copy {nro_path.name} to your Switch SD card under sdmc:/switch/DownhillRevived/")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wasm', type=Path, help="Prebuilt wasm module (default: build/wasm/dhd_core.wasm)")
    parser.add_argument('--jobs', type=int, default=4, help="Parallel compile jobs")
    parser.add_argument('--reuse-core', action='store_true', help="Reuse existing libdhd_switch.a if present")
    args = parser.parse_args()

    check_toolchain()
    OUT.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, DEVKITPRO=str(DEVKITPRO))

    core_lib = ROOT / 'build' / 'host64-switch' / 'libdhd_switch.a'
    if not (args.reuse_core and core_lib.is_file()):
        core_lib = prepare_native_core(args.wasm, args.jobs)
    else:
        print(f"switch: reusing existing core library {core_lib.name} ({core_lib.stat().st_size / (1024*1024):.1f} MB)")

    main_obj = compile_switch_main(env)
    elf = link_elf(main_obj, core_lib, env)

    icon_path = HERE / 'assets' / 'icon.jpg'
    nro_path = OUT / 'DownhillRevived.nro'
    build_nro(elf, nro_path, icon_path=icon_path)
    return 0


if __name__ == '__main__':
    sys.exit(main())
