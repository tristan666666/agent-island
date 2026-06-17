import { Composition } from "remotion";
import { Intro } from "./Intro";
import { Outro } from "./Outro";

export const Root: React.FC = () => (
  <>
    <Composition
      id="Intro"
      component={Intro}
      durationInFrames={180}     // 3.0s @ 60fps
      fps={60}
      width={1920}
      height={1080}
    />
    <Composition
      id="Outro"
      component={Outro}
      durationInFrames={180}
      fps={60}
      width={1920}
      height={1080}
    />
  </>
);
