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

	return keyPaths;
}

@end

