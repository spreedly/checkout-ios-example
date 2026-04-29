//
//  ViewController.m
//  MerchantExample
//
//
//

#import "ViewController.h"
#import "CheckoutBasicViewController.h"
#import "CheckoutWithAdditionalFieldsViewController.h"
#import "CustomFormViewController.h"
#import "CustomThemeFormViewController.h"
#import "CVVRecachingDemoViewController.h"
#import "GlobalThreeDSPaymentFlowViewController.h"
#import "GatewaySpecificThreeDSPaymentFlowViewController.h"
#import "OffsitePaymentFlowViewController.h"
#import "EbanxPaymentFlowViewController.h"
#import "StripeAPMPaymentFlowViewController.h"
#import "BraintreePaymentFlowViewController.h"
#import "ThemeHelper.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>

@interface ViewController ()

@property (nonatomic, strong) NSArray<NSDictionary *> *examples;
@property (nonatomic, strong) UIView *shadowContainerView;

@end

@implementation ViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Reset validation params when returning to Home so toggles don't carry over.
    [[Spreedly shared] setParamWithParameter:ValidationParamAllowBlankName value:NO];
    [[Spreedly shared] setParamWithParameter:ValidationParamAllowExpiredDate value:NO];
    [[Spreedly shared] setParamWithParameter:ValidationParamAllowBlankDate value:NO];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set background color matching SwiftUI MainNavigationView
    self.view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor blackColor]; // #000000
        } else {
            return [UIColor colorWithRed:251.0/255.0 green:252.0/255.0 blue:255.0/255.0 alpha:1.0]; // #FBFCFF
        }
    }];
    
    // Set table view background to clear so parent background shows
    self.tableView.backgroundColor = [UIColor clearColor];
    
    // Step 1: Just add custom font to the title in tableHeaderView
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 60)];
    headerView.backgroundColor = [UIColor clearColor];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Spreedly Examples";
    titleLabel.font = [self customTitleFont]; // Custom Poppins font
    titleLabel.textColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor whiteColor]; // #FFFFFF
        } else {
            return [UIColor colorWithRed:54.0/255.0 green:58.0/255.0 blue:58.0/255.0 alpha:1.0]; // #363A3A
        }
    }];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:titleLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:headerView.topAnchor constant:20],
        [titleLabel.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor constant:16],
        [titleLabel.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor constant:-16],
        [titleLabel.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor constant:-16]
    ]];
    
    self.tableView.tableHeaderView = headerView;
    
    // Step 2: Add shadow to tableView (matching SwiftUI)
    // Create a container view behind tableView for shadow effect
    // Shadow: gray-400 (#AFB4B5) with 0.8 opacity, radius 4, x: 0, y: 0
    self.shadowContainerView = [[UIView alloc] init];
    self.shadowContainerView.backgroundColor = [UIColor clearColor];
    self.shadowContainerView.layer.shadowColor = [UIColor colorWithRed:175.0/255.0 green:180.0/255.0 blue:181.0/255.0 alpha:1.0].CGColor; // gray-400 #AFB4B5
    self.shadowContainerView.layer.shadowOpacity = 0.8;
    self.shadowContainerView.layer.shadowOffset = CGSizeMake(0, 0);
    self.shadowContainerView.layer.shadowRadius = 4.0;
    self.shadowContainerView.layer.masksToBounds = NO;
    self.shadowContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view insertSubview:self.shadowContainerView belowSubview:self.tableView];
    
    // Match shadow container to tableView frame
    [NSLayoutConstraint activateConstraints:@[
        [self.shadowContainerView.topAnchor constraintEqualToAnchor:self.tableView.topAnchor],
        [self.shadowContainerView.leadingAnchor constraintEqualToAnchor:self.tableView.leadingAnchor],
        [self.shadowContainerView.trailingAnchor constraintEqualToAnchor:self.tableView.trailingAnchor],
        [self.shadowContainerView.bottomAnchor constraintEqualToAnchor:self.tableView.bottomAnchor]
    ]];
    
    // Configure examples data
    self.examples = @[
        @{
            @"title": @"Basic Checkout Component",
            @"subtitle": @"Default fields only (First Name, Last Name, Card Number, Expiry Date, CVC)",
            @"class": [CheckoutBasicViewController class],
            @"accessibilityId": @"basicCheckoutLink"
        },
        @{
            @"title": @"Checkout with Additional Fields",
            @"subtitle": @"Default fields plus address fields (Address, City, State, ZIP)",
            @"class": [CheckoutWithAdditionalFieldsViewController class],
            @"accessibilityId": @"additionalFieldsLink"
        },
        @{
            @"title": @"Custom Form with Headless Components",
            @"subtitle": @"Custom form built at application level using headless UI components",
            @"class": [CustomFormViewController class],
            @"accessibilityId": @"customFormLink"
        },
        @{
            @"title": @"Custom Theme Form",
            @"subtitle": @"Beautiful form with custom theme and modern design",
            @"class": [CustomThemeFormViewController class],
            @"accessibilityId": @"customThemeLink"
        },
        @{
            @"title": @"CVV Recaching",
            @"subtitle": @"Update CVV for saved payment methods to enable repeat transactions",
            @"class": [CVVRecachingDemoViewController class],
            @"accessibilityId": @"cvv-recaching-navigation-link"
        },
        @{
            @"title": @"Global 3DS Challenge",
            @"subtitle": @"Complete 3DS authentication flow with product selection and payment",
            @"class": [GlobalThreeDSPaymentFlowViewController class],
            @"accessibilityId": @"three-ds-challenge-navigation-link"
        },
        @{
            @"title": @"Gateway Specific 3DS Challenge",
            @"subtitle": @"Complete gateway-specific 3DS authentication flow with product selection and payment",
            @"class": [GatewaySpecificThreeDSPaymentFlowViewController class],
            @"accessibilityId": @"gateway-specific-3ds-challenge-navigation-link"
        }
        ,
        @{
            @"title": @"Offsite Payment Flow",
            @"subtitle": @"Create offsite payment method and complete checkout",
            @"class": [OffsitePaymentFlowViewController class],
            @"accessibilityId": @"offsite-payment-flow-navigation-link"
        },
        @{
            @"title": @"EBANX Payment Flow",
            @"subtitle": @"Create EBANX offsite payment (Pix, Boleto, OXXO, NuPay) and complete checkout",
            @"class": [EbanxPaymentFlowViewController class],
            @"accessibilityId": @"ebanx-payment-flow-navigation-link"
        },
        @{
            @"title": @"Stripe APM Payment Flow",
            @"subtitle": @"Create Stripe APM pending purchase, then complete checkout with PaymentSheet",
            @"class": [StripeAPMPaymentFlowViewController class],
            @"accessibilityId": @"stripe-apm-payment-flow-navigation-link"
        },
        @{
            @"title": @"Braintree Payment Flow",
            @"subtitle": @"PayPal and Venmo payments via Braintree gateway",
            @"class": [BraintreePaymentFlowViewController class],
            @"accessibilityId": @"braintree-payment-flow-navigation-link"
        }
    ];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return self.examples.count;
    } else {
        return 1; // About section
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"ExampleCell";
    static NSString *aboutCellIdentifier = @"AboutCell";
    
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
        
        NSDictionary *example = self.examples[indexPath.row];
        
        // Use dynamic colors matching SwiftUI MainNavigationView
        cell.backgroundColor = [ThemeHelper cardBackgroundColor];
        cell.textLabel.text = example[@"title"];
        cell.textLabel.textColor = [ThemeHelper textColor];
        cell.textLabel.font = [self headerFont];
        cell.detailTextLabel.text = example[@"subtitle"];
        cell.detailTextLabel.textColor = [ThemeHelper textColor];
        cell.detailTextLabel.font = [self subheadingFont];
        
        // Set accessibility identifier for UI testing
        cell.accessibilityIdentifier = example[@"accessibilityId"];
        cell.accessibilityLabel = example[@"title"];
        cell.accessibilityHint = example[@"subtitle"];
        cell.accessibilityTraits = UIAccessibilityTraitButton;
        
        return cell;
    } else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:aboutCellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:aboutCellIdentifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        
        // Use dynamic colors matching SwiftUI MainNavigationView
        cell.backgroundColor = [ThemeHelper cardBackgroundColor];
        cell.textLabel.text = @"Spreedly SDK for iOS";
        cell.textLabel.textColor = [ThemeHelper textColor];
        cell.textLabel.font = [self headerFont];
        
        // Set accessibility identifier for about section
        cell.accessibilityIdentifier = @"aboutSection";
        cell.accessibilityLabel = @"Spreedly SDK for iOS";
        cell.accessibilityHint = @"Information about the Spreedly SDK";
        
        return cell;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    // Update cell colors when trait collection changes (e.g., dark/light mode switch)
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self.tableView reloadData];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Spreedly SDK Examples";
    } else {
        return @"About";
    }
}


