#import <dobby.h>
#import <mach/mach.h>
#import <TargetConditionals.h>

// [FIX] Guard substrate.h cho RootHide: nếu không có thì bỏ qua, Logos vẫn link được
//       vì ElleKit/RootHide cung cấp ký hiệu MSHookFunction runtime.
#if __has_include(<substrate.h>)
#import <substrate.h>
#endif

// [FIX] Force undef: substrate.h định nghĩa MSHookFunction dạng macro,
//       nếu không undef thì macro của ta bị shadow và Dobby không được dùng.
#ifdef MSHookFunction
#undef MSHookFunction
#endif

// [KEEP] Giữ nguyên pattern enable/disable near-branch như bản gốc.
//        DobbyHook là sync nên disable sau khi return là an toàn,
//        chỉ tắt việc TẠO MỚI near trampoline — trampoline đã tạo vẫn dùng được.
// [FIX] Thêm cast (void*)/(void**) để tránh -Wincompatible-pointer-types
//       trên clang 15/16 (Xcode 15/16) và lỗi int-to-pointer trên arm64e.
// [ADD] Kiểm tra return value + log để biết ngay khi hook fail.
#define MSHookFunction(_func, _new, _orig) \
    do {\
        dobby_enable_near_branch_trampoline();\
        int _dobby_hook_ret = DobbyHook((void *)(_func), (void *)(_new), (void **)(_orig));\
        dobby_disable_near_branch_trampoline();\
        if (_dobby_hook_ret != 0) {\
            NSLog(@"[Unity60FPS] DobbyHook failed: %d (func=%p)", _dobby_hook_ret, (void *)(_func));\
        }\
    } while (0)
