#import "FPSLicenseViewController.h"

@implementation FPSLicenseViewController

-(void)loadView{
    [super loadView];
    self.navigationItem.title = @"Licenses";

    UITextView *textView = [[UITextView alloc] initWithFrame:self.view.bounds];

    // [FIX] Tự co giãn khi xoay màn hình / iPad split view
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // [FIX] Không cho user sửa text, nhưng vẫn copy được
    textView.editable = NO;
    textView.selectable = YES;
    textView.alwaysBounceVertical = YES;

    // [FIX] Tránh bị nav bar / notch / dynamic island che nội dung
    //       (iOS 11+, UITextView kế thừa UIScrollView nên có property này)
    if (@available(iOS 11.0, *)) {
        textView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    }

    // kBundlePath đã được ROOT_PATH_NS(...) trong Prefix.pch
    // → chạy đúng trên cả rootful / rootless / roothide, không cần sửa path.
    NSString *path = [kBundlePath stringByAppendingPathComponent:@"licenses.txt"];
    NSError *error = nil;
    NSString *licenses = [NSString stringWithContentsOfFile:path
                                                   encoding:NSUTF8StringEncoding
                                                      error:&error];
    if (!licenses) {
        // [FIX] Không còn im lặng — log lỗi và hiển thị path để debug
        NSLog(@"[Unity60FPS] Failed to load licenses.txt at %@: %@", path, error);
        licenses = [NSString stringWithFormat:
                    @"Cannot load licenses.txt\n\nPath:\n%@\n\nError:\n%@",
                    path,
                    error.localizedDescription ?: @"unknown"];
    }
    textView.text = licenses;

    [self.view addSubview:textView];
}

@end
