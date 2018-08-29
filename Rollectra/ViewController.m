//
//  ViewController.m
//  Rollectra
//
//  Created by pwn20wnd on 8/29/18.
//  Copyright © 2018 Pwn20wnd. All rights reserved.
//

#import "ViewController.h"
#include "common.h"
#include "offsets.h"
#include "sploit.h"
#include "kmem.h"
#include "QiLin.h"
#include "iokit.h"
#include <sys/snapshot.h>
#include <dlfcn.h>

@interface ViewController ()

@end

@implementation ViewController

#define IMAGE_OFFSET 0x2000
#define MACHO_HEADER_MAGIC 0xfeedfacf
#define MAX_KASLR_SLIDE 0x21000000
#define KERNEL_SEARCH_ADDRESS_IOS10 0xfffffff007004000

#define ptrSize sizeof(uintptr_t)

static vm_address_t get_kernel_base(mach_port_t tfp0) {
    uint64_t addr = 0;
    addr = KERNEL_SEARCH_ADDRESS_IOS10+MAX_KASLR_SLIDE;
    
    while (1) {
        char *buf;
        mach_msg_type_number_t sz = 0;
        kern_return_t ret = vm_read(tfp0, addr, 0x200, (vm_offset_t*)&buf, &sz);
        
        if (ret) {
            goto next;
        }
        
        if (*((uint32_t *)buf) == MACHO_HEADER_MAGIC) {
            int ret = vm_read(tfp0, addr, 0x1000, (vm_offset_t*)&buf, &sz);
            if (ret != KERN_SUCCESS) {
                printf("Failed vm_read %i\n", ret);
                goto next;
            }
            
            for (uintptr_t i=addr; i < (addr+0x2000); i+=(ptrSize)) {
                mach_msg_type_number_t sz;
                int ret = vm_read(tfp0, i, 0x120, (vm_offset_t*)&buf, &sz);
                
                if (ret != KERN_SUCCESS) {
                    printf("Failed vm_read %i\n", ret);
                    exit(-1);
                }
                if (!strcmp(buf, "__text") && !strcmp(buf+0x10, "__PRELINK_TEXT")) {
                    return addr;
                }
            }
        }
        
    next:
        addr -= 0x200000;
    }
}

int sha1_to_str(const unsigned char *hash, int hashlen, char *buf, size_t buflen)
{
    if (buflen < (hashlen*2+1)) {
        return -1;
    }
    
    int i;
    for (i=0; i<hashlen; i++) {
        sprintf(buf+i*2, "%02X", hash[i]);
    }
    buf[i*2] = 0;
    return ERR_SUCCESS;
}

char *copyBootHash(void)
{
    io_registry_entry_t chosen = IORegistryEntryFromPath(kIOMasterPortDefault, "IODeviceTree:/chosen");
    
    if (!MACH_PORT_VALID(chosen)) {
        printf("Unable to get IODeviceTree:/chosen port\n");
        return NULL;
    }
    
    CFDataRef hash = (CFDataRef)IORegistryEntryCreateCFProperty(chosen, CFSTR("boot-manifest-hash"), kCFAllocatorDefault, 0);
    
    IOObjectRelease(chosen);
    
    if (hash == nil) {
        fprintf(stderr, "Unable to read boot-manifest-hash\n");
        return NULL;
    }
    
    if (CFGetTypeID(hash) != CFDataGetTypeID()) {
        fprintf(stderr, "Error hash is not data type\n");
        CFRelease(hash);
        return NULL;
    }
    
    // Make a hex string out of the hash
    
    CFIndex length = CFDataGetLength(hash) * 2 + 1;
    char *manifestHash = (char*)calloc(length, sizeof(char));
    
    int ret = sha1_to_str(CFDataGetBytePtr(hash), (int)CFDataGetLength(hash), manifestHash, length);
    
    CFRelease(hash);
    
    if (ret != ERR_SUCCESS) {
        printf("Unable to generate bootHash string\n");
        free(manifestHash);
        return NULL;
    }
    
    return manifestHash;
}

#define APPLESNAP "com.apple.os.update-"

const char *systemSnapshot(char *bootHash) {
    if (!bootHash) {
        return NULL;
    }
    return [[NSString stringWithFormat:@APPLESNAP @"%s", bootHash] UTF8String];
}

