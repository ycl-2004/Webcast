#!/usr/bin/env python3
"""Package verified Release builds without personal signing/provisioning data."""
import argparse
import hashlib
import json
import plistlib
import shutil
import subprocess
import tempfile
from pathlib import Path

from verify_bundle import require, verify


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT).strip()


def inspect(app, platform):
    result = verify(app)
    info = plistlib.loads((app / "Info.plist").read_bytes())
    require(info["DTPlatformName"] == platform, "Unexpected platform: " + str(app))
    require(not list(app.rglob("*.mobileprovision")), "Personal provisioning profile in bundle")
    require(not (app / "_CodeSignature").exists(), "Expected unsigned input app")
    result["architectures"] = run("xcrun", "lipo", "-archs", str(app / "Webcast")).split()
    result.pop("result")
    return result


def archive(source, destination):
    subprocess.run(["ditto", "-c", "-k", "--norsrc", "--noextattr", "--noqtn",
                    "--keepParent", str(source), str(destination)], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator-app", type=Path,
                        default=Path(".build/Build/Products/Release-iphonesimulator/Webcast.app"))
    parser.add_argument("--device-app", type=Path,
                        default=Path(".build-device/Build/Products/Release-iphoneos/Webcast.app"))
    parser.add_argument("--cast-sdk", type=Path,
                        default=Path(".build/OfficialSourcePackages/artifacts/googlecast/GoogleCast"))
    parser.add_argument("--output", type=Path, default=Path("artifacts/Release/v0.1.2"))
    args = parser.parse_args()
    simulator = inspect(args.simulator_app, "iphonesimulator")
    device = inspect(args.device_app, "iphoneos")
    require((simulator["version"], simulator["build"]) == (device["version"], device["build"]),
            "Simulator and device versions differ")
    version = device["version"]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    names = [f"Webcast-{version}-iOS-unsigned.ipa", f"Webcast-{version}-Simulator.zip",
             f"Webcast-{version}-ThirdPartyNotices.zip", "release-manifest.json", "SHA256SUMS"]
    require(not any((output / name).exists() for name in names),
            "Output artifacts already exist; use a new output directory")
    with tempfile.TemporaryDirectory(prefix="webcast-release-") as temp:
        staging = Path(temp)
        payload = staging / "Payload"
        payload.mkdir()
        shutil.copytree(args.device_app, payload / "Webcast.app", symlinks=True)
        archive(payload, output / names[0])
        sim_app = staging / "Webcast.app"
        shutil.copytree(args.simulator_app, sim_app, symlinks=True)
        for framework in sorted((sim_app / "Frameworks").glob("*.framework")):
            run("codesign", "--force", "--sign", "-", str(framework))
        run("codesign", "--force", "--sign", "-", str(sim_app))
        run("codesign", "--verify", "--deep", "--strict", str(sim_app))
        archive(sim_app, output / names[1])
        notices = staging / f"GoogleCast-4.8.6"
        shutil.copytree(args.cast_sdk / "OpenSourceLicenses", notices / "OpenSourceLicenses")
        archive(notices, output / names[2])
    files = run("git", "ls-files", "Webcast", "Packages", "project.yml", "Package.resolved").splitlines()
    product_hashes = {name: hashlib.sha256(Path(name).read_bytes()).hexdigest() for name in files}
    manifest = {
        "product": "Webcast", "version": version, "build": device["build"],
        "sourceCommit": run("git", "rev-parse", "HEAD"),
        "toolchain": run("xcodebuild", "-version").splitlines(),
        "device": {**device, "signing": "unsigned; requires the user's own signing before installation"},
        "simulator": {**simulator, "signing": "ad-hoc; no Apple account identity"},
        "productFileSHA256": product_hashes,
        "artifacts": names[:3],
    }
    (output / names[3]).write_text(json.dumps(manifest, indent=2) + "\n")
    checksums = [hashlib.sha256((output / name).read_bytes()).hexdigest() + "  " + name
                 for name in names[:-1]]
    (output / names[4]).write_text("\n".join(checksums) + "\n")
    print(json.dumps({"version": version, "build": device["build"], "output": str(output),
                      "artifacts": names}, indent=2))


if __name__ == "__main__":
    main()
