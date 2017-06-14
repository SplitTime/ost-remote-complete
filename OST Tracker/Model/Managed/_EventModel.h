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

@property (nonatomic, strong, nullable) id aidStations;

@property (nonatomic, strong, nullable) NSString* eventId;

@property (nonatomic, strong, nullable) NSString* name;

@property (nonatomic, strong, nullable) NSString* slug;

@end

@interface _EventModel (CoreDataGeneratedPrimitiveAccessors)

- (id)primitiveAidStations;
- (void)setPrimitiveAidStations:(id)value;

- (NSString*)primitiveEventId;
- (void)setPrimitiveEventId:(NSString*)value;

- (NSString*)primitiveName;
- (void)setPrimitiveName:(NSString*)value;

- (NSString*)primitiveSlug;
- (void)setPrimitiveSlug:(NSString*)value;

@end

@interface EventModelAttributes: NSObject 
+ (NSString *)aidStations;
+ (NSString *)eventId;
+ (NSString *)name;
+ (NSString *)slug;
@end

NS_ASSUME_NONNULL_END
