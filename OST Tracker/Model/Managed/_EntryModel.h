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

@property (nonatomic, strong, nullable) NSString* absoluteTime;

@property (nonatomic, strong, nullable) NSString* bibNumber;

@property (nonatomic, strong, nullable) NSString* bitKey;

@property (nonatomic, strong, nullable) NSDecimalNumber* entryId;

@property (nonatomic, strong, nullable) NSString* source;

@property (nonatomic, strong, nullable) NSString* splitId;

@property (nonatomic, strong, nullable) NSString* stoppedHere;

@property (nonatomic, strong, nullable) NSNumber* submitted;

@property (atomic) BOOL submittedValue;
- (BOOL)submittedValue;
- (void)setSubmittedValue:(BOOL)value_;

@property (nonatomic, strong, nullable) NSString* withPacer;

@end

@interface _EntryModel (CoreDataGeneratedPrimitiveAccessors)

- (NSString*)primitiveAbsoluteTime;
- (void)setPrimitiveAbsoluteTime:(NSString*)value;

- (NSString*)primitiveBibNumber;
- (void)setPrimitiveBibNumber:(NSString*)value;

- (NSString*)primitiveBitKey;
- (void)setPrimitiveBitKey:(NSString*)value;

- (NSDecimalNumber*)primitiveEntryId;
- (void)setPrimitiveEntryId:(NSDecimalNumber*)value;

- (NSString*)primitiveSource;
- (void)setPrimitiveSource:(NSString*)value;

- (NSString*)primitiveSplitId;
- (void)setPrimitiveSplitId:(NSString*)value;

- (NSString*)primitiveStoppedHere;
- (void)setPrimitiveStoppedHere:(NSString*)value;

- (NSNumber*)primitiveSubmitted;
- (void)setPrimitiveSubmitted:(NSNumber*)value;

- (BOOL)primitiveSubmittedValue;
- (void)setPrimitiveSubmittedValue:(BOOL)value_;

- (NSString*)primitiveWithPacer;
- (void)setPrimitiveWithPacer:(NSString*)value;

@end

@interface EntryModelAttributes: NSObject 
+ (NSString *)absoluteTime;
+ (NSString *)bibNumber;
+ (NSString *)bitKey;
+ (NSString *)entryId;
+ (NSString *)source;
+ (NSString *)splitId;
+ (NSString *)stoppedHere;
+ (NSString *)submitted;
+ (NSString *)withPacer;
@end

NS_ASSUME_NONNULL_END
