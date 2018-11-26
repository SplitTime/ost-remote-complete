#import "_EffortModel.h"
#import "CrossCheckEntriesModel.h"

@interface EffortModel : _EffortModel
// Custom logic goes here.
@property (assign, nonatomic) BOOL bulkSelected;
@property (strong, nonatomic) NSNumber * expected;
@property (strong, nonatomic) NSArray * entries;
@property (assign, nonatomic) NSNumber * stoppedHere;
- (NSArray*) entriesForSplitName:(NSString*)splitName;
- (NSNumber*) expectedWithSplitName:(NSString*)splitName;
- (BOOL) checkIfEffortShouldBeInSplit:(NSString*)split;
- (BOOL) checkIfEffortShouldBeInSplit:(NSString*)split selectedSplitName:(NSString*)selectedSplitName;
- (void) clearVariables;

@end
