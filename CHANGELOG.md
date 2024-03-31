# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Updated the internal key map support to use the Alicia package
- Updated to initialise internal classes in `AppDelegate`
- Updated the enhanced user interface work around to use a function with callback

## [2.5.0] - 2024-02-29

### Removed

- Removed `window()` from `Application`
- Removed deprecated `.activateIgnoringOtherApps` option from application `focus()`

### Changed

- Changed `Bind` to `Keymap` in the API
- Changed minimum required macOS version to 14.0

## [2.4.0] - 2023-10-19

### Removed

- Removed `Task` API class
- Removed `Timer` API class
- Removed `Stark.run` API method

### Fixed

- Fixed an issue with Chromium based windows being unable to be moved or resized

## [2.3.0] - 2023-10-19

### Added

- Added `setFullScreen` method to `Window`

### Removed

- Removed deprecated API methods
- Removed `maximize` method from `Window`

### Changed

- Changed `@NSApplication` to `@main`
- Changed `App` to `Application` in the API
- Changed implementation of certain `Application` methods
- Changed implementation of certain `Window` methods
- Changed minimum macOS version to 13.5

## [2.2.0] - 2023-03-15

### Changed

- Changed the app icon to use a better macOS icon template
- Changed minimum macOS version to 13.0

## [2.1.6] - 2023-01-14

### Added

- Added `flippedFrame` and `flippedVisibleFrame` to `Screen`

### Changed

- Deprecated `frameIncludingDockAndMenu`
- Deprecated `frameWithoutDockOrMenu`

## [2.1.5] - 2023-01-09

### Added

- Added `⇧`, `⌃`, `⌥`, and `⌘` as strings for modifiers

## [2.1.4] - 2022-05-07

### Changed

- Changed to use `Self` instead of class name for static references
- Changed the resources `bind.js`, `task.js`, and `timer.js` into a single
  `library.js`
- Changed `setFrame` to call `setSize`, then `setTopLeft`, and finally `setSize`
- Changed `setFrame` to temporarily disable accessibility enhanced user
  interface when setting the size and position.

## [2.1.3] - 2022-04-14

### Changed

- Changed the macOS deployment target to 12.0

### Removed

- Removed `stark-example.js` being created when running without an existing
  configuration file

## [2.1.2] - 2022-04-12

### Added

- Added menu item to enable or disable logging JavaScript exceptions

## [2.1.1] - 2022-02-01

### Added

- Added `moveWindows` on `Space` in the JavaScript API

### Changed

- Changed the macOS deployment target to 12.2

### Removed

- Removed references to `event.js`

## [2.1.0] - 2021-12-22

### Changed

- Changed to use SkyLight private framework instead of CoreGraphics
- Changed to make `identifier` on `Space` available in the JavaScript API
- Changed to not use deprecated `UTGetOSTypeFromString` function.

### Removed

- Removed API for launching applications
- Removed the `Events` JavaScript API

### Fixed

- Fixed notifications not triggering for running applications
