# Confirm receiver playback before pausing the browser

Status: accepted in source, receiver acceptance pending. Date: 2026-10-18.

The phone used to pause all web media as soon as a Cast load request was sent. A failed request therefore interrupted the working local video. Request completion also did not establish that the receiver was playing the selected media.

The sender now keeps a small `CastLoadState` for the current attempt. A new UUID distinguishes retries and superseded requests. Confirmation requires both a request acknowledgement and a playing/paused receiver status identifying the complete requested URL. Buffering, unrelated media and unidentified error statuses do not confirm or fail a new attempt. A matching runtime playback failure can offer a retry; no error is classified as CORS/DRM/token expiry without evidence.

The browser arms a handoff with the attempt UUID, document UUID and page URL. Confirmation pauses local media only if all still match. Reload, navigation, website-data clear and session reset invalidate the handoff. This prevents a late receiver event from pausing unrelated content.

Loading UI expires after 45 seconds, enabling retry. A late matching acknowledgement/status may still confirm the same attempt; a new attempt or session reset invalidates old callbacks. Request cancellation is treated as stopping sender-side tracking, not proof that the receiver stopped processing.

The choice favors preserving a working phone player on failure. Phone and TV audio may briefly overlap until the receiver status arrives. Exact URL matching may leave the phone playing if a receiver changes the content identifier; this requires physical acceptance rather than speculative URL rewriting that could damage signed streams.

The value-type state, browser handoff and SDK `applicationRequest()` callbacks are tested without a Cast context or receiver. They establish local transition behavior, not actual receiver playback, lock-screen command delivery or network recovery.

Sources:

- [Google Cast request lifecycle](https://developers.google.com/cast/docs/reference/ios/interface_g_c_k_request)
- [Receiver-reported media status](https://developers.google.com/cast/docs/reference/ios/interface_g_c_k_remote_media_client)
