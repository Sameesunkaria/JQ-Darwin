#!/usr/bin/env zsh

# Script setup
set -e
trap 'echo "Build did not finish successfully."' ERR

BASEDIR=${PWD}


# Checking requirements
echo "Checking requirements"
check_requirement() {
    command -v $1 >/dev/null 2>&1 || {
        echo >&2 "Please install '$1', it is required for compiling jq."
        exit 1
    }
}

check_requirement git
check_requirement libtool
check_requirement make
check_requirement automake
check_requirement autoconf
check_requirement swift


# Checking out submodules
echo "Checking out submodules"
git submodule update --init --recursive


# Build setup.
echo "Starting build"
unset CFLAGS
unset CXXFLAGS
unset LDFLAGS

# Setting the ZERO_AR_DATE env var to avoid embedding timestamps in
# the generated lib, allowing for reproducible builds.
export ZERO_AR_DATE=1

MAKEJOBS="$(sysctl -n hw.ncpu || echo 1)"
CC="$(xcrun -f clang || echo clang)"

cd "${BASEDIR}/jq"
[[ ! -f ./configure ]] && autoreconf -fi


# Removes math flags for the given function from the makefile.
remove_math_flag() {
    MATH_FUNC=$1;
    sed -i'' -e "s/-DHAVE_${MATH_FUNC}=1//g" Makefile
}


# Removes depricated math functions.
# HACK: Required for catalyst builds as configure is able to see these
# functions for macos but they are marked as unavailable on iOS hence
# unavailable while building for catalyst.
disable_deprecated_functions() {
    remove_math_flag "SIGNIFICAND"
    remove_math_flag "GAMMA"
    remove_math_flag "DREM"
}


# Build oniguruma and jq.
build() {
    ARCH=$1; SDK=$2; TARGET=$3
    HOST="${ARCH}-apple-darwin"

    # HACK: The SDK path seems to be embedded into the generated lib.
    # This presents a hurdle to ensure reproducible build, as Xcode
    # must be located in the same directory to achieve an equivalent
    # binary. To work around this, the SDK is symlinked in /tmp.
    rm -f /tmp/${SDK}
    ln -s $(xcrun -f --sdk ${SDK} --show-sdk-path) /tmp/${SDK}
    SDK_PATH=/tmp/${SDK}

    # HACK: autoconf config.sub does not support arm64_32
    [[ "${ARCH}" = "arm64_32" ]] && HOST="arm64-apple-darwin"

    # Make sure all paths are relative to ensure reproducible builds.
    CFLAGS="-O2 -isysroot ${SDK_PATH} -target ${TARGET} -D_REENTRANT -fembed-bitcode -no-canonical-prefixes"
    LDFLAGS="-isysroot ${SDK_PATH}"

    # build oniguruma
    cd "${BASEDIR}/jq/modules/oniguruma"
    CC=${CC} CFLAGS=${CFLAGS} LDFLAGS=${LDFLAGS} \
    ./configure \
        --host=${HOST} \
        --enable-shared=no \
        --enable-static=yes \
        --prefix=''
    make -j${MAKEJOBS} install DESTDIR="${BASEDIR}/Products/oniguruma/${TARGET}"
    make clean

    # build jq
    cd "${BASEDIR}/jq"
    CC=${CC} CFLAGS=${CFLAGS} LDFLAGS=${LDFLAGS} \
    ./configure \
        --host=${HOST} \
        --enable-docs=no \
        --enable-shared=no \
        --enable-static=yes \
        --prefix='' \
        --with-oniguruma=../Products/oniguruma/${TARGET} \
        --disable-maintainer-mode
    disable_deprecated_functions
    make -j${MAKEJOBS} install DESTDIR="${BASEDIR}/Products/jq/${TARGET}"
    make clean
}


