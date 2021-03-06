//
//  RequestMoneyTableViewController.m
//  SimpleMoney
//
//  Created by Joshua Conner on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SendAndRequestMoneyTableViewController.h"
#import <Foundation/Foundation.h>

#define DEFAULT_IMAGE @"profile.png"
#define kTABLEVIEWHEIGHT 140.0
#define kTABLEVIEWOFFSET 60.0

#define kREQUESTRESOURCEPATH @"/invoices"
#define kREQUESTBUTTONTITLE @"Request"
#define kREQUESTVIEWTITLE @"Request Money"
#define kREQUESTSUCCESSTEXT @"Request Sent"

#define kSENDRESOURCEPATH @"/transactions"
#define kSENDBUTTONTITLE @"Send";
#define kSENDVIEWTITLE @"Send Money"
#define kSENDSUCCESSTEXT @"Payment Sent"

#define kPINCONSTANT @"1111"

@interface SendAndRequestMoneyTableViewController () {
    BOOL emailFieldIsSet;
    BOOL contactsAreShowing;
    BOOL sendButtonIsActive;
    NSNumberFormatter *numberFormatter;
}

@property (weak, nonatomic) IBOutlet UIImageView *emailCellImage;
@property (weak, nonatomic) IBOutlet UILabel *emailCellNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *emailCellEmailLabel;
@property (weak, nonatomic) IBOutlet UIButton *emailCellClearButton;
@property (weak, nonatomic) IBOutlet UITableView *contactsTableView;
@property (strong, nonatomic) NSMutableArray *filteredContacts;
@property (weak, nonatomic) IBOutlet UITableView *staticTableView;
@property (strong, nonatomic) NSNumber *amount;
@property (strong, nonatomic) NSIndexPath *lastSelectedIndexPath;
@property (nonatomic) BOOL pinEntrySuccess;


- (void)sendRequest;
- (void)hideTableView;
- (void)showTableView;
- (void)replaceEmailFieldWithName:(NSString *)name andEmail:(NSString *)email andImage:(UIImage *)image;
@end

@implementation SendAndRequestMoneyTableViewController
@synthesize emailTextFieldCell;
@synthesize emailTextField;
@synthesize emailCellImage;
@synthesize emailCellNameLabel;
@synthesize emailCellEmailLabel;
@synthesize emailCellClearButton;
@synthesize amountTextField;
@synthesize descriptionTextField;
@synthesize contactsTableView = _contactsTableView;
@synthesize contacts = _contacts;
@synthesize sendButton;
@synthesize filteredContacts = _filteredContacts;
@synthesize amount = _amount;
@synthesize staticTableView;
@synthesize lastSelectedIndexPath = _lastSelectedIndexPath;
@synthesize isRequestMoney = _isRequestMoney;
@synthesize pinEntrySuccess = _pinEntrySuccess;

#pragma mark - Getters and Setters
- (NSMutableArray *)filteredContacts {
    if (!_filteredContacts) _filteredContacts = self.contacts;
    
    return _filteredContacts;
}


#pragma mark - View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.contactsTableView.hidden = YES;
    self.contactsTableView.frame = CGRectMake(0, 600, self.staticTableView.frame.size.width, 0);
    [self.amountTextField setKeyboardType:UIKeyboardTypeDecimalPad];
    numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [numberFormatter setMinimumFractionDigits:0];
    [numberFormatter setMaximumFractionDigits:2];
    
    NSString *sendViewTitle = kSENDVIEWTITLE;
    if (self.isRequestMoney) {
        sendViewTitle = kREQUESTVIEWTITLE;
    }
    self.navigationItem.title = sendViewTitle;
}