// MARK: - Custom Fonts (matching SwiftUI)

- (UIFont *)customTitleFont {
    // Poppins-Medium 24px, or fallback to system font 24px medium
    if ([UIFont fontWithName:@"Poppins-Medium" size:24]) {
        return [UIFont fontWithName:@"Poppins-Medium" size:24];
    } else if ([UIFont fontWithName:@"Poppins" size:24]) {
        return [UIFont fontWithName:@"Poppins" size:24];
    } else {
        return [UIFont systemFontOfSize:24 weight:UIFontWeightMedium];
    }
}

- (UIFont *)headerFont {
    // Poppins-Medium 16px, or fallback to system font 16px medium
    if ([UIFont fontWithName:@"Poppins-Medium" size:16]) {
        return [UIFont fontWithName:@"Poppins-Medium" size:16];
    } else if ([UIFont fontWithName:@"Poppins" size:16]) {
        return [UIFont fontWithName:@"Poppins" size:16];
    } else {
        return [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    }
}

- (UIFont *)subheadingFont {
    // Poppins-Medium 14px, or fallback to system font 14px medium
    if ([UIFont fontWithName:@"Poppins-Medium" size:14]) {
        return [UIFont fontWithName:@"Poppins-Medium" size:14];
    } else if ([UIFont fontWithName:@"Poppins" size:14]) {
        return [UIFont fontWithName:@"Poppins" size:14];
    } else {
        return [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 44.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 80.0;
    } else {
        return 44.0;
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        NSDictionary *example = self.examples[indexPath.row];
        Class viewControllerClass = example[@"class"];

        UIViewController *viewController = nil;
        NSNumber *gatewaySpecificFlag = example[@"gatewaySpecific3DS"];
        if (gatewaySpecificFlag && [viewControllerClass isSubclassOfClass:[ThreeDSPaymentFlowViewController class]]) {
            viewController = [(ThreeDSPaymentFlowViewController *)[viewControllerClass alloc]
                initWithGatewaySpecificFlow:gatewaySpecificFlag.boolValue];
        } else {
            viewController = [[viewControllerClass alloc] init];
        }
        [self.navigationController pushViewController:viewController animated:YES];
    }
}

@end
