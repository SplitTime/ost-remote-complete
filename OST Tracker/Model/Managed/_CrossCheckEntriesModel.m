// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to CrossCheckEntriesModel.m instead.

#import "_CrossCheckEntriesModel.h"

@implementation CrossCheckEntriesModelID
@end

@implementation _CrossCheckEntriesModel

+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"CrossCheckEntriesModel" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"CrossCheckEntriesModel";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"CrossCheckEntriesModel" inManagedObjectContext:moc_];
}

- (CrossCheckEntriesModelID*)objectID {
	return (CrossCheckEntriesModelID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];

	return keyPaths;
}

@dynamic bibNumber;

@dynamic courseId;

@dynamic splitName;

@end

@implementation CrossCheckEntriesModelAttributes 
+ (NSString *)bibNumber {
	return @"bibNumber";
}
+ (NSString *)courseId {
	return @"courseId";
}
+ (NSString *)splitName {
	return @"splitName";
}
@end

