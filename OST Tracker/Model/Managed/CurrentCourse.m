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

@end
