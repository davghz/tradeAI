// TAAppDebugLog.mm
#import "TAAppDebugLog.h"
#import <signal.h>
#import <fcntl.h>
#import <unistd.h>
#import <string.h>

static char gLogPath[512] = {0};

static void TAWriteToFile(const char *message) {
    if (message == NULL || gLogPath[0] == '\0') {
        return;
    }
    int fd = open(gLogPath, O_CREAT | O_WRONLY | O_APPEND, 0644);
    if (fd < 0) {
        return;
    }
    write(fd, message, strlen(message));
    write(fd, "\n", 1);
    close(fd);
}

static void TASignalHandler(int signal) {
    char buffer[128];
    int len = snprintf(buffer, sizeof(buffer), "signal: %d", signal);
    if (len > 0) {
        TAWriteToFile(buffer);
    }
    _exit(128 + signal);
}

static void TAExceptionHandler(NSException *exception) {
    NSString *message = [NSString stringWithFormat:@"exception: %@ %@", exception.name ?: @"<nil>", exception.reason ?: @"<nil>"];
    TAAppendDebugLog(message);
    NSArray<NSString *> *stack = exception.callStackSymbols;
    if (stack.count > 0) {
        TAAppendDebugLog(@"exception: callstack start");
        for (NSString *line in stack) {
            TAAppendDebugLog(line);
        }
        TAAppendDebugLog(@"exception: callstack end");
    }
}

NSString *TAGetDebugLogPath(void) {
    NSString *home = NSHomeDirectory();
    NSString *path = [home stringByAppendingPathComponent:@"Library/Caches/ta_debug.log"];
    return path;
}

void TAInstallCrashHandlers(void) {
    NSString *path = TAGetDebugLogPath();
    const char *utf8 = [path UTF8String];
    if (utf8 != NULL) {
        strlcpy(gLogPath, utf8, sizeof(gLogPath));
    }

    NSSetUncaughtExceptionHandler(&TAExceptionHandler);
    signal(SIGABRT, TASignalHandler);
    signal(SIGILL, TASignalHandler);
    signal(SIGSEGV, TASignalHandler);
    signal(SIGFPE, TASignalHandler);
    signal(SIGBUS, TASignalHandler);
    signal(SIGPIPE, TASignalHandler);
}

void TAAppendDebugLog(NSString *message) {
    if (message.length == 0) {
        return;
    }
    NSString *line = [NSString stringWithFormat:@"%@ %@", [[NSDate date] description], message];
    TAWriteToFile([line UTF8String]);
}

void TASetDebugStage(NSString *stage) {
    if (stage.length == 0) {
        return;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:stage forKey:@"debug_last_stage"];
    [defaults setObject:[[NSDate date] description] forKey:@"debug_last_stage_at"];
    [defaults synchronize];

    TAAppendDebugLog([NSString stringWithFormat:@"stage: %@", stage]);
}