#ifdef WANT_CYDIA
void unjailbreak(int shouldEraseUserData) {
#else    /* !WANT_CYDIA */
void unjailbreak(mach_port_t tfp0, uint64_t kernel_base, int shouldEraseUserData) {
#endif    /* !WANT_CYDIA */
    // Initialize variables.
    int rv = 0;
#ifndef WANT_CYDIA
    uint64_t myOriginalCredAddr = 0;
#endif    /* WANT_CYDIA */
    NSMutableDictionary *md = nil;
    mach_port_t SBServerPort = MACH_PORT_NULL;
    
#ifndef WANT_CYDIA
    // Initialize offsets.
    LOG("%@", NSLocalizedString(@"Initializing offsets...", nil));
    offsets_init();
#endif    /* WANT_CYDIA */
    
#ifndef WANT_CYDIA
    // Initialize QiLin.
    LOG("%@", NSLocalizedString(@"Initializing QiLin...", nil));
    rv = initQiLin(tfp0, kernel_base);
    LOG("rv: " "%d" "\n", rv);
    _assert(rv == 0);
    LOG("%@", NSLocalizedString(@"Successfully initialized QiLin.", nil));
#endif    /* WANT_CYDIA */
    
#ifndef WANT_CYDIA
    // Rootify myself.
    LOG("%@", NSLocalizedString(@"Rootifying myself...", nil));
    rv = rootifyMe();
    LOG("rv: " "%d" "\n", rv);
    _assert(rv == 0);
    LOG("%@", NSLocalizedString(@"Successfully rootified myself.", nil));
#endif    /* WANT_CYDIA */
    
#ifndef WANT_CYDIA
    // Escape Sandbox.
    LOG("%@", NSLocalizedString(@"Escaping Sandbox...", nil));
    myOriginalCredAddr = ShaiHuludMe(0);
    LOG("myOriginalCredAddr: " ADDR "\n", myOriginalCredAddr);
    LOG("%@", NSLocalizedString(@"Successfully escaped Sandbox.", nil));
#endif    /* WANT_CYDIA */
    
#ifndef WANT_CYDIA
    // Write a test file.
    
    LOG("%@", NSLocalizedString(@"Writing a test file...", nil));
    if (!access("/var/mobile/test.txt", F_OK)) {
        rv = unlink("/var/mobile/test.txt");
        LOG("rv: " "%d" "\n", rv);
        _assert(rv == 0);
    }
    rv = fclose(fopen("/var/mobile/test.txt", "w+"));
    LOG("rv: " "%d" "\n", rv);
    _assert(rv == 0);
    rv = unlink("/var/mobile/test.txt");
    LOG("rv: " "%d" "\n", rv);
    _assert(rv == 0);
    LOG("%@", NSLocalizedString(@"Successfully wrote a test file.", nil));
#endif    /* WANT_CYDIA */
    
#ifndef WANT_CYDIA
    // Borrow entitlements from sysdiagnose.
    
    LOG("%@", NSLocalizedString(@"Borrowing entitlements from sysdiagnose...", nil));
    borrowEntitlementsFromDonor("/usr/bin/sysdiagnose", "-u");
    LOG("%@", NSLocalizedString(@"Successfully borrowed entitlements from sysdiagnose.", nil));
    
    // We now have Task_for_pid.
#endif    /* WANT_CYDIA */
    
#ifndef WANT_CYDIA
    // Entitle myself.
    LOG("%@", NSLocalizedString(@"Entitling myself...", nil));
    rv = entitleMe("\t<key>platform-application</key>\n"
                   "\t<true/>\n"
                   "\t<key>com.apple.private.vfs.snapshot</key>\n"
                   "\t<true/>\n"
                   "\t<key>com.apple.springboard.wipedevice</key>\n"
                   "\t<true/>");
    LOG("rv: " "%d" "\n", rv);
    _assert(rv == 0);
    LOG("%@", NSLocalizedString(@"Successfully entitled myself.", nil));
#endif    /* WANT_CYDIA */
    
    // Revert to the system snapshot.
    LOG("%@", NSLocalizedString(@"Reverting to the system snapshot...", nil));
    rv = fs_snapshot_rename(open("/", O_RDONLY, 0), "orig-fs", systemSnapshot(copyBootHash()), 0);
    LOG("rv: " "%d" "\n", rv);
    _assert(rv == 0);
    LOG("%@", NSLocalizedString(@"Successfully put the system snapshot in place, it should revert on the next mount.", nil));
    
    md = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"];
    _assert(md);
    md[@"SBShowNonDefaultSystemApps"] = @(NO);
    [md writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
#ifndef WANT_CYDIA
    rv = kill(findPidOfProcess("cfprefsd"), SIGKILL);
    LOG("rv: " "%d" "\n", rv);
    _assert(rv == 0);
#else     /* WANT_CYDIA */
    rv = execCommandAndWait("/usr/bin/killall", "-9", "cfprefsd", NULL, NULL, NULL);
    LOG("rv: " "%d" "\n", rv);
    _assert(rv == 0);
#endif    /* WANT_CYDIA */
    
    if (shouldEraseUserData) {
        // Get SBServerPort.
        LOG("%@", NSLocalizedString(@"Getting SBServerPort...", nil));
        extern mach_port_t SBSSpringBoardServerPort(void);
        SBServerPort = SBSSpringBoardServerPort();
        LOG("SBServerPort: " "%x" "\n", SBServerPort);
        _assert(SBServerPort);
        LOG("%@", NSLocalizedString(@"Successfully got SBServerPort.", nil));
        
        // Erase user data.
        LOG("%@", NSLocalizedString(@"Erasing user data...", nil));
        extern int SBDataReset(mach_port_t SpringBoardServerPort, int mode);
        rv = SBDataReset(SBServerPort, 5);
        LOG("rv: " "%d" "\n", rv);
        _assert(rv == 0);
        LOG("%@", NSLocalizedString(@"Successfully erased user data.", nil));
    } else {
        // Reboot.
        LOG("%@", NSLocalizedString(@"Rebooting...", nil));
        rv = reboot(0x400);
        LOG("rv: " "%d" "\n", rv);
        _assert(rv == 0);
        LOG("%@", NSLocalizedString(@"Successfully rebooted.", nil));
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
#ifndef WANT_CYDIA
    // Initialize kernel exploit.
    LOG("%@", NSLocalizedString(@"Initializing kernel exploit...", nil));
    vfs_sploit();
#endif    /* WANT_CYDIA */
    
#ifndef WANT_CYDIA
    // Validate TFP0.
    LOG("%@", NSLocalizedString(@"Validating TFP0...", nil));
    _assert(MACH_PORT_VALID(tfp0));
    LOG("%@", NSLocalizedString(@"Successfully validated TFP0.", nil));
#endif    /* WANT_CYDIA */
    
#ifdef WANT_CYDIA
    unjailbreak(true);
#else    /* !WANT_CYDIA */
    unjailbreak(tfp0, (uint64_t)get_kernel_base(tfp0), true);
#endif    /* !WANT_CYDIA */
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end