// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to EntryModel.h instead.

#if __has_feature(modules)
    @import Foundation;
    @import CoreData;
#else
    #import <Foundation/Foundation.h>
    #import <CoreData/CoreData.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface EntryModelID : NSManagedObjectID {}
@end

@interface _EntryModel : NSManagedObject
+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
@property (nonatomic, readonly, strong) EntryModelID *objectID;

@end

@interface _EntryModel (CoreDataGeneratedPrimitiveAccessors)

@end

NS_ASSUME_NONNULL_END
