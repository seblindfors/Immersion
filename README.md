# Immersion

Replaces World of Warcraft's quest and gossip frames with a cinematic dialogue box
that paces the text to encourage reading the lore.

Instead of dropping a wall of text into a static window, Immersion presents quest and
gossip dialogue in a talking-head frame with the NPC's model, revealing the text at
reading speed. The rest of the interface can fade away while you talk to someone, so
the conversation is the thing on screen rather than a panel competing with your bars.

## Features

- Talking-head dialogue frame with the NPC model, portrait and name
- Text revealed progressively, with an optional progress bar; automatic progression
  can be turned off if you would rather advance manually
- Text-to-speech playback, with separate male and female voices, rate and volume
- Immersive mode: hides the interface, and optionally the minimap and objective
  tracker, while a conversation is open
- Hooks the default talking head frame so it uses the same placement
- Quest rewards and item choices inspected in place
- Keyboard bindings for accept, next and goodbye, plus number keys for gossip options
- Gamepad bindings for every action, reassignable by pressing the button you want
- Placement, scale, frame strata and appearance options, including show-at-mouse

## Configuration

```
/immersion
```

Settings are saved per account in `ImmersionSetup`.

## Controller support

Immersion handles gamepad input on its own — no other addon required. Every action is
bound to a face button by default and can be reassigned on the Gamepad settings page.

[ConsolePort](https://github.com/seblindfors/ConsolePort) is optional. When it is
installed, Immersion adds its prompts to ConsolePort's hint bar, so the available
actions are shown on screen with the right button icons.

## Compatibility

Retail and Classic. The supported interface versions are listed in `Immersion.toc`.

## Download

- [CurseForge](https://www.curseforge.com/wow/addons/immersion)
- [WoWInterface](https://www.wowinterface.com/downloads/info24714)
- [Wago](https://addons.wago.io/addons/immersion)
