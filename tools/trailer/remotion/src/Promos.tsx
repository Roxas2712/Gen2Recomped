// The social promos: one beat list per video, rendered both 9:16 (TikTok,
// Reels, Shorts) and 16:9 (YouTube, X). The shot list and the post copy are
// tools/trailer/PROMOS.md.
//
// Footage goes in public/promo/<name>.mp4. A shot that is not recorded yet
// shows a slate naming the file it wants, so the cut can be timed in the
// studio before everything is captured.
//
//   npx remotion studio src/index.ts
//   npx remotion render src/index.ts Walker-Vertical out/walker_vertical.mp4 --crf 16
//
// Optional music: drop public/promo/music_<id>.mp3 and it is picked up.
import React from "react";
import {
  AbsoluteFill,
  Audio,
  getStaticFiles,
  interpolate,
  OffthreadVideo,
  Sequence,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { GOLD, INK, Logo, PIXEL, SANS, useEdgeFade } from "./Trailer";

const FPS = 30;
const s = (sec: number) => Math.round(sec * FPS);

const DISCORD = "discord.gg/4VXnEnePT";
const TILT = "tiltrips.com/r/GEN2RECOMP";

const hasFile = (path: string) => getStaticFiles().some((f) => f.name === path);

// ----------------------------------------------------------- building blocks

type Shot = {
  kind: "shot";
  file: string; // public/promo/<file>.mp4
  sec: number;
  from?: number; // seconds into the clip
  rate?: number; // playback rate, to squeeze a long take
  hook?: string; // big text at the top
  label?: string; // chip at the bottom
  // zoom into part of the frame for the vertical cut: scale and focus (0..1)
  focus?: { scale: number; x: number; y: number };
};
type Title = { kind: "title"; sec: number; top?: string; big: string; sub?: string };
type End = { kind: "end"; sec: number; line: string };
type Beat = Shot | Title | End;

export type Promo = { id: string; beats: Beat[] };

const Slate: React.FC<{ file: string }> = ({ file }) => (
  <AbsoluteFill style={{ backgroundColor: "#1b2236", justifyContent: "center", alignItems: "center" }}>
    <div style={{ fontFamily: PIXEL, fontSize: 28, color: GOLD }}>RECORD</div>
    <div style={{ fontFamily: SANS, fontSize: 40, color: "white", marginTop: 20, fontWeight: 700 }}>
      promo/{file}.mp4
    </div>
    <div style={{ fontFamily: SANS, fontSize: 24, color: "#9aa7c7", marginTop: 14 }}>see tools/trailer/PROMOS.md</div>
  </AbsoluteFill>
);

const Footage: React.FC<{ b: Shot; dur: number; vertical: boolean }> = ({ b, dur, vertical }) => {
  const f = useCurrentFrame();
  const path = `promo/${b.file}.mp4`;
  if (!hasFile(path)) return <Slate file={b.file} />;
  const push = interpolate(f, [0, dur], [1, 1.03]);
  const video = (style: React.CSSProperties) => (
    <OffthreadVideo
      src={staticFile(path)}
      startFrom={s(b.from ?? 0)}
      playbackRate={b.rate ?? 1}
      muted
      style={style}
    />
  );
  if (!vertical) {
    return video({ width: "100%", height: "100%", objectFit: "cover", transform: `scale(${push})` });
  }
  // vertical: the same clip blurred behind, the sharp clip in a tall window
  const z = b.focus ?? { scale: 1.6, x: 0.5, y: 0.5 };
  return (
    <AbsoluteFill>
      {video({ width: "100%", height: "100%", objectFit: "cover", filter: "blur(40px) brightness(0.45)" })}
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center" }}>
        <div style={{ width: 1080, height: 1080, overflow: "hidden", borderRadius: 24 }}>
          {video({
            width: "100%",
            height: "100%",
            objectFit: "cover",
            objectPosition: `${z.x * 100}% ${z.y * 100}%`,
            transform: `scale(${(z.scale / 1.6) * push})`,
            transformOrigin: `${z.x * 100}% ${z.y * 100}%`,
          })}
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

const Hook: React.FC<{ text: string; vertical: boolean }> = ({ text, vertical }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: f, fps, config: { damping: 14 } });
  return (
    <AbsoluteFill style={{ alignItems: "center", padding: vertical ? "230px 60px 0" : "70px 120px 0" }}>
      <div
        style={{
          fontFamily: SANS,
          fontWeight: 800,
          fontSize: vertical ? 76 : 64,
          lineHeight: 1.1,
          color: "white",
          textAlign: "center",
          textShadow: "0 6px 24px rgba(0,0,0,0.9), 4px 4px 0 #000",
          transform: `scale(${0.85 + 0.15 * p})`,
          opacity: p,
        }}
      >
        {text}
      </div>
    </AbsoluteFill>
  );
};

const Chip: React.FC<{ text: string; vertical: boolean }> = ({ text, vertical }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: f, fps, config: { damping: 200 } });
  return (
    <AbsoluteFill
      style={{
        justifyContent: "flex-end",
        alignItems: "center",
        paddingBottom: vertical ? 300 : 60,
      }}
    >
      <div
        style={{
          opacity: p,
          transform: `translateY(${(1 - p) * 24}px)`,
          background: "rgba(11,15,26,0.9)",
          border: `3px solid ${GOLD}`,
          borderRadius: 14,
          padding: "16px 28px",
          fontFamily: PIXEL,
          fontSize: vertical ? 30 : 26,
          color: "white",
        }}
      >
        {text}
      </div>
    </AbsoluteFill>
  );
};