# Generates a universal binary for the given targets
lipo_targets() {
    DEST_NAME=$1; shift; TARGETS=("$@")
    echo "lipo for target ${DEST_NAME}"
    mkdir -p ${BASEDIR}/Products/libs/${DEST_NAME}/oniguruma
    mkdir -p ${BASEDIR}/Products/libs/${DEST_NAME}/jq

    # Generating lipo command string
    LIPO_CMD_ONIG="lipo -create -output ${BASEDIR}/Products/libs/${DEST_NAME}/oniguruma/libonig.a"
    LIPO_CMD_JQ="lipo -create -output ${BASEDIR}/Products/libs/${DEST_NAME}/jq/libjq.a"
    for target in "${TARGETS[@]}"; do
        LIPO_CMD_ONIG+=" ${BASEDIR}/Products/oniguruma/${target}/lib/libonig.a"
        LIPO_CMD_JQ+=" ${BASEDIR}/Products/jq/${target}/lib/libjq.a"
    done
    # Evaluating the lipo command
    eval ${LIPO_CMD_ONIG}
    eval ${LIPO_CMD_JQ}

    mkdir -p ${BASEDIR}/Products/libs/${DEST_NAME}/jq/include/Cjq
    cp -r ${BASEDIR}/Products/jq/${TARGETS[1]}/include/* ${BASEDIR}/Products/libs/${DEST_NAME}/jq/include/Cjq
    cp ${BASEDIR}/jq.modulemap ${BASEDIR}/Products/libs/${DEST_NAME}/jq/include/Cjq/module.modulemap

    mkdir -p ${BASEDIR}/Products/libs/${DEST_NAME}/oniguruma/include/Coniguruma
    cp -r ${BASEDIR}/Products/oniguruma/${TARGETS[1]}/include/oniguruma.h ${BASEDIR}/Products/libs/${DEST_NAME}/oniguruma/include/Coniguruma
    cp ${BASEDIR}/oniguruma.modulemap ${BASEDIR}/Products/libs/${DEST_NAME}/oniguruma/include/Coniguruma/module.modulemap
}


# Building jq and oniguruma for all supported apple targets.
echo "Building"
# iOS
build "armv7"    "iphoneos"          "armv7-apple-ios9.0"
build "armv7s"   "iphoneos"          "armv7s-apple-ios9.0"
build "arm64"    "iphoneos"          "arm64-apple-ios9.0"
build "i386"     "iphonesimulator"   "i386-apple-ios9.0-simulator"
build "x86_64"   "iphonesimulator"   "x86_64-apple-ios9.0-simulator"
build "arm64"    "iphonesimulator"   "arm64-apple-ios9.0-simulator"
build "x86_64"   "macosx"            "x86_64-apple-ios13.0-macabi"
build "arm64"    "macosx"            "arm64-apple-ios13.0-macabi"
# macOS
build "x86_64"   "macosx"            "x86_64-apple-macos10.10"
build "arm64"    "macosx"            "arm64-apple-macos11.0"
# watchOS
build "armv7k"   "watchos"           "armv7k-apple-watchos2.0"
build "arm64_32" "watchos"           "arm64_32-apple-watchos5.0"
build "x86_64"   "watchsimulator"    "x86_64-apple-watchos2.0-simulator"
build "arm64"    "watchsimulator"    "arm64-apple-watchos2.0-simulator"
# tvOS
build "arm64"    "appletvos"         "arm64-apple-tvos9.0"
build "x86_64"   "appletvsimulator"  "x86_64-apple-tvos9.0-simulator"
build "arm64"    "appletvsimulator"  "arm64-apple-tvos9.0-simulator"


# Generating universal binaries for targets representing equivalent library definitions
echo "Generating required universal binaries"
lipo_targets "ios"               "armv7-apple-ios9.0" "armv7s-apple-ios9.0" "arm64-apple-ios9.0"
lipo_targets "ios-simulator"     "i386-apple-ios9.0-simulator" "x86_64-apple-ios9.0-simulator" "arm64-apple-ios9.0-simulator"
lipo_targets "ios-macabi"        "x86_64-apple-ios13.0-macabi" "arm64-apple-ios13.0-macabi"
lipo_targets "macos"             "x86_64-apple-macos10.10" "arm64-apple-macos11.0"
lipo_targets "watchos"           "armv7k-apple-watchos2.0" "arm64_32-apple-watchos5.0"
lipo_targets "watchos-simulator" "x86_64-apple-watchos2.0-simulator" "arm64-apple-watchos2.0-simulator"
lipo_targets "tvos"              "arm64-apple-tvos9.0"
lipo_targets "tvos-simulator"    "x86_64-apple-tvos9.0-simulator" "arm64-apple-tvos9.0-simulator"


# Generating xcframeworks
echo "Generating XCFrameworks"
cd ${BASEDIR}
XCFRAMEWORK_CMD_JQ="xcodebuild -create-xcframework -output ${BASEDIR}/Products/frameworks/Cjq.xcframework"
XCFRAMEWORK_CMD_ONIG="xcodebuild -create-xcframework -output ${BASEDIR}/Products/frameworks/Coniguruma.xcframework"
for target in ios ios-simulator ios-macabi macos watchos watchos-simulator tvos tvos-simulator; do
    XCFRAMEWORK_CMD_JQ+=" -library ${BASEDIR}/Products/libs/${target}/jq/libjq.a -headers ${BASEDIR}/Products/libs/${target}/jq/include"
    XCFRAMEWORK_CMD_ONIG+=" -library ${BASEDIR}/Products/libs/${target}/oniguruma/libonig.a -headers ${BASEDIR}/Products/libs/${target}/oniguruma/include"
done

eval ${XCFRAMEWORK_CMD_JQ}
eval ${XCFRAMEWORK_CMD_ONIG}

# Sorting contents of Info.plist inside the xcframeworks
swift ${BASEDIR}/ReorderPlist.swift \
    ${BASEDIR}/Products/frameworks/Cjq.xcframework/Info.plist \
    ${BASEDIR}/Products/frameworks/Coniguruma.xcframework/Info.plist

# Copying over the licenses
cp ${BASEDIR}/jq/COPYING ${BASEDIR}/Products/frameworks/Cjq.xcframework/COPYING
cp ${BASEDIR}/jq/modules/oniguruma/COPYING ${BASEDIR}/Products/frameworks/Coniguruma.xcframework/COPYING


# Compressing xcframeworks
echo "Compressing XCFrameworks"
cd ${BASEDIR}/Products/frameworks
# HACK: Setting the timestamps on all files to a fixed value
# allowing for reproducible zip files.
find Cjq.xcframework -exec touch -t 202101010000 {} +
find Coniguruma.xcframework -exec touch -t 202101010000 {} +
zip -r -X Cjq.xcframework.zip Cjq.xcframework/ -x "*.DS_Store"
zip -r -X Coniguruma.xcframework.zip Coniguruma.xcframework/ -x "*.DS_Store"


# Finishing
echo "Build successful."
echo "Build artifacts at ${BASEDIR}/Products"
echo "Frameworks can be found under ${BASEDIR}/Products/frameworks"
echo "Framework checksums"
shasum -a 1 ${BASEDIR}/Products/frameworks/Cjq.xcframework.zip
shasum -a 1 ${BASEDIR}/Products/frameworks/Coniguruma.xcframework.zip
