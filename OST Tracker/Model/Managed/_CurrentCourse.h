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

@interface CurrentCourseID : NSManagedObjectID {}
@end

@interface _CurrentCourse : NSManagedObject
+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
@property (nonatomic, readonly, strong) CurrentCourseID *objectID;

@property (nonatomic, strong, nullable) id combinedSplitAttributes;

@property (nonatomic, strong, nullable) NSString* eventId;

@property (nonatomic, strong, nullable) NSString* eventName;

@property (nonatomic, strong, nullable) id liveAttributes;

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

- (id)primitiveCombinedSplitAttributes;
- (void)setPrimitiveCombinedSplitAttributes:(id)value;

- (NSString*)primitiveEventId;
- (void)setPrimitiveEventId:(NSString*)value;

- (NSString*)primitiveEventName;
- (void)setPrimitiveEventName:(NSString*)value;

- (id)primitiveLiveAttributes;
- (void)setPrimitiveLiveAttributes:(id)value;

- (NSNumber*)primitiveMonitorPacers;
- (void)setPrimitiveMonitorPacers:(NSNumber*)value;

- (BOOL)primitiveMonitorPacersValue;
- (void)setPrimitiveMonitorPacersValue:(BOOL)value_;

- (NSNumber*)primitiveMultiLap;
- (void)setPrimitiveMultiLap:(NSNumber*)value;

- (BOOL)primitiveMultiLapValue;
- (void)setPrimitiveMultiLapValue:(BOOL)value_;

- (id)primitiveSplitAttributes;
- (void)setPrimitiveSplitAttributes:(id)value;

- (NSString*)primitiveSplitId;
- (void)setPrimitiveSplitId:(NSString*)value;

- (NSString*)primitiveSplitName;
- (void)setPrimitiveSplitName:(NSString*)value;

@end

@interface CurrentCourseAttributes: NSObject 
+ (NSString *)combinedSplitAttributes;
+ (NSString *)eventId;
+ (NSString *)eventName;
+ (NSString *)liveAttributes;
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
