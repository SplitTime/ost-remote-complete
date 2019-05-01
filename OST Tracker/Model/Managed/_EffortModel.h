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
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
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

- (NSNumber*)primitiveAge;
- (void)setPrimitiveAge:(NSNumber*)value;

- (int16_t)primitiveAgeValue;
- (void)setPrimitiveAgeValue:(int16_t)value_;

- (NSDecimalNumber*)primitiveBibNumber;
- (void)setPrimitiveBibNumber:(NSDecimalNumber*)value;

- (NSString*)primitiveEffortId;
- (void)setPrimitiveEffortId:(NSString*)value;

- (NSDecimalNumber*)primitiveEventId;
- (void)setPrimitiveEventId:(NSDecimalNumber*)value;

- (NSString*)primitiveFlexibleGeolocation;
- (void)setPrimitiveFlexibleGeolocation:(NSString*)value;

- (NSString*)primitiveFullName;
- (void)setPrimitiveFullName:(NSString*)value;

- (NSString*)primitiveGender;
- (void)setPrimitiveGender:(NSString*)value;

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
