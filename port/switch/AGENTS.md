# port/switch/: Nintendo Switch Homebrew Port

This area contains the Nintendo Switch platform layer (Horizon OS / libnx / devkitA64 / SDL3).

## Targets & Toolchain
- **CPU**: NVIDIA Tegra X1 (4x ARM Cortex-A57 @ 1.02 GHz, AArch64).
- **Toolchain**: devkitA64 (`aarch64-none-elf-gcc`, `clang`, `libnx`, `switch-sdl3`).
- **Output**: `DownhillRevived.nro` (executable with RomFS and NACP metadata).
- **Fibers**: Standard ARM64 context switch (`port/host64/fiber_arm64.c`).
- **Filesystem**: `sdmc:/switch/DownhillRevived/` for user config, saves, logs, and game ISO.

