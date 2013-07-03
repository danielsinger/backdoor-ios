//
//  YTStoreHelper.m
//  YouTellMobile
//
//  Copyright (c) 2013 Backdoor LLC. All rights reserved.
//

#import <StoreKit/StoreKit.h>

#import <MF_Base64Additions.h>
#import <SVProgressHUD/SVProgressHUD.h>
#import <Flurry.h>
#import <Mixpanel.h>

#import "YTStoreHelper.h"
#import "YTApiHelper.h"
#import "YTHelper.h"
#import "YTViewHelper.h"
#import "YTModelHelper.h"
#import "YTAppDelegate.h"


@implementation YTStoreHelper

- (id)init
{
    id ret = [super init];
    if (ret) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return ret;
}

- (void)showFromBarButtonItem:(UIBarButtonItem*)barButtonItem
{
    self.barButtonItem = barButtonItem;
    
    NSSet *productIdentifiers = [NSSet setWithObjects:@"YouTell_Mobile_Clues_001", @"YouTell_Mobile_Clues_002", @"YouTell_Mobile_Clues_003", nil];

    [SVProgressHUD showWithStatus:NSLocalizedString(@"Connecting to iTunes store", nil) maskType:SVProgressHUDMaskTypeClear];
    

    self.productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    self.productsRequest.delegate = self;
    [self.productsRequest start];
}


- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    [SVProgressHUD dismiss];
    
    if (!self.barButtonItem) {
        return;
    }
    
    NSArray *products = response.products;

    UIActionSheet *sheet = [[UIActionSheet alloc] init];
    
    sheet.title = NSLocalizedString(@"Clues can be used in all received threads.", nil);
    sheet.delegate = self;
    
    NSNumberFormatter *priceFormatter = [NSNumberFormatter new];
    priceFormatter.formatterBehavior = NSNumberFormatterBehavior10_4;
    priceFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
    self.products = [NSMutableDictionary new];
    
    for(SKProduct *prod in products) {
        priceFormatter.locale = prod.priceLocale;
        NSString *priceString = [priceFormatter stringFromNumber:prod.price];
        NSString *title = [NSString stringWithFormat:@"%@ %@ (%@)", NSLocalizedString(@"Buy", nil), prod.localizedTitle, priceString, nil];
        NSInteger index = [sheet addButtonWithTitle:title];
        self.products[[NSNumber numberWithInteger:index]] = prod;
    }

    
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    
    [sheet showFromBarButtonItem:self.barButtonItem animated:YES];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    [SVProgressHUD dismiss];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"Cannot connect with iTunes store", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK",nil) otherButtonTitles:nil];
    [alert show];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }
    
    SKProduct *product = self.products[[NSNumber numberWithInteger:buttonIndex]];
    SKPayment *payment = [SKPayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    NSLog(@"Adding product to the payment queue: %@", product.productIdentifier);
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for(SKPaymentTransaction *transaction in transactions) {
        NSLog(@"Transaction notification: %@ (%@), state: %d, error: %@", transaction.transactionIdentifier, transaction.payment.productIdentifier, transaction.transactionState, transaction.error.debugDescription);

        switch(transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self transactionDidPurchase:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self transactionDidPurchase:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self transactionDidFail:transaction];
                break;
            default:
                break;
        }
    }
}

- (void)transactionDidPurchase:(SKPaymentTransaction*)transaction
{
    NSInteger prevCount = [YTModelHelper userAvailableClues];

    [YTApiHelper buyCluesWithReceipt:[transaction.transactionReceipt base64String] success:^(id JSON) {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];

        [YTViewHelper refreshViews];
        NSInteger count = [YTModelHelper userAvailableClues];

        [Flurry logEvent:@"Bought_Clues" withParameters:@{@"count": [NSNumber numberWithInteger:count - prevCount]}];
        [[Mixpanel sharedInstance] track:@"Bought Clues"];

        YTAppDelegate *delegate = [YTAppDelegate current];
        if (delegate.currentGabViewController && delegate.currentGabViewController.clueHelper) {
            [delegate.currentGabViewController.clueHelper actionButtonWasPressed:nil];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Transaction", nil) message:[NSString stringWithFormat:NSLocalizedString(@"You have %d available clues. You can use them in all incoming threads", nil), count] delegate:nil cancelButtonTitle:NSLocalizedString(@"OK",nil) otherButtonTitles:nil];
            [alert show];
        }
    }];
}

- (void)transactionDidFail:(SKPaymentTransaction*)transaction
{
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];

    if (transaction.error.code != SKErrorPaymentCancelled) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil) message:transaction.error.localizedDescription delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
        [alert show];
    }
    
}

@end
