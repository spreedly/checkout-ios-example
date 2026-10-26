//
//  AdditionalFieldCataloguePanel.m
//  SpreedlySDKExampleObjectiveC
//

#import "AdditionalFieldCataloguePanel.h"
#import "ThemeHelper.h"

@interface AdditionalFieldCataloguePanel ()
@property (nonatomic, copy, readwrite) NSString *accessibilityPrefix;
@property (nonatomic, strong, readwrite) NSMutableArray<NSMutableDictionary *> *catalogueRows;
@property (nonatomic, strong) UISwitch *groupBillingSwitch;
@property (nonatomic, strong) UISwitch *groupShippingSwitch;
@property (nonatomic, strong) UISwitch *groupEmailSwitch;
@property (nonatomic, strong) UIButton *configShowHideButton;
@property (nonatomic, strong) UILabel *configCollapsedHintLabel;
@property (nonatomic, strong) UIStackView *detailStack;
@property (nonatomic, assign) BOOL showConfig;
@property (nonatomic, strong) NSLayoutConstraint *collapsedBottom;
@property (nonatomic, strong) NSLayoutConstraint *expandedBottom;
@end

@implementation AdditionalFieldCataloguePanel

+ (NSArray<NSString *> *)billingGroupIds {
    return @[@"city", @"country", @"state", @"zipCode"];
}

+ (NSArray<NSString *> *)shippingGroupIds {
    return @[@"shippingCity", @"shippingCountry", @"shippingState", @"shippingZip"];
}

+ (NSArray<NSString *> *)emailGroupIds {
    return @[@"email"];
}

- (instancetype)initWithAccessibilityPrefix:(NSString *)accessibilityPrefix
                         leadingDetailViews:(NSArray<UIView *> *)leadingDetailViews {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _accessibilityPrefix = [accessibilityPrefix copy] ?: @"additionalFields";
        _showConfig = NO;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        [self buildDefaultCatalogueRows];
        [self buildLayoutWithLeadingDetailViews:leadingDetailViews];
    }
    return self;
}

- (NSMutableDictionary *)rowWithId:(NSString *)fieldId
                             title:(NSString *)title
                              type:(FormFieldType)type
                           enabled:(BOOL)enabled
                          required:(BOOL)required {
    return [@{
        @"id": fieldId,
        @"title": title,
        @"type": @(type),
        @"enabled": @(enabled),
        @"required": @(required),
        @"customRule": @(DemoCustomValidationKindNone)
    } mutableCopy];
}

- (void)buildDefaultCatalogueRows {
    self.catalogueRows = [@[
        [self rowWithId:@"addressLine1" title:@"Address Line 1" type:FormFieldTypeAddressLine1 enabled:NO required:YES],
        [self rowWithId:@"addressLine2" title:@"Address Line 2" type:FormFieldTypeAddressLine2 enabled:NO required:NO],
        [self rowWithId:@"city" title:@"City" type:FormFieldTypeCity enabled:NO required:YES],
        [self rowWithId:@"state" title:@"State" type:FormFieldTypeState enabled:NO required:YES],
        [self rowWithId:@"zipCode" title:@"ZIP Code" type:FormFieldTypeZipCode enabled:NO required:YES],
        [self rowWithId:@"country" title:@"Country" type:FormFieldTypeCountry enabled:NO required:NO],
        [self rowWithId:@"email" title:@"Email" type:FormFieldTypeEmail enabled:NO required:NO],
        [self rowWithId:@"company" title:@"Company" type:FormFieldTypeCompany enabled:NO required:NO],
        [self rowWithId:@"phoneNumber" title:@"Phone Number" type:FormFieldTypePhoneNumber enabled:NO required:NO],
        [self rowWithId:@"houseNumberOrName" title:@"House Number or Name" type:FormFieldTypeHouseNumberOrName enabled:NO required:NO],
        [self rowWithId:@"street" title:@"Street" type:FormFieldTypeStreet enabled:NO required:NO],
        [self rowWithId:@"streetLine2" title:@"Street Line 2" type:FormFieldTypeStreetLine2 enabled:NO required:NO],
        [self rowWithId:@"phoneNumberCountryCode" title:@"Phone Country Code" type:FormFieldTypePhoneNumberCountryCode enabled:NO required:NO],
        [self rowWithId:@"phoneNumberAreaCode" title:@"Phone Area Code" type:FormFieldTypePhoneNumberAreaCode enabled:NO required:NO],
        [self rowWithId:@"shippingAddress1" title:@"Shipping Address 1" type:FormFieldTypeShippingAddress1 enabled:NO required:NO],
        [self rowWithId:@"shippingAddress2" title:@"Shipping Address 2" type:FormFieldTypeShippingAddress2 enabled:NO required:NO],
        [self rowWithId:@"shippingCity" title:@"Shipping City" type:FormFieldTypeShippingCity enabled:NO required:NO],
        [self rowWithId:@"shippingState" title:@"Shipping State" type:FormFieldTypeShippingState enabled:NO required:NO],
        [self rowWithId:@"shippingZip" title:@"Shipping ZIP" type:FormFieldTypeShippingZip enabled:NO required:NO],
        [self rowWithId:@"shippingCountry" title:@"Shipping Country" type:FormFieldTypeShippingCountry enabled:NO required:NO],
        [self rowWithId:@"shippingPhoneNumber" title:@"Shipping Phone" type:FormFieldTypeShippingPhoneNumber enabled:NO required:NO],
        [self rowWithId:@"shippingHouseNumberOrName" title:@"Shipping House Number" type:FormFieldTypeShippingHouseNumberOrName enabled:NO required:NO],
        [self rowWithId:@"shippingStreet" title:@"Shipping Street" type:FormFieldTypeShippingStreet enabled:NO required:NO],
        [self rowWithId:@"shippingStreetLine2" title:@"Shipping Street Line 2" type:FormFieldTypeShippingStreetLine2 enabled:NO required:NO],
        [self rowWithId:@"shippingPhoneNumberCountryCode" title:@"Shipping Phone Country Code" type:FormFieldTypeShippingPhoneNumberCountryCode enabled:NO required:NO],
        [self rowWithId:@"shippingPhoneNumberAreaCode" title:@"Shipping Phone Area Code" type:FormFieldTypeShippingPhoneNumberAreaCode enabled:NO required:NO]
    ] mutableCopy];
}

