
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdarg.h>
#include <getopt.h>
#include <signal.h>
#include <string.h>
#include <fcntl.h>
#include <sys/file.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/uio.h>
#include <unistd.h>
#include <Carbon/Carbon.h>
#include <CoreFoundation/CoreFoundation.h>

#include "log.h"
#include "hotload.h"
#include "event_tap.h"
#include "locale.h"
#include "carbon.h"
#include "notify.h"
/* #include "hotkey.h" */
#include "synthesize.h"
#include "hotkey.h"

/* #include "hotkey.c" */
/* #include "hotload.c" */
/* #include "event_tap.c" */
/* #include "locale.c" */
/* #include "carbon.c" */
/* /\* #include "hotkey.c" *\/ */
/* #include "synthesize.c" */
/* #include "notify.c" */

extern void NSApplicationLoad(void);
extern CFDictionaryRef CGSCopyCurrentSessionDictionary(void);
extern bool CGSIsSecureEventInputSet(void);
#define secure_keyboard_entry_enabled CGSIsSecureEventInputSet

#define GLOBAL_CONNECTION_CALLBACK(name) void name(uint32_t type, void *data, size_t data_length, void *context)
typedef GLOBAL_CONNECTION_CALLBACK(global_connection_callback);
extern CGError CGSRegisterNotifyProc(void *handler, uint32_t type, void *context);

#define CKHD_CONFIG_FILE ".ckhdrc"
#define CKHD_PIDFILE_FMT "/tmp/ckhd_%s.pid"

static struct hotloader hotloader;
static bool thwart_hotloader;

static HOTLOADER_CALLBACK(config_handler)
{
    debug("ckhd: config-file has been modified.. reloading config\n");
    /* evalConfig(config_file); */
}
static CF_NOTIFICATION_CALLBACK(keymap_handler)
{
    if (initialize_keycode_map()) {
        debug("ckhd: input source changed.. reloading config\n");
        /* evalConfig(config_file); */
    }
}

pid_t read_pid_file(void)
{
    char pid_file[255] = {};
    pid_t pid = 0;

    char *user = getenv("USER");
    if (user) {
        snprintf(pid_file, sizeof(pid_file), CKHD_PIDFILE_FMT, user);
    } else {
        error("ckhd: could not create path to pid-file because 'env USER' was not set! abort..\n");
    }

    int handle = open(pid_file, O_RDWR);
    if (handle == -1) {
        error("ckhd: could not open pid-file..\n");
    }

    if (flock(handle, LOCK_EX | LOCK_NB) == 0) {
        error("ckhd: could not locate existing instance..\n");
    } else if (read(handle, &pid, sizeof(pid_t)) == -1) {
        error("ckhd: could not read pid-file..\n");
    }

    close(handle);
    return pid;
}

void create_pid_file(void)
{
    char pid_file[255] = {};
    pid_t pid = getpid();

    char *user = getenv("USER");
    if (user) {
        snprintf(pid_file, sizeof(pid_file), CKHD_PIDFILE_FMT, user);
    } else {
        error("ckhd: could not create path to pid-file because 'env USER' was not set! abort..\n");
    }

    int handle = open(pid_file, O_CREAT | O_RDWR, 0644);
    if (handle == -1) {
        error("ckhd: could not create pid-file! abort..\n");
    }

    struct flock lockfd = {
        .l_start  = 0,
        .l_len    = 0,
        .l_pid    = pid,
        .l_type   = F_WRLCK,
        .l_whence = SEEK_SET
    };

    if (fcntl(handle, F_SETLK, &lockfd) == -1) {
        error("ckhd: could not lock pid-file! abort..\n");
    } else if (write(handle, &pid, sizeof(pid_t)) == -1) {
        error("ckhd: could not write pid-file! abort..\n");
    }

    // NOTE(koekeishiya): we intentionally leave the handle open,
    // as calling close(..) will release the lock we just acquired.

    debug("ckhd: successfully created pid-file..\n");
}