- (void)viewDidUnload
{
    [self setEmailCellImage:nil];
    [self setEmailCellNameLabel:nil];
    [self setEmailCellEmailLabel:nil];
    [self setEmailCellClearButton:nil];
    [self setStaticTableView:nil];
    [self setEmailTextFieldCell:nil];
    [self setSendButton:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewDidAppear:(BOOL)animated {
    //if the user successfully entered a PIN, don't re-show keyboard
    //this is set in the GCStoryboardPinViewDelegate method
    if (!self.pinEntrySuccess)
        [self.emailTextField becomeFirstResponder];
    self.lastSelectedIndexPath = [NSIndexPath indexPathWithIndex:NSIntegerMax];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"enterPinSegue"]) {
        GCStoryboardPINViewController *controller = (GCStoryboardPINViewController *)segue.destinationViewController;
        [controller configureWithMode:GCPINViewControllerModeVerify delegate:self];
        
        //this is who you're sending to or receiving from
        NSString *target = self.emailCellEmailLabel.text;
        if (!target) {
            target = self.emailTextField.text;
        }
        controller.businessNameText = target;
        
        if (self.isRequestMoney) {
            controller.messageText = @"Enter your PIN to request money from:";
        } else {
            controller.messageText = @"Enter your PIN to send money to:";
        }
        
        //TODO: unset this hint from the demo!
        controller.errorText = [NSString stringWithFormat:@"Invalid PIN. (Hint: %@)", kPINCONSTANT];

    }
}



#pragma mark - Validating and sending the request
- (BOOL)stringIsValidEmail:(NSString*)email {
    // Validate email with a regular expression
    NSString *emailRegEx =
    @"(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
    @"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
    @"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
    @"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
    @"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
    @"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
    @"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])";
    NSPredicate *regExPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegEx];

    return [regExPredicate evaluateWithObject:email] && ![email isEqualToString:[KeychainWrapper load:@"userEmail"]];
}

- (void)sendRequest {
    BOOL isValidEmail;
    NSString *senderEmail;
    
    /*
     * self.emailCellLabel will display the email address if the user chooses a contact from their contact list,
     * but it's also possible that they could enter an email address without selecting a contact, so we use
     * self.emailTextField as a fallback to also try.
     *
     * TODO: refactor this to make it more elegant...
     */
    if (emailFieldIsSet) {
        senderEmail = self.emailCellEmailLabel.text;
    } else {
        senderEmail = self.emailTextField.text;
    }
    isValidEmail = [self stringIsValidEmail:senderEmail];

    
    // Make sure the user doesn't request money from themselves, they have a valid email address, and the amount they're trying to send is greater than 0
    if (!isValidEmail || (!self.amount || self.amount <= 0)) {
        loadingIndicator.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"error"]];
        loadingIndicator.mode = MBProgressHUDModeCustomView;

        if ([senderEmail isEqualToString:[KeychainWrapper load:@"userEmail"]]) {
            loadingIndicator.labelText = @"Not allowed.";
            loadingIndicator.detailsLabelText = @"You can't request money from or send money to yourself.";
        } else if (!isValidEmail) {
            loadingIndicator.labelText = @"Invalid email address.";
        } else {
            loadingIndicator.labelText = @"Invalid amount.";
        }
        // Display the error message and hide it after 1 second
        [loadingIndicator hide:YES afterDelay:2.0];
    } else {
        // POST a new Transaction on the server
        RKObjectManager *objectManager = [RKObjectManager sharedManager];
        NSString *resourcePath = kSENDRESOURCEPATH;
        if (self.isRequestMoney)
            resourcePath = kREQUESTRESOURCEPATH;
        
        [objectManager loadObjectsAtResourcePath:resourcePath delegate:self block:^(RKObjectLoader* loader) {
            RKParams *params = [RKParams params];
            
            //need to set these fields as appropriate depending on the transaction type
            if (self.isRequestMoney) {
                [params setValue:senderEmail forParam:@"transaction[sender_email]"];
                [params setValue:@"false" forParam:@"transaction[complete]"];
            } else {
                [params setValue:senderEmail forParam:@"transaction[recipient_email]"];
                [params setValue:@"true" forParam:@"transaction[complete]"];
            }
            
            [params setValue:amountTextField.text forParam:@"transaction[amount]"];
            [params setValue:descriptionTextField.text forParam:@"transaction[description]"];

            loader.params = params;
            loader.objectMapping = [objectManager.mappingProvider objectMappingForClass:[Transaction class]];
            NSLog(@"%@", loader.params);
            loader.method = RKRequestMethodPOST;
        }];
    }
}

- (void)showPinEntry {
    [self performSegueWithIdentifier:@"enterPinSegue" sender:self];
}

#pragma mark - UI callbacks
- (IBAction)requestMoneyButtonWasPressed {
    [self dismissKeyboard];
    [self showPinEntry];
}

