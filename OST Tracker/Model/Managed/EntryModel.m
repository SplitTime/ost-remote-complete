#import "EntryModel.h"

@interface EntryModel ()

// Private interface goes here.

@end

@implementation EntryModel

// Custom logic goes here.
- (NSNumber*)bibNumberDecimal
{
    return [NSDecimalNumber decimalNumberWithString:self.bibNumber];
}

@end
