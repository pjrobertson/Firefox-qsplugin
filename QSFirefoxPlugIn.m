//
//  QSFirefoxPlugIn.m
//  QSFirefoxPlugIn
//
//  Created by Nicholas Jitkoff on 4/6/05.
//  Copyright __MyCompanyName__ 2005. All rights reserved.
//

#import "QSFirefoxPlugIn.h"

@implementation QSFirefoxPlugIn

- (void) performJavaScript:(NSString *)jScript{
	//NSLog(@"JAVASCRIPT perform: %@",jScript);
	NSDictionary *errorDict=nil;
	NSAppleScript *script=[[[NSAppleScript alloc]initWithSource:[NSString stringWithFormat:@"tell application \"Firefox\" to Get URL \"%@\"",jScript]]autorelease];
	if (errorDict) NSLog(@"Load Script: %@",[errorDict objectForKey:@"NSAppleScriptErrorMessage"]);
	else [script executeAndReturnError:&errorDict];
	if (errorDict) NSLog(@"Run Script: %@",[errorDict objectForKey:@"NSAppleScriptErrorMessage"]);
}

@end

@implementation QSFirefoxBookmarksParser

- (BOOL)validParserForPath:(NSString *)path {
	return [[path lastPathComponent] isEqualToString:@"places.sqlite"];
}

- (NSArray *)objectsFromPath:(NSString *)path withSettings:(NSDictionary *)settings {
	NSMutableArray *objects=[NSMutableArray arrayWithCapacity:0];

	// copy places.sqlite
	NSFileManager *manager = [NSFileManager defaultManager];
	NSString *tempPath = [NSTemporaryDirectory() stringByAppendingString:@"QSFirefoxPlaces.sqlite"];
	NSError *err;
	BOOL status;

	// make sure tmp-copy of places.sqlite isn't there
	status = [manager removeItemAtPath:tempPath error:&err];
	status = [manager copyItemAtPath:path toPath:tempPath error:&err];
	if (!status) {
		NSLog(@"Error while copying Firefox places.sqlite: %@", err);
	}
	
	// open places.sqlite DB
	FMDatabase *db = [FMDatabase databaseWithPath:tempPath];
	if (![db open]) {
		NSLog(@"Could not open Firefox's places.sqlite DB.");
		return objects;
	}
	
	// build SQL query
	NSString *url, *title;
	QSObject *newObject;
	NSString *query = @"SELECT "
					   "bookmarks.title AS title, "
					   "places.url AS url "
					   "FROM moz_bookmarks AS bookmarks "
					   "LEFT JOIN moz_places AS places ON places.id = bookmarks.fk "
					   "WHERE bookmarks.fk IS NOT NULL "
					   "AND bookmarks.title IS NOT NULL "
					   "ORDER BY bookmarks.title";
	FMResultSet *rs = [db executeQuery:query];
	if ([db hadError]) {
		NSLog(@"Error while reading Firefox's places.sqlite DB. Error %d: %@", [db lastErrorCode], [db lastErrorMessage]);
		return objects;
	}
	
	// build QSObjects
	while ([rs next]) {
		title = [rs stringForColumn:@"title"];
		url = [rs stringForColumn:@"url"];

		newObject = [QSObject URLObjectWithURL:url title:title];
		[objects addObject:newObject];
	}
	
	// close DB
	[rs close];
	[db close];		
	
	// delete tmp-copy of places.sqlite
	status = [manager removeItemAtPath:tempPath error:&err];
	if (!status) {
		NSLog(@"Error while removing copy of Firefox places.sqlite: %@", err);
	}
	
	return objects;
}

@end

