# RetroRecomped — social promos

Five short videos, each cut twice from one beat list in
`tools/trailer/remotion/src/Promos.tsx`:

| Composition | Length | For |
| --- | --- | --- |
| `Walker-Vertical` / `Walker-Wide` | ~31 s | Monster Walker |
| `Regions-Vertical` / `Regions-Wide` | ~22 s | Every supported game |
| `Translate-Vertical` / `Translate-Wide` | ~21 s | Translate a Game |
| `DualScreen-Vertical` / `DualScreen-Wide` | ~20 s | Dual screens, Pokétch, save companion, touch |
| `Voxel-Vertical` / `Voxel-Wide` | ~21 s | Flat → 3D (reuses trailer footage) |

`-Vertical` is 1080×1920 for TikTok, Reels and Shorts. `-Wide` is 1920×1080 for
YouTube, X, Bluesky, Reddit and Discord.

Footage goes in `tools/trailer/remotion/public/promo/<name>.mp4` (git-ignored).
Any shot not recorded yet shows a **RECORD promo/<name>.mp4** slate, so you can
time the cut in the studio before everything is captured. Music is optional:
`public/promo/music_<id>.mp3` (for example `music_Walker.mp3`) is picked up
automatically.

```powershell
cd tools/trailer/remotion
npx remotion studio src/index.ts
npx remotion render src/index.ts Walker-Vertical out/walker_vertical.mp4 --crf 16
npx remotion render src/index.ts Walker-Wide out/walker_wide.mp4 --crf 16
```

Then make the upload copy with the same ffmpeg line as `TRAILER.md`
(full range → TV range, `+faststart`).

In the vertical cut each shot is a 1080×1080 window over a blurred copy of
itself, leaving room for the hook text above and the platform UI below. A
shot's `focus` (`scale`, `x`, `y`) picks which part of a 16:9 frame fills the
window. The default is a 1.6× zoom on the centre; adjust it per shot if the
action is off to one side.

---

## Shot list

Record everything at 1920×1080, 30 fps, at least as long as the "min" column.
The `from` values in `Promos.tsx` assume the action starts at 0 s.

### Walker

| File | Min | What to capture | How |
| --- | --- | --- | --- |
| `walker_phone` | 5 s | A hand holding an Android phone outdoors with the Monster Walker open and steps ticking up. Shoot it on a second phone. | Camera |
| `walker_send` | 3 s | Launcher → Monster Walker: choose a Pokémon from a game's PC box and send it. | OBS |
| `walker_steps` | 3 s | The walker screen with the step and watt counters rising. `STEP_DEBUG=2000` credits steps on desktop. | OBS |
| `walker_radar` | 3 s | A Poké Radar battle: the bushes, then Attack / Catch. | OBS |
| `walker_runner` | 3 s | Jump Runner mid-run, bouncing on a wild Pokémon. | OBS, or the `walker_minigames_shot` harness with `GAME=runner` |
| `walker_rhythm` | 2 s | Rhythm Tap with a streak multiplier showing. | as above, `GAME=rhythm` |
| `walker_catch` | 2 s | Catch Timing: the ring shrinking and a "Great" grade. | as above, `GAME=catch` |
| `walker_shop_events` | 3 s | Watt Shop → Events tab, scrolling onto an event Pokémon (Mew, Deoxys, …). | OBS |
| `walker_home` | 4 s | In-game: open the party or PC after Send presents home. The walked Pokémon is there, a level higher. | OBS |

### Regions

| File | Min | What to capture | How |
| --- | --- | --- | --- |
| `launcher_games` | 5 s | The launcher's Games grid with scraped box art, a slow scroll across every card. | OBS |
| `red_pallet` | 2 s | Red, Pallet Town walk, voxels on. | `capture.lua` once a `red` block exists (see `TRAILER.md`) |
| `crystal_newbark_day` | 2 s | Already recorded by the trailer harness. Copy or link it in. | trailer footage |
| `firered_pallet` | 2 s | Already recorded. | trailer footage |
| `emerald_slateport` | 2 s | Already recorded. | trailer footage |
| `platinum_jubilife` | 2 s | Already recorded. | trailer footage |
| `hgss_newbark` | 2 s | HeartGold, New Bark Town. | OBS |
| `bw_nuvema` | 2 s | Black, Nuvema Town. | OBS |

