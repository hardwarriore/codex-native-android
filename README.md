# Codex Native Android

**Community-maintained Android ARM64 / Termux port of OpenAI Codex CLI.**

> Unofficial project. Not affiliated with, endorsed by, or supported by OpenAI.
>
> **Status:** An Android ARM64 executable for Codex CLI **0.154.0** has been built and its `--version` command tested in Termux. This does **not** yet establish a fully reproducible clean build or compatibility with all Codex features and devices.

## Release facts

| Property | Verified build |
| --- | --- |
| Upstream | [openai/codex](https://github.com/openai/codex) |
| CLI version | `0.154.0` |
| CPU / ABI | `aarch64` / Android ARM64 |
| Rust target | `aarch64-linux-android` |
| Android API | 24 |
| NDK | r30 (`16248370`, as reported by `file`) |
| Rust package in build environment | `1.99.1` |
| Clang package in build environment | `21.1.8-3` |
| Interpreter | `/system/bin/linker64` |
| Original executable size | ~334 MiB (`ls -lh` rounded) |
| Release tarball size | ~96 MiB (`ls -lh` rounded) |

Verified original **executable** SHA-256 (not the compressed archive):

```text
8633aaab24a4c8672c32cdfebf375148f1dbcc22d96f4fe3fe2dab1158b11b53
```

The tarball has a separate checksum in the release's `SHA256SUMS` file. Verify the published artifact against that file.

## Download and install

Download `codex-0.154.0-android-arm64.tar.gz` and `SHA256SUMS` from this repository's **Releases** page after they have been uploaded. Do not assume an unannounced release exists.

```sh
pkg update
pkg install tar coreutils
sha256sum -c SHA256SUMS
tar -xzf codex-0.154.0-android-arm64.tar.gz
mkdir -p "$HOME/bin"
install -m 755 codex "$HOME/bin/codex"
"$HOME/bin/codex" --version
```

Ensure `$HOME/bin` is on `PATH`, or invoke the executable with its full path. Android's dynamic linker may require shared libraries available in the build environment; see **Runtime dependencies** below.

## Runtime dependencies

The tested ELF has been reported to reference `liblzma.so.5`, `libssl.so.3`, `libcrypto.so.3`, `libdl.so`, `libm.so`, and `libc.so`. Some are Android system libraries; others may require Termux packages. On the target device, inspect the executable before diagnosing missing libraries:

```sh
pkg install binutils file
file "$HOME/bin/codex"
readelf -d "$HOME/bin/codex" | grep NEEDED
```

Install the appropriate Termux runtime packages where necessary (for example `openssl` and `liblzma`); do not copy system libraries from another phone. Run `codex --version`, then test authentication and a basic interactive session. Those latter tests have not been independently documented here.

## Build from source (port maintainer workflow)

**Important:** The original working binary was compiled from a modified upstream source tree. The exact Android-specific changes have not yet been fully inventoried and committed. The commands below describe the known build environment; **they are not a claim that pristine upstream sources compile without the port patches**.

### 1. Install the toolchain

On Termux ARM64:

```sh
pkg update
pkg install git rust clang lld cmake ninja make pkg-config \
  openssl openssl-tool protobuf ndk-sysroot binutils
rustc --version
clang --version
protoc --version
```

The working environment reported Termux `rust 1.99.1`, `clang 21.1.8-3`, `ndk-sysroot 30`, and NDK r30 in the ELF metadata. **There is no verified evidence that Rust or Clang were built from source locally.** They appeared as installed Termux packages. Record repository and package provenance when reproducing the build.

### 2. Get the exact upstream version

```sh
git clone https://github.com/openai/codex.git codex-native-android
cd codex-native-android
# Confirm the correct tag/commit exists before checkout:
git tag -l '*0.154.0*'
# The previous build was described as based on rust-v0.154.0:
git checkout rust-v0.154.0
```

Apply the Android-specific modifications from this project's committed source or patches **before** building. If the `patches/` directory has not been audited, do not blindly apply every file. Record exact upstream commit and patch commit in the release notes.

### 3. Configure Android tools

The previous build used target `aarch64-linux-android`, API 24, Termux `ndk-sysroot` r30, and Clang wrappers that translated an unversioned Android target into `aarch64-linux-android24`. It also used system `protoc` instead of an incompatible vendored executable.

```sh
export PROTOC="$PREFIX/bin/protoc"
export CARGO_BUILD_JOBS=1
export CARGO_INCREMENTAL=0
export CARGO_PROFILE_RELEASE_LTO=false
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16
export CARGO_PROFILE_RELEASE_OPT_LEVEL=1
export CARGO_PROFILE_RELEASE_DEBUG=0
export CARGO_PROFILE_RELEASE_STRIP=debuginfo
```

`CC`, `CXX`, `AR`, `CFLAGS`, `CXXFLAGS`, OpenSSL, and `PKG_CONFIG` settings were also involved. The shell history now establishes the API-24 Clang wrapper and the final release profile; the corresponding configuration is implemented in `scripts/build-termux.sh`. Clean-clone reproducibility remains unverified.

The `code-mode-protocol/build.rs` patch was reported to use `PROTOC` from the environment. Inspect that file and include the actual change in version control.

### 4. Build and verify

Once the tested Android configuration and patches are restored:

```sh
cd codex-rs
cargo build --release --target aarch64-linux-android -p codex-cli -j 1
file target/aarch64-linux-android/release/codex
target/aarch64-linux-android/release/codex --version
```

Expected build metadata: ARM64 ELF PIE, `/system/bin/linker64`, Android API 24, CLI version `0.154.0`.

The previous build's `target/` directory occupied about **18 GB**. Keep the resulting executable outside `target/` before `cargo clean`.

## Package a release

```sh
mkdir -p "$HOME/codex-release"
cp codex-rs/target/aarch64-linux-android/release/codex "$HOME/codex-release/codex"
chmod 755 "$HOME/codex-release/codex"
cd "$HOME/codex-release"
./codex --version
tar -czf codex-0.154.0-android-arm64.tar.gz codex
sha256sum codex-0.154.0-android-arm64.tar.gz > SHA256SUMS
sha256sum -c SHA256SUMS
```

Upload **the `.tar.gz` and `SHA256SUMS`** to GitHub Releases. Do not upload `target/`, build caches, credentials, or local user configuration. A `cargo clean` removes build outputs including the original binary under `target/`, but does not remove source files or a copy in `$HOME/codex-release`.

## Source publication checklist

1. Keep the upstream license and copyright notices. Review the actual license and any additional bundled third-party license requirements.
2. Publish all modified source files, Android patches, build scripts, and project-level `.cargo/config.toml` needed to reproduce the build.
3. Use `git status --short`, `git diff`, and `git ls-files` to verify that new, ignored, or untracked port files are accounted for.
4. Inspect `.cargo`, `patches`, `scripts`, and `codex-rs/*/build.rs` for local-only paths and secret material.
5. Avoid committing `$HOME/.codex`, auth caches, API keys, tokens, `.env`, and build outputs.
6. Verify the build from a **fresh clone** before marking the port reproducible.
7. Publish a release note stating tested Android versions, devices, Termux distribution, dependencies, limitations, and exact upstream commit.

## Known limitations

- `--version` has been tested; login, sandbox behavior, networking, interactive terminal handling, and tools need explicit validation.
- Runtime shared libraries and Termux package versions may differ across devices.
- The Clang wrapper and final build flags have been reconstructed from shell history; the final source tree still needs a clean-clone build test.
- The upstream Codex sandbox model may not map directly onto Android/Termux permissions.

## License and attribution

Codex originates from [OpenAI's Codex repository](https://github.com/openai/codex). Preserve upstream license and notices in any source redistribution. This project is an **unofficial Android port**, not a separately developed replacement for Codex.

## Reconstructed build procedure (October 2026)

The original build ultimately produced a working `codex --version` result. Earlier notes that say the build was still blocked at `protoc` describe an **intermediate** state, not the final release outcome. The exact repair of the protobuf/Abseil runtime mismatch was not recorded. Do not claim a particular package upgrade fixed it without reproducing that result.

**Known compilation problems and approaches:**

| Symptom | Recorded mitigation | Confidence |
| --- | --- | --- |
| Linux release binary had incompatible DNS/certificate assumptions | Compile for native Android Bionic | Motivation for port |
| `std required to be available in rlib format` | Match Rust compiler and Android standard library versions | Exact fix unrecorded |
| `ring` / `aws-lc-sys`: unversioned Android target unsupported | Rewrite Clang `--target=aarch64-linux-android` to API-24 triple using wrappers | Implemented |
| `openssl-sys`: `Text file busy` | Single Cargo job; clean affected build artifacts when needed | Recorded mitigation, not guaranteed fix |
| `codex-code-mode-protocol`: unsupported vendored `protoc` for Android | Use `$PREFIX/bin/protoc` via `build.rs` patch | Implemented |
| `protoc`: missing `absl::lts_20260817::InitializeLogEv` | Check protobuf and Abseil library compatibility | Final repair unrecorded |

The project includes `scripts/build-termux.sh` and the Clang wrappers under `scripts/wrappers/`. They reconstruct the **recorded environment**, but have **not been validated on a clean Termux install**. In particular, the full source patch inventory and any custom Rust linker configuration must be reviewed before describing the build as reproducible.

```sh
pkg update
pkg install git rust clang lld cmake ninja make pkg-config openssl openssl-tool protobuf ndk-sysroot binutils python file
# From the root of the fully patched repository:
chmod +x scripts/build-termux.sh scripts/wrappers/*
./scripts/build-termux.sh
```

The build script does not require `rustup`, because Termux's packaged Rust may use packaged target standard libraries instead. Confirm your `rustc` and `rust-std-aarch64-linux-android` versions match. It also deliberately stops if the `code-mode-protocol/build.rs` layout differs from the recorded version.

### Inspect source changes before publication

```sh
cd ~/src/codex-native
git status --short
git diff --stat
git diff -- codex-rs/ > "$HOME/codex-termux-working-tree.patch"
git ls-files --others --exclude-standard
find codex-rs/.cargo .cargo patches scripts -type f 2>/dev/null
```

`git diff` does **not** include untracked files; inspect the last two commands carefully. Copy the build scripts into your actual source repository and review them. Do not replace upstream source directories with the publishing kit: it contains documentation and scripts, not the complete source tree. Never commit credentials or `~/.codex/auth.json`.

### Record toolchain provenance

The successful environment listed `rust 1.99.1`, `rust-std-aarch64-linux-android 1.99.1`, `clang 21.1.8-3`, and `ndk-sysroot 30` as Termux packages. The ELF reported NDK r30. There is **no verified record of manually compiling Rust or Clang from source** or of a direct NDK download URL. Collect `apt-cache policy rust clang ndk-sysroot` and `dpkg -s` output before asserting a toolchain provenance.

### Release validation checklist

- [x] ARM64 Android ELF created (`/system/bin/linker64`, Android 24)
- [x] `codex --version` prints `codex-cli 0.154.0`
- [x] Backup binary SHA-256 matches original
- [x] Compressed release archive created (96 MB reported)
- [ ] Inspect runtime shared libraries (`readelf -d ... | grep NEEDED`)
- [ ] Test login and a real Codex session on clean Termux
- [ ] Audit and commit every Android source patch, including untracked files
- [ ] Rebuild from a clean checkout using the documented scripts

### Recovered shell-history evidence (build chronology)

- History **156–248**: initial build scripts installed `git rust clang lld make pkg-config openssl openssl-tool perl cmake`, cloned upstream tag `rust-v0.154.0`, and tried a host-default release build. These were **earlier attempts**, not the final build.
- **264–325**: repaired Rust/std mismatch using Termux packages, including `rust-std-aarch64-linux-android`; no evidence of compiling Rust or Clang from their source.
- **293–300**: temporarily renamed `codex-rs/.cargo/config.toml` to `.backup` to isolate build settings. The backup is byte-identical to upstream and contains Windows-only settings; it is **not** an Android configuration. Restoring the original is fine.
- **363–385**: created `~/.local/bin/clang-android24`, which replaces `--target=aarch64-linux-android` with `--target=aarch64-linux-android24`; configured `CC`, `CFLAGS`, `CXXFLAGS`. The repository includes a corresponding C++ wrapper for more consistent builds; the history only directly proves creation of the C wrapper.
- **396–421**: installed `protobuf`, patched `code-mode-protocol/build.rs` to use `PROTOC`, and configured Termux OpenSSL.
- **422–431**: `pkg upgrade -y` was run while diagnosing the Protobuf/Abseil symbol error. Its causal role in the eventual success is **not proven**.
- **466–481**: final observed release profile: jobs=1, incremental=0, LTO=false, codegen-units=16, opt-level=1, debug=0, strip=debuginfo; the Android-target binary was then inspected and `--version` tested.
- **484–497**: inspected ELF dependencies, installed the native binary into `~/.local/bin/codex`, and tried `llvm-strip --strip-debug` on a separate copy. The published backup executable hash refers to the separately verified unstripped build unless a new hash is recorded.

The original `Cargo.lock` changed many local workspace package versions from `0.0.0` to `0.154.0`. Preserve the working lockfile for now, but **do not describe those version changes as Android patches** without further evidence. The committed `code-mode-protocol/build.rs` change is the confirmed Android-specific source modification.

**Source publishing note:** This repository should be published as a fork or a full source checkout containing the modified `codex-rs` workspace, not merely as the small publishing-kit ZIP. The kit does not contain the 7,000+ tracked upstream files. Keep `upstream` pointing to `https://github.com/openai/codex.git` and use a new `origin` for your GitHub fork. If HEAD is detached, create a local branch before committing: `git switch -c android-v0.154.0`.