bool check_privileges(void)
{
    bool result;
    const void *keys[] = { kAXTrustedCheckOptionPrompt };
    const void *values[] = { kCFBooleanTrue };

    CFDictionaryRef options;
    options = CFDictionaryCreate(kCFAllocatorDefault,
                                 keys, values, sizeof(keys) / sizeof(*keys),
                                 &kCFCopyStringDictionaryKeyCallBacks,
                                 &kCFTypeDictionaryValueCallBacks);

    result = AXIsProcessTrustedWithOptions(options);
    CFRelease(options);

    return result;
}

static char *
secure_keyboard_entry_process_info(pid_t *pid)
{
    char *process_name = NULL;

    CFDictionaryRef session = CGSCopyCurrentSessionDictionary();
    if (!session) return NULL;

    CFNumberRef pid_ref = (CFNumberRef) CFDictionaryGetValue(session, CFSTR("kCGSSessionSecureInputPID"));
    if (pid_ref) {
        CFNumberGetValue(pid_ref, CFNumberGetType(pid_ref), pid);
        process_name = find_process_name_for_pid(*pid);
    }

    CFRelease(session);
    return process_name;
}

static void
dump_secure_keyboard_entry_process_info(void)
{
    pid_t pid;
    char *process_name = secure_keyboard_entry_process_info(&pid);
    if (process_name) {
        error("ckhd: secure keyboard entry is enabled by (%lld) '%s'! abort..\n", pid, process_name);
    } else {
        error("ckhd: secure keyboard entry is enabled! abort..\n");
    }
}

static GLOBAL_CONNECTION_CALLBACK(connection_handler)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1f * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        pid_t pid;
        char *process_name = secure_keyboard_entry_process_info(&pid);

        if (type == 752) {
            if (process_name) {
                notify("Secure Keyboard Entry", "Enabled by '%s' (%d)", process_name, pid);
            } else {
                notify("Secure Keyboard Entry", "Enabled by unknown application..");
            }
        } else if (type == 753) {
            if (process_name) {
                notify("Secure Keyboard Entry", "Disabled by '%s' (%d)", process_name, pid);
            } else {
                notify("Secure Keyboard Entry", "Disabled by unknown application..");
            }
        }

        if (process_name) free(process_name);
    });
}

void startRunloop() {
    CFRunLoopRun();
}

typedef void SignalCallback(int signal);

void signalSetup(SignalCallback *handler) {
    signal(SIGCHLD, SIG_IGN);
    signal(SIGUSR1, handler);
}

void main_setup()
{
    /* create_pid_file(); */

    if (secure_keyboard_entry_enabled()) {
        dump_secure_keyboard_entry_process_info();
    }

    CFNotificationCenterAddObserver
        (CFNotificationCenterGetDistributedCenter(),
         NULL,
         &keymap_handler,
         kTISNotifySelectedKeyboardInputSourceChanged,
         NULL,
         CFNotificationSuspensionBehaviorCoalesce);
    /* BEGIN_SCOPED_TIMED_BLOCK("parse_config"); */
    /* bool fileexistp = config_file[0] == 0 */
    /*     ? get_config_file("ckhdrc", config_file, sizeof(config_file)) */
    /*     : file_exists(config_file); */
    /* debug("ckhd: using config '%s'\n", config_file); */
    /* /\* getConfig("ckhdrc"); *\/ */
    /* if (fileexistp) evalConfig(config_file); */
    /* else debug("ckhd: config '%s' doesn't exist\n", config_file); */
    /* END_SCOPED_TIMED_BLOCK(); */

    /* BEGIN_SCOPED_TIMED_BLOCK("begin_eventtap"); */
    /* event_tap_begin(key_handler, NORMAL_MASK); */
    /* END_SCOPED_TIMED_BLOCK(); */
    NSApplicationLoad();
    notify_init();

    CGSRegisterNotifyProc((void*)connection_handler, 752, NULL);
    CGSRegisterNotifyProc((void*)connection_handler, 753, NULL);
}
