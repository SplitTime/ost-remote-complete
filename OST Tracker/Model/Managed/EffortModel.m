#import "EffortModel.h"
#import "CurrentCourse.h"

@interface EffortModel ()

// Private interface goes here.

@end

@implementation EffortModel

@synthesize bulkSelected = _bulkSelected;
// Custom logic goes here.

- (BOOL) checkIfEffortShouldBeInSplit:(NSString*)split
{
    CurrentCourse * course = [CurrentCourse getCurrentCourse];
    for (NSDictionary * dict in course.combinedSplitAttributes)
    {
        if ([dict[@"title"] isEqualToString:course.splitName])
        {
            for (NSDictionary * subEntry in dict[@"entries"])
            {
                if (subEntry[@"eventSplitIds"][[self.eventId stringValue]])
                {
                    return YES;
                }
            }
        }
    }
    
    return NO;
}

@end
