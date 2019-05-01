// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to EntryModel.h instead.

#if __has_feature(modules)
    @import Foundation;
    @import CoreData;
#else
    #import <Foundation/Foundation.h>
    #import <CoreData/CoreData.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface EntryModelID : NSManagedObjectID {}
@end

@interface _EntryModel : NSManagedObject
+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_;
+ (NSString*)entityName;
+ (nullable NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
@property (nonatomic, readonly, strong) EntryModelID *objectID;

@property (nonatomic, strong, nullable) NSString* absoluteTime;

@property (nonatomic, strong, nullable) NSString* bibNumber;

@property (nonatomic, strong, nullable) NSString* bitKey;

@property (nonatomic, strong, nullable) NSString* combinedCourseId;

@property (nonatomic, strong, nullable) NSString* courseName;

@property (nonatomic, strong, nullable) NSString* displayTime;

@property (nonatomic, strong, nullable) NSString* entryCourseId;

@property (nonatomic, strong, nullable) NSDecimalNumber* entryId;

@property (nonatomic, strong, nullable) NSDate* entryTime;

@property (nonatomic, strong, nullable) NSString* fullName;

@property (nonatomic, strong, nullable) NSString* source;

@property (nonatomic, strong, nullable) NSString* splitId;

@property (nonatomic, strong, nullable) NSString* splitName;

@property (nonatomic, strong, nullable) NSString* stoppedHere;

@property (nonatomic, strong, nullable) NSNumber* submitted;

@property (atomic) BOOL submittedValue;
- (BOOL)submittedValue;
- (void)setSubmittedValue:(BOOL)value_;

@property (nonatomic, strong, nullable) NSDate* timeEntered;

@property (nonatomic, strong, nullable) NSString* withPacer;

@end

@interface _EntryModel (CoreDataGeneratedPrimitiveAccessors)

- (nullable NSString*)primitiveAbsoluteTime;
- (void)setPrimitiveAbsoluteTime:(nullable NSString*)value;

- (nullable NSString*)primitiveBibNumber;
- (void)setPrimitiveBibNumber:(nullable NSString*)value;

- (nullable NSString*)primitiveBitKey;
- (void)setPrimitiveBitKey:(nullable NSString*)value;

- (nullable NSString*)primitiveCombinedCourseId;
- (void)setPrimitiveCombinedCourseId:(nullable NSString*)value;

- (nullable NSString*)primitiveCourseName;
- (void)setPrimitiveCourseName:(nullable NSString*)value;

- (nullable NSString*)primitiveDisplayTime;
- (void)setPrimitiveDisplayTime:(nullable NSString*)value;

- (nullable NSString*)primitiveEntryCourseId;
- (void)setPrimitiveEntryCourseId:(nullable NSString*)value;

- (nullable NSDecimalNumber*)primitiveEntryId;
- (void)setPrimitiveEntryId:(nullable NSDecimalNumber*)value;

- (nullable NSDate*)primitiveEntryTime;
- (void)setPrimitiveEntryTime:(nullable NSDate*)value;

- (nullable NSString*)primitiveFullName;
- (void)setPrimitiveFullName:(nullable NSString*)value;

- (nullable NSString*)primitiveSource;
- (void)setPrimitiveSource:(nullable NSString*)value;

- (nullable NSString*)primitiveSplitId;
- (void)setPrimitiveSplitId:(nullable NSString*)value;

- (nullable NSString*)primitiveSplitName;
- (void)setPrimitiveSplitName:(nullable NSString*)value;

- (nullable NSString*)primitiveStoppedHere;
- (void)setPrimitiveStoppedHere:(nullable NSString*)value;

- (nullable NSNumber*)primitiveSubmitted;
- (void)setPrimitiveSubmitted:(nullable NSNumber*)value;

- (BOOL)primitiveSubmittedValue;
- (void)setPrimitiveSubmittedValue:(BOOL)value_;

- (nullable NSDate*)primitiveTimeEntered;
- (void)setPrimitiveTimeEntered:(nullable NSDate*)value;

- (nullable NSString*)primitiveWithPacer;
- (void)setPrimitiveWithPacer:(nullable NSString*)value;

@end

@interface EntryModelAttributes: NSObject 
+ (NSString *)absoluteTime;
+ (NSString *)bibNumber;
+ (NSString *)bitKey;
+ (NSString *)combinedCourseId;
+ (NSString *)courseName;
+ (NSString *)displayTime;
+ (NSString *)entryCourseId;
+ (NSString *)entryId;
+ (NSString *)entryTime;
+ (NSString *)fullName;
+ (NSString *)source;
+ (NSString *)splitId;
+ (NSString *)splitName;
+ (NSString *)stoppedHere;
+ (NSString *)submitted;
+ (NSString *)timeEntered;
+ (NSString *)withPacer;
@end

NS_ASSUME_NONNULL_END
