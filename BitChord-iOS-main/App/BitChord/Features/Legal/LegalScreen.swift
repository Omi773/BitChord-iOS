// Copyright (C) 2026 Omi773 <https://github.com/Omi773>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Part of the standalone BitChord for iOS fork. See NOTICE.md.

import SwiftUI

// The in-app copy of the licence notice, Privacy Policy, Terms of Use and contact details, opened
// from Settings > About & legal. The text lives in `LegalContent`, mirrored from the .md files in
// the repository root.

enum LegalInfo {
    static let owner = "Omi773"
    static let ownerProfile = URL(string: "https://github.com/Omi773")!
    static let email = "omishikdr@gmail.com"
    static let github = "https://github.com/Omi773"
    static let repository = "https://github.com/Omi773/BitChord-iOS"
    static let upstream = "https://github.com/kushagrasinghx/BitChord"
}

/// "Omi773" with the GitHub mark, linking to the developer's GitHub profile.
struct OwnerGitHubLink: View {
    var body: some View {
        Link(destination: LegalInfo.ownerProfile) {
            HStack(spacing: 5) {
                Image("GitHubMark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .accessibilityHidden(true)
                Text(LegalInfo.owner)
            }
        }
        .accessibilityLabel("\(LegalInfo.owner) on GitHub")
    }
}

struct LegalScreen: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BitChord for iOS")
                        .font(.headline)
                    HStack(spacing: 6) {
                        Text("Copyright \u{00A9} 2026")
                            .foregroundStyle(.secondary)
                        OwnerGitHubLink()
                    }
                    .font(.subheadline)
                    Text("Free software under the GNU General Public License v3.0.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                NavigationLink {
                    LegalDocumentScreen(title: "Licence & credits", markdown: LegalContent.notice)
                } label: {
                    Label("Licence & credits", systemImage: "doc.text")
                }
                NavigationLink {
                    LegalDocumentScreen(title: "Privacy Policy", markdown: LegalContent.privacy)
                } label: {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                NavigationLink {
                    LegalDocumentScreen(title: "Terms of Use", markdown: LegalContent.terms)
                } label: {
                    Label("Terms of Use", systemImage: "checkmark.seal")
                }
                NavigationLink {
                    LegalDocumentScreen(title: "Contact", markdown: LegalContent.contact)
                } label: {
                    Label("Contact", systemImage: "envelope")
                }
            }

            Section {
                if let mail = URL(string: "mailto:\(LegalInfo.email)") {
                    Link(destination: mail) {
                        Label(LegalInfo.email, systemImage: "paperplane")
                    }
                }
                if let repo = URL(string: LegalInfo.repository) {
                    Link(destination: repo) {
                        Label("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
                if let upstream = URL(string: LegalInfo.upstream) {
                    Link(destination: upstream) {
                        Label("Original BitChord (Android)", systemImage: "heart")
                    }
                }
            } footer: {
                Text("BitChord is not affiliated with, endorsed by, or connected to YouTube, Google or Apple.")
            }
        }
        .collectionsListBottomInset()
        .navigationTitle("About & legal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Renders the small subset of Markdown the legal documents use: headings, bullet lists and
/// paragraphs with inline bold, italic and links.
struct LegalDocumentScreen: View {
    let title: String
    let markdown: String

    private enum Block: Identifiable {
        case title(String)
        case heading(String)
        case bullet(String)
        case paragraph(String)

        var id: String {
            switch self {
            case .title(let s): return "t:" + s
            case .heading(let s): return "h:" + s
            case .bullet(let s): return "b:" + s
            case .paragraph(let s): return "p:" + s
            }
        }
    }

    private var blocks: [Block] {
        var result: [Block] = []
        for raw in markdown.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("## ") {
                result.append(.heading(String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                result.append(.title(String(line.dropFirst(2))))
            } else if line.hasPrefix("- ") {
                result.append(.bullet(String(line.dropFirst(2))))
            } else {
                result.append(.paragraph(line))
            }
        }
        return result
    }

    private func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(blocks) { block in
                    switch block {
                    case .title(let text):
                        Text(text).font(.title2.bold())
                    case .heading(let text):
                        Text(text).font(.headline).padding(.top, 8)
                    case .bullet(let text):
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\u{2022}")
                            Text(inline(text))
                        }
                    case .paragraph(let text):
                        Text(inline(text))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .collectionsListBottomInset()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
