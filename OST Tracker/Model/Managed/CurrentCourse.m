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

- (NSArray*) getSplitLeftIds
{
    NSMutableArray * splitIdsArray = [NSMutableArray new];
    for (NSDictionary * dict in self.dataEntryGroups)
    {
        if ([dict[@"title"] isEqualToString:self.splitName])
        {
//            for (NSDictionary * subDict in dict[@"entries"])
//            {
//                if ([subDict[@"subSplitKind"] isEqualToString:@"in"])
//                {
//                    [splitIdsArray addObjectsFromArray:[subDict[@"eventSplitIds"] allValues]];
//                }
//            }
            return [dict[@"entries"][0][@"eventSplitIds"] allValues];
        }
    }
    
    return splitIdsArray;
}

- (NSArray*) getSplitRightIds
{
    NSMutableArray * splitIdsArray = [NSMutableArray new];
    for (NSDictionary * dict in self.dataEntryGroups)
    {
        if ([dict[@"title"] isEqualToString:self.splitName])
        {
//            for (NSDictionary * subDict in dict[@"entries"])
//            {
//                if ([subDict[@"subSplitKind"] isEqualToString:@"out"])
//                {
//                    [splitIdsArray addObjectsFromArray:[subDict[@"eventSplitIds"] allValues]];
//                }
//            }
            if ([dict[@"entries"] count] >= 2)
                return [dict[@"entries"][1][@"eventSplitIds"] allValues];
        }
    }
    
    return splitIdsArray;
}

@end
