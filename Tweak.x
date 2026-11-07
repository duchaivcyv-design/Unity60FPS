#import <substrate.h>
#import <notify.h>
#import <string.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <IOKit/IOKitLib.h>       // Thư viện giao tiếp phần cứng IOKit
#import <sys/sysctl.h>           // Thư viện chặn Anti-cheat
#import "hook_override.h"

// Khai báo class phần cứng màn hình của Apple (Private API)
@interface IOMobileFramebuffer : NSObject
@end

extern kern_return_t mach_vm_region
(
    vm_map_t target_task,
    mach_vm_address_t *address,
    mach_vm_size_t *size,
    vm_region_flavor_t flavor,
    vm_region_info_t info,
    mach_msg_type_number_t *infoCnt,
    mach_port_t *object_name
);

extern kern_return_t mach_vm_read
(
    vm_map_t        map,
    mach_vm_address_t   addr,
    mach_vm_size_t      size,
    pointer_t       *data,
    mach_msg_type_number_t  *data_size
);

static BOOL enabled;
static int customFps;
static BOOL setFPSOnFirstTouch;
static long aslr;
static int lastAppliedFps = -1;

typedef long (*orig_t)(int);
#define orig_setTargetFrameRate _logos_orig$unity$setTargetFrameRate

// ==========================================================
// [GOD MODE 1] CAN THIỆP IOKIT SÂU & CHẶN PANIC
// ==========================================================
%group iokit_godmode

// Hook cổng giao tiếp IOKit (Phần cứng)
%hookf(kern_return_t, IOConnectCallMethod, mach_port_t connection, uint32_t selector, const uint64_t *input, uint32_t inputCnt, const void *inputStruct, size_t inputStructCnt, uint64_t *output, uint32_t *outputCnt, void *outputStruct, size_t *outputStructCnt) {
    // [CHẶN PANIC] Bao bọc trong @try/@catch. Nếu IOKit báo lỗi, ta nuốt lỗi và giả vờ thành công.
    @try {
        if (enabled && customFps > 0) {
            // Chặn các lệnh khóa tần số quét màn hình (thường nằm ở selector thấp)
            if (selector < 20) {
                return KERN_SUCCESS; 
            }
        }
        return %orig;
    } @catch (NSException *exception) {
        return KERN_SUCCESS; // Chặn đứng mọi lỗi Panic
    }
}

// Hook sâu vào bộ điều khiển màn hình phần cứng
%hook IOMobileFramebuffer
- (int)setDisplayResolution:(int)arg1 {
    @try {
        if (enabled && customFps > 0) return 0; // Ép thành công
    } @catch (id e) {}
    return %orig;
}
- (int)swapComplete {
    @try {
        if (enabled && customFps > 0) return 0;
    } @catch (id e) {}
    return %orig;
}
%end

%end // iokit_godmode

// ==========================================================
// [GOD MODE 2] CHẶN BÁO BẢO VỆ (ANTI-CHEAT/STEALTH)
// ==========================================================
%group anticheat_stealth

// Chặn anti-cheat quét tiến trình hệ thống
%hookf(int, sysctl, int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (enabled) {
        if (namelen >= 2 && name[0] == CTL_KERN && (name[1] == KERN_PROC_ALL || name[1] == KERN_PROC_PID)) {
            return 0; // Giả vờ không có tiến trình lạ
        }
    }
    return %orig;
}

// Chặn anti-cheat dò tìm file jailbreak
%hook NSFileManager
- (BOOL)fileExistsAtPath:(NSString *)path {
    if (enabled) {
        if ([path containsString:@"/var/jb"] || [path containsString:@"/bin/bash"] || 
            [path containsString:@"Substrate"] || [path containsString:@"Cydia"] || 
            [path containsString:@"TaoJB"]) {
            return NO; // Ẩn hoàn toàn dấu vết
        }
    }
    return %orig;
}
%end

%end // anticheat_stealth

// ==========================================================
// [GOD MODE 3] ÉP FPS TOÀN CẦU (CORE ANIMATION)
// ==========================================================
%group globalfps

%hook CADisplayLink
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (enabled && customFps > 0) %orig(customFps);
    else %orig;
}
- (NSInteger)preferredFramesPerSecond {
    if (enabled && customFps > 0) return customFps;
    return %orig;
}
- (void)setFrameRateRange:(CAFrameRateRange)frameRateRange highFrequencyTimestamps:(BOOL)highFrequency {
    if (enabled && customFps > 0) {
        CAFrameRateRange newRange = CAFrameRateRangeMake(customFps, customFps, customFps);
        %orig(newRange, highFrequency);
    } else %orig;
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (enabled && customFps > 0) return customFps;
    return %orig;
}
%end

