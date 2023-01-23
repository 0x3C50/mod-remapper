#!/usr/bin/env bash

return_code_neq_failhard() {
    if [ $? -ne "$1" ]; then
        echo "$2"
        exit 1
    fi
}

if ! command -v git &> /dev/null; then
    echo "[!] The git command couldn't be found. Install git first, then re-run the script."
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "[!] The curl command couldn't be found. Install curl first, then re-run the script."
    exit 1
fi

if [ "$JAVA_HOME" != "" ]; then
    JAVA_PATH="$JAVA_HOME/bin/java"
else
    JAVA_PATH=$(command -v java)
fi

if [ ! "$JAVA_PATH" ]; then
    echo "[!] Java couldn't be found. Please first install java or set JAVA_HOME, then re-run the script."
    exit 1
fi
if [ ! -f "$JAVA_PATH" ]; then
    echo "[!] $JAVA_HOME points to an invalid JRE installation. Please make sure that $JAVA_HOME/bin/java exists"
    exit 1
fi

BASE_DIR=$(readlink -f "$(dirname -- "$0")")
r1=$?
GIT_PATH=$(command -v git)
r2=$?
if [ $r1 -ne 0 ] || [ $r2 -ne 0 ]; then
    echo "[!] fatal: Failed to set up. dirname exit code: $r1. pwd exit code: $r2"
    exit 1
fi

echo "[#] Base directory is $BASE_DIR"
echo "[#] Git @ $GIT_PATH"
echo "[#] Java @ $JAVA_PATH"

if [ "$#" -lt 2 ]; then
    echo "Syntax: modRemapper.sh modJarfile.jar mappingsToUse"
    echo "Example: modRemapper.sh modJarfile.jar 1.19.3+build.5 # mod compiled for minecraft 1.19.3, use 5th build of mappings. See https://fabricmc.net/develop/"
    exit 0
fi

INP_JAR="$1"
GAME_VERSION="$2"
TMP_DIR=".tmp"
echo "[#] Input jarfile is $INP_JAR"
echo "[#] Game version is $GAME_VERSION"

if [ ! -f "$INP_JAR" ]; then
    echo "[!] fatal: Input jarfile does not exist or is not a file"
    exit 1
fi

MAPPINGS_LOC="$BASE_DIR/$TMP_DIR/mappings/mappings.tiny"
MAPPINGS_URL="https://maven.fabricmc.net/net/fabricmc/yarn/$GAME_VERSION/yarn-$GAME_VERSION-v2.jar"

echo "[+] Getting mappings @ $MAPPINGS_URL ..."
if [ "200" != "$(curl -LI "$MAPPINGS_URL" -o /dev/null -w '%{http_code}\n' -s)" ]; then
    echo "[!] Server returned non-200 code, does the mappings version exist?"
    exit 1
fi

if [ -e "$BASE_DIR/$TMP_DIR" ]; then
    rm -vr "${BASE_DIR:-"."}/${TMP_DIR:-"the_void_aabbcc123123123"}" # be VERY careful here
fi
mkdir -p "$BASE_DIR/$TMP_DIR"
OUT_JF="$BASE_DIR/$TMP_DIR/mappings-$GAME_VERSION.jar"

curl -L --progress-bar "$MAPPINGS_URL" -o "$OUT_JF"
return_code_neq_failhard 0 "[!] Failed to download mappings. Please report this as a bug."

unzip -q "$OUT_JF" -d "$BASE_DIR/$TMP_DIR"

TINY_REMAPPER_LOC="$BASE_DIR/tiny-remapper.jar"
if [ ! -f "$TINY_REMAPPER_LOC" ]; then
    echo "[+] Downloading tiny-remapper..."
    curl -L --progress-bar "https://maven.fabricmc.net/net/fabricmc/tiny-remapper/0.8.6/tiny-remapper-0.8.6-fat.jar" -o "$TINY_REMAPPER_LOC"
    return_code_neq_failhard 0 "[!] Failed to download tiny-remapper. Please report this as a bug."
fi

echo "[+] Running tiny-remapper"
OUT_JAR="$(dirname "$INP_JAR")/$(basename "$INP_JAR" ".jar")-remapped.jar"
"$JAVA_PATH" -jar "$TINY_REMAPPER_LOC" "$INP_JAR" "$OUT_JAR" "$MAPPINGS_LOC" "intermediary" "named"
return_code_neq_failhard 0 "[!] Failed to remap. Not sure how to continue from here..."

echo "[+] Done remapping! Remapped jarfile @ $OUT_JAR"
rm -r "$BASE_DIR/.tmp"