- (IBAction)clearEmailCellButtonPressed {
    self.emailTextField.text = @"";
    emailFieldIsSet = NO;
    self.filteredContacts = self.contacts;
    [self checkForValidEmailAndAmountWithTextFieldWithTextField:self.emailTextField string:@""];
    [self.staticTableView reloadData];
    [self.contactsTableView reloadData];
    
    [UIView animateWithDuration:0.10 delay:0.0 options:UIViewAnimationCurveEaseIn animations:^(void){
        self.emailCellEmailLabel.alpha = 0;
        self.emailCellImage.alpha = 0;
        self.emailCellNameLabel.alpha = 0;
        self.emailCellClearButton.alpha = 0;
        self.emailTextField.alpha = 1;
    } completion:^(BOOL finished){
        [self.emailTextField becomeFirstResponder];
        self.emailCellEmailLabel.text = @"";
        [self.emailTextField becomeFirstResponder];
    }];
    
}

- (IBAction)dismissKeyboard {
    [self.view endEditing:YES];
}


# pragma mark - RKObjectLoader Delegate methods

- (void)objectLoader:(RKObjectLoader *)objectLoader didFailWithError:(NSError *)error {
	NSLog(@"RKObjectLoader failed with error: %@", error);
    loadingIndicator.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"error"]];
    loadingIndicator.mode = MBProgressHUDModeCustomView;
    loadingIndicator.labelText = @"Network error";
    [loadingIndicator hide:YES afterDelay:1];
}

- (void)objectLoader:(RKObjectLoader *)objectLoader didLoadObject:(id)object {
    Transaction *t = object;
    NSLog(@"Transaction loaded with amount: %@",t.amount);
    NSNumber *balance = [KeychainWrapper load:@"userBalance"];
    balance = [NSNumber numberWithInt:([balance intValue] - [t.amount intValue])];
    [KeychainWrapper save:@"userBalance" data:balance];

    loadingIndicator.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"checkmark"]];
    loadingIndicator.mode = MBProgressHUDModeCustomView;

    NSString *labelText = kSENDSUCCESSTEXT;
    NSString *recipient = self.emailCellNameLabel.text;
    if (!recipient)
        recipient = self.emailTextField.text;
    
    NSString *detailsText = [NSString stringWithFormat:@"Sent %@ to %@", self.amountTextField.text, recipient];
    if (self.isRequestMoney) {
        labelText = kREQUESTSUCCESSTEXT;
        detailsText = [NSString stringWithFormat:@"Requested %@ from %@", self.amountTextField.text, recipient];
    }
    
    loadingIndicator.labelText = labelText;
    loadingIndicator.detailsLabelText = detailsText;
    [loadingIndicator hide:YES afterDelay:3];
    [self performSelector:@selector(goBack) withObject:nil afterDelay:1];
}

- (void)setSendButtonActive:(BOOL)active {
    if (active) {
        [self.sendButton setTintColor:[UIColor blueColor]];
        [self.sendButton setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIColor whiteColor], UITextAttributeTextColor, [UIColor blackColor], UITextAttributeTextShadowColor, nil] forState:UIControlStateNormal];
        sendButtonIsActive = YES;
        
    } else {
        [self.sendButton setTintColor:[UIColor colorWithWhite:0.9 alpha:1.0]];
        [self.sendButton setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIColor colorWithHue:0 saturation:0 brightness:0.6 alpha:1], UITextAttributeTextColor, [UIColor whiteColor],UITextAttributeTextShadowColor, nil] forState:UIControlStateNormal];
        sendButtonIsActive = NO;
    }
}

- (void)goBack {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)request:(RKRequest *)request didReceiveData:(NSInteger)bytesReceived totalBytesReceived:(NSInteger)totalBytesReceived totalBytesExpectedToReceive:(NSInteger)totalBytesExpectedToReceive {
    NSLog(@"RKRequest did receive data");
}


#pragma mark - Show/hide helper methods
- (void) showEmailCellWithImage:(UIImage *)image 
                           name:(NSString *)name 
                          email:(NSString *)email {
    emailFieldIsSet = YES;
    
    
    if (image) {
        self.emailCellImage.image = image;
    } else {
        self.emailCellImage.image = [UIImage imageNamed:DEFAULT_IMAGE];
    }
    
    self.emailCellNameLabel.text = name;
    self.emailCellEmailLabel.text = email;
    [UIView animateWithDuration:0.20 delay:0.0 options:UIViewAnimationCurveEaseOut animations:^(void){
        self.emailCellImage.alpha = 1;
        self.emailCellEmailLabel.alpha = 1;
        self.emailCellNameLabel.alpha = 1;
        self.emailCellClearButton.alpha = 0.5;
        self.emailTextField.alpha = 0;
    } completion:^(BOOL finished){
    }];
    
    
    [self.staticTableView reloadData];
}

