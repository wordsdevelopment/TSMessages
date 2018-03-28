//
//  TSMessageView.m
//  Felix Krause
//
//  Created by Felix Krause on 24.08.12.
//  Copyright (c) 2012 Felix Krause. All rights reserved.
//

#import "TSMessageView.h"
#import "UIColor+HexColors.h"
#import "TSBlurView.h"
#import "TSMessage.h"

#define TSMessageViewMinimumPadding 15.0

#define TSDesignFileName @"TSMessagesDefaultDesign"

static NSMutableDictionary *_notificationDesign;

@interface TSMessage (TSMessageView)
- (void)fadeOutNotification:(TSMessageView *)currentView; // private method of TSMessage, but called by TSMessageView in -[fadeMeOut]
@end

@interface TSMessageView () <UIGestureRecognizerDelegate>

/** The displayed title of this message */
@property (nonatomic, strong) NSString *title;

/** The displayed subtitle of this message view */
@property (nonatomic, strong) NSString *subtitle;

/** The view to displayed content under the title of this message. If not nil the subtitle string will be ignored */
@property (nonatomic, strong) UIView *subtitleView;

/** The title of the added button */
@property (nonatomic, strong) NSString *buttonTitle;

/** The view controller this message is displayed in */
@property (nonatomic, strong) UIViewController *viewController;

/** The design dictionary for this view */
@property (nonatomic, strong) NSDictionary *designDictionary;

/** Internal properties needed to resize the view on device rotation properly */
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *contentLabel;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) UILabel *ctaLabel;
@property (nonatomic, strong) UIView *borderView;
@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) TSBlurView *backgroundBlurView; // Only used in iOS 7

@property (nonatomic, assign) CGFloat textSpaceLeft;
@property (nonatomic, assign) CGFloat textSpaceRight;

@property (nonatomic, assign) CGFloat pixelRatio;

@property (copy) void (^callback)();
@property (copy) void (^buttonCallback)();
@property (copy) void (^dismissalCallback)();

- (CGFloat)updateHeightOfMessageView;
- (void)layoutSubviews;

@end


@implementation TSMessageView{
    TSMessageNotificationType notificationType;
}
-(void) setContentFont:(UIFont *)contentFont{
    _contentFont = contentFont;
    [self.contentLabel setFont:contentFont];
}

-(void) setContentTextColor:(UIColor *)contentTextColor{
    _contentTextColor = contentTextColor;
    [self.contentLabel setTextColor:_contentTextColor];
}

-(void) setTitleFont:(UIFont *)aTitleFont{
    _titleFont = aTitleFont;
    [self.titleLabel setFont:_titleFont];
}

-(void)setTitleTextColor:(UIColor *)aTextColor{
    _titleTextColor = aTextColor;
    [self.titleLabel setTextColor:_titleTextColor];
}

-(void) setMessageIcon:(UIImage *)messageIcon{
    _messageIcon = messageIcon;
    [self updateCurrentIcon];
}

-(void) setErrorIcon:(UIImage *)errorIcon{
    _errorIcon = errorIcon;
    [self updateCurrentIcon];
}

-(void) setSuccessIcon:(UIImage *)successIcon{
    _successIcon = successIcon;
    [self updateCurrentIcon];
}

-(void) setWarningIcon:(UIImage *)warningIcon{
    _warningIcon = warningIcon;
    [self updateCurrentIcon];
}

-(void) updateCurrentIcon{
    UIImage *image = nil;
    switch (notificationType)
    {
        case TSMessageNotificationTypeMessage:
        {
            image = _messageIcon;
            self.iconImageView.image = _messageIcon;
            break;
        }
        case TSMessageNotificationTypeError:
        {
            image = _errorIcon;
            self.iconImageView.image = _errorIcon;
            break;
        }
        case TSMessageNotificationTypeSuccess:
        {
            image = _successIcon;
            self.iconImageView.image = _successIcon;
            break;
        }
        case TSMessageNotificationTypeWarning:
        {
            image = _warningIcon;
            self.iconImageView.image = _warningIcon;
            break;
        }
        default:
            break;
    }
    NSNumber *xPaddingNumber = [self.designDictionary valueForKey:@"xPadding"];
    CGFloat xPadding = (xPaddingNumber ? [xPaddingNumber floatValue] : [self padding]) * self.pixelRatio;
    NSNumber *yPaddingNumber = [self.designDictionary valueForKey:@"yPadding"];
    CGFloat yPadding = (yPaddingNumber ? [yPaddingNumber floatValue] : [self padding]) * self.pixelRatio;
    self.iconImageView.frame = CGRectMake(xPadding,
                                          yPadding,
                                          image.size.width * self.pixelRatio,
                                          image.size.height * self.pixelRatio);
}


