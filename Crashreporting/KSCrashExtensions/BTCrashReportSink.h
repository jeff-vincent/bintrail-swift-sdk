#import "KSCrashReportFilter.h"

NS_ASSUME_NONNULL_BEGIN

@interface BTCrashReportSink : NSObject <KSCrashReportFilter>

- (instancetype) initWithSessionToken: (NSString*)token;

@end

NS_ASSUME_NONNULL_END
