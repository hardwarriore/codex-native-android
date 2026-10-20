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

Install the appropriate Termux runtime packages where necessary (for example `openssl` and `liblzma`); . Run `codex --version`, then test authentication and a basic interactive session. 

## Build from source (port maintainer workflow)

**Important:** The original working binary was compiled from a modified upstream source tree. The exact Android-specific changes have not yet been fully inventoried and committed. The commands below describe the known build environment; **they are not a claim that pristine upstream sources compile without the port patches**.

### Install the toolchain

On Termux ARM64:

```sh
pkg update
pkg install git rust clang lld cmake ninja make pkg-config \
  openssl openssl-tool protobuf ndk-sysroot binutils
rustc --version
clang --version
protoc --version
```

The working environment reported Termux `rust 1.99.1`, `clang 21.1.8-3`, `ndk-sysroot 30`, and NDK r30 in the ELF metadata.


### Configure Android tools

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

### Build and verify

Once the tested Android configuration and patches are restored:

```sh
cd codex-rs
cargo build --release --target aarch64-linux-android -p codex-cli -j 1
file target/aarch64-linux-android/release/codex
target/aarch64-linux-android/release/codex --version
```

Expected build metadata: ARM64 ELF PIE, `/system/bin/linker64`, Android API 24, CLI version `0.154.0`.


## Known limitations

- Runtime shared libraries and Termux package versions may differ across devices.
- The upstream Codex sandbox model may not map directly onto Android/Termux permissions.

## License and attribution

Codex originates from [OpenAI's Codex repository](https://github.com/openai/codex). This project is an **unofficial Android port**, not a separately developed replacement for Codex.

## Reconstructed build procedure (October 2026)

The original build ultimately produced a working `codex --version` result. Earlier notes that say the build was still blocked at `protoc` describe an **intermediate** state, not the final release outcome. The exact repair of the protobuf/Abseil runtime mismatch was not recorded. 

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

## Fixes

### Codex Code Mode Host Executable

In the Android/Termux port, `codex-code-mode-host` may already be included in
  the package, but Codex expects it at:

  ```text
  ~/.local/bin/codex-code-mode-host

  Create the required symlink:

  mkdir -p "$HOME/.local/bin"

  ln -sf "$HOME/.codex/packages/standalone/releases/0.154.0-aarch64-unknown-linux-musl/
  bin/codex-code-mode-host" \
    "$HOME/.local/bin/codex-code-mode-host"

  chmod +x "$HOME/.local/bin/codex-code-mode-host"

  Test the installation:

  "$HOME/.local/bin/codex-code-mode-host" --help

  If you see Exec format error, the host binary is not compatible with the
  Android/Termux environment and must be rebuilt for Android/Termux.