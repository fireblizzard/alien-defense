# Alien Defense

This is a serverside mod (plugin) based on a gamemode that was present in Arctic Combat, and it aims
to resemble it as much as possible, but in a way that makes sense on AG gameplay-wise.
Currently it only works on AG (and probably AGMini on HL), because it depends on
AG's voting system for things like difficulty, mode or map votes.

The idea of this mod is that players cooperate (or solo) to clear as many waves of monsters as possible, while defending the Nexus.
It plays as a Tower Defense game (unfortunately), but it's planned to have an AI for monsters try to kill nearby players while prioritizing
attacking the Nexus, which they don't at the moment, they just crash into it and lower its HP.
There are several difficulties, each one with their own stats, and also a survival one
for unlimited rounds and adaptative difficulty. There's an ingame shop to buy different items, like weapons or Nexus effects.
There's an admin menu too for spawning/removing monsters, debugging, etc.

There are only a few maps custom-made for the mod. For it to work in other maps you have to add a `func_breakable` entity with name `ad_nexus`,
and waypoints like the ones found in the _configs_ directory. Waypoints are defined each one in its own line, as `name x y z neighbour_names`.

There are surely things that I've forgotten to mention, it's been a while without working on this mod which was started around May 2019,
so I don't remember everything. Feel free to open an issue for suggestions, bug reports, questions or similar.

Things to do: https://trello.com/b/D8m0Aeyz/ag-alien-defense
