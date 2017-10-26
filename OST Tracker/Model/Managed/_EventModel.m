// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to EventModel.m instead.

#import "_EventModel.h"

@implementation EventModelID
@end

@implementation _EventModel

+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"EventModel" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"EventModel";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"EventModel" inManagedObjectContext:moc_];
}

- (EventModelID*)objectID {
	return (EventModelID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];

	if ([key isEqualToString:@"multiLapValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"multiLap"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}

@dynamic combinedSplitAttributes;

@dynamic eventId;

@dynamic liveEntryAttributes;

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

@dynamic name;

@dynamic slug;

@dynamic splits;

@dynamic startTime;

@end

@implementation EventModelAttributes 
+ (NSString *)combinedSplitAttributes {
	return @"combinedSplitAttributes";
}
+ (NSString *)eventId {
	return @"eventId";
}
+ (NSString *)liveEntryAttributes {
	return @"liveEntryAttributes";
}
+ (NSString *)multiLap {
	return @"multiLap";
}
+ (NSString *)name {
	return @"name";
}
+ (NSString *)slug {
	return @"slug";
}
+ (NSString *)splits {
	return @"splits";
}
+ (NSString *)startTime {
	return @"startTime";
}
@end

@implementation EventModelUserInfo 
+ (NSString *)relatedByAttribute {
	return @"eventId";
}
@end

