#!/usr/bin/env bash
# ============================================================================
# card_rogue Android APK one-shot build (signature-consistency guard)
#
# Usage:
#     bash release/build_apk.sh R534                # test build -> dist/DuckCardsRogue_R534.apk
#     bash release/build_apk.sh R534 release        # release build -> dist/DuckCardsRogue_release_R534.apk
#     bash release/build_apk.sh                     # test build, no archive -> dist/DuckCardsRogue.apk
#     bash release/build_apk.sh "" release          # release build, no archive
#
# 第二参 = 构建模式：test（默认，全职业·全难度直接可用）/ release（发布版：
# 职业·难度渐进解锁，见 scripts/unlock_system.gd）。两版共用代码与素材，只有
# 导出预设里的 custom_features="cardrogue_release" 区分，`GameBuild.is_release()` 判定。
#
# WHY THIS SCRIPT EXISTS
#   Two machines used to sign with DIFFERENT keystores, so the same package name
#   (com.hanyuu.cardrogue) carried different signatures and Android refused to
#   overwrite-install (INSTALL_FAILED_UPDATE_INCOMPATIBLE).
#
#   This script pins ONE canonical keystore (release/keystore/debug.keystore,
#   tracked in git), syncs it to the fixed path C:/Android/debug.keystore that
#   export_presets.cfg points to, verifies the SHA-256 fingerprint BEFORE
#   building, then exports + signs + verifies. Run it on BOTH machines and both
#   produce the SAME signature -> the APK can always overwrite-install.
#
# EDIT ONLY THIS BLOCK IF A MACHINE'S TOOLCHAIN PATHS DIFFER (see README):
# ============================================================================
WINHOME="$(cygpath -m "$HOME")"
GODOT="$WINHOME/.workbuddy/binaries/godot/Godot_v4.3-stable_win64_console.exe"
JDK="$WINHOME/AndroidDev/jdk-17"
SDK="$WINHOME/AndroidDev/android-sdk"
BUILD_TOOLS="$SDK/build-tools/34.0.0"
APKSIGNER="$BUILD_TOOLS/apksigner.bat"
KEYTOOL="$JDK/bin/keytool.exe"
# ============================================================================

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANON_KS="$ROOT/release/keystore/debug.keystore"   # canonical key, tracked in git
LOCAL_KS="C:/Android/debug.keystore"               # fixed path preset points to
KS_ALIAS="androiddebugkey"
KS_PASS="android"
# canonical SHA-256 fingerprint (lowercase, no colons) -- measured on R533.apk
CANON_SHA256="59651c9b76e61240d1a1223a14635f658fe4d43f15020b3e44cfe22eec6e5baa"

ROUND="${1:-}"
MODE="${2:-test}"   # test（默认，全解锁）/ release（发布版：职业·难度渐进解锁）
case "$MODE" in
  release|Release) MODE=release ;;
  *) MODE=test ;;
esac
PRESET="Android"
[ "$MODE" = "release" ] && PRESET="Android Release"
SFX=""
[ "$MODE" = "release" ] && SFX="_release"
OUT_UNSIGNED="$ROOT/dist/DuckCardsRogue${SFX}.apk"
OUT_SIGNED="$ROOT/dist/DuckCardsRogue${SFX}-signed.apk"

say()  { printf '\n\033[1;36m[build]\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m[build]\033[0m %s\n' "$*"; }
die()  { printf '\n\033[1;31m[build][FATAL]\033[0m %s\n' "$*" >&2; exit 1; }

# fingerprint of a keystore -> lowercase SHA-256 hex (no colons)
sha_of() {
  "$KEYTOOL" -list -v -keystore "$1" -storepass "$KS_PASS" \
    -J-Duser.language=en -J-Dfile.encoding=UTF-8 2>/dev/null \
    | grep -i "SHA256:" | head -1 | sed 's/.*SHA256:[[:space:]]*//' \
    | tr -d ':' | tr 'A-F' 'a-f'
}

# ---- 1/6 toolchain self-check ---------------------------------------------
say "1/6 toolchain self-check"
for f in "$GODOT" "$KEYTOOL" "$APKSIGNER"; do
  [ -f "$f" ] || die "missing tool: $f"
done

# ---- 2/6 sync + verify canonical keystore ----------------------------------
say "2/6 sync canonical keystore"
[ -f "$CANON_KS" ] || die "canonical keystore not in git: $CANON_KS"

