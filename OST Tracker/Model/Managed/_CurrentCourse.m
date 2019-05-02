// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to CurrentCourse.m instead.

#import "_CurrentCourse.h"

@implementation CurrentCourseID
@end

@implementation _CurrentCourse

+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"CurrentCourse" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"CurrentCourse";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"CurrentCourse" inManagedObjectContext:moc_];
}

- (CurrentCourseID*)objectID {
	return (CurrentCourseID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];

	if ([key isEqualToString:@"monitorPacersValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"monitorPacers"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}
	if ([key isEqualToString:@"multiLapValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"multiLap"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}

@dynamic dataEntryGroups;

@dynamic eventGroupId;

@dynamic eventId;

@dynamic eventIdsAndSplits;

@dynamic eventName;

@dynamic eventShortNames;

@dynamic monitorPacers;

- (BOOL)monitorPacersValue {
	NSNumber *result = [self monitorPacers];
	return [result boolValue];
}

- (void)setMonitorPacersValue:(BOOL)value_ {
	[self setMonitorPacers:@(value_)];
}

- (BOOL)primitiveMonitorPacersValue {
	NSNumber *result = [self primitiveMonitorPacers];
	return [result boolValue];
}

- (void)setPrimitiveMonitorPacersValue:(BOOL)value_ {
	[self setPrimitiveMonitorPacers:@(value_)];
}

@dynamic multiLap;

- (BOOL)multiLapValue {
	NSNumber *result = [self multiLap];
	return [result boolValue];
}

- (void)setMultiLapValue:(BOOL)value_ {
	[self setMultiLap:@(value_)];
}

- (BOOL)primitiveMultiLapValue {
	NSNumber *result = [self primitiveMultiLap];
	return [result boolValue];
}

- (void)setPrimitiveMultiLapValue:(BOOL)value_ {
	[self setPrimitiveMultiLap:@(value_)];
}

@dynamic splitAttributes;

@dynamic splitId;

@dynamic splitName;

@end

@implementation CurrentCourseAttributes 
+ (NSString *)dataEntryGroups {
	return @"dataEntryGroups";
}
+ (NSString *)eventGroupId {
	return @"eventGroupId";
}
+ (NSString *)eventId {
	return @"eventId";
}
+ (NSString *)eventIdsAndSplits {
	return @"eventIdsAndSplits";
}
+ (NSString *)eventName {
	return @"eventName";
}
+ (NSString *)eventShortNames {
	return @"eventShortNames";
}
+ (NSString *)monitorPacers {
	return @"monitorPacers";
}
+ (NSString *)multiLap {
	return @"multiLap";
}
+ (NSString *)splitAttributes {
	return @"splitAttributes";
}
+ (NSString *)splitId {
	return @"splitId";
}
+ (NSString *)splitName {
	return @"splitName";
}
@end

@implementation CurrentCourseUserInfo 
+ (NSString *)relatedByAttribute {
	return @"splitId";
}
@end

