/**
 * TACoinbaseAPI+Debug.mm
 */

#import "TACoinbaseAPI+Private.h"

void TACoinbaseAppendDebugLine(NSString *line) {
    if (line.length == 0) {
        return;
    }
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"orchestrated_debug.txt"];
    NSData *data = [[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        handle = [NSFileHandle fileHandleForWritingAtPath:path];
    }
    if (handle) {
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    }
}

void TACoinbaseSetDebugValue(NSString *key, NSString *value) {
    if (key.length == 0) {
        return;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (value.length > 0) {
        [defaults setObject:value forKey:key];
    } else {
        [defaults removeObjectForKey:key];
    }
    [defaults setObject:[[NSDate date] description] forKey:@"debug_last_event"];
    [defaults synchronize];
}
