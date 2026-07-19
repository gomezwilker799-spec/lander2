#import <UIKit/UIKit.h>

@interface DiscordProWindow : UIWindow
@end

@implementation DiscordProWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        self.windowLevel = UIWindowLevelAlert + 1;
        self.layer.cornerRadius = 10;
        self.layer.masksToBounds = YES;

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        label.text = @"✅ DiscordPro cargado\nPitch + Clipper listo";
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [UIColor whiteColor];
        label.font = [UIFont boldSystemFontOfSize:14];
        label.numberOfLines = 0;
        [self addSubview:label];
    }
    return self;
}

@end

static void showHub() {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect screen = [UIScreen mainScreen].bounds;
        CGFloat w = 200, h = 60;
        DiscordProWindow *hub = [[DiscordProWindow alloc] initWithFrame:CGRectMake((screen.size.width - w)/2, 50, w, h)];
        hub.hidden = NO;
        // Mantener la ventana visible
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5]];
        hub.hidden = YES;
        hub = nil;
    });
}

__attribute__((constructor))
static void init() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        showHub();
    });
}
