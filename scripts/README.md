# Development Tools

The binary files contained in this directory are tools for use by developers. All of these files are shell scripts.

## Logging

`JXLook` is using Apple's [unified logging](https://developer.apple.com/documentation/os/logging) system. One of the ways to [view log messages](https://developer.apple.com/documentation/os/logging/viewing_log_messages) is to use the `log` tool from [Terminal](https://support.apple.com/guide/terminal/welcome/mac). The executable `streamLog` is merely a shell script that invokes the `log` tool specifying the `stream` command with a value for the `predicate` option to only show messages being emitted by `JXLook`.

The `log` tool requires that the  `stream` command be run from an admin account.

## Settings

`JXLook` settings use Apple's [UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults) system. The following executables use the [defaults](https://support.apple.com/guide/terminal/edit-property-lists-apda49a1bb2-577e-4721-8f25-ffc0836f6997/mac) tool to change various `JXLook` settings. This provides developers a way to quickly change settings from [Terminal](https://support.apple.com/guide/terminal/welcome/mac).

- disableExtendedDynamicRange
- disableHighDynamicRange
- disableToneMapping
- enableExtendedDynamicRange
- enableHighDynamicRange
- enableToneMapping
