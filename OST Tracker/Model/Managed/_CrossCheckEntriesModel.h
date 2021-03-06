// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to CrossCheckEntriesModel.h instead.

#if __has_feature(modules)
    @import Foundation;
    @import CoreData;
#else
    #import <Foundation/Foundation.h>
    #import <CoreData/CoreData.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface CrossCheckEntriesModelID : NSManagedObjectID {}
@end

@interface _CrossCheckEntriesModel : NSManagedObject
+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_;
+ (NSString*)entityName;
+ (nullable NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
@property (nonatomic, readonly, strong) CrossCheckEntriesModelID *objectID;

@property (nonatomic, strong, nullable) NSString* bibNumber;

@property (nonatomic, strong, nullable) NSString* courseId;

@property (nonatomic, strong, nullable) NSString* splitName;

@end

@interface _CrossCheckEntriesModel (CoreDataGeneratedPrimitiveAccessors)

- (nullable NSString*)primitiveBibNumber;
- (void)setPrimitiveBibNumber:(nullable NSString*)value;

- (nullable NSString*)primitiveCourseId;
- (void)setPrimitiveCourseId:(nullable NSString*)value;

- (nullable NSString*)primitiveSplitName;
- (void)setPrimitiveSplitName:(nullable NSString*)value;

@end

@interface CrossCheckEntriesModelAttributes: NSObject 
+ (NSString *)bibNumber;
+ (NSString *)courseId;
+ (NSString *)splitName;
@end

NS_ASSUME_NONNULL_END
