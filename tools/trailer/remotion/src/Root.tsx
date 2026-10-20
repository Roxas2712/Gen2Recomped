import React from "react";
import { Composition } from "remotion";
import { Trailer, TRAILER_FRAMES } from "./Trailer";
import { MapEditorVideo, MAP_EDITOR_FRAMES } from "./MapEditorVideo";
import { PROMOS, PromoVideo, promoFrames } from "./Promos";

export const RemotionRoot: React.FC = () => (
  <>
    <Composition
      id="Trailer"
      component={Trailer}
      durationInFrames={TRAILER_FRAMES}
      fps={30}
      width={1920}
      height={1080}
    />
    <Composition
      id="MapEditor"
      component={MapEditorVideo}
      durationInFrames={MAP_EDITOR_FRAMES}
      fps={30}
      width={1920}
      height={1080}
    />
    {PROMOS.flatMap((p) => [
      <Composition
        key={`${p.id}-Vertical`}
        id={`${p.id}-Vertical`}
        component={PromoVideo}
        defaultProps={{ promo: p, vertical: true }}
        durationInFrames={promoFrames(p)}
        fps={30}
        width={1080}
        height={1920}
      />,
      <Composition
        key={`${p.id}-Wide`}
        id={`${p.id}-Wide`}
        component={PromoVideo}
        defaultProps={{ promo: p, vertical: false }}
        durationInFrames={promoFrames(p)}
        fps={30}
        width={1920}
        height={1080}
      />,
    ])}
  </>
);
