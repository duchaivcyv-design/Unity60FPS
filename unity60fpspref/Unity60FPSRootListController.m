#include "Unity60FPSRootListController.h"
#import "BDInfoListController.h"
#import "FPSLicenseViewController.h"
#import <rootless.h>

@implementation Unity60FPSRootListController

// [ADD] helper tránh lặp code + đảm bảo cùng path với Tweak.x (qua ROOT_PATH_NS)
- (NSString *)prefsPathForSpecifier:(PSSpecifier *)specifier {
    NSString *defaults = specifier.properties[@"defaults"];
    if (!defaults) return nil;
    
    // Tách chuỗi ra biến trước để tránh lỗi macro nhận nhầm dấu phẩy làm tham số
    NSString *unrootedPath = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", defaults];
    return ROOT_PATH_NS(unrootedPath);
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        // Tải toàn bộ giao diện từ Root.plist (Bật/tắt, Chọn app, Chọn FPS)
        _specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] mutableCopy];

        PSSpecifier* spec;
        
        // [ADD] Thêm 1 khoảng trống (GroupCell) để tách phần Cài đặt và phần Thông tin
        spec = [PSSpecifier preferenceSpecifierNamed:@""
                                              target:self
                                              set:Nil
                                              get:Nil
                                              detail:Nil
                                              cell:PSGroupCell
                                              edit:Nil];
        [spec setProperty:@"" forKey:@"label"];
        [_specifiers addObject:spec];
        
        // [ADD] Nút Licenses
        spec = [PSSpecifier preferenceSpecifierNamed:@"Licenses"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(showLicenses);
        [_specifiers addObject:spec];

        // [ADD] Nút Author
        spec = [PSSpecifier preferenceSpecifierNamed:[[NSBundle bundleForClass:[self class]] localizedStringForKey:@"AUTHOR" value:@"Author" table:@"Root"]
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(showInfo);
        [_specifiers addObject:spec];
    }

    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier {
    NSString *path = [self prefsPathForSpecifier:specifier];
    if (!path) return specifier.properties[@"default"];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    return (settings[specifier.properties[@"key"]]) ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    NSString *path = [self prefsPathForSpecifier:specifier];
    if (!path) return;
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    [settings setObject:value forKey:specifier.properties[@"key"]];
    [settings writeToFile:path atomically:YES];

    // Gửi thông báo để Tweak cập nhật FPS ngay lập tức
    CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
    if (notificationName) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
    } else {
        // Fallback: đảm bảo tweak reload prefs live
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFSTR("com.taojb.fgotw60fps/loadPref"),
                                             NULL, NULL, YES);
    }
}

-(void)showInfo{
  UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
  self.navigationItem.backBarButtonItem = backItem; 
  [self.navigationController pushViewController:[[BDInfoListController alloc] init] animated:TRUE];
}

-(void)showLicenses{
  UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
  self.navigationItem.backBarButtonItem = backItem; 
  [self.navigationController pushViewController:[[FPSLicenseViewController alloc] init] animated:TRUE];
}

@end
