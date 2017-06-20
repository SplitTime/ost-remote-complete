// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to EffortModel.m instead.

#import "_EffortModel.h"

@implementation EffortModelID
@end

@implementation _EffortModel

+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"EffortModel" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"EffortModel";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"EffortModel" inManagedObjectContext:moc_];
}

- (EffortModelID*)objectID {
	return (EffortModelID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];

	return keyPaths;
}

@dynamic bibNumber;

@dynamic effortId;

@dynamic fullName;

@end

@implementation EffortModelAttributes 
+ (NSString *)bibNumber {
	return @"bibNumber";
}
+ (NSString *)effortId {
	return @"effortId";
}
+ (NSString *)fullName {
	return @"fullName";
}
@end

@implementation EffortModelUserInfo 
+ (NSString *)relatedByAttribute {
	return @"effortId";
}
@end

