# Testing native volume key passthrough

The routing tests use the same C header as the event tap. Run from the repository root on macOS or Linux:

```sh
cc -std=c11 -Wall -Wextra -Werror -pedantic Tests/VolumeKeyRoutingTests.c -o /tmp/volume-key-routing-tests
/tmp/volume-key-routing-tests
```

These tests cover key ownership across repeats, modifier changes, preference changes, overlapping keys, and missing events. They do not replace a macOS build or testing real keyboard events.

On macOS, after a Release build with `xcodebuild -derivedDataPath /tmp/VolumeControlDerived`, run:

```sh
bash bin/test_volume_events.sh /tmp/VolumeControlDerived
```

The native tests link against the app's compiled object files and call its actual event callback with synthetic volume events. They verify original-event passthrough, asynchronous Command handling, release delivery, Option shortcuts, and preference storage/checkmarks. They do not install a global event tap, change system or Spotify volume, or verify the visible HUD.

## Build and test on macOS

Build the app using [Compile.md](Compile.md). Quit any other copy of Volume Control before launching the build. For a personal build, use a distinct bundle identifier and turn off **Automatic weekly updates** so an upstream release cannot replace your changes. Grant Accessibility and Spotify Automation permission to the new build if prompted.

Select Spotify in the **Music player** section and deselect other players if you want only Spotify to be controlled. Enable **Invert behavior of ⌘ modifier** and **Pass volume keys without ⌘ to macOS**. Leave **Lock system to player volume** off to keep Spotify volume independent of system volume.

Compare the native cases below with Volume Control quit, using the same output device and macOS sound-feedback preference. Start at a low listening volume.

| Action | Expected result |
| --- | --- |
| Press volume up, down, and mute without ⌘ | macOS changes system volume and presents its native feedback; Spotify's own volume is unchanged. |
| Hold ordinary volume up/down, then press ⌘ before releasing the volume key | Repeats and release stay with macOS. No app volume change. |
| While Spotify plays, press ⌘ + volume up/down/mute | Spotify changes; system volume does not. Volume Control shows its usual player HUD if enabled. |
| Hold ⌘ + volume up/down, release ⌘ first, then release the volume key | Spotify continues to receive the held press and stops changing on key release; macOS receives no stray repeat or release. |
| Press ⌘ + mute, release ⌘ first, then release mute and press another volume key | No stuck mute state; the next ordinary key goes to macOS. |
| Press Option + volume or Option + Shift + volume | Sound settings or native fine volume steps, respectively, as with Volume Control quit. |
| Press ordinary volume keys while Spotify is paused, quit, or unresponsive | Native system volume still works without waiting for Spotify. |
| Press ⌘ + volume while Spotify is paused or quit | Existing player-selection/system-fallback behavior is retained. This preference does not add control of paused players. |
| Turn the new preference off | Existing app/system behavior returns. |
| Quit/relaunch the app | The preference and checkmark persist; ordinary keys still use macOS when enabled. |
| Switch audio outputs, including an output without software volume control | Ordinary keys behave as they do with the app quit. Display control by Volume Control applies only to intercepted keys. |

If other utilities intercept volume keys, they can also affect what macOS receives. **Copy Diagnostics** includes the new preference; its last handled key entry excludes presses passed directly to macOS.
