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

@property (nonatomic, strong, nullable) NSDecimalNumber* bibNumber;

@property (nonatomic, strong, nullable) NSString* effortId;

@property (nonatomic, strong, nullable) NSString* fullName;

@end

@interface _EffortModel (CoreDataGeneratedPrimitiveAccessors)

- (NSDecimalNumber*)primitiveBibNumber;
- (void)setPrimitiveBibNumber:(NSDecimalNumber*)value;

- (NSString*)primitiveEffortId;
- (void)setPrimitiveEffortId:(NSString*)value;

- (NSString*)primitiveFullName;
- (void)setPrimitiveFullName:(NSString*)value;

@end

@interface EffortModelAttributes: NSObject 
+ (NSString *)bibNumber;
+ (NSString *)effortId;
+ (NSString *)fullName;
@end

@interface EffortModelUserInfo: NSObject 
+ (NSString *)relatedByAttribute;
@end

NS_ASSUME_NONNULL_END
