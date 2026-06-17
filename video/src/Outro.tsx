import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { QRCodeSVG } from "qrcode.react";
import { Background } from "./Background";
import { FusedLogo } from "./FusedLogo";
import { COLORS } from "./colors";

const URL = "https://github.com/tristan666666/agent-island";

/// 3-second close: small logo slides up, wordmark + tagline + bilingual subline
/// + URL stagger fade in, QR pops at the end. Last 0.5s holds still so viewers
/// can read the link.
export const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const cardIn = spring({ fps, frame, config: { damping: 18, stiffness: 110, mass: 0.9 } });
  const cardY = interpolate(cardIn, [0, 1], [60, 0]);
  const cardOpacity = interpolate(cardIn, [0, 1], [0, 1]);

  const stagger = (start: number) => {
    const o = interpolate(frame, [start, start + 18], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
    const y = interpolate(frame, [start, start + 18], [10, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
    return { opacity: o, transform: `translateY(${y}px)` };
  };

  const wordmark = stagger(18);
  const tagEn = stagger(36);
  const tagZh = stagger(48);
  const url = stagger(70);

  const qr = spring({ fps, frame: frame - 100, config: { damping: 12, stiffness: 200, mass: 0.7 } });

  return (
    <AbsoluteFill>
      <Background />
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
        <div
          style={{
            opacity: cardOpacity,
            transform: `translateY(${cardY}px)`,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 20,
            padding: "48px 72px",
            borderRadius: 24,
            border: `1px solid ${COLORS.gold}33`,
            background: "rgba(255, 255, 255, 0.02)",
            backdropFilter: "blur(10px)",
          }}
        >
          <FusedLogo size={140} glowOpacity={0.14} />

          <div
            style={{
              ...wordmark,
              fontFamily: "Inter, -apple-system, system-ui, sans-serif",
              fontWeight: 500,
              fontSize: 56,
              letterSpacing: "0.02em",
              color: COLORS.text,
              lineHeight: 1,
            }}
          >
            Agent Island
          </div>

          <div
            style={{
              ...tagEn,
              fontFamily: "Inter, -apple-system, system-ui, sans-serif",
              fontWeight: 400,
              fontSize: 20,
              letterSpacing: "0.08em",
              color: COLORS.textMute,
            }}
          >
            YOUR AI NIGHT-WATCH
          </div>

          <div
            style={{
              ...tagZh,
              fontFamily: "PingFang SC, -apple-system, system-ui, sans-serif",
              fontWeight: 400,
              fontSize: 22,
              color: COLORS.textMute,
            }}
          >
            你的 AI 守夜人 · 看用量,自动续跑
          </div>

          <div style={{ display: "flex", alignItems: "center", gap: 24, marginTop: 8 }}>
            <div
              style={{
                ...url,
                fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
                fontSize: 22,
                color: COLORS.gold,
              }}
            >
              github.com/tristan666666/agent-island
            </div>
            <div
              style={{
                transform: `scale(${qr})`,
                padding: 10,
                background: "white",
                borderRadius: 8,
              }}
            >
              <QRCodeSVG value={URL} size={92} level="M" />
            </div>
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
