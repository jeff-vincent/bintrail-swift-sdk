#import "BTCrashReportSink.h"
#import "KSCrashReportFilterSets.h"

@implementation BTCrashReportSink {
    NSString *sessionToken;
}

#define NSLog(FORMAT, ...) printf("%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

- (instancetype) initWithSessionToken: (NSString*)token {

    if(self = [super init]) {
        sessionToken = token;
    }
    
    return self;
}

- (void)filterReports:(NSArray *)reports onCompletion:(KSCrashReportFilterCompletion)onCompletion {

    id<KSCrashReportFilter> filter = [KSCrashFilterSets
                                      appleFmtWithUserAndSystemData: KSAppleReportStyleSymbolicatedSideBySide
                                      compressed: false];

    [filter filterReports:reports onCompletion:^(NSArray *filteredReports, BOOL completed, NSError *error) {

        NSMutableArray<NSString*>* result = [[NSMutableArray alloc] initWithCapacity:filteredReports.count];

        for(NSString *report in filteredReports) {

            NSScanner *scanner = [NSScanner scannerWithString: report];

            NSString* crashReportString = [NSString new];
            NSString* notableAddressesJsonString = [NSString new];
            NSString* applicationStatsJsonString = [NSString new];
            NSString* userAndSystemDataJsonString;

            [scanner scanUpToString:@"\nExtra Information:\n" intoString:&crashReportString];

            [scanner scanUpToString:@"\nNotable Addresses:\n" intoString:nil];
            [scanner scanUpToString:@"{" intoString:nil];

            [scanner scanUpToString:@"\nApplication Stats:\n" intoString:&notableAddressesJsonString];
            [scanner scanUpToString:@"{" intoString:nil];


            [scanner scanUpToString:@"\n-------- User & System Data --------\n" intoString:&applicationStatsJsonString];
            [scanner scanUpToString:@"{" intoString:nil];

            userAndSystemDataJsonString = [report substringFromIndex:scanner.scanLocation];

            NSMutableString *jsonString = [NSMutableString new];


            [jsonString appendFormat:@"{\"report\":\"%@\"", [self JSONString:crashReportString]];
            [jsonString appendString:@","];
            [jsonString appendFormat:@"\"notable_addresses\":%@", [self stringExcludingWhitespace:notableAddressesJsonString]];
            [jsonString appendString:@","];
            [jsonString appendFormat:@"\"application_stats\":%@", [self stringExcludingWhitespace:applicationStatsJsonString]];
            [jsonString appendString:@","];
            [jsonString appendFormat:@"\"user_and_system_data\":%@", [self stringExcludingWhitespace:userAndSystemDataJsonString]];
            [jsonString appendString:@"}"];


            [result addObject:jsonString];
        }

        NSString* finalJsonString = [NSString stringWithFormat:@"[@%]", [result componentsJoinedByString:@","]];

        NSData * data = [finalJsonString dataUsingEncoding:NSUTF8StringEncoding];


        kscrash_callCompletion(onCompletion, reports, YES, nil);
    }];

}

- (NSString *) trimmedString:(NSString *)string {
    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *) stringExcludingWhitespace:(NSString *)string {
    return [[string stringByReplacingOccurrencesOfString:@"\n" withString:@""] stringByReplacingOccurrencesOfString:@" " withString:@""];
}

-(NSString *)JSONString:(NSString *)aString {
    NSMutableString *s = [NSMutableString stringWithString:aString];
    [s replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"/" withString:@"\\/" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\n" withString:@"\\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\b" withString:@"\\b" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\f" withString:@"\\f" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\r" withString:@"\\r" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\t" withString:@"\\t" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    return [self trimmedString:[NSString stringWithString:s]];
}

@end
