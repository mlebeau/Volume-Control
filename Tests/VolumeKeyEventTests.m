#import "AppDelegate.h"
#import <IOKit/hidsystem/ev_keymap.h>

#include <assert.h>

extern CGEventRef event_tap_callback(CGEventTapProxy, CGEventType, CGEventRef, void *);

// Exercise the real event callback without installing a global keyboard tap or
// changing any volume. Only the asynchronous volume-operation recipient is a
// test double. The preference setter is the production implementation.
@interface RecordingAppDelegate : AppDelegate
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *received;
@end

@implementation RecordingAppDelegate
- (void)handleAsynchronouslyTappedEventWithKeyCode:(int)keyCode
                                          keyState:(BOOL)keyState
                                       keyIsRepeat:(BOOL)keyIsRepeat
                                       keyModifier:(CGEventFlags)keyModifier
                                  keyboardModifier:(CGEventFlags)keyboardModifier
                                       commandHeld:(BOOL)commandHeld
{
    [self.received addObject:@{@"key": @(keyCode), @"down": @(keyState),
                              @"repeat": @(keyIsRepeat), @"command": @(commandHeld)}];
}
@end

static void drainMainQueue(void)
{
    __block BOOL drained = NO;
    dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2];
    while (!drained && deadline.timeIntervalSinceNow > 0)
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, true);
    assert(drained);
}

static void sendKey(RecordingAppDelegate *app, int key, BOOL down, BOOL repeat,
                    NSEventModifierFlags modifiers, BOOL expectPassThrough)
{
    NSInteger data1 = (key << 16) | ((down ? 0xa : 0xb) << 8) | (repeat ? 1 : 0);
    NSEvent *event = [NSEvent otherEventWithType:NSEventTypeSystemDefined
                                      location:NSZeroPoint
                                 modifierFlags:modifiers | (down ? 0xa00 : 0xb00)
                                     timestamp:0 windowNumber:0 context:nil
                                       subtype:NX_SUBTYPE_AUX_CONTROL_BUTTONS
                                         data1:data1 data2:-1];
    CGEventRef original = event.CGEvent;
    CGEventFlags originalFlags = CGEventGetFlags(original);
    CGEventRef result = event_tap_callback(NULL, NX_SYSDEFINED, original, (__bridge void *)app);
    assert(result == (expectPassThrough ? original : NULL));
    assert(CGEventGetFlags(original) == originalFlags);
    NSEvent *after = [NSEvent eventWithCGEvent:original];
    assert(after.data1 == data1 && after.data2 == -1);
}

int main(void)
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        assert((CGEventSourceFlagsState(kCGEventSourceStateHIDSystemState) &
                (kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate)) == 0);

        RecordingAppDelegate *app = [RecordingAppDelegate new];
        app.received = [NSMutableArray array];
        NSString *suite = [@"VolumeControl.EventTests." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        [app setValue:defaults forKey:@"preferences"];
        NSMenu *menu = [NSMenu new];
        NSMenuItem *preference = [[NSMenuItem alloc] initWithTitle:@"Passthrough"
                                                          action:@selector(togglePassVolumeKeysWithoutCommand:)
                                                   keyEquivalent:@""];
        preference.tag = 12;
        [menu addItem:preference];
        app.statusMenu = menu;

        [app setPassVolumeKeysWithoutCommand:YES];
        assert([defaults boolForKey:@"PassVolumeKeysWithoutCommand"]);
        assert(preference.state == NSControlStateValueOn);

        const int keys[] = {NX_KEYTYPE_SOUND_UP, NX_KEYTYPE_SOUND_DOWN, NX_KEYTYPE_MUTE};
        for (unsigned i = 0; i < sizeof(keys) / sizeof(keys[0]); i++) {
            // Native events remain intact, with no asynchronous volume work.
            sendKey(app, keys[i], YES, NO, 0, YES);
            sendKey(app, keys[i], YES, YES, NSEventModifierFlagCommand, YES);
            sendKey(app, keys[i], NO, NO, NSEventModifierFlagCommand, YES);
        }
        drainMainQueue();
        assert(app.received.count == 0);

        for (unsigned i = 0; i < sizeof(keys) / sizeof(keys[0]); i++) {
            // Releasing Command first must still deliver repeats and key-up
            // with the app's original Command routing.
            [app.received removeAllObjects];
            sendKey(app, keys[i], YES, NO, NSEventModifierFlagCommand, NO);
            sendKey(app, keys[i], YES, YES, 0, NO);
            sendKey(app, keys[i], NO, NO, 0, NO);
            drainMainQueue();
            assert(app.received.count == 3);
            for (NSDictionary *received in app.received) {
                assert([received[@"key"] intValue] == keys[i]);
                assert([received[@"command"] boolValue]);
            }
            assert([app.received[0][@"down"] boolValue]);
            assert([app.received[1][@"repeat"] boolValue]);
            assert(![app.received[2][@"down"] boolValue]);
        }

        [app.received removeAllObjects];
        // Option and Shift+Option keep the original modifier flags for macOS.
        sendKey(app, NX_KEYTYPE_SOUND_UP, YES, NO, NSEventModifierFlagOption, YES);
        sendKey(app, NX_KEYTYPE_SOUND_UP, NO, NO, 0, YES);
        NSEventModifierFlags fine = NSEventModifierFlagOption | NSEventModifierFlagShift;
        sendKey(app, NX_KEYTYPE_SOUND_DOWN, YES, NO, fine, YES);
        sendKey(app, NX_KEYTYPE_SOUND_DOWN, NO, NO, fine, YES);
        NSEventModifierFlags both = NSEventModifierFlagOption | NSEventModifierFlagCommand;
        sendKey(app, NX_KEYTYPE_MUTE, YES, NO, both, YES);
        sendKey(app, NX_KEYTYPE_MUTE, NO, NO, both, YES);
        sendKey(app, NX_KEYTYPE_BRIGHTNESS_UP, YES, NO, 0, YES);
        sendKey(app, NX_KEYTYPE_BRIGHTNESS_UP, NO, NO, 0, YES);
        drainMainQueue();
        assert(app.received.count == 0);

        // Turning the setting off restores the production interception path.
        [app togglePassVolumeKeysWithoutCommand:nil];
        assert(![defaults boolForKey:@"PassVolumeKeysWithoutCommand"]);
        assert(preference.state == NSControlStateValueOff);
        sendKey(app, NX_KEYTYPE_SOUND_UP, YES, NO, 0, NO);
        sendKey(app, NX_KEYTYPE_SOUND_UP, NO, NO, 0, NO);
        drainMainQueue();
        assert(app.received.count == 2);
        assert(![app.received[0][@"command"] boolValue]);

        [defaults removePersistentDomainForName:suite];
        puts("Native volume events: all tests passed");
    }
    return 0;
}
