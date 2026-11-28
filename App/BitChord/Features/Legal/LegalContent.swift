// Copyright (C) 2026 Omi Shikder <https://github.com/Omi773>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Part of the standalone BitChord for iOS fork. See NOTICE.md.

// Generated from NOTICE.md, PRIVACY.md, TERMS.md and CONTACT.md in the repository root.
// Keep the two in step: edit the .md files, then update the matching text here.

enum LegalContent {
    static let notice = #"""
# Notice

BitChord for iOS (this fork)

Copyright (C) 2026 Omi Shikder (<https://github.com/Omi773>)

This is a standalone fork, maintained by Omi Shikder, of the iOS port of BitChord. The changes made in this fork are copyright Omi Shikder and are released under the same licence as the rest of the project, the [GNU General Public License v3.0](LICENSE).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. It is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY, without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

## Original work and credits

This fork is built on the work of others. Their copyright and licence notices stay in place, and nothing in this fork replaces or removes them:

- **BitChord for Android** by [Kushagra Singh](https://github.com/kushagrasinghx), licensed under GPL-3.0. The design, features and most of the behaviour come from that project.
- **The BitChord for iOS port** by [maanya145](https://github.com/maanya145/BitChord-iOS), which this repository was forked from.
- **Orchard** by SFG545 and other third-party works, under their own licences. See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) and [LICENSES/](LICENSES/AGPL-3.0.txt).

## Policies

- [Privacy Policy](PRIVACY.md)
- [Terms of Use](TERMS.md)
- [Contact](CONTACT.md)

## Trademarks

BitChord is not affiliated with, endorsed by, or connected to YouTube, Google, Apple, Spotify, Tidal, Discord, Last.fm or any other service it can talk to. All product names and trademarks belong to their owners.
"""#

    static let privacy = #"""
# Privacy Policy

Last updated: 28 November 2026

BitChord for iOS (this fork) is a free, open-source music player maintained by Omi Shikder ("I", "me"). This page explains what the app does with your information.

## The short version

- I do not run a server for this app that collects your data. The app has no accounts with me, no advertising, no analytics and no crash-reporting service.
- Your settings, listening history, downloads and caches stay on your device.
- When you use a feature that needs the internet, the app talks directly to the service behind that feature. Those services have their own privacy policies and I do not control them.

## What stays on your device

Settings, play history, queue, library data, lyrics, downloaded and cached songs, imported files, equalizer presets and Replay statistics are stored on your iPhone or iPad. Deleting the app deletes them. You can also export or import your settings and history as a JSON file; that file is yours and goes only where you save it.

## Services the app contacts

The app only contacts a service when you use the feature that needs it. Depending on what you use, that can include:

- **YouTube Music and Google**, for search, browsing, streaming, and signing in to your account. If you sign in, the sign-in happens with Google, and the session is kept on your device. Google receives the requests the app makes, such as what you search for and play, in the same way as any YouTube Music client.
- **Lyrics providers** you enable (for example LRCLIB, Musixmatch, Genius, KuGou, BetterLyrics, SimpMusic and others). They receive the track title, artist, album and duration to find lyrics.
- **Translation**, if you translate lyrics. The lyric text is sent to a translation service.
- **Scrobbling services** (Last.fm, ListenBrainz, Libre.fm), if you connect them. They receive what you play and your login for that service.
- **Discord**, if you turn on Rich Presence. Discord receives the track, artist, progress and audio quality you choose to show.
- **Animated cover art sources** (Apple Music, Tidal, Spotify and a community index), if that feature is on. They receive the track and artist being looked up.
- **Listen Together.** Sessions run through a party server. The default server is operated by the upstream BitChord project, not by me. Your session code and playback state are sent to it. You can point the app at a different server.
- **Sources, SMB and WebDAV servers** that you add yourself. The app connects to the addresses you enter, with the credentials you provide, and I have no access to them.

I do not receive any of the data above.

## Sign-in details and credentials

Passwords and tokens you enter for Google, scrobbling services, Discord, SMB or WebDAV are used only to sign in to those services from your device. I never see them.

## Permissions

The app asks for access only for what you use, such as local network access for SMB shares and Listen Together, the Files app for imports and exports, and background audio so music keeps playing.

## Children

The app is not directed at children under 13, and I do not knowingly collect information from anyone.

## Your choices

You can sign out, remove connected services, delete downloads and caches, turn features off in Settings, or delete the app at any time. Because I do not hold your data, there is nothing for me to delete on my side. For data held by Google, Discord, Last.fm and the other services above, use their own privacy controls.

## Changes

If this policy changes, the new version will be published in the repository and in the app, with a new date at the top.

## Contact

Questions about this policy: [omishikdr@gmail.com](mailto:omishikdr@gmail.com)
"""#

    static let terms = #"""
# Terms of Use

Last updated: 28 November 2026

By installing or using BitChord for iOS (this fork), maintained by Omi Shikder, you agree to these terms. If you do not agree, please do not use the app.

## Licence

The app is free software under the GNU General Public License v3.0 (see [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md)). Nothing in these terms limits the rights that licence gives you to use, study, share and modify the source code. If these terms and the licence ever conflict about the source code, the licence wins.

## Not affiliated

BitChord is an independent project. It is not affiliated with, endorsed by, or connected to YouTube, Google, Apple or any other service it can use. Those names belong to their owners.

## Third-party services and content

The app lets you reach content and services provided by others, such as YouTube Music, lyrics providers, scrobbling services and servers you add yourself. I do not host or control that content or those services. You are responsible for following the terms of every service you use, including the YouTube and Google terms of service, and for respecting copyright and the rights of artists and content owners. Use downloads, caches and imported files only as the law and the content owners' terms allow.

## Your account and data

You are responsible for the accounts you sign in with, for the servers and credentials you add, and for keeping your device secure. See the [Privacy Policy](PRIVACY.md) for how information is handled.

## Acceptable use

Do not use the app to break the law, to infringe others' rights, to disrupt or attack any service, or to abuse Listen Together or any other shared feature.

## No warranty

The app is provided "as is" and "as available", without warranty of any kind, express or implied, including fitness for a particular purpose and non-infringement. Services it relies on can change or stop working at any time, and features may break without notice.

## Limitation of liability

To the fullest extent the law allows, I am not liable for any loss or damage arising from your use of the app, including loss of data, account restrictions imposed by third-party services, or interruptions to services. Nothing in these terms excludes liability that cannot be excluded by law.

## Changes and ending use

I may update these terms, and the new version will be published in the repository and in the app. You can stop using the app at any time by deleting it.

## Contact

Questions about these terms: [omishikdr@gmail.com](mailto:omishikdr@gmail.com)
"""#

    static let contact = #"""
# Contact

BitChord for iOS (this fork) is maintained by **Omi Shikder**.

- Email: [omishikdr@gmail.com](mailto:omishikdr@gmail.com)
- GitHub: [@Omi773](https://github.com/Omi773)
- Source code and issues: <https://github.com/Omi773/BitChord-iOS/issues>

Use email for privacy requests, licence questions and anything you would rather not post in public. Use GitHub issues for bugs and feature requests.

Bugs that also happen in the Android app belong with the upstream project: <https://github.com/kushagrasinghx/BitChord/issues>.
"""#
}
