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

@property (nonatomic, strong, nullable) NSString* kind;

@property (nonatomic, strong, nullable) id nameExtentions;

@property (nonatomic, strong, nullable) NSString* splitId;

@end

@interface _CourseSplits (CoreDataGeneratedPrimitiveAccessors)

- (NSString*)primitiveBaseName;
- (void)setPrimitiveBaseName:(NSString*)value;

- (NSString*)primitiveKind;
- (void)setPrimitiveKind:(NSString*)value;

- (id)primitiveNameExtentions;
- (void)setPrimitiveNameExtentions:(id)value;

- (NSString*)primitiveSplitId;
- (void)setPrimitiveSplitId:(NSString*)value;

@end

@interface CourseSplitsAttributes: NSObject 
+ (NSString *)baseName;
+ (NSString *)kind;
+ (NSString *)nameExtentions;
+ (NSString *)splitId;
@end

@interface CourseSplitsUserInfo: NSObject 
+ (NSString *)relatedByAttribute;
@end

NS_ASSUME_NONNULL_END
