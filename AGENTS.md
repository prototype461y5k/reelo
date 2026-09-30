# AGENTS.md: project guidance for the Osaurus Code agent (Reelo)

Osaurus loads this file automatically when this folder is the chat's trusted folder.

## This project
- Reelo is a native macOS app built with Xcode (`reelo.xcodeproj`).
- The project was renamed from boink, but the Xcode target and scheme are still called `boink`. Use `-scheme boink`.
- Build (outside the project, see the iCloud note below):
  `xcodebuild -project reelo.xcodeproj -scheme boink -configuration Release -derivedDataPath "$TMPDIR/DerivedData-reelo" build`
- `reelo-build/` is an old local build folder and is git-ignored. Don't commit it.

## Rules
- Reply in English. Explain what you did in plain terms.
- Never invent command output, versions, file paths or hashes. Quote real tool output. If a step did not run, say so.
- Run `git status` before and after changes. Ask before `git push`, tags, or GitHub releases.

## Sandbox limits in trusted-folder mode
`shell_run` can only write inside this folder and temp directories. Keep caches inside the project and git-ignored:

```sh
export CARGO_HOME="$PWD/.cargo-home"
export npm_config_cache="$PWD/.npm-cache"
# Xcode: build in a temp folder, NOT inside the project. Kaan's Desktop is synced by
# iCloud, which adds Finder attributes that make codesign fail
# ("resource fork, Finder information, or similar detritus not allowed").
xcodebuild -scheme <Scheme> -configuration Release -derivedDataPath "$TMPDIR/DerivedData-<Scheme>" build
```

`.gitignore` should contain: `.cargo-home/`, `.npm-cache/`, `build/`, `*.dmg`.

## Building a DMG (tested in this sandbox)
`hdiutil create -srcfolder …` fails here ("Directory not empty"). Use this instead:

```sh
APP="path/to/MyApp.app"; NAME="MyApp"; VER="1.0.0"
rm -rf build/dmg-stage && mkdir -p build/dmg-stage
cp -R "$APP" build/dmg-stage/
ln -s /Applications build/dmg-stage/Applications
hdiutil makehybrid -hfs -hfs-volume-name "$NAME" -o build/tmp.dmg build/dmg-stage
hdiutil convert build/tmp.dmg -format UDZO -ov -o "build/$NAME-$VER.dmg"
hdiutil verify "build/$NAME-$VER.dmg"
shasum -a 256 "build/$NAME-$VER.dmg"
```

## npm / Tauri
Pass CLI flags after `--`: `npm run tauri build -- --bundles app`.

## Releases
Match the style of earlier release notes (`gh release view <previous-tag>`). Include the SHA-256 from the command above, copied verbatim.
