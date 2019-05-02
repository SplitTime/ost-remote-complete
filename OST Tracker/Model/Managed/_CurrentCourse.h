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

@class NSObject;

@class NSObject;

@class NSObject;

@class NSObject;

@interface CurrentCourseID : NSManagedObjectID {}
@end

@interface _CurrentCourse : NSManagedObject
+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_;
+ (NSString*)entityName;
+ (nullable NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
@property (nonatomic, readonly, strong) CurrentCourseID *objectID;

@property (nonatomic, strong, nullable) id dataEntryGroups;

@property (nonatomic, strong, nullable) NSString* eventGroupId;

@property (nonatomic, strong, nullable) NSString* eventId;

@property (nonatomic, strong, nullable) id eventIdsAndSplits;

@property (nonatomic, strong, nullable) NSString* eventName;

@property (nonatomic, strong, nullable) id eventShortNames;

@property (nonatomic, strong, nullable) NSNumber* monitorPacers;

@property (atomic) BOOL monitorPacersValue;
- (BOOL)monitorPacersValue;
- (void)setMonitorPacersValue:(BOOL)value_;

@property (nonatomic, strong, nullable) NSNumber* multiLap;

@property (atomic) BOOL multiLapValue;
- (BOOL)multiLapValue;
- (void)setMultiLapValue:(BOOL)value_;

@property (nonatomic, strong, nullable) id splitAttributes;

@property (nonatomic, strong, nullable) NSString* splitId;

@property (nonatomic, strong, nullable) NSString* splitName;

@end

@interface _CurrentCourse (CoreDataGeneratedPrimitiveAccessors)

- (nullable id)primitiveDataEntryGroups;
- (void)setPrimitiveDataEntryGroups:(nullable id)value;

- (nullable NSString*)primitiveEventGroupId;
- (void)setPrimitiveEventGroupId:(nullable NSString*)value;

- (nullable NSString*)primitiveEventId;
- (void)setPrimitiveEventId:(nullable NSString*)value;

- (nullable id)primitiveEventIdsAndSplits;
- (void)setPrimitiveEventIdsAndSplits:(nullable id)value;

- (nullable NSString*)primitiveEventName;
- (void)setPrimitiveEventName:(nullable NSString*)value;

- (nullable id)primitiveEventShortNames;
- (void)setPrimitiveEventShortNames:(nullable id)value;

- (nullable NSNumber*)primitiveMonitorPacers;
- (void)setPrimitiveMonitorPacers:(nullable NSNumber*)value;

- (BOOL)primitiveMonitorPacersValue;
- (void)setPrimitiveMonitorPacersValue:(BOOL)value_;

- (nullable NSNumber*)primitiveMultiLap;
- (void)setPrimitiveMultiLap:(nullable NSNumber*)value;

- (BOOL)primitiveMultiLapValue;
- (void)setPrimitiveMultiLapValue:(BOOL)value_;

- (nullable id)primitiveSplitAttributes;
- (void)setPrimitiveSplitAttributes:(nullable id)value;

- (nullable NSString*)primitiveSplitId;
- (void)setPrimitiveSplitId:(nullable NSString*)value;

- (nullable NSString*)primitiveSplitName;
- (void)setPrimitiveSplitName:(nullable NSString*)value;

@end

@interface CurrentCourseAttributes: NSObject 
+ (NSString *)dataEntryGroups;
+ (NSString *)eventGroupId;
+ (NSString *)eventId;
+ (NSString *)eventIdsAndSplits;
+ (NSString *)eventName;
+ (NSString *)eventShortNames;
+ (NSString *)monitorPacers;
+ (NSString *)multiLap;
+ (NSString *)splitAttributes;
+ (NSString *)splitId;
+ (NSString *)splitName;
@end

@interface CurrentCourseUserInfo: NSObject 
+ (NSString *)relatedByAttribute;
@end

NS_ASSUME_NONNULL_END
