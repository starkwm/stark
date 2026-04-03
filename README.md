# Stark

Power your window management with JavaScript.

## Overview

Stark is a macOS window manager that provides a JavaScript API for managing windows, applications, and spaces. It uses macOS Accessibility APIs to interact with the windowing system.

## Features

- **JavaScript Configuration**: Configure window management using JavaScript
- **Window Control**: Move, resize, minimize, maximize, and focus windows programmatically
- **Application Management**: Launch, hide, show, and switch between applications
- **Space Support**: Work with macOS Spaces (virtual desktops)
- **Keyboard Shortcuts**: Bind custom keyboard shortcuts to JavaScript functions
- **Event Callbacks**: Register JavaScript callbacks for system events

## Installation

The official way to install **Stark** is via [Homebrew](https://brew.sh).

```
brew install starkwm/formulae/stark
```

You can then launch **Stark**, grant it accessibility permissions, and allow keyboard monitoring/input monitoring so global shortcuts can be intercepted. Restart the app after granting permissions. If you would like **Stark** to run when you log in, you can enable the _Launch at login_ menu item.

There is also a _tip_ version of **Stark** available in the Homebrew tap.

```
brew install starkwm/formulae/stark@tip
```

This is an unstable build of **Stark**, built from the current tip of the [GitHub repository](https://github.com/starkwm/stark). It is _not_ updated nightly.

## Configuration

You configure **Stark** with a `stark.js` configuration file. This file can live in one of three locations.

- `~/.stark.js`
- `~/.config/stark/stark.js`
- `~/Library/Application Support/Stark/stark.js`

The first file found will be the configuration that is loaded.

```javascript
// ~/.stark.js

// Log a message when Stark starts
print("Stark is running!");

// Example: Move focused window to center of screen
Keymap.on("c", ["cmd", "shift"], () => {
  const window = Window.focused();
  if (window) {
    const screen = window.screen;
    const frame = screen.flippedFrame;
    const x = frame.x + (frame.width - window.size.width) / 2;
    const y = frame.y + (frame.height - window.size.height) / 2;
    window.setTopLeft({ x, y });
  }
});
```

## API Reference

### Window

The `Window` class provides methods for managing individual windows.

#### Static Methods

- `Window.all()` - Get all managed windows
- `Window.focused()` - Get the currently focused window

#### Properties

- `id` - Unique window identifier
- `application` - The application that owns this window
- `screen` - The screen containing this window
- `title` - Window title
- `frame` - Window frame rectangle `{x, y, width, height}`
- `topLeft` - Window position `{x, y}`
- `size` - Window size `{width, height}`
- `isStandard` - Whether this is a standard window
- `isMain` - Whether this is the main window
- `isFullscreen` - Whether in fullscreen mode
- `isMinimized` - Whether minimized

#### Methods

- `setFrame(frame)` - Set window frame
- `setTopLeft(point)` - Set window position
- `setSize(size)` - Set window size
- `setFullscreen(boolean)` - Toggle fullscreen
- `minimize()` - Minimize window
- `unminimize()` - Restore window
- `focus()` - Focus window and activate application
- `spaces()` - Get spaces containing this window

### Application

The `Application` class provides methods for managing applications.

#### Static Methods

- `Application.all()` - Get all running applications
- `Application.focused()` - Get the frontmost application

#### Properties

- `name` - Application name
- `processID` - Process identifier

#### Methods

- `activate()` - Activate the application
- `focus()` - Focus without activating all windows
- `show()` - Unhide the application
- `hide()` - Hide the application
- `windows()` - Get all windows for this application
- `terminate()` - Quit the application

### Space

The `Space` class provides methods for working with macOS Spaces.

#### Static Methods

- `Space.all()` - Get all spaces
- `Space.current()` - Get the current space

#### Properties

- `id` - Space identifier

### Screen

The `Screen` class wraps `NSScreen` and provides screen information.

#### Static Methods

- `Screen.all()` - Get all screens
- `Screen.main()` - Get the main screen

#### Properties

- `frame` - Screen frame in flipped coordinates
- `flippedFrame` - Screen frame with origin at top-left

### Keymap

The `Keymap` class allows binding keyboard shortcuts.

Global shortcuts are matched through a keyboard event tap. When a shortcut matches, Stark swallows the original key event so it is not delivered to the foreground app.
Supported modifier values are `cmd`, `ctrl`, `alt`, `shift`, and `fn`, plus `lcmd`, `rcmd`, `lctrl`, `rctrl`, `lalt`, `ralt`, `lshift`, and `rshift` for side-specific bindings. `meh` and `hyper` remain available as composites. Older aliases such as `option`, `opt`, `control`, and `command` are no longer supported.

#### Methods

- `Keymap.on(key, modifiers, callback)` - Bind a keyboard shortcut
- `Keymap.off(id)` - Unbind a keyboard shortcut by ID

```javascript
// Examples
Keymap.on("return", ["cmd", "shift"], () => {
  // Open Terminal
});

Keymap.on("h", ["cmd"], () => {
  const app = Application.focused();
  if (app) app.hide();
});
```

### Event

The `Event` class allows registering callbacks for system events.

#### Methods

- `Event.on(event, callback)` - Register a callback for an event
- `Event.off(event)` - Unregister all callbacks for an event

#### Events

| Event                      | Callback Argument |
| -------------------------- | ----------------- |
| `applicationLaunched`      | `Application`     |
| `applicationTerminated`    | `Application`     |
| `applicationFrontSwitched` | `Application`     |
| `windowCreated`            | `Window`          |
| `windowDestroyed`          | `Window`          |
| `windowFocused`            | `Window`          |
| `windowMoved`              | `Window`          |
| `windowResized`            | `Window`          |
| `windowMinimized`          | `Window`          |
| `windowDeminimized`        | `Window`          |
| `spaceChanged`             | `Space`           |

```javascript
// Log when windows are focused
Event.on("windowFocused", (window) => {
  print(`focused: ${window.title}`);
});

// React to space changes
Event.on("spaceChanged", (space) => {
  print(`switched to space ${space.id}`);
});
```

## Examples

### Center Window

```javascript
Keymap.on("c", ["cmd", "shift"], () => {
  const window = Window.focused();
  if (!window) return;

  const screen = window.screen;
  const frame = screen.flippedFrame;
  const windowFrame = window.frame;

  const x = frame.x + (frame.width - windowFrame.width) / 2;
  const y = frame.y + (frame.height - windowFrame.height) / 2;

  window.setTopLeft({ x, y });
});
```

### Tile Windows

```javascript
Keymap.on("t", ["cmd", "shift"], () => {
  const screen = Screen.main();
  const frame = screen.flippedFrame;
  const windows = Window.all().filter((w) => {
    return w.screen == screen && w.isStandard;
  });

  const count = windows.length;
  if (count === 0) return;

  const cols = Math.ceil(Math.sqrt(count));
  const rows = Math.ceil(count / cols);
  const width = frame.width / cols;
  const height = frame.height / rows;

  windows.forEach((window, i) => {
    const col = i % cols;
    const row = Math.floor(i / cols);
    window.setFrame({
      x: frame.x + col * width,
      y: frame.y + row * height,
      width,
      height,
    });
  });
});
```

### Application Launcher

```javascript
Keymap.on("b", ["cmd", "shift"], () => {
  // Focus or launch Safari
  const safari = Application.all().find((app) => {
    return app.name === "Safari";
  });

  if (safari) {
    safari.activate();
  } else {
    // Safari not running, you could use other methods to launch
    print("Safari is not running");
  }
});
```

## Development

Stark is built with Swift and uses:

- macOS Accessibility APIs for window management
- JavaScriptCore for JavaScript execution
- Carbon APIs for keyboard shortcuts