CANON_ACTUAL="$(sha_of "$CANON_KS")"
[ "$CANON_ACTUAL" = "$CANON_SHA256" ] \
  || die "canonical keystore fingerprint mismatch: got [$CANON_ACTUAL]"

NEED_SYNC=1
if [ -f "$LOCAL_KS" ]; then
  LOCAL_ACTUAL="$(sha_of "$LOCAL_KS")"
  if [ "$LOCAL_ACTUAL" = "$CANON_SHA256" ]; then
    NEED_SYNC=0
  else
    warn "local key differs (SHA-256 $LOCAL_ACTUAL), replacing with canonical"
  fi
else
  warn "local key missing at $LOCAL_KS, installing canonical"
fi
if [ "$NEED_SYNC" = "1" ]; then
  mkdir -p "C:/Android"
  cp -f "$CANON_KS" "$LOCAL_KS"
fi
say "signature key OK: SHA-256 $CANON_SHA256"

# ---- 3/6 clean old artifacts ----------------------------------------------
say "3/6 clean old artifacts"
rm -f "$OUT_UNSIGNED" "$OUT_UNSIGNED.idsig" "$OUT_SIGNED" "$OUT_SIGNED.idsig"

# ---- 4/6 export (Godot may auto-sign) -------------------------------------
say "4/6 export APK"
export JAVA_HOME="$JDK"
export PATH="$JDK/bin:$BUILD_TOOLS:$PATH"
"$GODOT" --headless --path "$ROOT" --export-release "$PRESET" "$OUT_UNSIGNED" \
  || die "Godot export failed"

# ---- 5/6 ensure signed with canonical key + verify ------------------------
say "5/6 ensure signed with canonical key"

signed_ok=0
if "$APKSIGNER" verify "$OUT_UNSIGNED" >/dev/null 2>&1; then
  CUR_SHA="$("$APKSIGNER" verify --print-certs "$OUT_UNSIGNED" 2>/dev/null \
    | grep -i "SHA-256 digest" | head -1 | sed 's/.*:[[:space:]]*//' \
    | tr -d ':' | tr 'A-F' 'a-f')"
  if [ "$CUR_SHA" = "$CANON_SHA256" ]; then
    signed_ok=1
  else
    warn "export signed with WRONG key ($CUR_SHA), re-signing"
  fi
else
  warn "export not signed, signing manually"
fi

if [ "$signed_ok" = "1" ]; then
  cp -f "$OUT_UNSIGNED" "$OUT_SIGNED"
  say "Godot auto-signed correctly, no manual sign needed"
else
  "$APKSIGNER" sign \
    --ks "$LOCAL_KS" \
    --ks-key-alias "$KS_ALIAS" \
    --ks-pass "pass:$KS_PASS" \
    --key-pass "pass:$KS_PASS" \
    --out "$OUT_SIGNED" \
    "$OUT_UNSIGNED" || die "apksigner sign failed"
fi

"$APKSIGNER" verify -v "$OUT_SIGNED" | grep -iE "Verifies|Verified using" \
  || die "final signature verification failed"

FINAL_SHA="$("$APKSIGNER" verify --print-certs "$OUT_SIGNED" 2>/dev/null \
  | grep -i "SHA-256 digest" | head -1 | sed 's/.*:[[:space:]]*//' \
  | tr -d ':' | tr 'A-F' 'a-f')"
[ "$FINAL_SHA" = "$CANON_SHA256" ] \
  || die "signed APK fingerprint mismatch: got [$FINAL_SHA]"
say "signature verified: SHA-256 $FINAL_SHA"

# ---- 6/6 archive as R<round> ----------------------------------------------
say "6/6 archive (mode=$MODE)"
if [ -n "$ROUND" ]; then
  FINAL="$ROOT/dist/DuckCardsRogue${SFX}_R${ROUND}.apk"
  cp -f "$OUT_SIGNED" "$FINAL"
  rm -f "$OUT_UNSIGNED" "$OUT_SIGNED"
  ls -l "$FINAL"
  say "DONE: $FINAL"
  say "REMINDER: keep only latest + previous in dist/ (delete older _R*.apk)"
else
  cp -f "$OUT_SIGNED" "$OUT_UNSIGNED"
  rm -f "$OUT_SIGNED"
  ls -l "$OUT_UNSIGNED"
  say "DONE: dist/DuckCardsRogue${SFX}.apk (no round given)"
fi
