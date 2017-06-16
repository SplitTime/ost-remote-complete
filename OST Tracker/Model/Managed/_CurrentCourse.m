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

	return keyPaths;
}

@dynamic eventId;

@dynamic splitId;

@end

@implementation CurrentCourseAttributes 
+ (NSString *)eventId {
	return @"eventId";
}
+ (NSString *)splitId {
	return @"splitId";
}
@end

@implementation CurrentCourseUserInfo 
+ (NSString *)relatedByAttribute {
	return @"splitId";
}
@end

