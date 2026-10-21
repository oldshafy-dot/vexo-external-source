# Vexo external — iOS source

This project is based on the supplied OGIOS source project. The interface branding has been changed to **Vexo external**, with Home/Info navigation, a looping local video banner, FF NORMAL/FF MAX selection, patch rows, device status, Settings, cache cleaner, and Developer Shafey Telegram link.

## Build unsigned IPA

Run `./build_unsigned.sh` on a Mac with Xcode installed. The script creates `build/VexoExternal-unsigned.ipa`. The IPA is unsigned and must be signed using a compatible signing workflow before ordinary installation.

The build script places bundled `.3105` resources into `Patches/` with the `.OGIOS` extension expected by `PatchProjectLibrary`.

## Online patch catalogue

The app queries the configured public REST endpoint for `free_fire` and `free_fire_max` catalogue counts. Catalogue records currently expose `version`, `download_url`, `file_path`, and `notes`; the API does not yet provide a stable package identifier that links each remote record to a local `.OGIOS` package. Until that mapping and package format are confirmed, the ON/OFF rows operate on the original bundled local packages and do not pretend that remote download URLs have been applied.

## Important

The source includes device-specific privileged components. Building successfully does not prove those components are compatible with a given iOS version or device. Test only on devices and app data you are authorized to modify.
