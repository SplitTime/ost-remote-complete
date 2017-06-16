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

@interface EventModelID : NSManagedObjectID {}
@end

@interface _EventModel : NSManagedObject
+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
@property (nonatomic, readonly, strong) EventModelID *objectID;

@property (nonatomic, strong, nullable) NSString* eventId;

@property (nonatomic, strong, nullable) NSString* name;

@property (nonatomic, strong, nullable) NSString* slug;

@property (nonatomic, strong, nullable) id splits;

@end

@interface _EventModel (CoreDataGeneratedPrimitiveAccessors)

- (NSString*)primitiveEventId;
- (void)setPrimitiveEventId:(NSString*)value;

- (NSString*)primitiveName;
- (void)setPrimitiveName:(NSString*)value;

- (NSString*)primitiveSlug;
- (void)setPrimitiveSlug:(NSString*)value;

- (id)primitiveSplits;
- (void)setPrimitiveSplits:(id)value;

@end

@interface EventModelAttributes: NSObject 
+ (NSString *)eventId;
+ (NSString *)name;
+ (NSString *)slug;
+ (NSString *)splits;
@end

@interface EventModelUserInfo: NSObject 
+ (NSString *)relatedByAttribute;
@end

NS_ASSUME_NONNULL_END
