// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to EventModel.h instead.

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

@interface EventModelID : NSManagedObjectID {}
@end

@interface _EventModel : NSManagedObject
+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_;
+ (NSString*)entityName;
+ (nullable NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
@property (nonatomic, readonly, strong) EventModelID *objectID;

@property (nonatomic, strong, nullable) id dataEntryGroups;

@property (nonatomic, strong, nullable) NSString* eventGroupId;

@property (nonatomic, strong, nullable) NSString* eventId;

@property (nonatomic, strong, nullable) NSNumber* multiLap;

@property (atomic) BOOL multiLapValue;
- (BOOL)multiLapValue;
- (void)setMultiLapValue:(BOOL)value_;

@property (nonatomic, strong, nullable) NSString* name;

@property (nonatomic, strong, nullable) NSString* slug;

@property (nonatomic, strong, nullable) id splits;

@property (nonatomic, strong, nullable) NSDate* startTime;

@end

@interface _EventModel (CoreDataGeneratedPrimitiveAccessors)

- (nullable id)primitiveDataEntryGroups;
- (void)setPrimitiveDataEntryGroups:(nullable id)value;

- (nullable NSString*)primitiveEventGroupId;
- (void)setPrimitiveEventGroupId:(nullable NSString*)value;

- (nullable NSString*)primitiveEventId;
- (void)setPrimitiveEventId:(nullable NSString*)value;

- (nullable NSNumber*)primitiveMultiLap;
- (void)setPrimitiveMultiLap:(nullable NSNumber*)value;

- (BOOL)primitiveMultiLapValue;
- (void)setPrimitiveMultiLapValue:(BOOL)value_;

- (nullable NSString*)primitiveName;
- (void)setPrimitiveName:(nullable NSString*)value;

- (nullable NSString*)primitiveSlug;
- (void)setPrimitiveSlug:(nullable NSString*)value;

- (nullable id)primitiveSplits;
- (void)setPrimitiveSplits:(nullable id)value;

- (nullable NSDate*)primitiveStartTime;
- (void)setPrimitiveStartTime:(nullable NSDate*)value;

@end

@interface EventModelAttributes: NSObject 
+ (NSString *)dataEntryGroups;
+ (NSString *)eventGroupId;
+ (NSString *)eventId;
+ (NSString *)multiLap;
+ (NSString *)name;
+ (NSString *)slug;
+ (NSString *)splits;
+ (NSString *)startTime;
@end

@interface EventModelUserInfo: NSObject 
+ (NSString *)relatedByAttribute;
@end

NS_ASSUME_NONNULL_END