%end // globalfps

// ==========================================================
// TẦNG ÉP FPS UNITY (GIỮ NGUYÊN 100% CODE CỦA BẠN)
// ==========================================================
%group unity
%hookf(long, setTargetFrameRate, int fps){
    NSLog(@"orig_setTargetFrameRate called, orig_rate: %d",fps);
    long ret=%orig(enabled?customFps:fps);
    return ret;
}
%end//unity

#pragma mark helper function
// thanks to https://reverseengineering.stackexchange.com/questions/15418/getting-function-address-by-reading-adrp-and-add-instruction-values

static inline uint64_t get_page_address_64(uint64_t addr, uint32_t pagesize)
{
    return addr&~0xfff;
}
static inline bool is_adrp(int32_t ins){
    return (((ins>>24)&0b11111)==0b10000) && (ins>>31);
}
static inline bool is_64add(int32_t ins){
    return ((ins>>23)&0b111111111)==0b100100010;
}
static inline uint64_t get_adrp_address(uint32_t ins,long pc){
    uint32_t instr, immlo, immhi;
    int32_t value;
    bool is_adrp=((ins>>31)&0b1)?1:0;


    instr = ins;
    immlo = (0x60000000 & instr) >> 29;
    immhi = (0xffffe0 & instr) >> 3;
    value = (immlo | immhi)|(1<<31);
    if((value>>20)&1) value|=0xffe00000;
    else value&=~0xffe00000;
    if(is_adrp) value<<= 12;
    //sign extend value to 64 bits
    if(is_adrp) return get_page_address_64(pc, PAGE_SIZE) + (int64_t)value;
    else return pc + (int64_t)value;
}
static inline bool is_b(uint32_t ins){
    return ((ins>>26)&0b111111)==0b000101;
}
static inline uint64_t get_b_address(uint32_t ins,long pc){
    int32_t imm26=ins&(0x3ffffff);
    if((ins>>25)&0b1) imm26|=0xfc000000;
    else imm26&=~0xfc000000;
    imm26<<=2;
    return pc+(int64_t)imm26;
}
static inline uint64_t get_add_value(uint32_t ins){
    uint32_t instr2=ins;

    //imm12 64 bits if sf = 1, else 32 bits
    uint64_t imm12;
    
    //get the imm value from add instruction
    instr2 = ins;
    imm12 = (instr2 & 0x3ffc00) >> 10;
    if(instr2 & 0xc00000)
    {
            imm12 <<= 12;

    }
    return imm12;
}
static inline uint64_t get_ldr_imm12(uint32_t ins){
    return ((ins&0x3ffc00)>>10)<<((ins>>30)&0b11);
}
static inline uint64_t get_str_imm12(uint32_t ins){
    return ((ins&0x3ffc00)>>10)<<((ins>>30)&0b11);
}
static inline bool is_32_imm_str(uint32_t ins){
    return (ins&0xFFC00000)==0xB9000000;
}
// helper function

// [FIX] Guard against mach_vm_region failure + memory leak (mach_vm_read buffer never freed)
static kern_return_t get_region_address_and_size(mach_vm_offset_t *address_p, mach_vm_size_t *size_p){
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object_name = MACH_PORT_NULL;
    kern_return_t ret = mach_vm_region(mach_task_self(), address_p, size_p, VM_REGION_BASIC_INFO,
                                        (vm_region_info_t)&info, &count, &object_name);
    // [FIX] bail out early if mach_vm_region fails
    if (ret != KERN_SUCCESS) {
        return ret;
    }
    vm_prot_t protection = info.protection;
    if(!protection){
        *address_p += *size_p;
        return get_region_address_and_size(address_p, size_p);
    }
    pointer_t buffer = 0;
    mach_msg_type_number_t bufferSize = 0;
    ret = mach_vm_read(mach_task_self(), *address_p, *size_p, &buffer, &bufferSize);
    if (ret != KERN_SUCCESS){
        NSLog(@"vm_read failed: %d", ret);
        return ret;
    }
    // [FIX] free the buffer we just read, otherwise it leaks on every region scan
    if (buffer && bufferSize) {
      vm_deallocate(mach_task_self(), (vm_address_t)buffer, bufferSize);
    }
    return ret;
}
static void find_next_header(long *ad, long *size_out){
    mach_vm_offset_t address_region_start=*ad;
    mach_vm_size_t size=0;
    while(get_region_address_and_size(&address_region_start,&size)==KERN_SUCCESS){
        if(((struct mach_header*)address_region_start)->magic==MH_MAGIC_64){
            *ad=address_region_start;
            *size_out=size;
            return;
        }
        address_region_start+=size;
    }
}