### Translate

| File | Min | What to capture | How |
| --- | --- | --- | --- |
| `translate_tool` | 4 s | Tools → Translate a Game: pick Gold, pick a language, the progress bar running. | OBS |
| `translate_gold_ja` | 3 s | Gold's opening dialogue (Oak's speech) translated to Japanese. | OBS |
| `translate_gold_fr` / `_de` / `_pb` / `_pl` | 2 s each | The same line of dialogue in each language. Use the same line every time so the change is obvious. | OBS |

### DualScreen

Film these on a real device. A screen recording can't show two physical
screens.

| File | Min | What to capture |
| --- | --- | --- |
| `dual_platinum` | 3 s | The whole device in frame (AYN Thor, Retroid dual-screen, a phone with an external display): Platinum up top, the Pokétch below. |
| `dual_poketch` | 3 s | Close-up of the bottom screen with a finger tapping through Pokétch apps. |
| `dual_walk` | 3 s | Close-up of the top screen: walking through Jubilife in 3D. |
| `dual_companion` | 4 s | Crystal or Emerald up top, the save companion editing the party live below. |
| `dual_touch` | 3 s | Tools → Touch Controls: dragging a button to a new spot. |

### Voxel

All five shots (`crystal_voxel_reveal`, `crystal_first_person`,
`crystal_newbark_night`, `crystal_battle_shiny`) are trailer harness footage.
Copy them from your trailer footage folder into `public/promo/`.

---

## Post copy

Every post links the download and the Discord. Pin a reply or put in the
description:

> Free, non-commercial fan project. Not affiliated with or endorsed by
> Nintendo, Game Freak, Creatures or The Pokémon Company. No game files are
> included; you import your own legally obtained ROMs. Please don't ask for
> ROMs.

Fill in `[DOWNLOAD LINK]` before posting. Discord: `discord.gg/4VXnEnePT`.
Tilt Rips: `tiltrips.com/r/GEN2RECOMP`.

### 1. Monster Walker

**YouTube** (`Walker-Wide`)

- Title options:
  - I Rebuilt the Pokéwalker — and It Works With EVERY Pokémon Game
  - The Pokéwalker Is Back (Gen 1 to Gen 5)
  - Walk Your Red Team's Pikachu With Your Phone in 2026
- Description:

```
Remember the Pokéwalker? We rebuilt it, and it works with every game RetroRecomped runs.

Take a Pokémon out of any game's PC (Red, Crystal, Emerald, Platinum, HeartGold…), walk it with your phone's step counter, and send it home levelled up with whatever it found.

• All 27 original Pokéwalker courses, Poké Radar battles and Dowsing
• 5 minigames with leaderboards: Jump Runner, Catch Timing, Treasure Hunt, Memory Match, Rhythm Tap
• The Watt Shop: items for every generation, daily Pokémon, weekly Mystery Gifts, and real event distributions
• Login streaks, passive watts and 26 achievements
• Every save it touches is backed up first

▶ Download: [DOWNLOAD LINK]
▶ Discord: https://discord.gg/4VXnEnePT
▶ Rip packs with us on Tilt Rips: https://tiltrips.com/r/GEN2RECOMP/

RetroRecomped is a non-commercial fan project. It is not affiliated with or endorsed by Nintendo, Game Freak, Creatures or The Pokémon Company. No game files are included; you import your own legally obtained ROMs.

#RetroRecomped #Pokewalker #Pokemon #HeartGold #RetroGaming
```

- Thumbnail: a hand holding a phone with the Walker open, a pixel Pikachu next to it. Text: **"IT'S BACK"**.

**X / Twitter** (`Walker-Wide`)
```
Remember the Pokéwalker?

We rebuilt it. And it works with EVERY game.

Walk your Red team's Pikachu with your phone, play minigames for watts, and send it home to Kanto levelled up. 🚶⚡

Free · bring your own ROM
[DOWNLOAD LINK]
```
Follow-up reply in the thread:
```
The Watt Shop sells the real event distributions too. Mew in your Emerald save, bought with steps. 👀
```

