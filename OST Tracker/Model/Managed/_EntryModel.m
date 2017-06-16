// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to EntryModel.m instead.

#import "_EntryModel.h"

@implementation EntryModelID
@end

@implementation _EntryModel

+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"EntryModel" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"EntryModel";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"EntryModel" inManagedObjectContext:moc_];
}

- (EntryModelID*)objectID {
	return (EntryModelID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];

	if ([key isEqualToString:@"submittedValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"submitted"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}

@dynamic absoluteTime;

@dynamic bibNumber;

@dynamic bitKey;

@dynamic entryId;

@dynamic source;

@dynamic splitId;

@dynamic stoppedHere;

@dynamic submitted;

- (BOOL)submittedValue {
	NSNumber *result = [self submitted];
	return [result boolValue];
}

- (void)setSubmittedValue:(BOOL)value_ {
	[self setSubmitted:@(value_)];
}

- (BOOL)primitiveSubmittedValue {
	NSNumber *result = [self primitiveSubmitted];
	return [result boolValue];
}

- (void)setPrimitiveSubmittedValue:(BOOL)value_ {
	[self setPrimitiveSubmitted:@(value_)];
}

@dynamic withPacer;

@end

@implementation EntryModelAttributes 
+ (NSString *)absoluteTime {
	return @"absoluteTime";
}
+ (NSString *)bibNumber {
	return @"bibNumber";
}
+ (NSString *)bitKey {
	return @"bitKey";
}
+ (NSString *)entryId {
	return @"entryId";
}
+ (NSString *)source {
	return @"source";
}
+ (NSString *)splitId {
	return @"splitId";
}
+ (NSString *)stoppedHere {
	return @"stoppedHere";
}
+ (NSString *)submitted {
	return @"submitted";
}
+ (NSString *)withPacer {
	return @"withPacer";
}
@end

