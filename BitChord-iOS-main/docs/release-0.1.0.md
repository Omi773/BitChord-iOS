# BitChord 0.1.0

**The first release of BitChord for iOS (standalone fork)**: a native YouTube Music client for iPhone and iPad, built in SwiftUI and ported from [BitChord for Android](https://github.com/kushagrasinghx/BitChord) by Kushagra Singh. It follows the Android app screen for screen, currently tracking BitChord for Android 1.8, and is maintained by [Omi773](https://github.com/Omi773).

> [!CAUTION]
> ## ⚠️ Read this before installing
> - **Unofficial.** BitChord is not affiliated with, endorsed by, or connected to YouTube, Google or Apple. It is not on the App Store.
> - **Sideload only.** The IPA is unsigned (ad-hoc signed only), so iOS will not install it directly. A sideloading app has to re-sign it with your own Apple ID.
> - **Free Apple ID limits.** Apps signed with a free Apple ID expire after 7 days and must be refreshed. SideStore and AltStore can refresh them for you.
> - **First release.** This is version 0.1.0. Expect rough edges and bugs. Keep your own backup of anything you care about (Settings can export your settings and history).
> - **Your responsibility.** You are responsible for following the YouTube Terms of Service and your local copyright law. The app is provided "as is", with no warranty. Third-party services can change or stop working at any time.

## Download

**`BitChord-0.1.0-unsigned.ipa`** (attached below under Assets). The SHA-256 checksum is at the bottom of these notes.

| | |
|---|---|
| Version | 0.1.0 |
| Requires | iPhone or iPad on iOS 17 or later |
| Bundle ID | `com.music.bitchord` |
| Contains | The app, three Home Screen widgets and a Share extension |

## How to install

1. Download `BitChord-0.1.0-unsigned.ipa` to your iPhone or iPad.
2. Open it in a sideloader: Feather, ESign, SideStore, AltStore or Sideloadly.
3. Sign in with your Apple ID in that app when it asks, and let it install BitChord.
4. If iOS says the developer is not trusted, go to Settings → General → VPN & Device Management and trust your Apple ID.

To update later, install the new IPA over the old one. Downloads, library and settings carry over.

## What BitChord does

### Playback
- Search, browse and play the YouTube Music catalogue: Home, Explore, moods and genres, artist, album and playlist pages.
- Separate streaming quality for Wi-Fi and mobile data, plus a Dolby Atmos option.
- Optional add-on sources for lossless and Atmos streams, with YouTube Music as the fallback. Sources can be added, tested and reordered.
- Crossfade from 0 to 12 seconds, and Automix, which plans each transition from the beat grid and vocal activity of both tracks.
- Loudness normalization, skip silence, stereo widening and a built-in equalizer.
- A sleep timer: 15, 30, 45 or 60 minutes, or the end of the current track.
- An on-device song cache with an adjustable size limit.
- Stats for nerds on the now playing screen: codec, bitrate and the audio pipeline.

### Lyrics
- Synced lyrics with line and word highlighting, gathered from several providers: LRCLIB, Musixmatch, Genius, KuGou, PaxSenix, BetterLyrics, BiniLyrics, LyricsPlus, SimpMusic, Unison, Megalobiz and YouTube Music.
- Choose and reorder providers, adjust the timing offset, and translate lyrics into another language.
- Share selected lines as an image card. Lyrics are kept on the device per track.

### Library and offline
- Sign in with a Google account for your YouTube Music library, playlists and history. Several accounts and brand profiles are supported.
- Download tracks for offline play, with metadata and lyrics written into the file.
- Import your own audio files from the Files app.
- Play music from SMB and WebDAV shares on your network.
- Export and import settings and listening history as a JSON file.

### Look and feel
- Animated cover art from Apple Music, Tidal, Spotify and a community index, on the player and on the lock screen.
- Player colours and background taken from the album artwork.
- A landscape player layout and iPad support.
- Five app icons to choose from in Settings.
- The interface is available in 16 languages.

### Social and integrations
- Listen Together: host a listening party and invite others with a code, a link or a QR code.
- Replay: listening statistics by period, with a shareable poster.
- Scrobbling to ListenBrainz (and Last.fm, see the limitations below).
- Discord Rich Presence with in-app Discord sign-in.

### System
- Lock screen and Control Center controls.
- Three Home Screen widgets, in small and medium sizes.
- A Share extension that opens YouTube and YouTube Music links in BitChord.
- App Intents for playback.

### About, privacy and legal
- **Settings → About & legal** has the licence and credits, Privacy Policy, Terms of Use and contact details.
- No accounts with the maintainer, no ads, no analytics and no crash reporting. Your settings, history, downloads and caches stay on your device. The app only contacts a service (YouTube Music, lyrics providers, Discord and so on) when you use the feature that needs it.

## Known limitations in this release
- **CarPlay** needs Apple's CarPlay audio entitlement, which this build does not carry.
- **Last.fm** sign-in, Last.fm scrobbling and the genre chart in Replay are unavailable, because this build has no Last.fm API key.
- **Invite links** that start with `https://` cannot open the app yet (Universal Links are not set up). The `bitchord://` links and the Share extension work.
- **Listen Together** uses the default party server run by the upstream BitChord project, not by the maintainer.

## Open source
BitChord for iOS is free software under the [GNU General Public License v3.0](https://github.com/Omi773/BitChord-iOS/blob/main/LICENSE). Copyright © 2026 Omi773 for the changes in this fork. It is a port of BitChord for Android by Kushagra Singh. Third-party code keeps its own licences. See [NOTICE.md](https://github.com/Omi773/BitChord-iOS/blob/main/NOTICE.md) and [THIRD-PARTY-NOTICES.md](https://github.com/Omi773/BitChord-iOS/blob/main/THIRD-PARTY-NOTICES.md).

- [Privacy Policy](https://github.com/Omi773/BitChord-iOS/blob/main/PRIVACY.md)
- [Terms of Use](https://github.com/Omi773/BitChord-iOS/blob/main/TERMS.md)
- Contact: [omishikdr@gmail.com](mailto:omishikdr@gmail.com) or [GitHub issues](https://github.com/Omi773/BitChord-iOS/issues)

*Bugs that also happen in the Android app belong with the [upstream project](https://github.com/kushagrasinghx/BitChord/issues).*
