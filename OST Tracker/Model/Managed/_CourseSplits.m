// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to CourseSplits.m instead.

#import "_CourseSplits.h"

@implementation CourseSplitsID
@end

@implementation _CourseSplits

+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"CourseSplits" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"CourseSplits";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"CourseSplits" inManagedObjectContext:moc_];
}

- (CourseSplitsID*)objectID {
	return (CourseSplitsID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];

	return keyPaths;
}

@dynamic baseName;

@dynamic entries;

@end

@implementation CourseSplitsAttributes 
+ (NSString *)baseName {
	return @"baseName";
}
+ (NSString *)entries {
	return @"entries";
}
@end

@implementation CourseSplitsUserInfo 
+ (NSString *)relatedByAttribute {
	return @"baseName";
}
@end

