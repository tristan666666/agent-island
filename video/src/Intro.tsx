import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { Background } from "./Background";
import { FusedLogo, Piece } from "./FusedLogo";
import { COLORS } from "./colors";

/// 3-second open: 12 pieces (6 petals + 6 rays) fly in from off-screen with a
/// spring, snap into the fused mark, the gold core pops, then a quick golden
/// halo bloom under "Agent Island".
export const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Each piece gets its own spring keyed off a staggered delay so they don't
  // all land on the same frame.
  const pieces: Piece[] = [];
  // petals (i 0..5) first, then rays (i 6..11)
  for (let i = 0; i < 12; i++) {
    const isPetal = i < 6;
    const angle = isPetal ? 30 + i * 60 : (i - 6) * 60;
    const delay = i * 4; // 4 frames between pieces ≈ 67ms stagger
    const travel = spring({
      fps, frame: frame - delay,
      config: { damping: 14, stiffness: 120, mass: 0.9 },
    });
    const spin = interpolate(travel, [0, 1], [-60, 0]);
    const opacity = interpolate(frame - delay, [0, 6], [0, 1], {
      extrapolateLeft: "clamp", extrapolateRight: "clamp",
    });
    pieces.push({ kind: isPetal ? "petal" : "ray", angle, travel, spin, opacity });
  }

  // Gold core pops in after the pieces settle (~frame 80).
  const corePop = spring({
    fps, frame: frame - 80,
    config: { damping: 11, stiffness: 200, mass: 0.7 },
  });

  // Halo bloom around frame 120 (~2s) — fast ramp up, slow ease down.
  const haloUp = interpolate(frame, [120, 132], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const haloDown = interpolate(frame, [132, 168], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const halo = haloUp * haloDown;

  // Wordmark fades in after the halo peaks.
  const wordmark = interpolate(frame, [136, 160], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const wordmarkY = interpolate(frame, [136, 160], [10, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  // Subtle breathe on the assembled logo (after settle).
  const breathe = 1 + 0.012 * Math.sin(((frame - 90) / fps) * Math.PI * 1.2);

  return (
    <AbsoluteFill>
      <Background />
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
        <div style={{ position: "relative", transform: `scale(${breathe})`, transformOrigin: "center" }}>
          {/* Halo bloom */}
          <div
            style={{
              position: "absolute",
              left: "50%", top: "50%",
              width: 1000, height: 1000,
              transform: `translate(-50%, -50%) scale(${0.6 + halo * 0.6})`,
              borderRadius: "50%",
              background: `radial-gradient(circle, ${COLORS.gold}55 0%, ${COLORS.gold}00 60%)`,
              filter: "blur(40px)",
              opacity: halo,
              pointerEvents: "none",
            }}
          />
          <FusedLogo size={480} pieces={pieces} coreScale={corePop} glowOpacity={0.22} />
        </div>

        <div
          style={{
            marginTop: 32,
            opacity: wordmark,
            transform: `translateY(${wordmarkY}px)`,
            fontFamily: "Inter, -apple-system, system-ui, sans-serif",
            fontWeight: 500,
            fontSize: 44,
            letterSpacing: "0.04em",
            color: COLORS.text,
          }}
        >
          Agent Island
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
