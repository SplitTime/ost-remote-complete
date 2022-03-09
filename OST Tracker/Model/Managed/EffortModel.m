#import "EffortModel.h"
#import "CurrentCourse.h"
#import "EntryModel.h"

@interface EffortModel ()

// Private interface goes here.

@end

@implementation EffortModel

@synthesize bulkSelected = _bulkSelected;
@synthesize expected = _expected;
@synthesize entries = _entries;
@synthesize stoppedHere = _stoppedHere;

// Custom logic goes here.

- (BOOL) checkIfEffortShouldBeInSplit:(NSString*)split
{
    CurrentCourse * course = [CurrentCourse getCurrentCourse];
    for (NSDictionary * dict in course.dataEntryGroups)
    {
        if ([dict[@"title"] isEqualToString:course.splitName])
        {
            for (NSDictionary * subEntry in dict[@"entries"])
            {
                if ([course.eventIdsAndSplits[[NSString stringWithFormat:@"%@",self.eventId]][0] containsObject:subEntry[@"parameterizedSplitName"]])
                {
                    return YES;
                }
            }
        }
    }
    
    return NO;
}
- (BOOL) checkIfEffortShouldBeInSplit:(NSString*)split selectedSplitName:(NSString*)selectedSplitName
{
    CurrentCourse * course = [CurrentCourse getCurrentCourse];
    for (NSDictionary * dict in course.dataEntryGroups)
    {
        if ([dict[@"title"] isEqualToString:course.splitName])
        {
            for (NSDictionary * subEntry in dict[@"entries"])
            {
                if ([subEntry[@"splitName"] isEqualToString:selectedSplitName])
                {
                    @try
                    {
                        if ([course.eventIdsAndSplits[[NSString stringWithFormat:@"%@",self.eventId]][0] containsObject:subEntry[@"parameterizedSplitName"]])
                        {
                            return YES;
                        }
                    }@catch(id anException) {
                        NSLog(anException);
                    }
                }
            }
        }
    }
    
    return NO;
}

- (NSNumber*) expectedWithSplitName:(NSString*)splitName
{
    if (!_expected)
    {
        if ([self entriesForSplitName:splitName].count == 0)
        {
            NSArray * crossCheckEntries = [CrossCheckEntriesModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber LIKE[c] %@ && courseId LIKE[c] %@ && splitName LIKE[c] %@",[self.bibNumber stringValue],[CurrentCourse getCurrentCourse].eventId,splitName]];
            
            if (crossCheckEntries.count != 0)
            {
                _expected = @(NO);
            }
            else
            {
                _expected = @(YES);
            }
        }
    }
    return _expected;
}

- (void) clearVariables
{
    _expected = nil;
    _entries = nil;
}

- (NSNumber*) expected
{
    if (!_expected)
    {
        if (self.entries.count == 0)
        {
            NSArray * crossCheckEntries = [CrossCheckEntriesModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber LIKE[c] %@ && courseId LIKE[c] %@ && splitName LIKE[c] %@",[self.bibNumber stringValue],[CurrentCourse getCurrentCourse].eventId,[CurrentCourse getCurrentCourse].splitName]];
            
            if (crossCheckEntries.count != 0)
            {
                _expected = @(NO);
            }
            else
            {
                _expected = @(YES);
            }
        }
    }
    return _expected;
}

- (NSArray*) entriesForSplitName:(NSString*)splitName
{
//    if (!_entries)
//    {
        _entries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber LIKE[c] %@ && combinedCourseId LIKE[c] %@ && splitName LIKE[c] %@",[self.bibNumber stringValue],[CurrentCourse getCurrentCourse].eventId,splitName]];
        self.stoppedHere = @(NO);
        if (_entries.lastObject != nil)
        {
            EntryModel *entry = _entries.lastObject;
            _stoppedHere = @([entry.stoppedHere isEqualToString:@"true"]);
        }
    //}
    return _entries;
}

- (NSArray*) entries
{
//    if (!_entries)
//    {
        _entries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber LIKE[c] %@ && combinedCourseId LIKE[c] %@ && splitName LIKE[c] %@",[self.bibNumber stringValue],[CurrentCourse getCurrentCourse].eventId,[CurrentCourse getCurrentCourse].splitName]];
        
   // }
    return _entries;
}

@end
