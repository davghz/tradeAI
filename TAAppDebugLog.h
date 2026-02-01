// TAAppDebugLog.h
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

void TAInstallCrashHandlers(void);
void TASetDebugStage(NSString *stage);
void TAAppendDebugLog(NSString *message);
NSString *TAGetDebugLogPath(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
