#!/usr/bin/env bash

try_cd() {
    cd "$1" || { echo "Failed to cd into $1. aborting"; exit 1; }  
}

confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

confirm_yes_default() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure? [Y/n]} " response
    case "$response" in
        [nN][oO]|[nN]) 
            false
            ;;
        *)
            true
            ;;
    esac
}

if ! command -v git &> /dev/null; then
    echo "The git command couldn't be found. Install git first, then re-run the script."
    exit 1
fi

BASE_DIR=$(readlink -f "$(dirname -- "$0")")
r1=$?
CURRENT_PATH=$(pwd)
GIT_PATH=$(command -v git)
r2=$?
if [ $r1 -ne 0 ] || [ $r2 -ne 0 ]; then
    echo "fatal: Failed to set up. dirname exit code: $r1. pwd exit code: $r2"
    exit 1
fi

return_code_neq_failhard() {
    if [ $? -ne "$1" ]; then
        echo "$2"
        try_cd "$CURRENT_PATH"
        exit 1
    fi
}

echo "Base directory is $BASE_DIR"
echo "Git @ $GIT_PATH"

if [ "$#" -lt 2 ]; then
    echo "Syntax: modRemapper.sh modJarfile.jar gameVersion"
    echo "Example: modRemapper.sh modJarfile.jar 1.19.3 # mod compiled for minecraft 1.19.3"
    exit 0
fi

INP_JAR="$1"
GAME_VERSION="$2"
echo "Input jarfile is $INP_JAR"
echo "Game version is $GAME_VERSION"

if [ ! -f "$INP_JAR" ]; then
    echo "fatal: Input jarfile does not exist or is not a file"
    exit 1
fi
if [ -e "$BASE_DIR/mappings" ]; then
    confirm "Mappings directory already exists. Replace? (Recommended yes, mappings might've changed) [Y/n]" && rm -rf "$BASE_DIR/mappings"
fi
if [ -e "$BASE_DIR/tiny-remapper" ]; then
    confirm "Tiny remapper already exists. Re-download? [y/N]" && rm -rf "$BASE_DIR/tiny-remapper"
fi

MAPPINGS_LOC="$BASE_DIR/mappings/build/libs/tmp_out/mappings/mappings.tiny"
if [ ! -e "$BASE_DIR/mappings" ]; then
    echo "[+] Cloning yarn..."
    git clone -b "$GAME_VERSION" "https://github.com/FabricMC/yarn" "$BASE_DIR/mappings"
    return_code_neq_failhard 0 "Failed to clone repository https://github.com/FabricMC/yarn on branch $GAME_VERSION to $BASE_DIR/mappings. Please correct the above error first"

    echo "[+] Building mappings, this might take a while..."
    try_cd "$BASE_DIR/mappings" # we need go to here because of gradle
    if [ ! -f "$BASE_DIR/mappings/gradlew" ] || [ ! -f "$BASE_DIR/mappings/build.gradle" ]; then
        echo "Failed to find gradlew or build.gradle in mappings directory. Not sure how we got here..."
        echo "BASE_DIR=\"$BASE_DIR\""
        try_cd "$CURRENT_PATH"
        exit 1
    fi
    "$BASE_DIR/mappings/gradlew" "clean" "build"
    return_code_neq_failhard 0 "Gradle failed to build. Please correct any errors and re-run the script"

    TARGET_JAR="$BASE_DIR/mappings/build/libs/yarn-$GAME_VERSION+build.local-mergedv2.jar"
    if [ ! -f "$TARGET_JAR" ]; then
        echo "Failed to find target jar $TARGET_JAR. This shouldn't happen, please report this as an issue"
        try_cd "$CURRENT_PATH"
        exit 1
    fi

    unzip "$TARGET_JAR" -d "$BASE_DIR/mappings/build/libs/tmp_out"
    return_code_neq_failhard 0 "Unzip exited with non-zero exit code. Cannot continue"
    if [ ! -f "$MAPPINGS_LOC" ]; then
        echo "Failed to find mappings.tiny at $MAPPINGS_LOC. Can't continue"
        try_cd "$CURRENT_PATH"
        exit 1
    fi

    echo "[+] Done building mappings"
    try_cd "$BASE_DIR" # back to home
fi

if [ ! -d "$BASE_DIR/tiny-remapper" ]; then # we would've deleted this one previously, if we'd want to update it
    echo "[+] Cloning tiny-remapper..."
    git clone "https://github.com/FabricMC/tiny-remapper" "$BASE_DIR/tiny-remapper"
    return_code_neq_failhard 0 "Failed to clone repository https://github.com/FabricMC/tiny-remapper to $BASE_DIR/tiny-remapper. Please correct the above error first"

    echo "[+] Building tiny-remapper..."
    try_cd "$BASE_DIR/tiny-remapper"
    if [ ! -f "$BASE_DIR/tiny-remapper/gradlew" ] || [ ! -f "$BASE_DIR/tiny-remapper/build.gradle" ]; then
        echo "Failed to find gradlew or build.gradle in tiny-remapper directory. Not sure how we got here..."
        try_cd "$CURRENT_PATH"
        exit 1
    fi

    "$BASE_DIR/tiny-remapper/gradlew" "clean" "shadowJar"
    return_code_neq_failhard 0 "Gradle failed to build. Please correct any errors and re-run the script"
fi

TINY_REMAPPER_LOC="$(find "$BASE_DIR/tiny-remapper/build/libs" -name "tiny-remapper-*+local-fat.jar")"
if [ ! -f "$TINY_REMAPPER_LOC" ]; then
    echo "Failed to find tiny-remapper @ $TINY_REMAPPER_LOC. Did you delete it since last time? Try re-downloading tiny-remapper at the start of this script"
    try_cd "$CURRENT_PATH"
    exit 1
fi
echo "[+] Running tiny-remapper"
OUT_JAR="$(dirname "$INP_JAR")/$(basename "$INP_JAR" ".jar")-remapped.jar"
java -jar "$TINY_REMAPPER_LOC" "$INP_JAR" "$OUT_JAR" "$MAPPINGS_LOC" "intermediary" "named"
return_code_neq_failhard 0 "Failed to remap. Not sure how to continue from here..."

echo "[+] Done remapping! Remapped jarfile @ $OUT_JAR"