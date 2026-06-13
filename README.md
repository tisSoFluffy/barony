# Barony of Azeroth

A self-contained, Barony-like first-person dungeon crawler with Warcraft-styled
characters. Everything — the raycasting engine (textured walls *and* floors),
the dungeon generator, every sprite and texture, the music, and the sound
effects — is procedurally generated in a single `index.html` with zero
dependencies.

**Play:** open `index.html` in any browser. Works on desktop (mouse + WASD)
and touch devices (on-screen controls).

## The crawl
- 5 themed floors: the Old Mines, the Flooded Halls, the Crypt of the Barons,
  the Horde Warcamp, and Gor'maul's Throne — each with its own walls, floors,
  and palette, lit by flickering braziers
- Two classes:
  - **Footman** — heavy melee; hold right-click to raise your shield (-70% damage)
  - **Mage** — fireballs (right-click), **Q** frost nova (AoE slow), **B** blink
- Barony staples: hunger, potions, gold, XP levels, spike traps, gamble shrines
- **Loot & inventory** (press **I**): randomized gear in three tiers —
  weapons, armor, helms, rings with WoW-style names ("Orcish Cleaver of the
  Tiger") and stat affixes; 4 equipment slots + a 6-slot pack
- **Locked treasure vaults**: from depth 2, one room per floor is sealed by
  locked doors; a wandering monster carries the key
- Bestiary: Kobold Tunnelers, Murloc Raiders, Troll Headhunters (thrown axes),
  Scourge Skeletons, Orc Grunts, Cultist Necromancers (shadow bolts, raise
  skeletons) — and **Gor'maul the Ogre Warlord**, who enrages at half health
  and calls reinforcements
- Procedural dungeon music that doubles tempo when enemies are on you, plus
  a local **Hall of Heroes** high-score board on the title screen

## Co-op (up to 3 heroes)
Online multiplayer over WebRTC, peer-to-peer — no server to run:

1. Send each friend a copy of `index.html`.
2. One player clicks **Host Co-op** and shares the 4-letter room code.
3. The others enter the code and click **Join Friend**, then the host clicks
   **Begin the Descent**.

The host's machine runs the world (enemies, loot); everyone else streams
inputs. XP is shared by the whole party, gear and gold are personal, the dead
haunt the dungeon as ghosts and rise again at the next floor, and the run only
ends when the whole party falls. Matchmaking uses the free PeerJS broker, so
everyone needs internet; if a friend can't connect (strict NAT), have them
host instead. Append `?testnet=1` to the URL to run all players as tabs in
one browser via a loopback transport (used by the automated tests).

## Controls
| Input | Action |
|---|---|
| WASD / arrows | move & turn |
| Mouse (click to lock) | look |
| Left click / Space | melee attack |
| Right click / F | fireball (mage) · hold to block (footman) |
| Q / B | frost nova / blink (mage) |
| I / Tab | inventory — click to equip, right-click to drop |
| E | doors, vaults, shrines, stairs & portal |
| H / M / G | health potion / mana potion / eat |
