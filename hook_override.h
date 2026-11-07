#import <dobby.h>
#import <mach/mach.h>
#import <TargetConditionals.h>

// [FIX] Guard substrate.h cho RootHide
#if __has_include(<substrate.h>)
#import <substrate.h>
#endif

// [FIX] Force undef: substrate.h định nghĩa MSHookFunction dạng macro
#ifdef MSHookFunction
#undef MSHookFunction
#endif

// [FIX] Bỏ dobby_enable/disable_near_branch_trampoline vì bản Dobby mới không hỗ trợ.
//       DobbyHook trực tiếp vẫn hoạt động hoàn hảo và an toàn cho 1 hook duy nhất.
#define MSHookFunction(_func, _new, _orig) \
    do {\
        int _dobby_hook_ret = DobbyHook((void *)(_func), (void *)(_new), (void **)(_orig));\
        if (_dobby_hook_ret != 0) {\
            NSLog(@"[Unity60FPS] DobbyHook failed: %d (func=%p)", _dobby_hook_ret, (void *)(_func));\
        }\
    } while (0)
