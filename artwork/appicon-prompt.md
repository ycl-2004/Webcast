# Webcast app icon

Generated with the built-in `image_gen` tool. References are style inputs only; the new subject represents Webcast's video-to-TV casting function.

Production asset: `Webcast/Assets.xcassets/AppIcon.appiconset/appicon-watercolor.png` (1024 × 1024, opaque PNG). The existing `AppIcon` catalog now references this file; iOS applies the outer icon mask. The previous icon is preserved as `artwork/appicon-original.png`.

Validation (2026-10-07): inspected the generated image and its 60 px thumbnail; `sips` confirmed 1024 × 1024 PNG with no alpha channel. Xcode `actool` compiled the iPhone/iPad asset catalog successfully (exit 0), producing `Assets.car` and device icon variants. The catalog filename resolves, the previous icon backup matches the Git version byte-for-byte, and `git diff --check` passed. The sandbox emitted CoreSimulator service/log diagnostics during compilation; asset compilation still completed successfully. This check did not rebuild or install the app, launch Webcast, or control the television.

Phone update follow-up (2026-10-07): at the user's request, `make device-build` produced a signed Release successfully; strict signature verification passed. The built app's 120 px icon was decoded with `sips` and visually confirmed as the new watercolor icon. `devicectl device install app` successfully installed `dev.yc.Webcast` on the connected iPhone 15; the exact-bundle query confirmed version 0.1.1 (2). Webcast was not launched and no television command was sent. The phone home screen itself was not visually inspected. Current installable build: `.build-device/Build/Products/Release-iphoneos/Webcast.app` (ignored by Git).

Style references inspected:
- FoldPeek: `artwork/FoldPeek-AppIcon-master.png`
- Wisp: `Wisp/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png`
- NoType: `App_Icon.png`
- Orbit: `Orbit/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png`

## Final generation prompt

```text
Use case: logo-brand.
Asset type: production iPhone app icon for Webcast, a browser-video-to-TV casting app.
Primary request: Generate ONE new app icon, visually belonging to the same personal app family as the supplied FoldPeek, Wisp, NoType, and Orbit references. References are ONLY style references, not edit targets. Make a new casting illustration.
Input images: Image 1 FoldPeek — watercolor paper texture, dusty blue and muted warm yellow, handmade dark reddish-brown pencil outlines. Image 2 Wisp — simple readable large symbols, cream paper and gentle shallow relief, calm dusty blue and peach. Image 3 NoType — warm pencil outlines and watercolor filling. Image 4 Orbit — cream background, pale blue washes and hand-drawn warm contours. Extract their shared look, not their specific symbols or outer macOS icon tile.
Scene/backdrop: Full-bleed opaque warm ivory watercolor paper fills EVERY pixel of a perfectly square canvas, with a very subtle pale blue watercolor wash behind the subject. No separate tile, no rounded outer container, no outside margin, no dark or transparent corners. iOS applies the icon mask itself.
Subject: A single large simplified modern television with softly rounded rectangular bezel, a pale dusty-blue screen, and two short stable feet. On its screen is one large warm coral-peach right-pointing play triangle. At the LOWER LEFT corner of the TV, naturally integrated into the main silhouette, a small warm golden-orange dot and TWO clear thick quarter-circle wireless casting arcs extend up and right. This corner casting motif communicates wireless video-to-TV; keep it unambiguous and elegantly integrated, not a separate Wi-Fi symbol floating elsewhere. No extra phone, browser tabs, cables, remote, symbols, badge, or decorative stars.
Style/medium: Hand-rendered watercolor and colored pencil on fine cream paper, same craft and restrained warmth as the app references. Gently imperfect dark reddish-brown pencil contours with clean readable shapes, delicate watercolor pigment variation inside shapes, extremely subtle paper-cut depth and shadow. A premium, calm, friendly native utility icon. Closer to FoldPeek and Orbit's watercolor outline language, with Wisp's simplicity. Not glossy plastic, not flat corporate vector art.
Composition/framing: Front-facing television centered, subject occupies roughly 73 percent of canvas width and 61 percent of its height. Balanced overall silhouette; optical centering includes the casting arcs and TV feet. Generous safe area around the main subject. All important details remain recognizable at 60px. Thick confident outlines; simple shapes. No perspective skew.
Color palette: warm ivory cream background, dusty periwinkle/denim blue television, soft coral play triangle, restrained golden amber casting signal, warm oxblood pencil outlines. Muted hues consistent with references, with enough value contrast for phone home-screen size.
Constraints: One icon image only, 1:1 square high-resolution 1024x1024 or larger. Full opaque background. NO text, NO letters (including YC), NO labels, NO watermark, NO grid, NO mockup, NO phone screenshot, NO frame around the canvas, NO pre-rounded outer corners, NO reference contact sheet.
```
