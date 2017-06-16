// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to CurrentCourse.h instead.

#if __has_feature(modules)
    @import Foundation;
    @import CoreData;
#else
    #import <Foundation/Foundation.h>
    #import <CoreData/CoreData.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface CurrentCourseID : NSManagedObjectID {}
@end

@interface _CurrentCourse : NSManagedObject
+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
@property (nonatomic, readonly, strong) CurrentCourseID *objectID;

@property (nonatomic, strong, nullable) NSString* eventId;

@property (nonatomic, strong, nullable) NSString* splitId;

@end

@interface _CurrentCourse (CoreDataGeneratedPrimitiveAccessors)

- (NSString*)primitiveEventId;
- (void)setPrimitiveEventId:(NSString*)value;

- (NSString*)primitiveSplitId;
- (void)setPrimitiveSplitId:(NSString*)value;

@end

@interface CurrentCourseAttributes: NSObject 
+ (NSString *)eventId;
+ (NSString *)splitId;
@end

@interface CurrentCourseUserInfo: NSObject 
+ (NSString *)relatedByAttribute;
@end

NS_ASSUME_NONNULL_END
