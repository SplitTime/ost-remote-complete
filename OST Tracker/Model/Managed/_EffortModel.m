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

	if ([key isEqualToString:@"ageValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"age"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}

@dynamic age;

- (int16_t)ageValue {
	NSNumber *result = [self age];
	return [result shortValue];
}

- (void)setAgeValue:(int16_t)value_ {
	[self setAge:@(value_)];
}

- (int16_t)primitiveAgeValue {
	NSNumber *result = [self primitiveAge];
	return [result shortValue];
}

- (void)setPrimitiveAgeValue:(int16_t)value_ {
	[self setPrimitiveAge:@(value_)];
}

@dynamic bibNumber;

@dynamic effortId;

@dynamic eventId;

@dynamic flexibleGeolocation;

@dynamic fullName;

@dynamic gender;

@end

@implementation EffortModelAttributes 
+ (NSString *)age {
	return @"age";
}
+ (NSString *)bibNumber {
	return @"bibNumber";
}
+ (NSString *)effortId {
	return @"effortId";
}
+ (NSString *)eventId {
	return @"eventId";
}
+ (NSString *)flexibleGeolocation {
	return @"flexibleGeolocation";
}
+ (NSString *)fullName {
	return @"fullName";
}
+ (NSString *)gender {
	return @"gender";
}
@end

@implementation EffortModelUserInfo 
+ (NSString *)relatedByAttribute {
	return @"effortId";
}
@end

