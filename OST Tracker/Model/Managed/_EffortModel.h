// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to EffortModel.h instead.

#if __has_feature(modules)
    @import Foundation;
    @import CoreData;
#else
    #import <Foundation/Foundation.h>
    #import <CoreData/CoreData.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface EffortModelID : NSManagedObjectID {}
@end

@interface _EffortModel : NSManagedObject
+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_;
+ (NSString*)entityName;
+ (nullable NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
@property (nonatomic, readonly, strong) EffortModelID *objectID;

@property (nonatomic, strong, nullable) NSNumber* age;

@property (atomic) int16_t ageValue;
- (int16_t)ageValue;
- (void)setAgeValue:(int16_t)value_;

@property (nonatomic, strong, nullable) NSDecimalNumber* bibNumber;

@property (nonatomic, strong, nullable) NSString* effortId;

@property (nonatomic, strong, nullable) NSDecimalNumber* eventId;

@property (nonatomic, strong, nullable) NSString* flexibleGeolocation;

@property (nonatomic, strong, nullable) NSString* fullName;

@property (nonatomic, strong, nullable) NSString* gender;

@end

@interface _EffortModel (CoreDataGeneratedPrimitiveAccessors)

- (nullable NSNumber*)primitiveAge;
- (void)setPrimitiveAge:(nullable NSNumber*)value;

- (int16_t)primitiveAgeValue;
- (void)setPrimitiveAgeValue:(int16_t)value_;

- (nullable NSDecimalNumber*)primitiveBibNumber;
- (void)setPrimitiveBibNumber:(nullable NSDecimalNumber*)value;

- (nullable NSString*)primitiveEffortId;
- (void)setPrimitiveEffortId:(nullable NSString*)value;

- (nullable NSDecimalNumber*)primitiveEventId;
- (void)setPrimitiveEventId:(nullable NSDecimalNumber*)value;

- (nullable NSString*)primitiveFlexibleGeolocation;
- (void)setPrimitiveFlexibleGeolocation:(nullable NSString*)value;

- (nullable NSString*)primitiveFullName;
- (void)setPrimitiveFullName:(nullable NSString*)value;

- (nullable NSString*)primitiveGender;
- (void)setPrimitiveGender:(nullable NSString*)value;

@end

@interface EffortModelAttributes: NSObject 
+ (NSString *)age;
+ (NSString *)bibNumber;
+ (NSString *)effortId;
+ (NSString *)eventId;
+ (NSString *)flexibleGeolocation;
+ (NSString *)fullName;
+ (NSString *)gender;
@end

@interface EffortModelUserInfo: NSObject 
+ (NSString *)relatedByAttribute;
@end

NS_ASSUME_NONNULL_END
