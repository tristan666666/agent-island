import { AbsoluteFill } from "remotion";
import { COLORS } from "./colors";

/// Solid dark gradient backdrop, matches the app's window fill.
export const Background: React.FC = () => (
  <AbsoluteFill
    style={{
      background: `linear-gradient(180deg, ${COLORS.bgTop} 0%, ${COLORS.bgBot} 100%)`,
    }}
  />
);