- (void)hideTableView {
    contactsAreShowing = NO;
    [self.staticTableView reloadData];
    
    [UIView animateWithDuration:0.10 delay:0.0 options:UIViewAnimationCurveEaseIn animations:^(void){
        float xPosition = self.contactsTableView.frame.origin.x;
        float yPosition = self.contactsTableView.frame.origin.y;
        float width = self.contactsTableView.frame.size.width;
        self.contactsTableView.frame = CGRectMake(xPosition, yPosition, width, 0.0);
        self.contactsTableView.alpha = 0.0;
        
        self.amountTextField.alpha = 1.0;
        self.descriptionTextField.alpha = 1.0;
        
    } completion:^(BOOL finished){
        [self.contactsTableView setHidden:YES];
        [self.amountTextField becomeFirstResponder];
    }];
}

- (void)showTableView {
    contactsAreShowing = YES;
    //[self.staticTableView reloadData];
    [self.contactsTableView setHidden:NO];

    //scroll the table view back to the top; otherwise it remembers the previous position scrolled to.
    [self.contactsTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    
    [UIView animateWithDuration:0.10 delay:0.2 options:UIViewAnimationCurveEaseOut animations:^(void){
        float xPosition = self.staticTableView.frame.origin.x;
        float yPosition = self.staticTableView.frame.origin.y + kTABLEVIEWOFFSET;

        float width = self.staticTableView.frame.size.width;
        self.contactsTableView.frame = CGRectMake(xPosition, yPosition, width, kTABLEVIEWHEIGHT);
        self.contactsTableView.alpha = 1.0;

        self.amountTextField.alpha = 0.0;
        self.descriptionTextField.alpha = 0.0;
        
    } completion:^(BOOL finished){
    }];
}

#pragma mark - this is also the ABContactCell Delegate method
- (void)replaceEmailFieldWithName:(NSString *)name 
                         andEmail:(NSString *)email 
                         andImage:(UIImage *)image {
    [self showEmailCellWithImage:image name:name email:email];

    if (!self.staticTableView.isHidden)[self hideTableView];
    
    [self changeSendButtonText];
    [self.amountTextField becomeFirstResponder];
    self.lastSelectedIndexPath = [NSIndexPath indexPathWithIndex:NSIntegerMax];
    [self checkForValidEmailAndAmountWithTextFieldWithTextField:nil string:nil];
}

- (void)changeSendButtonText {
    if ([self.sendButton.title isEqualToString:@"Next"]) {
        if (self.isRequestMoney) {
            self.sendButton.title = kREQUESTBUTTONTITLE;
        } else {
            self.sendButton.title = kSENDBUTTONTITLE;
        }
    }
}

- (void)checkForValidEmailAndAmountWithTextFieldWithTextField:(UITextField *)textField string:(NSString *)currentString {
    BOOL emailIsSet;
    if (textField == self.emailTextField) {
        emailIsSet = (emailFieldIsSet || [self stringIsValidEmail:currentString]);
    } else {
        emailIsSet = (emailFieldIsSet || [self stringIsValidEmail:self.emailTextField.text]);
    }
    
    BOOL amountIsValid;
    if (textField == self.amountTextField) {
        NSLog(@"amount: %@", self.amountTextField.text);
        amountIsValid = !([currentString isEqualToString:@""] || [currentString isEqualToString:@"$0.00"]);
    } else {
        amountIsValid = (![self.amountTextField.text isEqualToString:@""] && ![self.amountTextField.text isEqualToString:@"$0.00"]);
    }
    
    if (emailIsSet && amountIsValid && !sendButtonIsActive) {
        [self setSendButtonActive:YES];
    } else if (!(emailIsSet && amountIsValid) && sendButtonIsActive) {
        [self setSendButtonActive:NO];
    }
}

# pragma mark - UITextFieldDelegate methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.emailTextField) {
        [self checkForValidEmailAndAmountWithTextFieldWithTextField:textField string:textField.text];
        
        //if there's only one match in filteredcontacts, we use that match
        if ([self.filteredContacts count] == 1) {
            NSDictionary *match = [self.filteredContacts objectAtIndex:0];
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[c] %@", textField.text];
            NSArray *emails = [[match objectForKey:@"emails"] filteredArrayUsingPredicate:predicate];
            [self replaceEmailFieldWithName:[match objectForKey:@"name"] andEmail:[emails objectAtIndex:0] andImage:[match objectForKey:@"image"]];
            
            [self changeSendButtonText];
            [self.amountTextField becomeFirstResponder];
        
        //if the string is a valid email, we let the user send to that email address
        } else if ([self stringIsValidEmail:textField.text]) {
            [self replaceEmailFieldWithName:textField.text andEmail:textField.text andImage:nil];
            [self changeSendButtonText];
            [self.amountTextField becomeFirstResponder];
            
        //if it's NOT a valid email, we show an error message and return them to the textfield
        } else {
            loadingIndicator = [[MBProgressHUD alloc] initWithView:self.view.window];
            loadingIndicator.delegate = self;
            [self.view.window addSubview:loadingIndicator];
            loadingIndicator.dimBackground = YES;
            loadingIndicator.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"error"]];
            loadingIndicator.mode = MBProgressHUDModeCustomView;
            loadingIndicator.labelText = @"Error";
            
            if ([textField.text isEqualToString:[KeychainWrapper load:@"userEmail"]]) {
                loadingIndicator.detailsLabelText = @"You can't send money to your own email address.";
            } else {
                loadingIndicator.detailsLabelText = @"You must enter a valid email address.";
            }
            
            //offset the HUD so it's not partially covered by the keyboard
            loadingIndicator.yOffset = -77;
            [loadingIndicator show:YES];
            // Display the error message and hide it after 1 second
            [loadingIndicator hide:YES afterDelay:1.5];
            
            //send them back to the emailtextfield so they can fix it
            return NO;
        }
    } else if (textField == self.amountTextField) {
        [self.descriptionTextField becomeFirstResponder];
    } else {
        [self dismissKeyboard];
    }
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *currentString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    NSLog(@"Current string: %@", currentString);
    
    
    if (textField == self.emailTextField) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(name CONTAINS[c] %@) || (ANY emails CONTAINS[c] %@)",currentString,currentString];

        
        NSMutableArray *copyOfContacts = [NSMutableArray arrayWithArray:self.contacts];
        NSArray *filtered  = [copyOfContacts filteredArrayUsingPredicate:predicate];
        
        self.filteredContacts = [NSMutableArray arrayWithArray:filtered];
        if (currentString.length == 0) {
            self.filteredContacts = copyOfContacts;
        }
        [self.contactsTableView reloadData];
    } else if (textField == self.amountTextField) {
        // Clear all characters that are not numbers
        // (like currency symbols or dividers)
        NSString *cleanCentString = [[textField.text componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];
        // Parse final integer value
        NSInteger centAmount = cleanCentString.integerValue;
        // Check the user input
        if (string.length > 0) {
            // Digit added
            centAmount = centAmount * 10 + string.integerValue;
        }
        else {
            // Digit deleted
            centAmount = centAmount / 10;
        }
        // Update call amount value
        NSNumber *amountToDisplay = [[NSNumber alloc] initWithFloat:(float)centAmount / 100.0f];
        // Write amount with currency symbols to the textfield
        NSNumberFormatter *_currencyFormatter = [[NSNumberFormatter alloc] init];
        [_currencyFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [_currencyFormatter setCurrencyCode:@"USD"];
        [_currencyFormatter setNegativeFormat:@"-¤#,##0.00"];
        NSString *amountText = [_currencyFormatter stringFromNumber:amountToDisplay];
        textField.text = amountText;
        self.amount = [NSNumber numberWithInteger:centAmount];
        // Since we already wrote our changes to the textfield
        // we don't want to change the textfield again
        
        [self checkForValidEmailAndAmountWithTextFieldWithTextField:textField string:amountText];
        return NO;
    }
    
    [self checkForValidEmailAndAmountWithTextFieldWithTextField:textField string:currentString];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if (textField == self.emailTextField){
        emailFieldIsSet = NO;
        if (self.contactsTableView.isHidden)[self showTableView];
    }
    else {
        if (!self.contactsTableView.isHidden)[self hideTableView];
    }
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    self.filteredContacts = self.contacts;
    [self.contactsTableView reloadData];
    return YES;
}


#pragma mark - MBProgressHUDDelegate methods
- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    hud = nil;
}

