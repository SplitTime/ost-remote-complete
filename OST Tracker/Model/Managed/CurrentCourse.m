#import "CurrentCourse.h"

@interface CurrentCourse ()

// Private interface goes here.

@end

@implementation CurrentCourse

// Custom logic goes here.

+ (CurrentCourse*) getCurrentCourse
{
    return [CurrentCourse MR_findFirst];
}

- (NSArray*) getSplitInIds
{
    NSMutableArray * splitIdsArray = [NSMutableArray new];
    for (NSDictionary * dict in self.combinedSplitAttributes)
    {
        if ([dict[@"title"] isEqualToString:self.splitName])
        {
            for (NSDictionary * subDict in dict[@"entries"])
            {
                if ([subDict[@"subSplitKind"] isEqualToString:@"in"])
                {
                    [splitIdsArray addObjectsFromArray:[subDict[@"eventSplitIds"] allValues]];
                }
            }
        }
    }
    
    return splitIdsArray;
}

- (NSArray*) getSplitOutIds
{
    NSMutableArray * splitIdsArray = [NSMutableArray new];
    for (NSDictionary * dict in self.combinedSplitAttributes)
    {
        if ([dict[@"title"] isEqualToString:self.splitName])
        {
            for (NSDictionary * subDict in dict[@"entries"])
            {
                if ([subDict[@"subSplitKind"] isEqualToString:@"out"])
                {
                    [splitIdsArray addObjectsFromArray:[subDict[@"eventSplitIds"] allValues]];
                }
            }
        }
    }
    
    return splitIdsArray;
}

@end
