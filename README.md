# Barony of Azeroth

A self-contained, Barony-like first-person dungeon crawler with Warcraft-styled
characters. Everything — the raycasting engine, the dungeon generator, every
sprite and texture, and the sound effects — is procedurally generated in a
single `index.html` with zero dependencies.

**Play:** open `index.html` in any browser. Works on desktop (mouse + WASD)
and touch devices (on-screen controls).

## The crawl
- 5 procedurally generated floors; doors, mossy halls, Horde banners
- Two classes: **Footman** (heavy melee) and **Mage** (fireballs)
- Barony staples: hunger, potions, gold, XP levels, weapon upgrades
- Bestiary: Kobold Tunnelers, Murloc Raiders, Scourge Skeletons, Orc Grunts —
  and **Gor'maul the Ogre Warlord** on the throne at depth 5

## Co-op (up to 3 heroes)
Online multiplayer over WebRTC, peer-to-peer — no server to run:

1. Send each friend a copy of `index.html`.
2. One player clicks **Host Co-op** and shares the 4-letter room code.
3. The others enter the code and click **Join Friend**, then the host clicks
   **Begin the Descent**.

The host's machine runs the world (enemies, loot); everyone else streams
inputs. XP is shared by the whole party, the dead haunt the dungeon as
ghosts and rise again at the next floor, and the run only ends when the
whole party falls. Matchmaking uses the free PeerJS broker, so everyone
needs internet; if a friend can't connect (strict NAT), have them host
instead. Append `?testnet=1` to the URL to run all players as tabs in one
browser via a loopback transport (used by the automated tests).

## Controls
| Input | Action |
|---|---|
| WASD / arrows | move & turn |
| Mouse (click to lock) | look |
| Left click / Space | melee attack |
| Right click / F | fireball |
| E | open doors, use stairs & portal |
| H / M / G | health potion / mana potion / eat |
