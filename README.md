# BigQuestFrame

A small World of Warcraft Classic addon (built for WoW Forever, Interface 16001) that makes the NPC gossip and quest windows bigger and easier to read.

## Features
- Scales the whole gossip/quest window (frame, parchment and text) together.
- `+`, `-` and `R` (reset) buttons sit just outside the window's right edge.
- Optional reader: shows one or two sentences at a time. Click anywhere or press **Next** to continue; **Show all** skips it; the normal window is revealed on the last page so you can accept or complete the quest.

## Install
Copy the `BigQuestFrame` folder into `World of Warcraft\_forever_\Interface\AddOns\`, then `/reload`.

## Commands
| Command | Effect |
|---|---|
| `/bqf <0.8-2.2>` | Set the window scale (default 1.4) |
| `/bqf reader` | Toggle the click-through reader (off by default) |

If the game's `Interface` version changes, edit the number in `BigQuestFrame.toc`.

## License
MIT