const TitleCard: React.FC<{ b: Title; dur: number; vertical: boolean }> = ({ b, dur, vertical }) => {
  const opacity = useEdgeFade(dur, 6);
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: f, fps, config: { damping: 12 } });
  return (
    <AbsoluteFill style={{ backgroundColor: INK, justifyContent: "center", alignItems: "center", opacity, padding: 60 }}>
      {b.top ? <div style={{ fontFamily: PIXEL, fontSize: 32, color: GOLD, letterSpacing: 4 }}>{b.top}</div> : null}
      <div
        style={{
          fontFamily: PIXEL,
          fontSize: vertical ? 64 : 80,
          lineHeight: 1.3,
          color: "white",
          textAlign: "center",
          marginTop: 28,
          textShadow: "6px 6px 0 #000",
          transform: `scale(${0.8 + 0.2 * p})`,
        }}
      >
        {b.big}
      </div>
      {b.sub ? (
        <div style={{ fontFamily: SANS, fontSize: 34, color: "#d6e0f5", marginTop: 30, fontWeight: 600, textAlign: "center" }}>
          {b.sub}
        </div>
      ) : null}
    </AbsoluteFill>
  );
};

const EndCard: React.FC<{ b: End; dur: number; vertical: boolean }> = ({ b, dur, vertical }) => {
  const opacity = useEdgeFade(dur, 8);
  return (
    <AbsoluteFill style={{ backgroundColor: "black", justifyContent: "center", alignItems: "center", opacity, padding: 60 }}>
      <Logo width={vertical ? 900 : 1000} />
      <div style={{ fontFamily: SANS, fontSize: 40, color: "white", marginTop: 40, fontWeight: 700, textAlign: "center" }}>
        {b.line}
      </div>
      <div style={{ fontFamily: SANS, fontSize: 28, color: "#9aa7c7", marginTop: 18, textAlign: "center" }}>
        Free fan project · No game files included · Bring your own ROM
      </div>
      <div style={{ fontFamily: SANS, fontSize: 32, color: "#b9c6ff", marginTop: 34 }}>{DISCORD}</div>
      <div style={{ fontFamily: PIXEL, fontSize: 24, color: GOLD, marginTop: 18 }}>{TILT}</div>
    </AbsoluteFill>
  );
};

const BeatView: React.FC<{ b: Beat; dur: number; vertical: boolean }> = ({ b, dur, vertical }) => {
  if (b.kind === "title") return <TitleCard b={b} dur={dur} vertical={vertical} />;
  if (b.kind === "end") return <EndCard b={b} dur={dur} vertical={vertical} />;
  return (
    <AbsoluteFill style={{ backgroundColor: "black" }}>
      <Footage b={b} dur={dur} vertical={vertical} />
      {b.hook ? <Hook text={b.hook} vertical={vertical} /> : null}
      {b.label ? <Chip text={b.label} vertical={vertical} /> : null}
    </AbsoluteFill>
  );
};

export const promoFrames = (p: Promo) => p.beats.reduce((n, b) => n + s(b.sec), 0);

export const PromoVideo: React.FC<{ promo: Promo; vertical: boolean }> = ({ promo, vertical }) => {
  let t = 0;
  const music = `promo/music_${promo.id}.mp3`;
  return (
    <AbsoluteFill style={{ backgroundColor: "black" }}>
      {promo.beats.map((b, i) => {
        const from = t;
        const len = s(b.sec);
        t += len;
        return (
          <Sequence key={i} from={from} durationInFrames={len}>
            <BeatView b={b} dur={len} vertical={vertical} />
          </Sequence>
        );
      })}
      {hasFile(music) ? <Audio src={staticFile(music)} /> : null}
    </AbsoluteFill>
  );
};

// ----------------------------------------------------------- the videos

const shot = (file: string, sec: number, rest: Partial<Shot> = {}): Shot => ({ kind: "shot", file, sec, ...rest });