+ (NSMutableDictionary *)notificationDesign
{
    if (!_notificationDesign)
    {
        NSString *path = [[NSBundle bundleForClass:self.class] pathForResource:TSDesignFileName ofType:@"json"];
        NSData *data = [NSData dataWithContentsOfFile:path];
        NSAssert(data != nil, @"Could not read TSMessages config file from main bundle with name %@.json", TSDesignFileName);

        _notificationDesign = [NSMutableDictionary dictionaryWithDictionary:[NSJSONSerialization JSONObjectWithData:data
                                                                                                            options:kNilOptions
                                                                                                              error:nil]];
    }

    return _notificationDesign;
}


+ (void)addNotificationDesignFromFile:(NSString *)filename
{
    NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:filename];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        NSDictionary *design = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path]
                                                               options:kNilOptions
                                                                 error:nil];

        [[TSMessageView notificationDesign] addEntriesFromDictionary:design];
    }
    else
    {
        NSAssert(NO, @"Error loading design file with name %@", filename);
    }
}

- (CGFloat)padding
{
    // Adds 10 padding to to cover navigation bar
    return self.messagePosition == TSMessageNotificationPositionNavBarOverlay ? TSMessageViewMinimumPadding + 10.0f : TSMessageViewMinimumPadding;
}

- (id)initWithTitle:(NSString *)title
           subtitle:(NSString *)subtitle
       subtitleView:(UIView *)subtitleView
           ctaTitle:(NSString *)ctaTitle
              image:(UIImage *)image
         pixelRatio:(CGFloat)pixelRatio
               type:(TSMessageNotificationType)aNotificationType
           duration:(CGFloat)duration
   inViewController:(UIViewController *)viewController
           callback:(void (^)())callback
             button:(UIButton *)button
        buttonTitle:(NSString *)buttonTitle
     buttonCallback:(void (^)())buttonCallback
         atPosition:(TSMessageNotificationPosition)position
