#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${CODEX_WORKSPACE:-$ROOT/codex-rs}"
TARGET=aarch64-linux-android
API=24
WRAPPERS="$ROOT/scripts/wrappers"
if [[ ! -f "$WORKSPACE/Cargo.toml" ]]; then
  echo "Missing Cargo workspace: $WORKSPACE" >&2; exit 1
fi
: "${PREFIX:?Run this in Termux with PREFIX set}"
for tool in cargo rustc clang clang++ llvm-ar protoc python; do
  command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 1; }
done
[[ -x "$WRAPPERS/clang-android24" && -x "$WRAPPERS/clangxx-android24" ]] || {
  echo 'Missing executable Clang wrappers in scripts/wrappers' >&2; exit 1;
}
protoc --version || { echo 'protoc failed: check protobuf/abseil compatibility' >&2; exit 1; }
# Termux's packaged Rust may not ship rustup. Check the target by attempting the build,
# rather than requiring rustup unconditionally.
if command -v rustup >/dev/null 2>&1; then
  rustup target list --installed | grep -qx "$TARGET" || {
    echo "Rust target $TARGET is not installed" >&2; exit 1;
  }
fi
export CC="$WRAPPERS/clang-android24"
export CXX="$WRAPPERS/clangxx-android24"
export AR=llvm-ar
export CC_aarch64_linux_android="$CC"
export CXX_aarch64_linux_android="$CXX"
export AR_aarch64_linux_android="$AR"
export CFLAGS="--target=${TARGET}${API} ${CFLAGS:-}"
export CXXFLAGS="--target=${TARGET}${API} ${CXXFLAGS:-}"
export OPENSSL_DIR="$PREFIX" OPENSSL_LIB_DIR="$PREFIX/lib" OPENSSL_INCLUDE_DIR="$PREFIX/include" OPENSSL_NO_VENDOR=1
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_ALLOW_CROSS=1
export PROTOC="$PREFIX/bin/protoc" PROTOC_INCLUDE="$PREFIX/include"
export CARGO_BUILD_JOBS=1 CARGO_INCREMENTAL=0
export CARGO_PROFILE_RELEASE_LTO=false
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16
export CARGO_PROFILE_RELEASE_OPT_LEVEL=1
export CARGO_PROFILE_RELEASE_DEBUG=0
export CARGO_PROFILE_RELEASE_STRIP=debuginfo
# Avoid inheriting unknown global flags, but keep any project .cargo/config.toml intact.
unset RUSTFLAGS CARGO_ENCODED_RUSTFLAGS RUSTC_BOOTSTRAP RUSTUP_TOOLCHAIN || true
cd "$WORKSPACE"
python - <<'PY'
from pathlib import Path
p=Path('code-mode-protocol/build.rs')
if not p.is_file():
    raise SystemExit('Missing code-mode-protocol/build.rs; check upstream revision')
s=p.read_text()
old='config.protoc_executable(protoc_bin_vendored::protoc_bin_path()?);'
new='config.protoc_executable(std::env::var("PROTOC").unwrap_or_else(|_| "protoc".to_string()));'
if old in s:
    p.write_text(s.replace(old,new,1)); print('Applied system protoc patch')
elif 'std::env::var("PROTOC")' in s:
    print('System protoc patch already present')
else:
    raise SystemExit('Unrecognized build.rs: inspect manually; no automatic patch')
PY
printf 'Rust: '; rustc --version
printf 'Cargo: '; cargo --version
printf 'Clang: '; clang --version | head -1
printf 'Protoc: '; protoc --version
# The actual Android source changes and linker settings must exist in the source tree.
# A successful --version is not a full runtime/authentication test.
cargo build --release --target "$TARGET" -p codex-cli -j 1
BIN="${CARGO_TARGET_DIR:-$WORKSPACE/target}/$TARGET/release/codex"
[[ -x "$BIN" ]] || { echo "Expected binary missing: $BIN" >&2; exit 1; }
"$BIN" --version
command -v file >/dev/null && file "$BIN" || true
printf 'Binary: %s\n' "$BIN"
