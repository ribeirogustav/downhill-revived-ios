/* Nintendo Switch memory backend for guest_memory.c (libnx / Horizon OS). */
#include <switch.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "guest_memory_os.h"
#include "core_host.h"

#define GUEST_SIZE 0x80010000ull
#define RAM_SIZE 0x2000000ull

static VirtmemReservation *reservation;
static void *guest_ptr;
static uint8_t *ram_backing;

void os_fail(const char *what) {
    fprintf(stderr, "host64 switch memory: %s\n", what);
    abort();
}

uintptr_t os_reserve(void) {
    ram_backing = (uint8_t *)malloc(RAM_SIZE);
    if (!ram_backing) return 0;
    memset(ram_backing, 0, RAM_SIZE);

    virtmemLock();
    guest_ptr = virtmemFindAslr(GUEST_SIZE, 0x10000);
    if (guest_ptr) {
        reservation = virtmemAddReservation(guest_ptr, GUEST_SIZE);
    }
    virtmemUnlock();

    if (!guest_ptr || !reservation) {
        if (ram_backing) { free(ram_backing); ram_backing = NULL; }
        return 0;
    }
    return (uintptr_t)guest_ptr;
}

int os_split(uintptr_t at, uint64_t size) {
    (void)at; (void)size;
    return 1;
}

int os_map_ram(uintptr_t at, uint64_t size, uint64_t file_offset) {
    (void)at; (void)size; (void)file_offset;
    return 1;
}

int os_private(uintptr_t at, uint64_t size) {
    (void)at; (void)size;
    return 1;
}

int os_commit(uintptr_t at, uint64_t size) {
    (void)at; (void)size;
    return 1;
}

void os_decommit(const void *at, uint64_t size) {
    (void)at; (void)size;
}

int os_unmap_view(void *at, uint64_t size) {
    (void)at; (void)size;
    return 1;
}

int os_release(void *at, uint64_t size) {
    (void)at; (void)size;
    return 1;
}

void os_backing_close(void) {
    if (reservation) {
        virtmemLock();
        virtmemRemoveReservation(reservation);
        virtmemUnlock();
        reservation = NULL;
    }
    if (ram_backing) {
        free(ram_backing);
        ram_backing = NULL;
    }
}

int os_fault_install(void) {
    return 1;
}

void os_fault_remove(void) {
}

