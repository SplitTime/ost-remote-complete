#import "_EffortModel.h"
#import "CrossCheckEntriesModel.h"

@interface EffortModel : _EffortModel
// Custom logic goes here.
@property (assign, nonatomic) BOOL bulkSelected;
@property (strong, nonatomic) NSNumber * expected;
@property (strong, nonatomic) NSArray * entries;
- (NSArray*) entriesForSplitName:(NSString*)splitName;
- (BOOL) checkIfEffortShouldBeInSplit:(NSString*)split;

@end
