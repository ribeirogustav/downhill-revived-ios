/* The Nintendo Switch start (Horizon OS / libnx / SDL3).
   Initializes RomFS, sets working directory to sdmc:/switch/DownhillRevived,
   and boots into Downhill Revived via SDL3. */
#include <switch.h>
#include <SDL3/SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

#define SWITCH_DIR "sdmc:/switch/DownhillRevived"
#define DISC_NAME "SCUS-97177.iso"

int dhd_launcher_main(int argc, char **argv);   /* launcher.c's main */
void host_console_init(void);                   /* host.c: the log */
const char *host_disc_check(const char *path);  /* host.c: NULL when path is the game */

static char exe[1100] = SWITCH_DIR "/dhd64";

/* host_posix.c's host_exe_path on Nintendo Switch. */
const char *switch_exe_path(void) { return exe; }

static void ensure_switch_dirs(void)
{
    mkdir("sdmc:/switch", 0777);
    mkdir(SWITCH_DIR, 0777);
    mkdir(SWITCH_DIR "/saves", 0777);
    mkdir(SWITCH_DIR "/iso", 0777);
}

int main(int argc, char **argv)
{
    /* Initialize RomFS for embedded assets and shaders */
    Result rc = romfsInit();
    if (R_FAILED(rc)) {
        printf("switch: romfsInit failed: 0x%x\n", rc);
    }

    /* Ensure directory structure on SD card */
    ensure_switch_dirs();

    /* Set current directory to SD card app folder */
    chdir(SWITCH_DIR);

    /* Initialize logging to sdmc:/switch/DownhillRevived/dhd.log */
    host_console_init();

    printf("switch: Downhill Revived starting on Horizon OS\n");
    printf("switch: working directory set to %s\n", SWITCH_DIR);

    /* Run the standard game engine */
    int exit_code = dhd_launcher_main(argc, argv);

    /* Clean up RomFS */
    romfsExit();

    return exit_code;
}

