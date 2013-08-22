//
//  YTModelHelper.m
//  YouTellMobile
//
//  Copyright (c) 2013 Backdoor LLC. All rights reserved.
//

#import <CoreData/CoreData.h>

#import <Base64/MF_Base64Additions.h>

#import "YTConfig.h"
#import "YTHelper.h"
#import "YTModelHelper.h"
#import "YTViewHelper.h"
#import "YTFBHelper.h"
#import "YTGPPHelper.h"
#import "YTTourViewController.h"

@implementation YTModelHelper


+ (void)setup
{
    NSURL *storeURL = [YTModelHelper storeURL];
    //[[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
    
    NSError *error = nil;
    
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:[YTModelHelper modelURL]];
    
    NSPersistentStoreCoordinator *coord = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    
    if (![coord addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        
        [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
        
        if (![coord addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
    
    NSManagedObjectContext *context = [NSManagedObjectContext new];
    context.persistentStoreCoordinator = coord;
    
    [YTAppDelegate current].managedObjectContext = context;
}

+ (void)save
{
    NSError *error;
    [[YTAppDelegate current].managedObjectContext save:&error];
}

+ (NSString*)settingsForKey:(NSString*)key
{
    NSManagedObjectContext *context = [YTAppDelegate current].managedObjectContext;

    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Settings"];
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"(key = %@)", key];
    [request setPredicate:pred];
    
    NSError *error;
    NSArray *objects = [context executeFetchRequest:request error:&error];
    
    if ([objects count] == 0) {
        return @"";
    }
    NSManagedObject *obj = objects[0];
    return [obj valueForKey:@"value"];
}

+ (void)removeSettingsForKey:(NSString*)key
{
    NSManagedObjectContext *context = [YTAppDelegate current].managedObjectContext;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Settings"];
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"(key = %@)", key];
    [request setPredicate:pred];
    
    NSError *error;
    NSArray *objects = [context executeFetchRequest:request error:&error];
    
    if ([objects count] > 0) {
        [context deleteObject:objects[0]];
    }
}

+ (void)setSettingsForKey:(NSString*)key value:(id)value
{
    NSManagedObjectContext *context = [YTAppDelegate current].managedObjectContext;

    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Settings"];
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"(key = %@)", key];
    [request setPredicate:pred];
    
    NSError *error;
    NSObject *object;
    NSArray *objects = [context executeFetchRequest:request error:&error];
    
    if ([objects count] > 0) {
        object = objects[0];
    } else {
        object = [NSEntityDescription insertNewObjectForEntityForName:@"Settings" inManagedObjectContext:context];
    }
    
    [object setValue:key forKey:@"key"];
    [object setValue:value forKey:@"value"];
    
    //save immediately
    [context save:&error];
}

+ (NSManagedObject*)findOrCreateWithId:(NSString*)oId entityName:(NSString*)entityName context:(NSManagedObjectContext*)context
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:entityName];
    NSNumber *myId = [YTHelper parseNumber:oId];
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"(id = %@)", myId];
    
    [request setPredicate:pred];
    
    NSError *error;
    
    NSArray *objects = [context executeFetchRequest:request error:&error];
    NSManagedObject *object;
    if ([objects count] > 0) {
        object = objects[0];
    } else {
        object = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:context];
        [object setValue:myId forKey:@"id"];
    }
    
    return object;
}

+ (void)updateUnreadCount
{
    NSManagedObjectContext *context = [YTAppDelegate current].managedObjectContext;

    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Gabs"];
   
    NSError *error;
    
    int unread = 0;
    NSArray *objects = [context executeFetchRequest:request error:&error];
    for(NSManagedObject* object in objects) {
        NSNumber* u_count = [object valueForKey:@"unread_count"];
        if(u_count)
            unread += u_count.integerValue;
    }
    
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:unread];

}