**TikTok / Reels / Shorts** (`Walker-Vertical`)
```
POV: your Pokéwalker never broke 🥹 works with every game, link in bio #pokemon #pokewalker #heartgold #nostalgia #retrogaming #gaming
```
On-screen text is already in the video. Use a trending nostalgic sound, or a
chiptune track at about 120 BPM so the minigame cuts land on beats.

**Bluesky / Threads**
```
We rebuilt the Pokéwalker for every Pokémon game. Take any Pokémon out of any save, walk it, play minigames, buy event Pokémon with watts, and send it home. Free fan project, bring your own ROM. [DOWNLOAD LINK]
```

**Reddit** (r/pokemon, r/PokemonHGSS, r/AndroidGaming; upload the video natively)
- Title: *I remade the Pokéwalker so it works with every Pokémon game, from Red to Black & White*
- Body:
```
It's part of RetroRecomped, a free fan engine that runs the classic games natively from your own ROM. The walker reads any imported game's PC, so you can walk a Gen 1 Pikachu with your phone's step counter and send it back to Kanto.

It has the 27 original courses, the radar and dowsing rules from the original, plus 5 minigames and a Watt Shop with real event distributions. Every save gets backed up before it's touched.

Happy to answer how the save round-trip works. Download and source are in the comments.
```

**Discord**
```
🚶 **Monster Walker is out!**
Take a Pokémon from ANY game, walk it, earn watts and send it home.
🎮 5 minigames · 🛒 Watt Shop with real event Pokémon · 🏆 26 achievements
Post your best Jump Runner score in #leaderboards. Top 3 each week get a shoutout!
```

### 2. Every region

**YouTube** (`Regions-Wide`)
- Title: *Every Pokémon Region in One Engine: Red to Black & White, No Emulator*
- Description:
```
Kanto, Johto, Hoenn, Sinnoh and Unova, all running natively in one launcher, rebuilt from your own cartridge dumps.

SUPPORTED
• Red, Blue, Yellow
• Gold, Silver, Crystal, plus Polished Crystal & Prism
• FireRed, Emerald (alpha)
• Platinum, HeartGold, SoulSilver, Black, White (pre-alpha)

Windows · macOS · Linux · Steam Deck · Android · iOS · Switch · Xbox Dev Mode · Anbernic handhelds

▶ Download: [DOWNLOAD LINK]
▶ Discord: https://discord.gg/4VXnEnePT

RetroRecomped is a non-commercial fan project. Not affiliated with Nintendo, Game Freak, Creatures or The Pokémon Company. No game files are included; you import your own legally obtained ROMs.

#RetroRecomped #Pokemon #RetroGaming #SteamDeck
```

**X / Twitter**
```
One engine. Red to Black & White.
All native. No emulator. Your own cartridge dumps.

Which one are you booting first? 👇
```
Attach `Regions-Wide`, or a 4-image grid of Johto, Hoenn, Sinnoh and Unova
stills.

**TikTok / Reels / Shorts** (`Regions-Vertical`)
```
every pokémon region in one app 😳 which are you playing first? #pokemon #retrogaming #steamdeck #pokemonplatinum #pokemonblack
```

**Bluesky / Threads**
```
Kanto → Johto → Hoenn → Sinnoh → Unova, one launcher, no emulator. RetroRecomped now imports Gen 1 through Gen 5 from your own dumps. [DOWNLOAD LINK]
```

**Reddit** (r/SteamDeck, r/SBCGaming, r/retrogaming; best with a photo of the real device)
- Title: *Gen 1–5 Pokémon running natively (not emulated) on Steam Deck, from a single launcher*
- Body: name the device, the frame rate you see, and how the import works:
  verify the ROM by SHA-1, extract the data, then the ROM is released from
  memory.

### 3. Translate a Game

