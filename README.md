# Michael Myers Gametype
In this gametype a random player gets picked as the so called "Myer" this player will have to kill all "Survivors" with his knive, do note that the last Survivor is allowed to attack back!

### Usage
Copy the content of userraw to your own userraw, then simply set the `g_gametype` on mm and you are all set.

### Server Config
Add the following to your server.cfg
```
//////////////////////////////////////////////////
// MICHAEL MYERS GAMETYPE SETTINGS              //
//////////////////////////////////////////////////

set scr_mm_scorelimit "1"                       // Score limit required to win the game.
set scr_mm_timelimit "5"                        // Duration in minutes for the game to end if the score limit isnt reached.
set scr_mm_numlives "1"							// Number of lives per player per game.
set scr_mm_roundlimit "0"                       // Rounds the game is limited to 0 for unlimited.
set scr_mm_winlimit "2"                         // amount of wins needed to win a round-based game.
```