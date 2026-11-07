#import "BDInfoListController.h"
#import <Preferences/PSSpecifier.h>

extern UIApplication *UIApp;

@interface PSTableCell (Unity60FPSIcon)
- (UIImageView *)iconImageView;
@end

@implementation BDInfoListController

- (void)loadView {
    [super loadView];
    // [REBRAND] Đổi tên tác giả hiển thị
    self.navigationItem.title = @"TaoJB";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    id cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    UIImageView *imageView = [cell iconImageView];
    imageView.layer.cornerRadius = 7.0;
    imageView.layer.masksToBounds = YES;
    return cell;
}

// Helper an toàn: tránh no-op im lặng khi UIApp nil hoặc URL nil
- (void)_openURLString:(NSString *)urlString {
    if (!UIApp || !urlString) return;
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;
    [UIApp openURL:url];
}

- (BOOL)_canOpenURLString:(NSString *)urlString {
    if (!UIApp || !urlString) return NO;
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return NO;
    return [UIApp canOpenURL:url];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [NSMutableArray arrayWithCapacity:11];
        PSSpecifier* spec;

        spec = [PSSpecifier emptyGroupSpecifier];
        [_specifiers addObject:spec];

        // Nếu bạn có Twitter, hãy đổi tên label và action cho phù hợp
        spec = [PSSpecifier preferenceSpecifierNamed:@"Follow Me On Twitter"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(open_twitter);
        [spec setProperty:@YES forKey:@"hasIcon"];
        [spec setProperty:[UIImage imageNamed:@"twitter" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil] forKey:@"iconImage"];
        [_specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Donate"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(open_paypal);
        [spec setProperty:@YES forKey:@"hasIcon"];
        [spec setProperty:[UIImage imageNamed:@"paypal" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil] forKey:@"iconImage"];
        [_specifiers addObject:spec];

        // [REBRAND] Đổi tên Label và trỏ link Github về repo của bạn
        spec = [PSSpecifier preferenceSpecifierNamed:@"Github (TaoJB)"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(open_github);
        [spec setProperty:@YES forKey:@"hasIcon"];
        [spec setProperty:[UIImage imageNamed:@"github" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil] forKey:@"iconImage"];
        [_specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:[[NSBundle bundleForClass:[self class]] localizedStringForKey:@"ADD_MY_REPO" value:@"Add my repo" table:@"Root"]
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(open_cydia);
        [spec setProperty:@YES forKey:@"hasIcon"];
        [spec setProperty:[UIImage imageNamed:@"cydia" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil] forKey:@"iconImage"];
        [_specifiers addObject:spec];

        spec = [PSSpecifier emptyGroupSpecifier];
        [_specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"打赏"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(open_alipay);
        [spec setProperty:@YES forKey:@"hasIcon"];
        [spec setProperty:[UIImage imageNamed:@"alipay" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil] forKey:@"iconImage"];
        [_specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Bilibili"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(open_bilibili);
        [spec setProperty:@YES forKey:@"hasIcon"];
        [spec setProperty:[UIImage imageNamed:@"bilibili" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil] forKey:@"iconImage"];
        [_specifiers addObject:spec];
    }
    return _specifiers;
}

#pragma mark - Actions

- (void)open_bilibili {
    // (Bạn có thể đổi UID Bilibili của Brend0n thành của bạn)
    NSString *appURL = @"bilibili://space/22182611";
    if ([self _canOpenURLString:appURL]) {
        [self _openURLString:appURL];
    } else {
        [self _openURLString:@"https://space.bilibili.com/22182611"];
    }
}

- (void)open_github {
    // [REBRAND] Trỏ về link Github của bạn
    [self _openURLString:@"https://github.com/duchaivcyv-design/Unity60FPS"];
}

- (void)open_alipay {
    // (Bạn có thể đổi link Alipay QR của Brend0n thành của bạn)
    [self _openURLString:@"https://qr.alipay.com/fkx199226yyspdubbiibddc"];
}

- (void)open_paypal {
    // (Bạn có thể đổi link Paypal của Brend0n thành của bạn)
    [self _openURLString:@"https://paypal.me/brend0n"];
}

- (void)open_cydia {
    // (Bạn có thể đổi link repo Cydia/Sileo của Brend0n thành của bạn)
    NSString *cydiaURL = @"cydia://url/https://cydia.saurik.com/api/share#?source=http://brendonjkding.github.io";
    if ([self _canOpenURLString:cydiaURL]) {
        [self _openURLString:cydiaURL];
    } else {
        [self _openURLString:@"sileo://source/https://brendonjkding.github.io"];
    }
}

- (void)open_twitter {
    // (Bạn có thể đổi username Twitter của Brend0n thành của bạn)
    if ([self _canOpenURLString:@"twitter://user?screen_name=brendonjkding"]) {
        [self _openURLString:@"twitter://user?screen_name=brendonjkding"];
    } else if ([self _canOpenURLString:@"tweetbot:///user_profile/brendonjkding"]) {
        [self _openURLString:@"tweetbot:///user_profile/brendonjkding"];
    } else {
        [self _openURLString:@"https://mobile.twitter.com/brendonjkding"];
    }
}

@end
