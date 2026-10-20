# Publishing the source and release

The downloadable package is a **publishing kit**, not a replacement for the already modified upstream source tree.

## In the existing Termux source checkout

```sh
cd ~/src/codex-native
git status --short
git remote -v
git diff --stat
git ls-files patches scripts codex-rs/.cargo
find . -path './codex-rs/target' -prune -o -name '*.patch' -print
```

Inspect the output for modified and untracked port files. In particular check `codex-rs/.cargo/config.toml`, `codex-rs/code-mode-protocol/build.rs`, wrapper scripts, and NDK-related environment settings. **Do not replace the real modifications with guessed patches.**

Copy README.md, scripts/, .gitignore, RELEASE_NOTES_TEMPLATE.md, and .github/workflows/release.yml from this kit into the existing checkout. Merge .gitignore rather than overwriting existing rules. If using a separate port repository, preserve upstream provenance and all relevant license notices. Before staging, inspect for secrets and personal paths:

```sh
git status --short
git diff --check
git diff --cached --stat
```

Stage selected files only, review `git diff --cached`, then commit. Create a new GitHub repository named `codex-native-android`, set its remote, and push your intended branch. Do not run `git push --force` over upstream history.

## Binary release

Your already-built release files live in:

```text
~/codex-release/codex-0.154.0-android-arm64.tar.gz
~/codex-release/SHA256SUMS
```

Create a GitHub Release (for example tag `android-v0.154.0-1`) and upload **both** files. Do not add them to normal Git history. Copy the release notes template, filling in the actual commits, device and testing status.

## Before claiming reproducibility

Perform a clean-clone build using the published files. Until then, label the build instructions as a documented maintainer workflow rather than a verified one-command build.

## Important: preserving port changes

The 18 GB `codex-rs/target/` directory was build output and has already been deleted. That does not normally remove changes to tracked Rust source, `.cargo/config.toml`, `patches/`, or scripts. The Git repository itself should be published only after reviewing `git status --short`, `git diff`, and **untracked files**. A patch made only in `target/` cannot be recovered from the clean command and must be recreated.

Use `git add -p` to review changes, then commit source and scripts; do not stage `target/` or secret configuration. For GitHub Releases upload the existing `~/codex-release/codex-0.154.0-android-arm64.tar.gz` and `~/codex-release/SHA256SUMS` as assets. The binary SHA-256 and the archive SHA-256 are different values. Confirm upstream license and notices are retained in the fork.

## Recovery from actual Termux shell history

The `.cargo/config.toml.backup` file was created by renaming the upstream Windows-only Cargo config (history line 295). It does **not** hold Android settings. It can be compared against `git show HEAD:codex-rs/.cargo/config.toml`; the user restored the tracked file from the backup.

The final build flags are set in `scripts/build-termux.sh`. Preserve the modified `codex-rs/Cargo.lock` pending a full diff review; many visible changes are workspace package versions `0.0.0 -> 0.154.0`. Preserve the `code-mode-protocol/build.rs` patch. Before commit, review `git diff --check`, `git diff -- codex-rs/Cargo.lock`, and `git status --short`. Remove only verified redundant `.backup`/`.bak` files.

The existing checkout is detached (`git branch --show-current` returned blank). To make a publishing branch without losing changes:

```sh
cd ~/src/codex-native
git switch -c android-v0.154.0
git remote rename origin upstream
git remote add origin https://github.com/YOUR_USERNAME/codex-native-android.git
# Copy this kit's README, scripts, and workflow into this checkout, then review and commit.
git add README.md SOURCE_UPLOAD_GUIDE.md scripts/ .github/ codex-rs/Cargo.lock codex-rs/code-mode-protocol/build.rs
git diff --cached --check
git diff --cached --stat
# Commit only after inspecting the staged diff and confirming upstream licensing.
# git commit -m "Port Codex CLI 0.154.0 to native Termux ARM64"
# git push -u origin android-v0.154.0
```

If `.github/` or `scripts/` contains other changes, stage files selectively. Do not use `git add -A` without reviewing credentials and artifacts.