- (UIView *)cardContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper cardBackgroundColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    UIColor *borderColor = [ThemeHelper cardBorderColor];
    container.layer.borderColor = borderColor.CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];
    return container;
}

- (void)buildLayoutWithLeadingDetailViews:(NSArray<UIView *> *)leadingDetailViews {
    UIStackView *root = [[UIStackView alloc] init];
    root.axis = UILayoutConstraintAxisVertical;
    root.spacing = [ThemeHelper spacingSM];
    root.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:root];

    [root addArrangedSubview:[self buildGroupsCard]];
    [root addArrangedSubview:[self buildConfigCardWithLeadingDetailViews:leadingDetailViews]];

    [NSLayoutConstraint activateConstraints:@[
        [root.topAnchor constraintEqualToAnchor:self.topAnchor],
        [root.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [root.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [root.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
}

- (UIView *)groupRowWithTitle:(NSString *)title subtitle:(NSString *)subtitle switch:(UISwitch *)toggle {
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = subtitle;
    subtitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    subtitleLabel.textColor = [UIColor secondaryLabelColor];

    UIStackView *labels = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];
    labels.axis = UILayoutConstraintAxisVertical;
    labels.spacing = 2;

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[labels, toggle]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 8;
    return row;
}

- (UIView *)buildGroupsCard {
    UIView *container = [self cardContainer];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:stack];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"Optional address groups";
    title.font = [ThemeHelper screenHeadlineFont];
    title.textColor = [ThemeHelper textColor];
    title.accessibilityTraits = UIAccessibilityTraitHeader;
    [stack addArrangedSubview:title];

    UILabel *hint = [[UILabel alloc] init];
    hint.text = @"Turn on a group to enable its fields. Groups also turn on when you Enable every field in that group below.";
    hint.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    hint.textColor = [UIColor secondaryLabelColor];
    hint.numberOfLines = 0;
    [stack addArrangedSubview:hint];

    self.groupBillingSwitch = [[UISwitch alloc] init];
    self.groupBillingSwitch.onTintColor = [ThemeHelper primaryColor];
    self.groupBillingSwitch.accessibilityIdentifier = [NSString stringWithFormat:@"%@_group_billing", self.accessibilityPrefix];
    [self.groupBillingSwitch addTarget:self action:@selector(groupBillingToggled:) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:[self groupRowWithTitle:@"Billing address"
                                             subtitle:@"City, country, state, zip"
                                               switch:self.groupBillingSwitch]];

    self.groupShippingSwitch = [[UISwitch alloc] init];
    self.groupShippingSwitch.onTintColor = [ThemeHelper primaryColor];
    self.groupShippingSwitch.accessibilityIdentifier = [NSString stringWithFormat:@"%@_group_shipping", self.accessibilityPrefix];
    [self.groupShippingSwitch addTarget:self action:@selector(groupShippingToggled:) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:[self groupRowWithTitle:@"Shipping address"
                                             subtitle:@"Shipping city, country, state, zip"
                                               switch:self.groupShippingSwitch]];

    self.groupEmailSwitch = [[UISwitch alloc] init];
    self.groupEmailSwitch.onTintColor = [ThemeHelper primaryColor];
    self.groupEmailSwitch.accessibilityIdentifier = [NSString stringWithFormat:@"%@_group_email", self.accessibilityPrefix];
    [self.groupEmailSwitch addTarget:self action:@selector(groupEmailToggled:) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:[self groupRowWithTitle:@"Email"
                                             subtitle:@"Contact email field"
                                               switch:self.groupEmailSwitch]];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [stack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    return container;
}

- (void)syncRuleButton:(UIButton *)button kind:(DemoCustomValidationKind)kind {
    [button setTitle:[NSString stringWithFormat:@"%@ ▾", [DemoCustomValidationRecipes pickerLabelForKind:kind]]
            forState:UIControlStateNormal];
}

- (UIView *)buildConfigCardWithLeadingDetailViews:(NSArray<UIView *> *)leadingDetailViews {
    UIView *container = [self cardContainer];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Additional Fields Configuration";
    titleLabel.font = [ThemeHelper screenHeadlineFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = [NSString stringWithFormat:@"%@AdditionalFieldsTitle", self.accessibilityPrefix];
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;

    self.configShowHideButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.configShowHideButton setTitle:@"Show" forState:UIControlStateNormal];
    self.configShowHideButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.configShowHideButton.accessibilityIdentifier = [NSString stringWithFormat:@"%@_configShowHide", self.accessibilityPrefix];
    [self.configShowHideButton addTarget:self action:@selector(configShowHideTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *headerRow = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, self.configShowHideButton]];
    headerRow.axis = UILayoutConstraintAxisHorizontal;
    headerRow.alignment = UIStackViewAlignmentCenter;
    headerRow.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:headerRow];

    self.configCollapsedHintLabel = [[UILabel alloc] init];
    self.configCollapsedHintLabel.text = @"Hidden to shorten this screen. Tap Show for Enable billing defaults, Disable all, and per-field Enable / Required / Custom rule.";
    self.configCollapsedHintLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.configCollapsedHintLabel.textColor = [UIColor secondaryLabelColor];
    self.configCollapsedHintLabel.numberOfLines = 0;
    self.configCollapsedHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.configCollapsedHintLabel];

    self.detailStack = [[UIStackView alloc] init];
    self.detailStack.axis = UILayoutConstraintAxisVertical;
    self.detailStack.spacing = 10;
    self.detailStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailStack.hidden = YES;
    [container addSubview:self.detailStack];

    for (UIView *extra in leadingDetailViews ?: @[]) {
        [self.detailStack addArrangedSubview:extra];
    }

    UIButton *enableBillingDefaults = [UIButton buttonWithType:UIButtonTypeSystem];
    [enableBillingDefaults setTitle:@"Enable billing defaults" forState:UIControlStateNormal];
    enableBillingDefaults.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    enableBillingDefaults.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    enableBillingDefaults.accessibilityIdentifier = [NSString stringWithFormat:@"%@_enableBillingDefaults", self.accessibilityPrefix];
    [enableBillingDefaults addTarget:self action:@selector(enableBillingDefaultsTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton *disableAll = [UIButton buttonWithType:UIButtonTypeSystem];
    [disableAll setTitle:@"Disable all" forState:UIControlStateNormal];
    disableAll.contentHorizontalAlignment = UIControlContentHorizontalAlignmentTrailing;
    disableAll.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    disableAll.accessibilityIdentifier = [NSString stringWithFormat:@"%@_disableAll", self.accessibilityPrefix];
    [disableAll addTarget:self action:@selector(disableAllCatalogueTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *quickActions = [[UIStackView alloc] initWithArrangedSubviews:@[enableBillingDefaults, disableAll]];
    quickActions.axis = UILayoutConstraintAxisHorizontal;
    quickActions.distribution = UIStackViewDistributionEqualSpacing;
    [self.detailStack addArrangedSubview:quickActions];

    UILabel *individualTitle = [[UILabel alloc] init];
    individualTitle.text = @"Individual fields";
    individualTitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [self.detailStack addArrangedSubview:individualTitle];

    for (NSMutableDictionary *row in self.catalogueRows) {
        UILabel *name = [[UILabel alloc] init];
        name.text = row[@"title"];
        name.font = [ThemeHelper screenBodyFont];
        name.textColor = [ThemeHelper textColor];

        UISwitch *enableSwitch = [[UISwitch alloc] init];
        enableSwitch.onTintColor = [ThemeHelper primaryColor];
        enableSwitch.on = [row[@"enabled"] boolValue];
        enableSwitch.accessibilityIdentifier = [NSString stringWithFormat:@"%@_%@_enable", self.accessibilityPrefix, row[@"id"]];
        [enableSwitch addTarget:self action:@selector(catalogueEnableToggled:) forControlEvents:UIControlEventValueChanged];
        row[@"enableSwitch"] = enableSwitch;

        UILabel *enableLabel = [[UILabel alloc] init];
        enableLabel.text = @"Enable";
        enableLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];

        UISwitch *requiredSwitch = [[UISwitch alloc] init];
        requiredSwitch.onTintColor = [ThemeHelper primaryColor];
        requiredSwitch.on = [row[@"required"] boolValue];
        requiredSwitch.enabled = enableSwitch.on;
        requiredSwitch.accessibilityIdentifier = [NSString stringWithFormat:@"%@_%@_required", self.accessibilityPrefix, row[@"id"]];
        [requiredSwitch addTarget:self action:@selector(catalogueRequiredToggled:) forControlEvents:UIControlEventValueChanged];
        row[@"requiredSwitch"] = requiredSwitch;

        UILabel *requiredLabel = [[UILabel alloc] init];
        requiredLabel.text = @"Required";
        requiredLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];

        UIButton *ruleButton = [UIButton buttonWithType:UIButtonTypeSystem];
        ruleButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentTrailing;
        ruleButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        ruleButton.accessibilityIdentifier = [NSString stringWithFormat:@"%@_%@_customRule", self.accessibilityPrefix, row[@"id"]];
        [ruleButton addTarget:self action:@selector(catalogueRuleTapped:) forControlEvents:UIControlEventTouchUpInside];
        row[@"ruleButton"] = ruleButton;
        [self syncRuleButton:ruleButton kind:DemoCustomValidationKindNone];
        ruleButton.enabled = enableSwitch.on;
        ruleButton.alpha = enableSwitch.on ? 1.0 : 0.45;

        UILabel *ruleLabel = [[UILabel alloc] init];
        ruleLabel.text = @"Custom rule";
        ruleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        ruleLabel.textColor = [UIColor secondaryLabelColor];

        UIStackView *ruleRow = [[UIStackView alloc] initWithArrangedSubviews:@[ruleLabel, ruleButton]];
        ruleRow.axis = UILayoutConstraintAxisHorizontal;
        ruleRow.spacing = 8;
        ruleRow.alignment = UIStackViewAlignmentCenter;

        UIStackView *toggles = [[UIStackView alloc] initWithArrangedSubviews:@[enableLabel, enableSwitch, requiredLabel, requiredSwitch]];
        toggles.axis = UILayoutConstraintAxisHorizontal;
        toggles.spacing = 8;
        toggles.alignment = UIStackViewAlignmentCenter;

        UIStackView *rowStack = [[UIStackView alloc] initWithArrangedSubviews:@[name, toggles, ruleRow]];
        rowStack.axis = UILayoutConstraintAxisVertical;
        rowStack.spacing = 4;
        [self.detailStack addArrangedSubview:rowStack];
    }

    [NSLayoutConstraint activateConstraints:@[
        [headerRow.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [headerRow.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [headerRow.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [self.configCollapsedHintLabel.topAnchor constraintEqualToAnchor:headerRow.bottomAnchor constant:4],
        [self.configCollapsedHintLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.configCollapsedHintLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [self.detailStack.topAnchor constraintEqualToAnchor:headerRow.bottomAnchor constant:[ThemeHelper spacingSM]],
        [self.detailStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.detailStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]]
    ]];

    self.collapsedBottom = [self.configCollapsedHintLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]];
    self.expandedBottom = [self.detailStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]];
    self.collapsedBottom.active = YES;
    self.expandedBottom.active = NO;

    return container;
}

#pragma mark - Actions

- (void)notifyChanged {
    if (self.onCatalogueChanged) {
        self.onCatalogueChanged();
    }
}

- (void)configShowHideTapped {
    self.showConfig = !self.showConfig;
    self.detailStack.hidden = !self.showConfig;
    self.configCollapsedHintLabel.hidden = self.showConfig;
    [self.configShowHideButton setTitle:(self.showConfig ? @"Hide" : @"Show") forState:UIControlStateNormal];
    self.collapsedBottom.active = !self.showConfig;
    self.expandedBottom.active = self.showConfig;
    [UIView animateWithDuration:0.2 animations:^{
        [self.superview layoutIfNeeded];
    }];
}

- (BOOL)catalogueIdsAllEnabled:(NSArray<NSString *> *)ids {
    NSSet *idSet = [NSSet setWithArray:ids];
    for (NSMutableDictionary *row in self.catalogueRows) {
        if (![idSet containsObject:row[@"id"]]) { continue; }
        if (![row[@"enabled"] boolValue]) { return NO; }
    }
    return YES;
}

- (void)syncGroupTogglesFromCatalogue {
    self.groupBillingSwitch.on = [self catalogueIdsAllEnabled:[AdditionalFieldCataloguePanel billingGroupIds]];
    self.groupShippingSwitch.on = [self catalogueIdsAllEnabled:[AdditionalFieldCataloguePanel shippingGroupIds]];
    self.groupEmailSwitch.on = [self catalogueIdsAllEnabled:[AdditionalFieldCataloguePanel emailGroupIds]];
}

- (void)setCatalogueEnabledForIds:(NSArray<NSString *> *)ids enabled:(BOOL)enabled {
    NSSet *idSet = [NSSet setWithArray:ids];
    for (NSMutableDictionary *row in self.catalogueRows) {
        if (![idSet containsObject:row[@"id"]]) { continue; }
        row[@"enabled"] = @(enabled);
        UISwitch *enableSwitch = row[@"enableSwitch"];
        enableSwitch.on = enabled;
        UISwitch *requiredSwitch = row[@"requiredSwitch"];
        requiredSwitch.enabled = enabled;
        UIButton *ruleButton = row[@"ruleButton"];
        ruleButton.enabled = enabled;
        ruleButton.alpha = enabled ? 1.0 : 0.45;
    }
    [self syncGroupTogglesFromCatalogue];
    [self notifyChanged];
}

- (void)groupBillingToggled:(UISwitch *)sender {
    [self setCatalogueEnabledForIds:[AdditionalFieldCataloguePanel billingGroupIds] enabled:sender.isOn];
}

- (void)groupShippingToggled:(UISwitch *)sender {
    [self setCatalogueEnabledForIds:[AdditionalFieldCataloguePanel shippingGroupIds] enabled:sender.isOn];
}

- (void)groupEmailToggled:(UISwitch *)sender {
    [self setCatalogueEnabledForIds:[AdditionalFieldCataloguePanel emailGroupIds] enabled:sender.isOn];
}

- (void)enableBillingDefaultsTapped {
    NSSet *enabledIds = [NSSet setWithArray:@[
        @"addressLine1", @"addressLine2", @"city", @"state", @"zipCode", @"country"
    ]];
    NSSet *requiredIds = [NSSet setWithArray:@[@"addressLine1", @"city", @"state", @"zipCode"]];
    for (NSMutableDictionary *row in self.catalogueRows) {
        NSString *fieldId = row[@"id"];
        BOOL enabled = [enabledIds containsObject:fieldId];
        BOOL required = [requiredIds containsObject:fieldId];
        row[@"enabled"] = @(enabled);
        row[@"required"] = @(required);
        row[@"customRule"] = @(DemoCustomValidationKindNone);
        UISwitch *enableSwitch = row[@"enableSwitch"];
        enableSwitch.on = enabled;
        UISwitch *requiredSwitch = row[@"requiredSwitch"];
        requiredSwitch.on = required;
        requiredSwitch.enabled = enabled;
        UIButton *ruleButton = row[@"ruleButton"];
        [self syncRuleButton:ruleButton kind:DemoCustomValidationKindNone];
        ruleButton.enabled = enabled;
        ruleButton.alpha = enabled ? 1.0 : 0.45;
    }
    [self syncGroupTogglesFromCatalogue];
    [self notifyChanged];
}

- (void)disableAllCatalogueTapped {
    for (NSMutableDictionary *row in self.catalogueRows) {
        row[@"enabled"] = @NO;
        UISwitch *enableSwitch = row[@"enableSwitch"];
        enableSwitch.on = NO;
        UISwitch *requiredSwitch = row[@"requiredSwitch"];
        requiredSwitch.enabled = NO;
        UIButton *ruleButton = row[@"ruleButton"];
        ruleButton.enabled = NO;
        ruleButton.alpha = 0.45;
    }
    [self syncGroupTogglesFromCatalogue];
    [self notifyChanged];
}

- (void)catalogueEnableToggled:(UISwitch *)sender {
    for (NSMutableDictionary *row in self.catalogueRows) {
        if (row[@"enableSwitch"] == sender) {
            row[@"enabled"] = @(sender.isOn);
            UISwitch *requiredSwitch = row[@"requiredSwitch"];
            requiredSwitch.enabled = sender.isOn;
            UIButton *ruleButton = row[@"ruleButton"];
            ruleButton.enabled = sender.isOn;
            ruleButton.alpha = sender.isOn ? 1.0 : 0.45;
            break;
        }
    }
    [self syncGroupTogglesFromCatalogue];
    [self notifyChanged];
}

- (void)catalogueRequiredToggled:(UISwitch *)sender {
    for (NSMutableDictionary *row in self.catalogueRows) {
        if (row[@"requiredSwitch"] == sender) {
            row[@"required"] = @(sender.isOn);
            break;
        }
    }
    [self notifyChanged];
}

- (void)catalogueRuleTapped:(UIButton *)sender {
    UIViewController *host = self.hostViewController;
    if (!host) { return; }

    for (NSMutableDictionary *row in self.catalogueRows) {
        if (row[@"ruleButton"] != sender) { continue; }
        DemoCustomValidationKind current = (DemoCustomValidationKind)[row[@"customRule"] integerValue];
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Custom rule"
                                                                       message:row[@"title"]
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        FormFieldType type = (FormFieldType)[row[@"type"] integerValue];
        NSArray *kinds = [DemoCustomValidationRecipes pickerKindsForFormFieldType:type];
        for (NSNumber *boxed in kinds) {
            DemoCustomValidationKind kind = (DemoCustomValidationKind)boxed.integerValue;
            NSString *title = [DemoCustomValidationRecipes pickerLabelForKind:kind];
            if (kind == current) {
                title = [title stringByAppendingString:@" ✓"];
            }
            [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                row[@"customRule"] = @(kind);
                [self syncRuleButton:sender kind:kind];
                [self notifyChanged];
            }]];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        if (sheet.popoverPresentationController) {
            sheet.popoverPresentationController.sourceView = sender;
            sheet.popoverPresentationController.sourceRect = sender.bounds;
        }
        [host presentViewController:sheet animated:YES completion:nil];
        break;
    }
}

- (NSDictionary<NSString *, NSNumber *> *)catalogueCustomValidationSelections {
    NSMutableDictionary<NSString *, NSNumber *> *map = [NSMutableDictionary dictionary];
    for (NSMutableDictionary *row in self.catalogueRows) {
        FormFieldType type = (FormFieldType)[row[@"type"] integerValue];
        NSString *wire = [DemoCustomValidationRecipes wireKeyForFormFieldType:type];
        if (wire.length == 0) { continue; }
        BOOL enabled = [row[@"enabled"] boolValue];
        DemoCustomValidationKind kind = enabled
            ? (DemoCustomValidationKind)[row[@"customRule"] integerValue]
            : DemoCustomValidationKindNone;
        // Drop "Only when country = US" if it was left on a non-state/ZIP row.
        if (kind == DemoCustomValidationKindOnlyWhenCountryUS) {
            NSArray<NSNumber *> *allowed = [DemoCustomValidationRecipes pickerKindsForFormFieldType:type];
            if (![allowed containsObject:@(DemoCustomValidationKindOnlyWhenCountryUS)]) {
                kind = DemoCustomValidationKindNone;
                row[@"customRule"] = @(DemoCustomValidationKindNone);
            }
        }
        map[wire] = @(kind);
    }
    return map;
}

- (NSArray<FormField *> *)enabledFormFields {
    NSMutableArray<FormField *> *fields = [NSMutableArray array];
    for (NSDictionary *row in self.catalogueRows) {
        if (![row[@"enabled"] boolValue]) { continue; }
        FormFieldType type = (FormFieldType)[row[@"type"] integerValue];
        FormField *field = [[FormField alloc] initWithId:row[@"id"]
                                                   title:row[@"title"]
                                                    type:type
                                             placeholder:nil
                                              isRequired:[row[@"required"] boolValue]];
        [fields addObject:field];
    }
    return fields;
}

@end