**YouTube** (`Translate-Wide`)
- Title: *I Translated Pokémon Gold Into 25 Languages With One Button*
- Description:
```
RetroRecomped's Translate a Game tool machine-translates a game's own text into 25 languages, keeping the official Pokémon names from a glossary. Pick a language per game or for the whole launcher.

French · German · Spanish · Italian · Portuguese (PT & BR) · Dutch · Polish · Czech · Danish · Swedish · Finnish · Greek · Romanian · Hungarian · Turkish · Norwegian · Bulgarian · Slovak · Slovenian · Catalan · Ukrainian · Russian · Japanese · Chinese (Simplified)

▶ Download: [DOWNLOAD LINK]
▶ Discord: https://discord.gg/4VXnEnePT

Non-commercial fan project. Not affiliated with Nintendo, Game Freak, Creatures or The Pokémon Company. No game files included.
```

**X / Twitter**
```
Pokémon Gold… in Japanese? Polish? Brazilian Portuguese?

One button. 25 languages. Official Pokémon names kept.

Which language should we show next? 👇
```
Reply to each language request with a 5-second clip in that language.

**TikTok / Reels / Shorts** (`Translate-Vertical`)
```
pokémon gold in your language 🌍 comment yours and I'll show it next #pokemon #pokemongold #gaming #translation
```
Answer the comments with reply videos; this is the format's growth loop.

**Bluesky / Threads**
```
Play Pokémon Gold (or any supported game) in 25 languages: one click machine-translates the game's own text, keeping the official names. Free fan project. [DOWNLOAD LINK]
```

**Reddit**: post to language-learning and country subs only where self-promo is
allowed (r/languagelearning has strict rules). Lead with "learn a language by
replaying a game you know by heart".

### 4. Dual screens

**YouTube** (`DualScreen-Wide`)
- Title: *Pokémon Platinum on a Real Dual-Screen Handheld — Native, Not Emulated*
- Description:
```
On dual-screen Android handhelds and second displays, RetroRecomped puts Platinum's lower screen, the Pokétch and menus, on the second panel. On Gen 1–3 games the second screen becomes a live save companion: edit your party while you play.

Plus touch controls you can lay out yourself, and DS X/Y buttons for Gen 4+.

▶ Download: [DOWNLOAD LINK]
▶ Discord: https://discord.gg/4VXnEnePT

Non-commercial fan project. Not affiliated with Nintendo, Game Freak, Creatures or The Pokémon Company. No game files included.
```

**X / Twitter**
```
Platinum. Two screens. No emulator.

The Pokétch lives on the bottom screen, and on Gen 1–3 that screen becomes a live save editor. 🤯
```

**TikTok / Reels / Shorts** (`DualScreen-Vertical`)
```
pokémon platinum on a dual screen handheld hits different 😮‍💨 #pokemonplatinum #aynthor #retroid #handheld #retrogaming
```
Tag the device maker's account. Handheld brands often reshare.

**Reddit** (r/SBCGaming, r/retroid, r/AYN): title it with the device name
first: *[AYN Thor] Pokémon Platinum running natively with the Pokétch on the
bottom screen*.

### 5. Flat to 3D

**X / Twitter** (`Voxel-Wide`)
```
I grew up here.

Now I can walk in it. 🏡

Crystal's New Bark Town, flat to 3D voxels in one button.
```

**TikTok / Reels / Shorts** (`Voxel-Vertical`)
```
new bark town but you can actually walk in it 🥲 #pokemoncrystal #pokemon #voxel #nostalgia #gaming
```

**Bluesky / Threads**
```
You remember it flat. Now walk back in. Gen 1–4 rebuilt as voxel dioramas, first and third person, real day/night. [DOWNLOAD LINK]
```

---

## Schedule (one week)

| Day | Short-form | X / Bluesky | Reddit | YouTube |
| --- | --- | --- | --- | --- |
| Mon | Walker | Walker | r/pokemon | Walker |
| Tue | Voxel | Voxel | — | — |
| Wed | Regions | Regions | r/SteamDeck | Regions |
| Thu | Translate | Translate | — | — |
| Fri | DualScreen | DualScreen | r/SBCGaming | DualScreen |
| Sat | Reply videos to the top comments | Leaderboard shoutouts | — | — |
| Sun | Best-performing short, reposted with a new hook | Recap thread | — | Shorts compilation |

Spread Reddit posts out and follow each subreddit's self-promotion rules. Never
link ROMs, and avoid official logos in thumbnails.