+ (NSManagedObject*)messageForKey:(NSString*)key context:(NSManagedObjectContext*)context
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Messages"];
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"(key = %@)", key];
    
    [request setPredicate:pred];
    
    NSError *error;
    
    NSArray *objects = [context executeFetchRequest:request error:&error];
    NSManagedObject *object;
    if ([objects count] > 0) {
        object = objects[0];
    } else {
        object = [NSEntityDescription insertNewObjectForEntityForName:@"Messages" inManagedObjectContext:context];
        [object setValue:key forKey:@"key"];
    }
    
    return object;
}

+ (NSDictionary*)cluesForGab:(NSNumber*)gabId
{
    YTAppDelegate *delegate = [YTAppDelegate current];
    NSManagedObjectContext *context = [delegate managedObjectContext];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(gab_id = %@)", gabId];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"id" ascending:YES];
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Clues"];

    request.sortDescriptors = @[sortDescriptor];
    request.predicate = predicate;
    
    NSError *error;
    
    NSArray *objects = [context executeFetchRequest:request error:&error];
    NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
    
    for (NSManagedObject *obj in objects) {
        NSDictionary *dict = [obj dictionaryWithValuesForKeys:obj.entity.attributesByName.allKeys];
        ret[dict[@"number"]] = dict;
    }
    
    return ret;
}

+ (NSManagedObject*)createOrUpdateClue:(NSDictionary*)data
{
    YTAppDelegate *delegate = [YTAppDelegate current];
    NSManagedObjectContext *context = [delegate managedObjectContext];

    NSManagedObject *clue = [YTModelHelper findOrCreateWithId:data[@"id"] entityName:@"Clues" context:context];
    
    [clue setValue:[YTHelper parseNumber:data[@"gab_id"]] forKey:@"gab_id"];
    [clue setValue:data[@"field"] forKey:@"field"];
    [clue setValue:data[@"value"] forKey:@"value"];
    [clue setValue:[YTHelper parseNumber:data[@"number"]] forKey:@"number"];
    
    return clue;
}

+ (void)clearDataWithEntityName:(NSString*)entityName
{
    YTAppDelegate *delegate = [YTAppDelegate current];
    NSManagedObjectContext *context = delegate.managedObjectContext;

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:entityName];
    fetchRequest.includesPropertyValues = NO;
    
    NSError *error = nil;
    
    for (NSManagedObject *obj in [context executeFetchRequest:fetchRequest error:&error]) {
        [context deleteObject:obj];
    }
}

+ (void)clearData
{
    NSArray *names = @[@"Clues", @"Gabs", @"Messages", @"Settings"];
    for (NSString *name in names) {
        [YTModelHelper clearDataWithEntityName:name];
    }
}

+ (NSURL*)modelURL
{
    return [[NSBundle mainBundle] URLForResource:CONFIG_MODEL withExtension:@"momd"];
}

+ (NSURL*)storeURL
{
    NSString *prefix = CONFIG_MODEL;
    NSString *ext = @"sqlite";
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *storeId = [defs stringForKey:@"storeId"];
    NSString *md5 = [YTHelper md5FromString:storeId];
    NSString *filename = [NSString stringWithFormat:@"%@_%@.%@", prefix, md5, ext];
    NSURL *dir = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *ret = [dir URLByAppendingPathComponent:filename];
    
    return ret;
}

+ (void)changeStoreId:(NSString *)storeId
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:storeId forKey:@"storeId"];
    [defs synchronize];
    [YTModelHelper setup];
}

static int available_clues;

+ (NSInteger)userAvailableClues
{
    return available_clues;
}

+ (void)setUserAvailableClues:(NSNumber*) value
{
    available_clues = value.integerValue;
}

+ (BOOL)userHasShared
{
    return [[YTAppDelegate current].userInfo[@"settings"][@"has_shared"] boolValue];
}

+ (NSString*)phoneForUid:(NSString*)uid
{
    NSString *key = [NSString stringWithFormat:@"facebook_%@", uid];
    return [YTModelHelper settingsForKey:key];
}

+ (void)setPhoneForUid:(NSString*)uid phone:(NSString*)phone
{
    NSString *key = [NSString stringWithFormat:@"facebook_%@", uid];
    return [YTModelHelper setSettingsForKey:key value:phone];
}

@end
