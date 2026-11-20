#ifndef VolumeKeyRouting_h
#define VolumeKeyRouting_h

#include <stdbool.h>

typedef enum {
    VCVolumeKeyExistingBehavior,
    VCVolumeKeyPassThrough,
    VCVolumeKeyWithCommand
} VCVolumeKeyRoute;

typedef struct {
    bool pressed;
    VCVolumeKeyRoute route;
} VCVolumeKeyPress;

// Keep each press with its original recipient, including repeats and release.
// In particular, releasing Command must not send an app-owned key-up to macOS:
// the app needs that release to stop its volume ramp. Separate state per key
// also keeps overlapping volume and mute presses from stealing each other's up.
static inline VCVolumeKeyRoute VCVolumeKeyRouteEvent(VCVolumeKeyPress *press,
                                                    bool keyDown,
                                                    bool isRepeat,
                                                    bool passWithoutCommand,
                                                    bool commandHeld,
                                                    bool optionHeld)
{
    if (!press->pressed || (keyDown && !isRepeat)) {
        press->route = VCVolumeKeyExistingBehavior;
        if (passWithoutCommand) {
            press->route = (optionHeld || !commandHeld)
                ? VCVolumeKeyPassThrough : VCVolumeKeyWithCommand;
        }
    }

    press->pressed = keyDown;
    return press->route;
}

#endif
