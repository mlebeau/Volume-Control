#include "../Sources/Controllers/VolumeKeyRouting.h"

#include <assert.h>
#include <stdio.h>

static void testOrdinaryPressStaysNative(void)
{
    VCVolumeKeyPress press = {0};
    assert(VCVolumeKeyRouteEvent(&press, true, false, true, false, false) == VCVolumeKeyPassThrough);
    // Command pressed, Option pressed, or the preference turned off mid-hold
    // must not send repeats or the release to the app.
    assert(VCVolumeKeyRouteEvent(&press, true, true, true, true, false) == VCVolumeKeyPassThrough);
    assert(VCVolumeKeyRouteEvent(&press, true, true, false, true, true) == VCVolumeKeyPassThrough);
    assert(VCVolumeKeyRouteEvent(&press, false, false, false, true, false) == VCVolumeKeyPassThrough);
    assert(!press.pressed);
    // The next press uses the current preference and modifiers.
    assert(VCVolumeKeyRouteEvent(&press, true, false, true, true, false) == VCVolumeKeyWithCommand);
}

static void testCommandPressKeepsItsRelease(void)
{
    VCVolumeKeyPress press = {0};
    assert(VCVolumeKeyRouteEvent(&press, true, false, true, true, false) == VCVolumeKeyWithCommand);
    // Releasing Command must not strand the app's volume ramp or mute state.
    assert(VCVolumeKeyRouteEvent(&press, true, true, true, false, false) == VCVolumeKeyWithCommand);
    assert(VCVolumeKeyRouteEvent(&press, true, true, false, false, true) == VCVolumeKeyWithCommand);
    assert(VCVolumeKeyRouteEvent(&press, false, false, false, false, true) == VCVolumeKeyWithCommand);
    assert(!press.pressed);
    assert(VCVolumeKeyRouteEvent(&press, true, false, false, false, false) == VCVolumeKeyExistingBehavior);
}

static void testOptionShortcuts(void)
{
    VCVolumeKeyPress press = {0};
    // Option has precedence over Command, as in the existing event tap.
    assert(VCVolumeKeyRouteEvent(&press, true, false, true, true, true) == VCVolumeKeyPassThrough);
    assert(VCVolumeKeyRouteEvent(&press, true, true, true, true, false) == VCVolumeKeyPassThrough);
    assert(VCVolumeKeyRouteEvent(&press, false, false, true, true, false) == VCVolumeKeyPassThrough);
    assert(VCVolumeKeyRouteEvent(&press, true, false, true, false, true) == VCVolumeKeyPassThrough);
    assert(VCVolumeKeyRouteEvent(&press, false, false, true, false, false) == VCVolumeKeyPassThrough);
}

static void testDisabledPreferenceLeavesExistingHandling(void)
{
    for (int command = 0; command <= 1; command++) {
        for (int option = 0; option <= 1; option++) {
            VCVolumeKeyPress press = {0};
            assert(VCVolumeKeyRouteEvent(&press, true, false, false, command, option) == VCVolumeKeyExistingBehavior);
            // Enabling during a press only changes the next press.
            assert(VCVolumeKeyRouteEvent(&press, true, true, true, !command, !option) == VCVolumeKeyExistingBehavior);
            assert(VCVolumeKeyRouteEvent(&press, false, false, true, !command, !option) == VCVolumeKeyExistingBehavior);
        }
    }
}

static void testOverlappingKeys(void)
{
    VCVolumeKeyPress up = {0}, down = {0}, mute = {0};
    assert(VCVolumeKeyRouteEvent(&up, true, false, true, false, false) == VCVolumeKeyPassThrough);
    assert(VCVolumeKeyRouteEvent(&down, true, false, true, true, false) == VCVolumeKeyWithCommand);
    assert(VCVolumeKeyRouteEvent(&mute, true, false, true, false, false) == VCVolumeKeyPassThrough);
    assert(VCVolumeKeyRouteEvent(&mute, false, false, true, true, false) == VCVolumeKeyPassThrough);
    assert(VCVolumeKeyRouteEvent(&up, true, true, true, true, false) == VCVolumeKeyPassThrough);
    assert(VCVolumeKeyRouteEvent(&down, false, false, true, false, false) == VCVolumeKeyWithCommand);
    assert(VCVolumeKeyRouteEvent(&up, false, false, true, true, false) == VCVolumeKeyPassThrough);
    assert(!up.pressed && !down.pressed && !mute.pressed);
}

static void testMissingEvents(void)
{
    VCVolumeKeyPress press = {0};
    // If the tap starts during a hold, ordinary repeats/releases still pass.
    assert(VCVolumeKeyRouteEvent(&press, true, true, true, false, false) == VCVolumeKeyPassThrough);
    assert(VCVolumeKeyRouteEvent(&press, false, false, true, true, false) == VCVolumeKeyPassThrough);
    assert(VCVolumeKeyRouteEvent(&press, false, false, true, false, false) == VCVolumeKeyPassThrough);
    // A fresh key-down replaces stale state after a missed key-up.
    assert(VCVolumeKeyRouteEvent(&press, true, false, true, true, false) == VCVolumeKeyWithCommand);
    assert(VCVolumeKeyRouteEvent(&press, true, false, true, false, false) == VCVolumeKeyPassThrough);
    assert(VCVolumeKeyRouteEvent(&press, false, false, true, false, false) == VCVolumeKeyPassThrough);
}

int main(void)
{
    testOrdinaryPressStaysNative();
    testCommandPressKeepsItsRelease();
    testOptionShortcuts();
    testDisabledPreferenceLeavesExistingHandling();
    testOverlappingKeys();
    testMissingEvents();
    puts("Volume key routing: all tests passed");
    return 0;
}
