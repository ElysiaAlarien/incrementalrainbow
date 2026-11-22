# Building the game

This file tells you how to make the builds for Steam (Windows, macOS, and Linux), iOS, and Android (#28, ADR-0001). The presets are in `export_presets.cfg`.

The game is bought once. It has no ads and no in-app purchases. The test `tests/build/test_no_ads_or_purchases.gd` checks this on each pull request (see [No ads and no in-app purchases](#no-ads-and-no-in-app-purchases)).

## What you need

| Build | Needs | Signing |
| --- | --- | --- |
| Linux | Godot and the export templates | None |
| Windows | Godot and the export templates | Optional (Authenticode) |
| macOS | Godot and the export templates | Ad-hoc for tests. A Developer ID and notarization to release. |
| Android (debug) | Also a JDK 17 and the Android SDK | A debug key that Godot makes |
| Android (release) | Also a release key | Your upload key |
| iOS | Also a Mac with Xcode, and an Apple developer account | Your Apple team and profiles |

## Do the steps for all builds

1. Install Godot 4.7.2. This is `GODOT_VERSION` in `.github/workflows/ci.yml` and `.github/workflows/builds.yml`. When you change the version, change it in the two workflows and in this file.
2. Install the export templates of the same version. In the editor, use **Editor > Manage Export Templates > Download and Install**. Or download `Godot_v4.7.2-stable_export_templates.tpz` from the Godot release page, check it against `SHA512-SUMS.txt`, and unzip its `templates/` folder to:
   - Linux: `~/.local/share/godot/export_templates/4.7.2.stable/`
   - macOS: `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`
   - Windows: `%APPDATA%\Godot\export_templates\4.7.2.stable\`
3. For Android, install a JDK 17 and the Android SDK. Set `JAVA_HOME` and `ANDROID_HOME` before you start Godot the first time. Or set the paths in **Editor Settings > Export > Android**.
4. Run the tests: `GODOT=/path/to/godot tools/test.sh`.

## Make a build

Run `tools/build.sh` with the preset names. Each build goes to the `export_path` of its preset, in `build/`. Git ignores `build/`.

```bash
GODOT=/path/to/godot tools/build.sh Linux Windows macOS
```

```bash
GODOT=/path/to/godot tools/build.sh --debug Android
```

The script imports the project and exports each preset. It stops when an export fails, when the export log has an error, or when the export makes no file. The log of each export is in `build/<preset>.log`.

You can also export from the editor: **Project > Export**, select the preset, then click **Export Project**.

## Do a start check

`tools/start_check.sh` starts an exported game headless for 300 frames, in an empty user data folder. Thus it does not touch your save. The check passes when the game exits with code 0, the log has no errors, and the game wrote a save. The game writes a save only when its content loaded. Thus the check finds an export that does not have the content.

```bash
tools/start_check.sh build/linux/IncrementalRainbow.x86_64
```

On Windows, run it in Git Bash. On macOS, unzip the build, then give the path of the executable in the app: `"build/macos/Incremental Rainbow.app/Contents/MacOS/Incremental Rainbow"`. If you copied an ad-hoc signed build from another computer, macOS can block it. Then remove the quarantine flag first: `xattr -dr com.apple.quarantine "build/macos/Incremental Rainbow.app"`.

## The builds in CI

The **Builds** workflow (`.github/workflows/builds.yml`) is apart from the **CI** workflow, so that "Import and test" stays fast. It runs on each pull request and each push to `main`, because a change to `src/`, `data/`, or `addons/` can break an exported build when the tests still pass. To run it at other times, go to **Actions > Builds > Run workflow**.

It does these steps:

1. Exports Linux, Windows, and macOS (ad-hoc signed) on Ubuntu.
2. Exports a debug Android APK, and fails if the APK has a permission for billing or for ads.
3. Exports the iOS Xcode project, with a placeholder team id in a copy of the presets. It cannot make an `.ipa`, because that needs a Mac and your team.
4. Starts the Linux build on Ubuntu, the Windows build on Windows, and the macOS build on macOS, with `tools/start_check.sh`.
5. Uploads each build as an artifact of the run.

CI does not start the Android or iOS build, because that needs an emulator, a simulator, or a device. Do the device checks in [Before each release](#before-each-release).

The iOS export log has two warnings that are not problems: `Property not found: application/boot_splash/fullsize` (from the Godot iOS template) and `.ipa can only be built on macOS`.

The start check runs the game headless. Thus it shows that the build loads its scripts and content, but not that the game draws or takes input. Do that check by hand in [Before each release](#before-each-release).

## Secrets

Do not put a key, a password, or a certificate in `export_presets.cfg`. The test `tests/build/test_export_presets.gd` fails when a secret field in the presets has a value.

Give the secrets to Godot in one of these ways:

- **Environment variables.** Godot reads the names below. Use these in CI, from GitHub secrets.
- **The editor.** When you type a secret in **Project > Export**, Godot keeps it in `.godot/export_credentials.cfg`. Git ignores `.godot/`.

| Platform | Environment variables |
| --- | --- |
| Android | `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` (also `..._DEBUG_...` for a debug key of your own) |
| Windows | `GODOT_WINDOWS_CODESIGN_IDENTITY`, `GODOT_WINDOWS_CODESIGN_IDENTITY_TYPE`, `GODOT_WINDOWS_CODESIGN_PASSWORD` |
| macOS | `GODOT_MACOS_CODESIGN_CERTIFICATE_FILE`, `GODOT_MACOS_CODESIGN_CERTIFICATE_PASSWORD`, `GODOT_MACOS_CODESIGN_PROVISIONING_PROFILE`, `GODOT_MACOS_NOTARIZATION_API_KEY`, `GODOT_MACOS_NOTARIZATION_API_KEY_ID`, `GODOT_MACOS_NOTARIZATION_API_UUID` (or `GODOT_MACOS_NOTARIZATION_APPLE_ID_NAME` and `GODOT_MACOS_NOTARIZATION_APPLE_ID_PASSWORD`) |
| iOS | `GODOT_APPLE_PLATFORM_PROVISIONING_PROFILE_UUID_RELEASE`, `GODOT_APPLE_PLATFORM_PROFILE_SPECIFIER_RELEASE` (also `..._DEBUG`) |

## Steps that need your accounts and keys

Do these steps before the first release. CI cannot do them, because they need your accounts.

### Application ids

The presets use the placeholder `com.example.incrementalrainbow` as the macOS bundle id, the iOS bundle id, and the Android package name. Change it to an id of yours before the first upload. After the first upload to a store, do not change it, because the store then sees a different app.

### Version

Set `application/config/version` in **Project Settings** (for example `1.0.0`). The macOS, iOS, and Android presets use it when their own version field is empty. For each Android upload, make `version/code` in the Android preset larger by 1.

### Linux, Windows, and macOS on Steam

1. Get a Steamworks partner account.
2. Pay the app fee for the game. Steam then gives an App ID and depot ids. Write them in this file.
3. Make the builds with `tools/build.sh Linux Windows macOS`.
4. Windows (optional): sign the `.exe`. Get a code signing certificate, set the Windows variables in [Secrets](#secrets), and set `codesign/enable=true` in the Windows preset. Godot uses `signtool` on Windows and `osslsigncode` on Linux and macOS.
5. macOS: sign and notarize the app.
   1. Join the Apple Developer Program.
   2. Make a "Developer ID Application" certificate, and export it as a `.p12` file.
   3. Make an App Store Connect API key for notarization.
   4. Set the macOS variables in [Secrets](#secrets).
   5. In the macOS preset, set `codesign/codesign` to `2` (rcodesign) on Linux, or to `3` (Xcode codesign) on a Mac.
   6. Set `codesign/apple_team_id` to your team id.
   7. Set `notarization/notarization` to `1` (rcodesign) or to `2` (notarytool).
   8. Make the build again. For rcodesign, install [rcodesign](https://github.com/indygreg/apple-platform-rs) and set its path in **Editor Settings > Export > macOS > rcodesign**.
6. Upload the builds with SteamPipe. Each start check must pass first.
   1. Download the Steamworks SDK from the Steamworks partner site. Use `sdk/tools/ContentBuilder/builder_linux/steamcmd.sh` (or `builder/steamcmd.exe` on Windows, `builder_osx/steamcmd.sh` on macOS).
   2. In the Steamworks app admin, make one depot for each operating system, and set the operating system of each depot. Set a launch option for each: `IncrementalRainbow.x86_64` for Linux, `IncrementalRainbow.exe` for Windows, and `Incremental Rainbow.app` for macOS.
   3. Put the builds in a content folder, one folder for each depot. Unzip the macOS build there, so that the folder has `Incremental Rainbow.app`.
   4. Write an app build script, `app_build.vdf`, next to the content folder. Change `<APP_ID>` and the depot ids to yours.

      ```text
      "AppBuild"
      {
      	"AppID" "<APP_ID>"
      	"Desc" "Incremental Rainbow 1.0.0"
      	"ContentRoot" "./content/"
      	"BuildOutput" "./output/"
      	"Depots"
      	{
      		"<LINUX_DEPOT_ID>" { "FileMapping" { "LocalPath" "linux/*" "DepotPath" "." "Recursive" "1" } }
      		"<WINDOWS_DEPOT_ID>" { "FileMapping" { "LocalPath" "windows/*" "DepotPath" "." "Recursive" "1" } }
      		"<MACOS_DEPOT_ID>" { "FileMapping" { "LocalPath" "macos/*" "DepotPath" "." "Recursive" "1" } }
      	}
      }
      ```

   5. Upload: `steamcmd.sh +login <your Steam build account> +run_app_build "$PWD/app_build.vdf" +quit`. Use a Steam account that has only the rights to upload builds. Steam Guard asks for a code at the first login.
   7. In the Steamworks app admin, go to **SteamPipe > Builds**, and set the new build live on a beta branch first. Install it from that branch with the Steam client on each operating system, and do the checks in [Before each release](#before-each-release). Then set it live on the default branch.
   8. In the store page setup, add no DLC and no in-game purchases.

### Android on Google Play

1. Get a Google Play developer account.
2. Make an upload key. Keep it out of the repository, and keep a backup.

   ```bash
   keytool -genkeypair -v -keystore ~/keys/incrementalrainbow-upload.keystore -alias upload -keyalg RSA -keysize 4096 -validity 10000
   ```

3. Set the Android release variables in [Secrets](#secrets) to the keystore path, the alias, and the password.
4. Google Play wants an Android App Bundle (`.aab`). Godot makes an `.aab` only with a Gradle build:
   1. In the editor, use **Project > Install Android Build Template**. This makes `android/`, which git ignores.
   2. In the Android preset, set `gradle_build/use_gradle_build=true`.
   3. Set `gradle_build/export_format=1` (AAB).
   4. Change `export_path` to end in `.aab`.
   5. CI checks the permissions only in the debug APK. Before each upload, check the permissions of the AAB in the Play Console (**App bundle explorer**).
5. Before you change to an AAB, make a debug APK with `tools/build.sh --debug Android`. Install it on a device with `adb install build/android/IncrementalRainbow.apk`, and play the game for some minutes.
6. Make the release AAB with `tools/build.sh Android`.
7. Upload the `.aab` in the Play Console. Use Play App Signing. In the store listing, set "Contains ads" to **No**, and add no in-app products.

### iOS on the App Store

1. Join the Apple Developer Program, and register the bundle id.
2. Set `application/app_store_team_id` in the iOS preset to your team id (10 characters). A team id is not a secret.
3. On a Mac with Xcode, make the build with `tools/build.sh iOS`. Godot makes the Xcode project and the `.ipa`. For an App Store build, the preset uses export method 0 (App Store) for a release build.
4. Set the provisioning profile variables in [Secrets](#secrets), or let Xcode manage the signing.
5. Install the debug build on a device from Xcode, and play the game for some minutes.
6. Upload the `.ipa` with Xcode or Transporter. In App Store Connect, add no in-app purchases.

## Before each release

CI starts the desktop builds headless only. Before each release, do these checks by hand on each platform, with the build that you will upload:

1. Start the game on a clean install, with no save. The guided start shows.
2. Play for some minutes: build a factory, sell widgets, and close the game.
3. Wait some minutes, then start the game again. The game loads the save, and shows what happened while you were away.
4. Look for an ad, a store, a purchase button, or a request for a permission. There must be none.

| Platform | Where | How to get the build there |
| --- | --- | --- |
| Linux | A Linux computer, and a Steam Deck if you can | The Steam beta branch, or `build/linux/` |
| Windows | A Windows 10 or 11 computer | The Steam beta branch, or `build/windows/` |
| macOS | An Apple silicon Mac, and an Intel Mac if you can (the build is universal) | The Steam beta branch, after notarization |
| Android | A phone and a tablet | `adb install`, then the Play Console internal testing track |
| iOS | An iPhone and an iPad | Xcode, then TestFlight |

## No ads and no in-app purchases

An ad or a purchase needs code from outside the project, such as a plugin, an addon, or a GDExtension. On Android it also needs a permission, such as `com.android.vending.BILLING` or `AD_ID`. `tests/helpers/store_policy.gd` (`StorePolicy`) has an allowlist for each of these, with the reason for each item. The test fails when the project has an item that is not in its list.

To add a plugin, for example for cloud saves or achievements:

1. Add the plugin, and turn it on in the preset.
2. In the same change, add each of its items to its list in `StorePolicy`, with the reason: the addon folder, the `.gdextension` file, the `plugins/<name>` option, and each Android permission, iOS capability, or iOS entitlement that it needs.
3. If the export must not have the addon, add it to `StorePolicy.ADDONS_NOT_IN_BUILDS` and to the `exclude_filter` of each preset.

The **Builds** workflow also reads the permissions in the Android APK, and fails on a permission for billing or for ads.