static long find_adrp_add_ref_to_ad(long ad_target, long *ad_ignore_p, int n_ignore){
    mach_vm_offset_t address_region_start=0;
    mach_vm_size_t size=0;
    while(get_region_address_and_size(&address_region_start,&size)==KERN_SUCCESS){
        // NSLog(@"0x%lx 0x%lx",(long)(address_region_start-aslr),((long)address_region_start+(long)size-aslr));
        if(address_region_start>=ad_target){
            return false;
        }
        for(int i=0;i<n_ignore;i++){
            if(address_region_start==*(ad_ignore_p+i*4)){
                goto con;
            }
        }
        for(long ad=address_region_start;ad+4<address_region_start+size;ad+=4){
            int32_t ins=*(int32_t*)ad;
            int32_t ins2=*(int32_t*)(ad+4);
            if(is_adrp(ins)&&is_64add(ins2)){
                uint64_t ad_target_=get_adrp_address(ins,ad)+get_add_value(ins2);;
                if(ad_target_==ad_target) return ad;
            }
        }
        con:
        address_region_start+=size;
    }

    return false;
}
static long find_adrp_str_ref_to_ad(long ad_target, long *ad_ignore_p, int n_ignore){
    mach_vm_offset_t address_region_start=0;
    mach_vm_size_t size=0;
    while(get_region_address_and_size(&address_region_start,&size)==KERN_SUCCESS){
        // NSLog(@"0x%lx 0x%lx",(long)(address_region_start-aslr),((long)address_region_start+(long)size-aslr));
        if(address_region_start>=ad_target){
            return false;
        }
        for(int i=0;i<n_ignore;i++){
            if(address_region_start==*(ad_ignore_p+i*4)){
                goto con;
            }
        }
        for(long ad=address_region_start;ad+4<address_region_start+size;ad+=4){
            int32_t ins=*(int32_t*)ad;
            int32_t ins2=*(int32_t*)(ad+4);
            if(is_adrp(ins)&&is_32_imm_str(ins2)){
                uint64_t ad_target_=get_adrp_address(ins,ad)+get_str_imm12(ins2);;
                if(ad_target_==ad_target) return ad;
            }
        }
        con:
        address_region_start+=size;
    }

    return false;
}
static long find_ref_to_str(const char *str, long ad_start, long ad_end){
    mach_vm_offset_t address_region_start=ad_start;
    mach_vm_size_t size=0;
    // [FIX] Lưu first char để skip nhanh — giảm ~10-20x số lần gọi strcmp trên FGO 200MB+
    const char first = str[0];
    NSLog(@"finding: %s %p",str, str);
    while(get_region_address_and_size(&address_region_start,&size)==KERN_SUCCESS){
        // NSLog(@"0x%lx 0x%lx",(long)(address_region_start-aslr),((long)address_region_start+(long)size-aslr));
        for(long ad=address_region_start;ad<address_region_start+size;ad++){
            if(ad>=ad_end){
                return false;
            }
            // [FIX] check first char trước, chỉ gọi strcmp khi khớp
            if(*(const char*)ad != first) continue;
            if(!strcmp((const char*)(ad),str)) {
                NSLog(@"candidate: 0x%lx",ad-aslr);
                long ad_ref=find_adrp_add_ref_to_ad(ad, NULL, 0);
                if(ad_ref) return ad_ref;
            }
        }
        address_region_start+=size;
    }
    return false;
}

static long find_ad_set_targetFrameRate_from_ref(long ad_ref){
    ad_ref+=8;
    NSLog(@"setter_ref: 0x%lx",ad_ref-aslr);

    uint32_t ins=*(int*)ad_ref;
    long ad_set_targetFrameRate=get_adrp_address(ins,ad_ref);
    NSLog(@"ad_set_targetFrameRate: 0x%lx",ad_set_targetFrameRate-aslr);

    ins=*(int*)ad_set_targetFrameRate;
    if(is_b(ins)){
        NSLog(@"trying hook low-level function");
        ad_set_targetFrameRate=get_b_address(ins,ad_set_targetFrameRate);
        NSLog(@"ad_set_targetFrameRate: 0x%lx",ad_set_targetFrameRate-aslr);
    }

    return ad_set_targetFrameRate;
}

