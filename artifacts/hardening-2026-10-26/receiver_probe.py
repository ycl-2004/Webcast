"""Manual receiver-only QA. Requires an explicit receiver name; never run from CI."""
import json
import sys
import time
from pathlib import Path

import pychromecast

receiver_name, output = sys.argv[1:]
streams = [
    ("HLS", "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8", "application/x-mpegurl"),
]
report = {"scope": "receiver protocol test from macOS Python, not the iOS app", "checks": []}
casts, browser = pychromecast.get_listed_chromecasts(friendly_names=[receiver_name], discovery_timeout=12)
cast = None
own_media = False
original_volume = None
original_muted = None


def check(name, predicate, timeout=20):
    started = time.monotonic()
    while time.monotonic() - started < timeout:
        cast.media_controller.update_status()
        if predicate():
            report["checks"].append({"name": name, "result": "passed", "seconds": round(time.monotonic() - started, 2)})
            return
        time.sleep(0.4)
    raise RuntimeError(f"{name} timed out; state={cast.media_controller.status.player_state}")


try:
    if len(casts) != 1:
        raise RuntimeError("Expected exactly one matching receiver")
    cast = casts[0]
    cast.wait(timeout=12)
    report["connected"] = True
    report["model"] = cast.cast_info.model_name
    report["initialAppID"] = cast.status.app_id
    if not cast.status.is_stand_by:
        raise RuntimeError("Receiver is not in standby; no playback takeover attempted")
    original_volume, original_muted = cast.status.volume_level, cast.status.volume_muted
    cast.set_volume(0.08)
    mc = cast.media_controller
    for label, url, mime in streams:
        own_media = True
        mc.play_media(url, mime, title="Webcast public-media acceptance", stream_type="BUFFERED")
        check(label + " playing", lambda: mc.status.content_id == url and mc.status.player_state == "PLAYING", 35)
        before = mc.status.current_time
        check(label + " position advancing", lambda: mc.status.current_time > before + 1)
        mc.pause()
        check(label + " paused", lambda: mc.status.player_state == "PAUSED")
        mc.seek(30)
        check(label + " seek", lambda: abs(mc.status.current_time - 30) < 4)
        mc.play()
        check(label + " resumed", lambda: mc.status.player_state == "PLAYING")
        cast.set_volume(0.10)
        check(label + " volume", lambda: abs(cast.status.volume_level - 0.10) < 0.02)
        cast.set_volume_muted(True)
        check(label + " muted", lambda: cast.status.volume_muted)
        cast.set_volume_muted(False)
        check(label + " unmuted", lambda: not cast.status.volume_muted)
        mc.stop()
        check(label + " stopped", lambda: mc.status.player_state == "IDLE")
    report["result"] = "passed"
except Exception as error:
    report["result"] = "failed"
    report["error"] = str(error)
finally:
    if cast:
        try:
            # Only clean up the receiver app/media started by this probe.
            if own_media and cast.status.app_id == "CC1AD845":
                cast.media_controller.stop()
                check("cleanup media stopped", lambda: cast.media_controller.status.player_state == "IDLE")
                cast.quit_app()
            if original_volume is not None:
                cast.set_volume(original_volume)
                cast.set_volume_muted(original_muted)
                check("original volume/mute restored", lambda: abs(cast.status.volume_level - original_volume) < 0.02 and cast.status.volume_muted == original_muted)
            report["cleanup"] = "passed"
        except Exception as error:
            report["cleanup"] = str(error)
        cast.disconnect()
    pychromecast.discovery.stop_discovery(browser)
    Path(output).write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))

sys.exit(0 if report.get("result") == "passed" and report.get("cleanup") == "passed" else 1)
