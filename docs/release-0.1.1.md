# BitChord 0.1.1

A small update to 0.1.0: the explicit "E" badge now sits where you expect it, and BitChord now tells iOS when a track is explicit.

> [!CAUTION]
> ## ⚠️ Read this before installing
> - **Unofficial.** BitChord is not affiliated with, endorsed by, or connected to YouTube, Google or Apple. It is not on the App Store.
> - **Sideload only.** The IPA is unsigned (ad-hoc signed only), so iOS will not install it directly. A sideloading app has to re-sign it with your own Apple ID.
> - **Free Apple ID limits.** Apps signed with a free Apple ID expire after 7 days and must be refreshed.
> - **Your responsibility.** You are responsible for following the YouTube Terms of Service and your local copyright law. The app is provided "as is", with no warranty.

## What's new in 0.1.1

### Added
- BitChord now sends the explicit flag to iOS with the current track, so the lock screen, Control Center, CarPlay and AirPlay can show the "E" beside the song title. Whether and how it is drawn is up to iOS.

### Changed
- **Now Playing:** the "E" badge sits directly after the song title instead of at the far edge of the row. A title that scrolls takes the badge with it, and VoiceOver reads "Explicit" after the title.
- App version is 0.1.1 (build 2), for the app, the widgets and the Share extension.
- The Release IPA workflow reads the version from the IPA itself, so the version no longer has to be typed in for each release.

### Fixed
- The "E" badge floating away from short titles on the Now Playing screen.

## Download

**`BitChord-0.1.1-unsigned.ipa`** (attached below under Assets). The SHA-256 checksum is at the bottom of these notes.

| | |
|---|---|
| Version | 0.1.1 |
| Requires | iPhone or iPad on iOS 17 or later |
| Bundle ID | `com.music.bitchord` |

## How to update

Install the new IPA over the old one in your sideloader (Feather, ESign, SideStore, AltStore or Sideloadly). Downloads, library and settings carry over. As with every new build, the first launch clears the song and artwork caches, so the first plays after updating may take a little longer.

## Known limitations

The limitations listed in the [0.1.0 release notes](https://github.com/Omi773/BitChord-iOS/blob/main/docs/release-0.1.0.md) still apply: CarPlay, Last.fm, https invite links and the default Listen Together server.

- [Privacy Policy](https://github.com/Omi773/BitChord-iOS/blob/main/PRIVACY.md)
- [Terms of Use](https://github.com/Omi773/BitChord-iOS/blob/main/TERMS.md)
- Contact: [omishikdr@gmail.com](mailto:omishikdr@gmail.com) or [GitHub issues](https://github.com/Omi773/BitChord-iOS/issues)
