# Receiver acceptance — 0.1.2 (4)

Status: **core HLS playback/control passed with both a physical iPhone 15 (iOS 26.5) and an iOS 26.5 simulator sender, against a physical Chromecast.** The signed Release **0.1.2 (4)** is installed, developer-trusted and launch-verified on the iPhone, and was restored after the Debug acceptance host. See the [phone receipt](../artifacts/iphone-2026-10-26.json), [phone receiver test](../artifacts/iphone-receiver-2026-10-26.json), and [build 4 record](../artifacts/hardening-2026-10-26.md). Signing expires on 2026-11-02.

The separate manual suite verified SDK discovery, connection, matching HLS load confirmation, advancing position, pause, seek, resume, mute/unmute, stop, restored volume and disconnect. It exercises the same CastManager/MediaLoader as the app. It does not click the browser/device UI or establish human picture/sound confirmation, target-site compatibility, lock-screen behavior, network recovery or sustained playback. A Google-hosted sample MP4 returned HTTP 403 and failed receiver playback; Apple HLS succeeded. Do not classify that source failure as an App playback regression.

The initial missing-profile and developer-trust blockers are resolved: the user authorized the scoped signing/install request and completed trust manually. [Cleanup confirmation](../artifacts/iphone-receiver-cleanup-2026-10-26.json) records receiver standby and restored volume/mute. Rows below distinguish core SDK acceptance from the remaining manual UI/system cases.

Before testing, build a signed Release using the existing local signing configuration. Manual receiver QA requires authorization for that session. `scripts/run_receiver_acceptance.py` requires a receiver ID, destination and `--allow-control`; ordinary tests/CI never run it. The script does not update provisioning resources. Confirm **Settings → About → Version = 0.1.2 (4)** on the phone. Record iOS version, phone model, receiver model/firmware, test time and app version; exclude signed media URLs, cookies and personal device names from shared evidence.

| Check | Expected result | Result |
| --- | --- | --- |
| Discover with Local Network allowed | Same-Wi-Fi receiver appears; select the intended device | SDK discovery/explicit target passed on iPhone; picker UI pending |
| Deny Local Network, then recover | Help opens app Settings; enabling permission and reopening discovery works | Pending |
| Known public HLS and MP4 | TV plays the selected media; local playback pauses only after matching confirmation | HLS SDK playback passed on iPhone; MP4 source 403; browser handoff pending |
| Target site: at least three identified episodes | Record each episode, first cast and episode switch; do not infer support for all site streams | Pending |
| Native player, iframe, next episode | Current badge follows playback; removed frames vanish; surviving iframe remains after parent route | Pending |
| Slow connection, then navigate to another page | Selected media may load on TV; newer local page must keep playing | Pending |
| Same-page A → B → A during connection | Late confirmation must not pause the replacement local playback | Pending |
| Cancel pending cast / dismiss picker while connecting | Connection may finish; queued media must not load | Pending |
| Load failure, retry | Phone remains usable; retry retains original selection context; diagnostics show stage/code/host | Pending |
| Play/pause twice, ±15 s, seek, volume, mute | Each operation has the requested effect; repeated play/pause is idempotent | SDK pause twice, resume, seek 30s, low/restore volume and mute toggle passed; ±15s/physical buttons/UI pending |
| Stop / stop and disconnect | Stop ends media; confirmed disconnect stops the receiver session, including while connecting | SDK stop/disconnect passed after playback; connecting-state case/UI pending |
| Background or lock for 30 s, then return | System controls may disappear; foreground reconnects and refreshes playback/volume | Pending |
| Lock for 5 min | Record receiver playback continuity independently of phone controls; no background-control guarantee | Pending |
| Continuous playback for 1–2 hours | Record interruptions, app responsiveness, observed memory/heat and recovery time; no claim of a power benchmark | Pending |
| Short Wi-Fi interruption | Reconnect or clear error; no stale controls or unexpected new media load | Pending |
| English / Simplified / Traditional Chinese | Status, errors, help and diagnostics use selected language; website/device names are unchanged | Pending |
| iOS 16 device and physical iPad | Launch, navigation, discovery and media flow work on deployment minimum and larger device | Pending |

The app explicitly suspends Cast sessions in the background. It does not request background audio or run a relay. System media command mapping is implemented for an active session; sustained lock-screen control is outside the supported behavior.

On failure, note the exact action and time, and inspect **Settings → Cast diagnostics** before terminating the app. Only the latest 20 problems remain in memory. A numeric SDK code is evidence of that failure, not automatic proof of CORS, DRM or token expiry.

## Manual receiver QA

```sh
python3 scripts/run_receiver_acceptance.py --receiver-id <CAST_DEVICE_ID> \
  --simulator-id <SIMULATOR_ID> --allow-control --result /tmp/receiver-acceptance.xcresult
```

Use `--device-id <IPHONE_UDID>` instead only after local signing is ready. This plays public HLS at low volume and exercises the app's CastManager commands, then stops and restores volume/mute. It skips without a selected receiver when the scheme is run directly. SDK `deviceID` identifies the receiver; `uniqueID` also contains the provider category. Keep device names, UDIDs and raw SDK logs out of shared evidence.

Foreground connection/recovery waits now show an error after 30 seconds and cancel queued media; the SDK can still connect later, without loading the cancelled selection. Verify late recovery and the Stop and disconnect exit on hardware.