canBeDismissedByUser:(BOOL)dismissingEnabled
   dismissalCallback:(void (^)())dismissalCallback
{
    NSDictionary *notificationDesign = [TSMessageView notificationDesign];

    if ((self = [self init]))
    {
        _title = title;
        _subtitle = subtitle;
        _subtitleView = subtitleView;
        _buttonTitle = buttonTitle;
        _duration = duration;
        _viewController = viewController;
        _messagePosition = position;
        _pixelRatio = pixelRatio;
        self.callback = callback;
        self.buttonCallback = buttonCallback;
        self.dismissalCallback = dismissalCallback;

        CGFloat screenWidth = self.viewController.view.bounds.size.width;

        NSDictionary *current;
        NSString *currentString;
        notificationType = aNotificationType;
        switch (notificationType)
        {
            case TSMessageNotificationTypeMessage:
            {
                currentString = @"message";
                break;
            }
            case TSMessageNotificationTypeError:
            {
                currentString = @"error";
                break;
            }
            case TSMessageNotificationTypeSuccess:
            {
                currentString = @"success";
                break;
            }
            case TSMessageNotificationTypeWarning:
            {
                currentString = @"warning";
                break;
            }

            default:
                break;
        }

        current = [notificationDesign valueForKey:currentString];
        self.designDictionary = current;
        
        NSNumber *xPaddingNumber = [current valueForKey:@"xPadding"];
        CGFloat xPadding = (xPaddingNumber ? [xPaddingNumber floatValue] : [self padding]) * self.pixelRatio;
        NSNumber *yPaddingNumber = [current valueForKey:@"yPadding"];
        CGFloat yPadding = (yPaddingNumber ? [yPaddingNumber floatValue] : [self padding]) * self.pixelRatio;

        if (!image && [[current valueForKey:@"imageName"] length])
        {
            image = [UIImage imageNamed:[current valueForKey:@"imageName"]];
        }

        if (![TSMessage iOS7StyleEnabled])
        {
            self.alpha = 0.0;

            // add background image here
            UIImage *backgroundImage = [UIImage imageNamed:[current valueForKey:@"backgroundImageName"]];
            backgroundImage = [backgroundImage stretchableImageWithLeftCapWidth:0.0 topCapHeight:0.0];

            _backgroundImageView = [[UIImageView alloc] initWithImage:backgroundImage];
            self.backgroundImageView.autoresizingMask = (UIViewAutoresizingFlexibleWidth);
            [self addSubview:self.backgroundImageView];
        }
        else
        {
            // On iOS 7 and above use a blur layer instead (not yet finished)
            _backgroundBlurView = [[TSBlurView alloc] init];
            self.backgroundBlurView.autoresizingMask = (UIViewAutoresizingFlexibleWidth);
            self.backgroundBlurView.blurTintColor = [UIColor colorFromHexString:current[@"backgroundColor"]];
            [self addSubview:self.backgroundBlurView];
        }
        
        UIColor *fontColor = [UIColor colorFromHexString:[current valueForKey:@"textColor"]];
        
        self.textSpaceLeft = xPadding;
        if (image) self.textSpaceLeft += image.size.width * self.pixelRatio + xPadding;

        // Set up title label
        _titleLabel = [[UILabel alloc] init];
        [self.titleLabel setText:title];
        [self.titleLabel setTextColor:fontColor];
        [self.titleLabel setBackgroundColor:[UIColor clearColor]];
        CGFloat fontSize = [[current valueForKey:@"titleFontSize"] floatValue] * self.pixelRatio;
        NSString *fontName = [current valueForKey:@"titleFontName"];
        if (fontName != nil) {
            [self.titleLabel setFont:[UIFont fontWithName:fontName size:fontSize]];
        } else {
            [self.titleLabel setFont:[UIFont boldSystemFontOfSize:fontSize]];
        }
        [self.titleLabel setShadowColor:[UIColor colorFromHexString:[current valueForKey:@"shadowColor"]]];
        [self.titleLabel setShadowOffset:CGSizeMake([[current valueForKey:@"shadowOffsetX"] floatValue],
                                                    [[current valueForKey:@"shadowOffsetY"] floatValue])];
        self.titleLabel.minimumScaleFactor = 0.75;
        self.titleLabel.adjustsFontSizeToFitWidth = YES;
        
        self.titleLabel.numberOfLines = 1;
        self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

        [self addSubview:self.titleLabel];

        if (self.subtitleView != nil) {
            [self addSubview:self.subtitleView];
        }
        // Set up content label (if set)
        else if ([subtitle length])
        {
            _contentLabel = [[UILabel alloc] init];
            [self.contentLabel setText:subtitle];
            
            UIColor *contentTextColor = [UIColor colorFromHexString:[current valueForKey:@"contentTextColor"]];
            if (!contentTextColor)
            {
                contentTextColor = fontColor;
            }
            [self.contentLabel setTextColor:contentTextColor];
            [self.contentLabel setBackgroundColor:[UIColor clearColor]];
            CGFloat fontSize = [[current valueForKey:@"contentFontSize"] floatValue] * self.pixelRatio;
            NSString *fontName = [current valueForKey:@"contentFontName"];
            if (fontName != nil) {
                [self.contentLabel setFont:[UIFont fontWithName:fontName size:fontSize]];
            } else {
                [self.contentLabel setFont:[UIFont systemFontOfSize:fontSize]];
            }
            [self.contentLabel setShadowColor:self.titleLabel.shadowColor];
            [self.contentLabel setShadowOffset:self.titleLabel.shadowOffset];
            
            int64_t contentNumberOfLines = [[current valueForKey:@"contentNumberOfLines"] intValue];
            self.contentLabel.numberOfLines = contentNumberOfLines;
            self.contentLabel.lineBreakMode = [[current valueForKey:@"lineBreakMode"] intValue];;

            [self addSubview:self.contentLabel];
        }

        if (image)
        {
            _iconImageView = [[UIImageView alloc] initWithImage:image];
            self.iconImageView.frame = CGRectMake(xPadding,
                                                  yPadding,
                                                  image.size.width * self.pixelRatio,
                                                  image.size.height * self.pixelRatio);
            [self addSubview:self.iconImageView];
        }

        // Set up button (if set)
        _button = (button) ? button : [UIButton buttonWithType:UIButtonTypeCustom];
        
        UIImage *buttonBackgroundImage = [UIImage imageNamed:[current valueForKey:@"buttonBackgroundImageName"]];
        
        if (buttonBackgroundImage) {
            buttonBackgroundImage = [buttonBackgroundImage resizableImageWithCapInsets:UIEdgeInsetsMake(15.0, 12.0, 15.0, 11.0)];
            [self.button setBackgroundImage:buttonBackgroundImage forState:UIControlStateNormal];
        }
        
        UIImage *buttonImage = [UIImage imageNamed:[current valueForKey:@"buttonImageName"]];
        if (buttonImage) {
            [self.button setImage:buttonImage forState:UIControlStateNormal];
            self.button.frame = CGRectMake(0,
                                           0,
                                           buttonImage.size.width * self.pixelRatio,
                                           buttonImage.size.height * self.pixelRatio);
            self.button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
            self.button.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
        }
        UIImage *buttonHighlightedImage = [UIImage imageNamed:[current valueForKey:@"buttonImageHighlightedName"]];
        if (buttonHighlightedImage) {
            [self.button setImage:buttonHighlightedImage forState:UIControlStateHighlighted];
        }
        
        if (self.buttonTitle) {
            [self.button setTitle:self.buttonTitle forState:UIControlStateNormal];

            UIColor *buttonTitleShadowColor = [UIColor colorFromHexString:[current valueForKey:@"buttonTitleShadowColor"]];
            if (!buttonTitleShadowColor)
            {
                buttonTitleShadowColor = self.titleLabel.shadowColor;
            }

            [self.button setTitleShadowColor:buttonTitleShadowColor forState:UIControlStateNormal];
            
            UIColor *buttonTitleTextColor = [UIColor colorFromHexString:[current valueForKey:@"buttonTitleTextColor"]];
            if (!buttonTitleTextColor)
            {
                buttonTitleTextColor = fontColor;
            }

            [self.button setTitleColor:buttonTitleTextColor forState:UIControlStateNormal];
            self.button.titleLabel.font = [UIFont boldSystemFontOfSize:14.0 * self.pixelRatio];
            self.button.titleLabel.shadowOffset = CGSizeMake([[current valueForKey:@"buttonTitleShadowOffsetX"] floatValue],
                                                             [[current valueForKey:@"buttonTitleShadowOffsetY"] floatValue]);
        }
        
        [self.button addTarget:self
                        action:@selector(buttonTapped:)
              forControlEvents:UIControlEventTouchUpInside];
        
        self.button.frame = CGRectMake(screenWidth - xPadding - self.button.frame.size.width,
                                       0.0,
                                       self.button.frame.size.width,
                                       self.button.frame.size.height);
        
        [self addSubview:self.button];
        
        if (ctaTitle.length > 0) {
            UIColor *ctaColor = [UIColor colorFromHexString:[current valueForKey:@"ctaTitleColor"]];
            self.ctaLabel = [[UILabel alloc] init];
            self.ctaLabel.text = ctaTitle;
            self.ctaLabel.textColor = ctaColor;
            self.ctaLabel.layer.borderWidth = 1.0f * pixelRatio;
            self.ctaLabel.layer.borderColor = ctaColor.CGColor;
            self.ctaLabel.layer.cornerRadius = 5.0f * pixelRatio;
            self.ctaLabel.clipsToBounds = YES;
            self.ctaLabel.backgroundColor = [UIColor clearColor];
            CGFloat fontSize = [[current valueForKey:@"ctaTitleFontSize"] floatValue] * pixelRatio;
            NSString *fontName = [current valueForKey:@"ctaTitleFontName"];
            if (fontName != nil) {
                [self.ctaLabel setFont:[UIFont fontWithName:fontName size:fontSize]];
            } else {
                [self.ctaLabel setFont:[UIFont boldSystemFontOfSize:fontSize]];
            }
            self.ctaLabel.numberOfLines = 1;
            self.ctaLabel.textAlignment = NSTextAlignmentCenter;
            [self.ctaLabel sizeToFit];
            CGRect ctaFrame = self.ctaLabel.frame;
            ctaFrame.size.width += [[current valueForKey:@"ctaTitleXPadding"] floatValue] * pixelRatio;
            ctaFrame.size.height += [[current valueForKey:@"ctaTitleYPadding"] floatValue] * pixelRatio;
            self.ctaLabel.frame = ctaFrame;
            [self addSubview:self.ctaLabel];
        }
        
        self.textSpaceRight = self.button.frame.size.width + xPadding;
        if (self.ctaLabel) {
            self.textSpaceRight = self.textSpaceRight + self.ctaLabel.frame.size.width + xPadding;
        }
        
        // Add a border on the bottom (or on the top, depending on the view's postion)
        if (![TSMessage iOS7StyleEnabled])
        {
            _borderView = [[UIView alloc] initWithFrame:CGRectMake(0.0,
                                                                   0.0, // will be set later
                                                                   screenWidth,
                                                                   [[current valueForKey:@"borderHeight"] floatValue] * self.pixelRatio)];
            self.borderView.backgroundColor = [UIColor colorFromHexString:[current valueForKey:@"borderColor"]];
            self.borderView.autoresizingMask = (UIViewAutoresizingFlexibleWidth);
            [self addSubview:self.borderView];
        }


        CGFloat actualHeight = [self updateHeightOfMessageView]; // this call also takes care of positioning the labels
        CGFloat topPosition = -actualHeight;

        if (self.messagePosition == TSMessageNotificationPositionBottom)
        {
            topPosition = self.viewController.view.bounds.size.height;
        }

        self.frame = CGRectMake(0.0, topPosition, screenWidth, actualHeight);

        if (self.messagePosition == TSMessageNotificationPositionTop)
        {
            self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        }
        else
        {
            self.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
        }

        if (dismissingEnabled)
        {
            UISwipeGestureRecognizer *gestureRec = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                             action:@selector(dismiss)];
            [gestureRec setDirection:(self.messagePosition == TSMessageNotificationPositionBottom ?
                                      UISwipeGestureRecognizerDirectionDown :
                                      UISwipeGestureRecognizerDirectionUp)];
            [self addGestureRecognizer:gestureRec];

            UITapGestureRecognizer *tapRec = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                     action:@selector(dismiss)];
            [self addGestureRecognizer:tapRec];
        }

        if (self.callback) {
            UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
            tapGesture.delegate = self;
            [self addGestureRecognizer:tapGesture];
        }
    }
    return self;
}

