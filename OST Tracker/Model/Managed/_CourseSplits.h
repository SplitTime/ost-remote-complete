// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to CourseSplits.h instead.

#if __has_feature(modules)
    @import Foundation;
    @import CoreData;
#else
    #import <Foundation/Foundation.h>
    #import <CoreData/CoreData.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class NSObject;

@interface CourseSplitsID : NSManagedObjectID {}
@end

@interface _CourseSplits : NSManagedObject
+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
@property (nonatomic, readonly, strong) CourseSplitsID *objectID;

@property (nonatomic, strong, nullable) NSString* baseName;

@property (nonatomic, strong, nullable) id entries;

@end

@interface _CourseSplits (CoreDataGeneratedPrimitiveAccessors)

- (NSString*)primitiveBaseName;
- (void)setPrimitiveBaseName:(NSString*)value;

- (id)primitiveEntries;
- (void)setPrimitiveEntries:(id)value;

@end

@interface CourseSplitsAttributes: NSObject 
+ (NSString *)baseName;
+ (NSString *)entries;
@end

@interface CourseSplitsUserInfo: NSObject 
+ (NSString *)relatedByAttribute;
@end

NS_ASSUME_NONNULL_END
