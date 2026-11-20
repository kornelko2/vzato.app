// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Screenshots only: moves the wall clock of the simulator app by FAKE_OFFSET seconds, so the demo
// data looks like the middle of the day whenever the screenshots are taken. Loaded with
// SIMCTL_CHILD_DYLD_INSERT_LIBRARIES by Scripts/screenshots.sh; never part of the app.
#include <stdlib.h>
#include <sys/time.h>
#include <time.h>
#include <stdint.h>

static long long offset(void) {
    static long long value = -1; static int loaded = 0;
    if (!loaded) { const char *s = getenv("FAKE_OFFSET"); value = s ? atoll(s) : 0; loaded = 1; }
    return value;
}
static int my_gettimeofday(struct timeval *tv, void *tz) {
    int r = gettimeofday(tv, tz); if (r == 0 && tv) tv->tv_sec += offset(); return r;
}
static int my_clock_gettime(clockid_t id, struct timespec *ts) {
    int r = clock_gettime(id, ts); if (r == 0 && ts && id == CLOCK_REALTIME) ts->tv_sec += offset(); return r;
}
static uint64_t my_clock_gettime_nsec_np(clockid_t id) {
    uint64_t v = clock_gettime_nsec_np(id); return id == CLOCK_REALTIME ? v + (uint64_t)offset() * 1000000000ULL : v;
}
static time_t my_time(time_t *t) { time_t v = time(NULL) + offset(); if (t) *t = v; return v; }

__attribute__((used)) static struct { const void *replacement; const void *replacee; } interposers[] __attribute__((section("__DATA,__interpose"))) = {
    { (const void *)my_gettimeofday, (const void *)gettimeofday },
    { (const void *)my_clock_gettime, (const void *)clock_gettime },
    { (const void *)my_clock_gettime_nsec_np, (const void *)clock_gettime_nsec_np },
    { (const void *)my_time, (const void *)time },
};