- (id)initWithTitle:(NSString *)title
           subtitle:(NSString *)subtitle
           ctaTitle:(NSString *)ctaTitle
              image:(UIImage *)image
         pixelRatio:(CGFloat)pixelRatio
               type:(TSMessageNotificationType)notificationType
           duration:(CGFloat)duration
   inViewController:(UIViewController *)viewController
           callback:(void (^)())callback
             button:(UIButton *)button
        buttonTitle:(NSString *)buttonTitle
     buttonCallback:(void (^)())buttonCallback
         atPosition:(TSMessageNotificationPosition)position
canBeDismissedByUser:(BOOL)dismissingEnabled
  dismissalCallback:(void (^)())dismissalCallback {
    return [[TSMessageView alloc] initWithTitle:title
                                       subtitle:subtitle
                                   subtitleView:nil
                                       ctaTitle:ctaTitle
                                          image:image
                                     pixelRatio:pixelRatio
                                           type:notificationType
                                       duration:duration
                               inViewController:viewController
                                       callback:callback
                                         button:button
                                    buttonTitle:buttonTitle
                                 buttonCallback:buttonCallback
                                     atPosition:position
                           canBeDismissedByUser:dismissingEnabled
                              dismissalCallback:dismissalCallback];
}

- (id)initWithTitle:(NSString *)title
       subtitleView:(UIView *)subtitleView
           ctaTitle:(NSString *)ctaTitle
              image:(UIImage *)image
         pixelRatio:(CGFloat)pixelRatio
               type:(TSMessageNotificationType)notificationType
           duration:(CGFloat)duration
   inViewController:(UIViewController *)viewController
           callback:(void (^)())callback
             button:(UIButton *)button
        buttonTitle:(NSString *)buttonTitle
     buttonCallback:(void (^)())buttonCallback
         atPosition:(TSMessageNotificationPosition)position