export const PROMOS: Promo[] = [
  {
    // "Remember the Pokéwalker? We rebuilt it."
    id: "Walker",
    beats: [
      shot("walker_phone", 2.5, { hook: "Remember the Pokéwalker?" }),
      shot("walker_phone", 2, { from: 2.5, hook: "We rebuilt it." }),
      shot("walker_send", 3, { hook: "And it works with EVERY game.", label: "SEND FROM ANY PC" }),
      shot("walker_steps", 3, { label: "WALK WITH YOUR PHONE" }),
      shot("walker_radar", 3, { label: "POKé RADAR" }),
      shot("walker_runner", 2.5, { label: "JUMP RUNNER" }),
      shot("walker_rhythm", 2, { label: "RHYTHM TAP" }),
      shot("walker_catch", 2, { label: "CATCH TIMING" }),
      shot("walker_shop_events", 3, { hook: "Real event Pokémon in the Watt Shop", label: "WATT SHOP" }),
      shot("walker_home", 3.5, { hook: "…and it comes home levelled up.", label: "BACK IN YOUR SAVE" }),
      { kind: "end", sec: 4, line: "Monster Walker · in the launcher sidebar" },
    ],
  },
  {
    // "One engine. Red to Black & White."
    id: "Regions",
    beats: [
      shot("launcher_games", 2.5, { hook: "Every region. One engine.", focus: { scale: 1.6, x: 0.55, y: 0.5 } }),
      shot("red_pallet", 1.6, { label: "KANTO · RED" }),
      shot("crystal_newbark_day", 1.6, { label: "JOHTO · CRYSTAL" }),
      shot("firered_pallet", 1.6, { label: "KANTO · FIRERED" }),
      shot("emerald_slateport", 1.6, { label: "HOENN · EMERALD" }),
      shot("platinum_jubilife", 1.6, { label: "SINNOH · PLATINUM" }),
      shot("hgss_newbark", 1.6, { label: "JOHTO · HEARTGOLD" }),
      shot("bw_nuvema", 1.6, { label: "UNOVA · BLACK" }),
      { kind: "title", sec: 2.5, top: "NO EMULATOR", big: "NATIVE.", sub: "Rebuilt from your own cartridge dump" },
      shot("launcher_games", 2.5, { hook: "Which one are you booting first?", from: 2.5 }),
      { kind: "end", sec: 3.5, line: "Red to Black & White · Windows · Mac · Linux · Deck · Android · iOS · Switch" },
    ],
  },
  {
    // "Pokémon Gold… in Japanese?"
    id: "Translate",
    beats: [
      shot("translate_gold_ja", 2.5, { hook: "Pokémon Gold… in Japanese?" }),
      shot("translate_tool", 3.5, { hook: "One button.", label: "TOOLS → TRANSLATE A GAME" }),
      shot("translate_gold_fr", 2, { label: "FRANÇAIS" }),
      shot("translate_gold_de", 2, { label: "DEUTSCH" }),
      shot("translate_gold_pb", 2, { label: "PORTUGUÊS (BR)" }),
      shot("translate_gold_pl", 2, { label: "POLSKI" }),
      { kind: "title", sec: 3, top: "25 LANGUAGES", big: "ANY GAME.", sub: "Official Pokémon names kept from a glossary" },
      { kind: "end", sec: 4, line: "Which language should we show next? 👇" },
    ],
  },
  {
    // "Platinum on a real dual-screen handheld"
    id: "DualScreen",
    beats: [
      shot("dual_platinum", 3, { hook: "Platinum. Two screens. No emulator." }),
      shot("dual_poketch", 3, { label: "THE POKéTCH, ON THE BOTTOM SCREEN" }),
      shot("dual_walk", 3, { label: "SINNOH IN 3D UP TOP" }),
      shot("dual_companion", 3.5, { hook: "On Gen 1–3 it's a live save editor", label: "SAVE COMPANION" }),
      shot("dual_touch", 3, { label: "TOUCH CONTROLS YOU LAY OUT" }),
      { kind: "end", sec: 4, line: "Android dual-screen handhelds · second displays" },
    ],
  },
  {
    // "Flat to 3D in one button", from the trailer harness's footage
    id: "Voxel",
    beats: [
      shot("crystal_voxel_reveal", 3, { hook: "I grew up here." }),
      shot("crystal_voxel_reveal", 4, { from: 3, hook: "Now I can walk in it." }),
      shot("crystal_first_person", 3.5, { label: "FIRST PERSON" }),
      shot("crystal_newbark_night", 3, { label: "REAL DAY & NIGHT" }),
      shot("crystal_battle_shiny", 3.5, { label: "BATTLES ON THE MAP" }),
      { kind: "end", sec: 4, line: "Gen 1 to Gen 4 in voxels" },
    ],
  },
];