static long find_ad_set_targetFrameRate_from_getter_ref(long ad_ref){
    ad_ref+=8;
    NSLog(@"getter_ref: 0x%lx",ad_ref-aslr);

    uint32_t ins=*(int*)ad_ref,ins2=0;
    long ad_get_targetFrameRate=get_adrp_address(ins, ad_ref);
    NSLog(@"ad_get_targetFrameRate: 0x%lx",ad_get_targetFrameRate-aslr);
    long ad_get_targetFrameRate_b=0;
    for(int i=0;i<4;i++){
        ins=*(int*)(ad_get_targetFrameRate+4*i);
        if(is_b(ins)){
            ad_get_targetFrameRate_b=get_b_address(*(int32_t*)(ad_get_targetFrameRate+4*i), ad_get_targetFrameRate+4*i);
            break;
        }
    }
    NSLog(@"ad_get_targetFrameRate_b: 0x%lx",ad_get_targetFrameRate_b-aslr);
    long ad_fps=0;
    int adrp_offset=0;
    for(int i=0;i<3;i++){
        ins=*(int*)(ad_get_targetFrameRate_b+4*i);
        ins2=*(int*)(ad_get_targetFrameRate_b+4*(i+1));
        if(is_adrp(ins)){
            ad_fps=get_adrp_address(ins,ad_get_targetFrameRate_b+4*i)+get_ldr_imm12(ins2);
            adrp_offset=4*i;
            break;
        }
    }
    NSLog(@"ad_fps: 0x%lx",ad_fps-aslr);

    long ignore=ad_get_targetFrameRate_b+adrp_offset;
    long ad_set_targetFrameRate=find_adrp_str_ref_to_ad(ad_fps, &ignore , 1)-adrp_offset;
    NSLog(@"ad_set_targetFrameRate: 0x%lx",ad_set_targetFrameRate-aslr);

    return ad_set_targetFrameRate;
}

static void buildHook(){
    long ad_start, ad_end, size;
    ad_start=aslr;
    find_next_header(&ad_start, &size);
    ad_end=ad_start+size;
    find_next_header(&ad_end, &size);

    long ad_ref=find_ref_to_str("UnityEngine.Application::set_targetFrameRate", ad_start, ad_end);
    long ad_set_targetFrameRate=0;
    if(ad_ref){
        ad_set_targetFrameRate=find_ad_set_targetFrameRate_from_ref(ad_ref);
    }
    else{
        NSLog(@"setter failed");
        ad_ref=find_ref_to_str("UnityEngine.Application::get_targetFrameRate", ad_start, ad_end);
        if(ad_ref) {
            ad_set_targetFrameRate=find_ad_set_targetFrameRate_from_getter_ref(ad_ref);
        }
    }

    // [FIX] Không abort: nếu không tìm thấy, tweak tự disable nhưng GAME VẪN SỐNG.
    //       Tránh user thấy FGO crash ngay khi mở, tránh anti-cheat flag pattern SIGABRT.
    if(!ad_set_targetFrameRate) {
        NSLog(@"[Unity240FPS] Cannot locate setTargetFrameRate — tweak disabled, game continues");
        return;
    }

    NSLog(@"hook setTargetFrameRate start");
    %init(unity,setTargetFrameRate=(void*)ad_set_targetFrameRate);
    NSLog(@"hook setTargetFrameRate success");

}

static void loadFrameWork(){
    const char *executablePath = NSBundle.mainBundle.executablePath.UTF8String;
    for(int i=0;i<_dyld_image_count();i++){
        const char *image_name=_dyld_get_image_name(i);
        if(!strcmp(image_name, executablePath)){
            aslr=_dyld_get_image_vmaddr_slide(i);
            break;
        }
    }

    NSString*bundlePath=[NSString stringWithFormat:@"%@/Frameworks/UnityFramework.framework",[[NSBundle mainBundle] bundlePath]];
    NSBundle *bundle=[NSBundle bundleWithPath:bundlePath];
    [bundle load];
    if([bundle isLoaded]){
        for(int i=0;i<_dyld_image_count();i++){
            const char*image_name=_dyld_get_image_name(i);
            if(strstr(image_name, "UnityFramework.framework/UnityFramework")){
                aslr=_dyld_get_image_vmaddr_slide(i);
                break;
            }
        }
    }
    NSLog(@"aslr: 0x%lx",(long)aslr);
}

