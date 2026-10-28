#!/usr/bin/env python3
"""Explicit hardware-control QA. Never invoked by the normal test/CI scheme."""
import argparse
import plistlib
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receiver-id", required=True)
    destinations = parser.add_mutually_exclusive_group(required=True)
    destinations.add_argument("--simulator-id")
    destinations.add_argument("--device-id")
    parser.add_argument("--allow-control", action="store_true", required=True,
                        help="Confirm authorization to play public HLS and test this receiver now.")
    parser.add_argument("--result", required=True, help="New .xcresult path")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    build = root / (".build-receiver-device" if args.device_id else ".build-receiver")
    subprocess.run(["make", "generate"], cwd=root, check=True)
    destination = "platform=iOS,id=" + args.device_id if args.device_id else "platform=iOS Simulator,id=" + args.simulator_id
    build_command = ["xcodebuild", "-project", "Webcast.xcodeproj", "-scheme", "WebcastReceiverAcceptance",
                     "-configuration", "Debug", "-destination", destination, "-derivedDataPath", str(build),
                     "-clonedSourcePackagesDirPath", str(root / ".build/OfficialSourcePackages"),
                     "SYMROOT=" + str(build / "Build/Products"), "OBJROOT=" + str(build / "Build/Intermediates.noindex")]
    if not args.device_id:
        build_command.append("CODE_SIGNING_ALLOWED=NO")
    subprocess.run(build_command + ["build-for-testing"], cwd=root, check=True)
    products = build / "Build/Products"
    specifications = list(products.glob("WebcastReceiverAcceptance*.xctestrun"))
    if len(specifications) != 1:
        raise RuntimeError("Expected exactly one receiver test-run specification")
    data = plistlib.loads(specifications[0].read_bytes())
    if "TestConfigurations" in data:
        targets = [target for configuration in data["TestConfigurations"] for target in configuration["TestTargets"]]
    else:
        targets = [value for key, value in data.items() if not key.startswith("__") and isinstance(value, dict)]
    if not targets:
        raise RuntimeError("No test targets in the generated specification")
    for target in targets:
        environment = target.setdefault("EnvironmentVariables", {})
        environment["WEBCAST_CAST_RECEIVER_ID"] = args.receiver_id
        environment["WEBCAST_OFFLINE_VALIDATION"] = "1"
    # Keeping the specification in Products preserves __TESTROOT__ resolution.
    authorized_spec = products / "AuthorizedReceiverAcceptance.xctestrun"
    authorized_spec.write_bytes(plistlib.dumps(data))
    try:
        subprocess.run(["xcodebuild", "test-without-building", "-xctestrun", str(authorized_spec),
                        "-destination", destination, "-resultBundlePath", str(Path(args.result).resolve())],
                       cwd=root, check=True)
    finally:
        authorized_spec.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
