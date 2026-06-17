import { COLORS } from "./colors";

/// The Agent Island fused mark: 6 Codex/OpenAI petals + 6 Claude rays,
/// interleaved at 30° offsets, plus a gold core. Each of the 12 pieces is
/// rendered as its own <g> so the Intro can animate them in independently.
///
/// Props let the Intro drive each piece's offset / opacity / rotation.
export type Piece = {
  kind: "ray" | "petal";
  angle: number;       // resting angle (0..360)
  travel: number;      // 0 = at edge of canvas (off-screen), 1 = locked in
  spin: number;        // extra degrees on top of resting angle
  opacity: number;
};

type Props = {
  size: number;        // px — final logo width
  pieces?: Piece[];    // overrides; if missing, all locked-in at rest
  coreScale?: number;  // 0..1 for the gold center
  glowOpacity?: number;
};

const REST_PIECES: Piece[] = (() => {
  const out: Piece[] = [];
  for (let i = 0; i < 6; i++) out.push({ kind: "petal", angle: 30 + i * 60, travel: 1, spin: 0, opacity: 1 });
  for (let i = 0; i < 6; i++) out.push({ kind: "ray", angle: i * 60, travel: 1, spin: 0, opacity: 1 });
  return out;
})();

export const FusedLogo: React.FC<Props> = ({
  size,
  pieces = REST_PIECES,
  coreScale = 1,
  glowOpacity = 0.18,
}) => {
  const VB = 1024;
  const cx = VB / 2;
  const cy = VB / 2;

  return (
    <svg width={size} height={size} viewBox={`0 0 ${VB} ${VB}`}>
      {/* warm radial glow under the mark */}
      <defs>
        <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
          <stop offset="0" stopColor={COLORS.gold} stopOpacity={glowOpacity} />
          <stop offset="1" stopColor={COLORS.gold} stopOpacity="0" />
        </radialGradient>
      </defs>
      <circle cx={cx} cy={cy} r={VB * 0.42} fill="url(#glow)" />

      {pieces.map((p, i) => {
        // Off-screen radius = travel-out distance from center.
        const flyOutPx = VB * 0.8;
        const r = flyOutPx * (1 - p.travel);
        const rad = (p.angle * Math.PI) / 180;
        const tx = Math.sin(rad) * r;
        const ty = -Math.cos(rad) * r;
        const finalAngle = p.angle + p.spin;
        return (
          <g
            key={i}
            transform={`translate(${tx}, ${ty}) rotate(${finalAngle} ${cx} ${cy})`}
            opacity={p.opacity}
          >
            {p.kind === "ray" ? (
              <polygon
                points={`${cx} ${cy - 416}, ${cx + 16} ${cy - 174}, ${cx} ${cy - 110}, ${cx - 16} ${cy - 174}`}
                fill={COLORS.warm}
              />
            ) : (
              <rect
                x={cx - 32}
                y={cy - 346}
                width={64}
                height={210}
                rx={32}
                fill={COLORS.cool}
              />
            )}
          </g>
        );
      })}

      <circle
        cx={cx}
        cy={cy}
        r={28 * coreScale}
        fill={COLORS.gold}
        opacity={coreScale}
      />
    </svg>
  );
};
