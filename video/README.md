# video/

3-second **intro** + 3-second **outro** for the launch video, built with [Remotion](https://www.remotion.dev). Main 35s body is shot in Screen Studio (see `../docs/launch-shoot.md`); these two clips top-and-tail it.

## Run

```sh
cd video
npm install
npm run dev       # opens Remotion Studio in browser — preview live, scrub frames
npm run intro     # → out/intro.mp4  (3.0s, 1920×1080, 60fps)
npm run outro     # → out/outro.mp4
npm run build     # both
```

## What it looks like

- **Intro** (`src/Intro.tsx`): 12 pieces (6 Claude rays in warm orange + 6 Codex petals in teal) spring in from off-screen with a 4-frame stagger, snap into the fused mark, gold core pops, warm halo bloom under "Agent Island".
- **Outro** (`src/Outro.tsx`): card slides up, wordmark + bilingual tagline + GitHub URL stagger in, QR code pops at the end. Last ~0.5s holds still so viewers can read the link.

Brand colors in `src/colors.ts` match the SwiftUI app's `IslandColor`. Change values there, not inline.

## Stitching

Drop the three pieces onto a Final Cut / CapCut / iMovie timeline in this order:
`intro.mp4` → your Screen Studio body → `outro.mp4`. Crossfade 6 frames between cuts. Lay the Suno track on top.