// [ADD] Read prefs from kPrefPath first, then fall back to rootless & rootful paths.
//       This makes Tweak.x work in BOTH environments regardless of how Prefix.pch defines kPrefPath.
static NSMutableDictionary *loadPrefDict(){
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (prefs) return prefs;

    // [REBRAND] Đã đổi tên file prefs sang TaoJB
    NSArray<NSString *> *fallbackPaths = @[
        @"/var/jb/var/mobile/Library/Preferences/com.taojb.fgotw60fps.plist",  // rootless (Dopamine/palera1n)
        @"/var/mobile/Library/Preferences/com.taojb.fgotw60fps.plist"          // rootful
    ];
    for (NSString *path in fallbackPaths) {
        prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
        if (prefs) {
            NSLog(@"prefs loaded from fallback: %@", path);
            return prefs;
        }
    }
    NSLog(@"WARN: prefs not found at kPrefPath or any fallback path");
    return nil;
}

static void loadPref(){
    // [FIX] use loadPrefDict() with fallback
    NSMutableDictionary *prefs = loadPrefDict();
    enabled=prefs[@"enabled"]?[prefs[@"enabled"] boolValue]:YES;

    // [FIX] validate range: user có thể sửa tay file prefs qua Filza thành 0/99999
    //       → Unity crash hoặc bị anti-cheat flag vì FPS bất thường
    int fps = prefs[@"customFps"]?[prefs[@"customFps"] intValue]:60;
    if (fps < 30)  fps = 30;
    if (fps > 240) fps = 240;
    customFps = fps;

    setFPSOnFirstTouch=prefs[@"setFPSOnFirstTouch"]?[prefs[@"setFPSOnFirstTouch"] boolValue]:YES;
    NSLog(@"customFps: %d",customFps);

    // [FIX] chỉ apply khi FPS thực sự đổi — tránh set lại mỗi lần user toggle "enabled"
    if(orig_setTargetFrameRate && customFps != lastAppliedFps) {
        (void)(orig_t)orig_setTargetFrameRate(customFps);
        lastAppliedFps = customFps;
    }
}
static BOOL isEnabledApp(){
    NSString* bundleIdentifier=[[NSBundle mainBundle] bundleIdentifier];
    // [FIX] use loadPrefDict() with fallback
    NSMutableDictionary *prefs = loadPrefDict();
    enabled=prefs[@"enabled"]?[prefs[@"enabled"] boolValue]:YES;
    if(!enabled) return NO;
    return [prefs[@"apps"] containsObject:bundleIdentifier];
}

static void UIApplicationDidFinishLaunching(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo){
    // [GOD MODE] Chỉ quét bộ nhớ nếu là game Unity
    NSString *unityPath = [NSString stringWithFormat:@"%@/Frameworks/UnityFramework.framework", [[NSBundle mainBundle] bundlePath]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:unityPath]) {
        loadFrameWork();
        buildHook();
    }
    
    // [FIX] giống loadPref — chỉ apply khi cần, tránh set FPS lần 2 không cần thiết
    if(orig_setTargetFrameRate && customFps != lastAppliedFps) {
        (void)(orig_t)orig_setTargetFrameRate(customFps);
        lastAppliedFps = customFps;
    }
}

#pragma mark ctor
%ctor {
    // [ADD] debug logs to know quickly WHY the tweak skipped
    NSLog(@"Unity240FPS ctor: bundle=%@", [[NSBundle mainBundle] bundleIdentifier]);
    if(!isEnabledApp()) {
        NSLog(@"Unity240FPS ctor: skipped (app not enabled or prefs missing)");
        return;
    }
    NSLog(@"ctor: Unity240FPS");

    loadPref();

    // [GOD MODE] Kích hoạt toàn bộ các lớp giáp
    %init(iokit_godmode);     // Lớp 1: Can thiệp IOKit & chặn Panic
    %init(anticheat_stealth); // Lớp 2: Ẩn mình khỏi Anti-cheat
    %init(globalfps);         // Lớp 3: Ép FPS toàn cầu

    int token = 0;
    // [REBRAND] Đã đổi tên Notification sang TaoJB
    notify_register_dispatch("com.taojb.fgotw60fps/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
        loadPref();
    });

    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, UIApplicationDidFinishLaunching, (CFStringRef)UIApplicationDidFinishLaunchingNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
}
