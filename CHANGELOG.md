# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][keep-a-changelog], and this project
adheres to [Semantic Versioning][semver].

[keep-a-changelog]: https://keepachangelog.com/en/1.0.0/
[semver]: https://semver.org/spec/v2.0.0.html

## [Unreleased]

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