canBeDismissedByUser:(BOOL)dismissingEnabled
  dismissalCallback:(void (^)())dismissalCallback {
    return [[TSMessageView alloc] initWithTitle:title
                                       subtitle:nil
                                   subtitleView:subtitleView
                                       ctaTitle:ctaTitle
                                          image:image
                                     pixelRatio:pixelRatio
                                           type:notificationType
                                       duration:duration
                               inViewController:viewController
                                       callback:callback
                                         button:button
                                    buttonTitle:buttonTitle
                                 buttonCallback:buttonCallback
                                     atPosition:position
                           canBeDismissedByUser:dismissingEnabled
                              dismissalCallback:dismissalCallback];
}

- (void)dismiss {
    if (self.dismissalCallback) {
        self.dismissalCallback();
    }
    [self fadeMeOut];
}

- (CGFloat)updateHeightOfMessageView
{
    CGFloat currentHeight;
    CGFloat screenWidth = self.viewController.view.bounds.size.width;
    NSNumber *xPaddingNumber = [self.designDictionary valueForKey:@"xPadding"];
    CGFloat xPadding = (xPaddingNumber ? [xPaddingNumber floatValue] : [self padding]) * self.pixelRatio;
    NSNumber *yPaddingNumber = [self.designDictionary valueForKey:@"yPadding"];
    CGFloat yPadding = (yPaddingNumber ? [yPaddingNumber floatValue] : [self padding]) * self.pixelRatio;

    self.titleLabel.frame = CGRectMake(self.textSpaceLeft,
                                       yPadding + 4.0f,
                                       screenWidth - xPadding - self.textSpaceLeft - self.textSpaceRight,
                                       0.0);
    [self.titleLabel sizeToFit];
    CGRect newTitleFrame = self.titleLabel.frame;
    newTitleFrame.size.width = screenWidth - xPadding - self.textSpaceLeft - self.textSpaceRight;
    self.titleLabel.frame = newTitleFrame;
    
    if (self.subtitleView != nil) {
        self.subtitleView.frame = CGRectMake(self.textSpaceLeft,
                                             self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height,
                                             screenWidth - xPadding - self.textSpaceLeft - self.textSpaceRight,
                                             self.subtitleView.frame.size.height);
        
        currentHeight = self.subtitleView.frame.origin.y + self.subtitleView.frame.size.height;
    } else if ([self.subtitle length]) {
        self.contentLabel.frame = CGRectMake(self.textSpaceLeft,
                                             self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height,
                                             screenWidth - xPadding - self.textSpaceLeft - self.textSpaceRight,
                                             0.0);
        [self.contentLabel sizeToFit];
        CGRect newContentFrame = self.contentLabel.frame;
        newContentFrame.size.width = screenWidth - xPadding - self.textSpaceLeft - self.textSpaceRight;
        self.contentLabel.frame = newContentFrame;

        currentHeight = self.contentLabel.frame.origin.y + self.contentLabel.frame.size.height;
    }
    else
    {
        // only the title was set
        currentHeight = self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height;
    }
    
    currentHeight += yPadding;
    
    if (self.iconImageView)
    {
        // Check if that makes the popup larger (height)
        if (self.iconImageView.frame.size.height + 2*yPadding > currentHeight)
        {
            currentHeight = self.iconImageView.frame.size.height + 2*yPadding;
        }
        else
        {
            // z-align
            self.iconImageView.center = CGPointMake([self.iconImageView center].x,
                                                    round(currentHeight / 2.0));
        }
    }

    // z-align button
    self.button.center = CGPointMake([self.button center].x,
                                     round(currentHeight / 2.0));

    if (self.messagePosition == TSMessageNotificationPositionTop)
    {
        // Correct the border position
        CGRect borderFrame = self.borderView.frame;
        borderFrame.origin.y = currentHeight;
        self.borderView.frame = borderFrame;
    }

    currentHeight += self.borderView.frame.size.height;
    
    CGFloat yOffset = 0.0f;
    if (self.messagePosition == TSMessageNotificationPositionNavBarOverlay)
    {
        // Increase height of frame to account for status bar (we subtract a small amount or top spacing appears disproportionately large)
        CGSize statusBarSize = [UIApplication sharedApplication].statusBarFrame.size;
        yOffset = MAX(0, MIN(statusBarSize.width, statusBarSize.height)-7.0f);
        currentHeight += yOffset;
    }
    
    self.frame = CGRectMake(0.0, self.frame.origin.y, self.frame.size.width, currentHeight);
    
    // Reposition UI elements
    if (self.button)
    {
        self.button.frame = CGRectMake(self.frame.size.width - self.textSpaceRight,
                                       round(((self.frame.size.height-yOffset) / 2.0) - self.button.frame.size.height / 2.0) + yOffset,
                                       self.button.frame.size.width,
                                       self.button.frame.size.height);
    }
    if (self.ctaLabel) {
        if (self.button) {
            self.button.frame = CGRectMake(self.button.frame.origin.x + self.ctaLabel.frame.size.width + xPadding,
                                           self.button.frame.origin.y,
                                           self.button.frame.size.width,
                                           self.button.frame.size.height);
        }

        self.ctaLabel.frame = CGRectMake(self.frame.size.width - self.textSpaceRight,
                                       round(((self.frame.size.height - yOffset) / 2.0) - self.ctaLabel.frame.size.height / 2.0) + yOffset,
                                       self.ctaLabel.frame.size.width,
                                       self.ctaLabel.frame.size.height);
    }
    
    if (self.titleLabel)
    {
        self.titleLabel.frame = CGRectMake(self.titleLabel.frame.origin.x,
                                           self.titleLabel.frame.origin.y + yOffset,
                                           self.titleLabel.frame.size.width,
                                           self.titleLabel.frame.size.height);
    }
    
    if (self.subtitleView) {
        self.subtitleView.frame = CGRectMake(self.subtitleView.frame.origin.x,
                                             self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height,
                                             self.subtitleView.frame.size.width,
                                             self.subtitleView.frame.size.height);
    } else if (self.contentLabel) {
        self.contentLabel.frame = CGRectMake(self.contentLabel.frame.origin.x,
                                             self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height,
                                             self.contentLabel.frame.size.width,
                                             self.contentLabel.frame.size.height);
    }
    
    if (self.iconImageView)
    {
        self.iconImageView.frame = CGRectMake(self.iconImageView.frame.origin.x,
                                              round(((self.frame.size.height-yOffset) / 2.0) - self.iconImageView.frame.size.height / 2.0) + yOffset,
                                              self.iconImageView.frame.size.width,
                                              self.iconImageView.frame.size.height);
    }
    
    if (self.borderView)
    {
        self.borderView.frame = CGRectMake(self.borderView.frame.origin.x,
                                           self.borderView.frame.origin.y + yOffset,
                                           self.borderView.frame.size.width,
                                           self.borderView.frame.size.height);
    }
    
    CGRect backgroundFrame = CGRectMake(self.backgroundImageView.frame.origin.x,
                                        self.backgroundImageView.frame.origin.y,
                                        screenWidth,
                                        currentHeight);

    // increase frame of background view because of the spring animation
    if ([TSMessage iOS7StyleEnabled])
    {
        if (self.messagePosition == TSMessageNotificationPositionTop)
        {
            float topOffset = 0.f;

            UINavigationController *navigationController = self.viewController.navigationController;
            if (!navigationController && [self.viewController isKindOfClass:[UINavigationController class]]) {
                navigationController = (UINavigationController *)self.viewController;
            }
            BOOL isNavBarIsHidden = !navigationController || [TSMessage isNavigationBarInNavigationControllerHidden:navigationController];
            BOOL isNavBarIsOpaque = !navigationController.navigationBar.isTranslucent && navigationController.navigationBar.alpha == 1;

            if (isNavBarIsHidden || isNavBarIsOpaque) {
                topOffset = -30.f;
            }
            backgroundFrame = UIEdgeInsetsInsetRect(backgroundFrame, UIEdgeInsetsMake(topOffset, 0.f, 0.f, 0.f));
        }
        else if (self.messagePosition == TSMessageNotificationPositionBottom)
        {
            backgroundFrame = UIEdgeInsetsInsetRect(backgroundFrame, UIEdgeInsetsMake(0.f, 0.f, -30.f, 0.f));
        }
    }

    self.backgroundImageView.frame = backgroundFrame;
    self.backgroundBlurView.frame = backgroundFrame;

    return currentHeight;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self updateHeightOfMessageView];
}

- (void)fadeMeOut
{
    [[TSMessage sharedMessage] performSelectorOnMainThread:@selector(fadeOutNotification:) withObject:self waitUntilDone:NO];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.duration == TSMessageNotificationDurationEndless && self.superview && !self.window )
    {
        // view controller was dismissed, let's fade out
        [self fadeMeOut];
    }
}
#pragma mark - Target/Action

- (void)buttonTapped:(id) sender
{
    if (self.buttonCallback)
    {
        self.buttonCallback();
    }

    [self fadeMeOut];
}

- (void)handleTap:(UITapGestureRecognizer *)tapGesture
{
    if (tapGesture.state == UIGestureRecognizerStateRecognized)
    {
        if (self.callback)
        {
            self.callback();
        }
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return ! ([touch.view isKindOfClass:[UIControl class]]);
}

@end
