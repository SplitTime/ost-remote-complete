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

	return keyPaths;
}

@dynamic eventId;

@dynamic name;

@dynamic slug;

@dynamic splits;

@end

@implementation EventModelAttributes 
+ (NSString *)eventId {
	return @"eventId";
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
@end

@implementation EventModelUserInfo 
+ (NSString *)relatedByAttribute {
	return @"eventId";
}
@end

