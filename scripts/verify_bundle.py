#!/usr/bin/env python3
"""Validate a built Release bundle, rather than assuming source settings were packaged."""
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(app):
    with (app / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    require(info.get("WebcastBuildConfiguration") == "Release", "Expected a Release app")
    require(info.get("NSLocalNetworkUsageDescription"), "Local Network explanation is missing")
    require({"_googlecast._tcp", "_CC1AD845._googlecast._tcp"}.issubset(info.get("NSBonjourServices", [])),
            "Cast Bonjour declarations are incomplete")
    with (app / "PrivacyInfo.xcprivacy").open("rb") as handle:
        privacy = plistlib.load(handle)
    reasons = {entry["NSPrivacyAccessedAPIType"]: entry["NSPrivacyAccessedAPITypeReasons"]
               for entry in privacy.get("NSPrivacyAccessedAPITypes", [])}
    require("CA92.1" in reasons.get("NSPrivacyAccessedAPICategoryUserDefaults", []),
            "App UserDefaults reason is missing")
    require(privacy.get("NSPrivacyTracking") is False, "Unexpected tracking declaration")
    require((app / "Frameworks/GoogleCast.framework/PrivacyInfo.xcprivacy").is_file(),
            "Cast SDK privacy manifest is missing")
    # A successful link does not catch duplicate Objective-C classes across dynamic images.
    # The upstream 4.8.6 wrapper added GTMSessionFetcher despite it being inside GoogleCast.
    owners = {}
    binaries = [app / info["CFBundleExecutable"]]
    for framework in (app / "Frameworks").glob("*.framework"):
        with (framework / "Info.plist").open("rb") as handle:
            executable = plistlib.load(handle)["CFBundleExecutable"]
        binaries.append(framework / executable)
    for path in binaries:
        # Stripped SDKs can hide class symbols from nm while retaining runtime metadata.
        metadata = subprocess.run(["xcrun", "otool", "-ov", str(path)], check=True,
                                  capture_output=True, text=True).stdout.splitlines()
        classes = set()
        in_class_list = False
        for line in metadata:
            if line.startswith("Contents of "):
                in_class_list = ",__objc_classlist)" in line
            match = re.match(r"^        name\s+0x[0-9a-fA-F]+\s+(\S+)$", line)
            if in_class_list and match:
                classes.add(match.group(1))
        require(classes, "Could not inspect Objective-C runtime classes: " + path.name)
        for symbol in sorted(classes):
            require(symbol not in owners, "Duplicate Objective-C class: " + symbol)
            owners[symbol] = path
    for language in ["en", "zh-Hant"]:
        require((app / f"{language}.lproj/Localizable.strings").is_file(), "Missing UI localization: " + language)
        require((app / f"{language}.lproj/InfoPlist.strings").is_file(), "Missing permission localization: " + language)
    require("audio" not in info.get("UIBackgroundModes", []), "Unexpected background audio capability")
    require((app / "sniff.js").stat().st_size > 0, "Video detection script is missing or empty")
    binary = (app / info["CFBundleExecutable"]).read_bytes()
    for marker in [b"WEBCAST_OFFLINE_VALIDATION", b"WEBCAST_DEMO", b"[GCK]", b"openDemo", b"debugTools"]:
        require(marker not in binary, "Debug marker in Release executable: " + marker.decode())
    require(not list(app.rglob("*.xctest")), "Release app contains a test bundle")
    require(not list(app.rglob("*.debug.dylib")), "Release app contains a debug library")
    return {"bundle": info["CFBundleIdentifier"], "configuration": "Release", "result": "Passed",
            "version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"],
            "noDuplicateObjCClasses": True, "uiAndPermissionLocalizations": True,
            "appPrivacyManifest": True, "castPrivacyManifest": True, "snifferScript": True}


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python3 scripts/verify_bundle.py path/to/Webcast.app")
    try:
        print(json.dumps(verify(Path(sys.argv[1])), indent=2))
    except (OSError, ValueError, KeyError, plistlib.InvalidFileException, subprocess.CalledProcessError) as error:
        sys.exit("Release bundle validation failed: " + str(error))