#pragma mark - UITableViewDataSource methods
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.contactsTableView) {
        ABContactCell *cell;
        NSMutableDictionary *contact = [self.filteredContacts objectAtIndex:indexPath.row];
        
        if ([[contact objectForKey:@"emails"] count] == 1) {
            // Check for a reusable cell first, use that if it exists
            cell = [tableView dequeueReusableCellWithIdentifier:@"oneEmail"];
            // If there is no reusable cell of this type, create a new one
            if (!cell) {
                cell = [[ABContactCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"oneEmail"];
            }
        } else {
            // Check for a reusable cell first, use that if it exists
            cell = [tableView dequeueReusableCellWithIdentifier:@"multipleEmails"];
            // If there is no reusable cell of this type, create a new one
            if (!cell) {
                cell = [[ABContactCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"multipleEmails"];
            }
        }

        cell.delegateTVC = self;
        [cell configureWithDictionary:contact];
        return cell;
    } else {
        return [super tableView:tableView cellForRowAtIndexPath:indexPath];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.contactsTableView) {
        return [self.filteredContacts count];
    } else {
        //otherwise it's the static table view
        if (emailFieldIsSet) return 3;
        else return 1;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {    
    //contacts table view
    if (tableView == self.contactsTableView) {
        NSDictionary *contact = [self.filteredContacts objectAtIndex:indexPath.row];
        NSString *name = [contact objectForKey:@"name"];
        NSArray *emails = [contact objectForKey:@"emails"];
        UIImage *image = [UIImage imageWithData:[contact objectForKey:@"imageData"]];
        
        //if the cell is big, selecting it again makes it small
        if ([indexPath isEqual:self.lastSelectedIndexPath]) {
            self.lastSelectedIndexPath = [NSIndexPath indexPathWithIndex:NSIntegerMax];
            [self.contactsTableView beginUpdates];
            [[self.contactsTableView cellForRowAtIndexPath:indexPath] setSelected:NO];
            [self.contactsTableView endUpdates];

        //if the cell has multiple emails, expand and scroll table view so cell is at top of visible table view
        } else if ([emails count] > 1) {
            self.lastSelectedIndexPath = indexPath;
        
            [self.contactsTableView beginUpdates];
            [self.contactsTableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
            [self.contactsTableView endUpdates];
        
        //if the cell only has one email we replace the email field with the contact selected
        } else {
            emailFieldIsSet = YES;
            [self replaceEmailFieldWithName:(NSString *)name andEmail:[emails lastObject] andImage:image];
        }
        
    //static table view
    } else {
        if (emailFieldIsSet && indexPath.row == 0) {
            [self clearEmailCellButtonPressed];
        }
    }
    
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.staticTableView) {

        if (emailFieldIsSet && indexPath.row == 0) {
            return 60;
        } else {
            return 44;
        }
            
    } else if (tableView == self.contactsTableView) {
        int emailCount = [[[self.filteredContacts objectAtIndex:indexPath.row] objectForKey:@"emails"] count];
        
        if ([indexPath isEqual:self.lastSelectedIndexPath] && emailCount > 1) {
            return 35 + (45*emailCount);
        } 
    }
    
    return 56;
}

- (NSInteger)tableView:(UITableView *)tableView indentationLevelForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 1;
}

#pragma mark - GCStoryboardPinViewControllerDelegate methods
- (void) pinViewController:(GCStoryboardPINViewController *)controller didEnterPIN:(NSString *)PIN; {
    //TODO: don't use a constant PIN (duh)
    if ([PIN isEqualToString:kPINCONSTANT]) {
        //set up the HUD and send the request!
        
        //keeps the keyboard from re-showing when we come back from modal
        self.pinEntrySuccess = YES;
        [self dismissModalViewControllerAnimated:YES];

        loadingIndicator = [[MBProgressHUD alloc] initWithView:self.view.window];
        loadingIndicator.delegate = self;
        [self.view.window addSubview:loadingIndicator];
        loadingIndicator.dimBackground = YES;
        [loadingIndicator show:YES];
        
        [self sendRequest];
    } else {
        [controller wrong];
    }
}

- (void) pinViewController:(GCStoryboardPINViewController *)controller didCancel:(BOOL)cancel; {
    [self dismissModalViewControllerAnimated:YES];
}
@end
