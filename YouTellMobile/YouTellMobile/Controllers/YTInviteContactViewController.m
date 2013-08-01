//
//  YTInviteContactViewController.m
//  Backdoor
//
//  Created by Lin Xu on 7/30/13.
//  Copyright (c) 2013 4WT. All rights reserved.
//

#import "YTInviteContactViewController.h"
#import "YTContacts.h"
#import <AddressBook/AddressBook.h>
#import "YTAddressBookHelper.h"
#import "YTAppDelegate.h"
#import "YTHelper.h"
#import <QuartzCore/QuartzCore.h>
#import "YTInviteContactComposeViewController.h"
#import "YTMainViewHelper.h"

@interface YTInviteContactViewController ()
@property (nonatomic, retain) YTContacts* possibleContacts;
@property (nonatomic, retain) YTInviteContactComposeViewController* compose;
@end


@implementation YTInviteContactViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.headerLabel.text = [NSString stringWithFormat:NSLocalizedString(@"What's %@'s number?", nil),
                        self.contact.name];
    
    self.title = NSLocalizedString(@"Invite", nil);
    //cancel please
    self.navigationItem.backBarButtonItem = nil;
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonItemStyleBordered target:self action:@selector(cancelButtonWasClicked)];

    [YTAddressBookHelper fetchContactsFromAddressBookByContact:self.contact
                                                       success:^(YTContacts *c) {
                                                           self.possibleContacts = c;
                                                           [self.contactsTable reloadData];
                                                       }];
    
    self.compose = [[YTInviteContactComposeViewController alloc] init];    
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch(section) {
        case 0:
            return self.possibleContacts.count;
        case 1:
            return 1;
        default:
            return 0;
    }
    
}

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    NSString* title = @"";
    NSString* subtitle = @"";
    NSString* time = @"";
    UIImage* image = nil;

    if(indexPath.section == 0) {
        YTContact* c = [self.possibleContacts contactAtIndex:indexPath.row];
        title = c.name;
        subtitle = c.phone_number;
        image = c.image;
        if(!image)
            image = [YTHelper imageNamed:@"avatar6"];
    }

    cell = [[YTMainViewHelper sharedInstance] cellWithTableView:tableView title:title subtitle:subtitle time:time
                                                          image:nil
                                                         avatar:nil
                                               placeHolderImage:image
                                                backgroundColor:nil];

    if(indexPath.section == 1) {
        //for some reason, iOS is not letting us have two cell types in the same UITableView, though that
        //should be just fine. urgh.
        UILabel *textLabel = (UILabel*)[cell viewWithTag:3];
        textLabel.text = @"Choose from my address book";
        textLabel.frame = CGRectMake(0,(60-17)/2, self.view.frame.size.width, 17);
        textLabel.font = [UIFont systemFontOfSize:17.0];
        textLabel.textAlignment = NSTextAlignmentCenter;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:tableView.indexPathForSelectedRow animated:NO];
    
    switch(indexPath.section) {
        case 0:
        {
            YTContact* c = [self.possibleContacts contactAtIndex:indexPath.row];
            [self showInviteViewForContact:c];
            return;
        }
        case 1:
        {
            ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
            picker.displayedProperties = @[[NSNumber numberWithInt:kABPersonPhoneProperty]];
            picker.peoplePickerDelegate = self;
            [picker.navigationBar setBackgroundImage:[YTHelper imageNamed:@"navbar3"] forBarMetrics:UIBarMetricsDefault];
            [self presentModalViewController:picker animated:YES];

            return;
        }
    }
    
}
- (void) cancelButtonWasClicked
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload {
    [self setHeaderLabel:nil];
    [self setContactsTable:nil];
    [super viewDidUnload];
}

- (void)showInviteViewForContact:(YTContact*)c
{
    NSLog(@"%@ - %@", c.name, c.phone_number);
    self.compose.contact = c;
    [[YTAppDelegate current].navController pushViewController:self.compose animated:YES];
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person
{
    return YES;
}

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker
{
    [peoplePicker dismissModalViewControllerAnimated:YES];
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
    [peoplePicker dismissModalViewControllerAnimated:YES];
    YTContact* c = [self.contact copy];
    c.first_name = (__bridge_transfer NSString*) ABRecordCopyValue(person, kABPersonFirstNameProperty);
    c.last_name = (__bridge_transfer NSString*) ABRecordCopyValue(person, kABPersonLastNameProperty);
    
    ABMutableMultiValueRef multi = ABRecordCopyValue(person, property);
    c.phone_number = (__bridge_transfer NSString*) ABMultiValueCopyValueAtIndex(multi,
                                                                                ABMultiValueGetIndexForIdentifier(multi, identifier));

    [self showInviteViewForContact:c];

    return NO;
}
@end
