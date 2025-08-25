# What's Training? Epoch (Server-agnostic)
### Although the name suggests this fork is for Epoch specifically, it was made to be server-agnostic and *should* work on any 3.3.5 server.  

A server‑agnostic rework of “What’s Training?” made to be used on Project Epoch primarily. But really it's for WotLK servers.  
It keeps the original What's Training? UI and scans for spells/abilities upon class trainer visit instead of coming pre-bundled with a static database.

## Differences compared to WhatsTraining_WotLK
- **Server-agnostic:** discovers spells by scanning class trainers and saves a per‑character cache and therefore should work on *all* 3.3.5 servers.  
- **First Run:** requires visiting a trainer before the addon can display any useful information.  
- **Level‑up + Login summary:** posts available spells plus total cost in chat.  
- Minor UI tweaks.

## Usage Notes  
- **First run:** visit your class trainer once to populate the cache.  
- The “What can I train?” tab appears in your Spellbook (uses a custom skill line tab).  

Demo: 
<video src='https://github.com/user-attachments/assets/404658a6-6a4c-4d7d-ae94-0be52e466c55' width=180 height=100/>
## Commands
- **/wte reset** — clear the per‑character cache
- **/wte test** — show the current “Available now” summary from cache (requires cached trainer data + unlearned available spells)  
- **/wte scan** — force a trainer scan (use while a trainer window is open, shouldn't be necessary)  
- **/wte debug** — toggle debug logging  

## Localization
Should *hopefully* work for: enUS (default), frFR, ruRU, zhCN, zhTW, deDE, koKR.  
The Localization is directly ripped from WhatsTraining_WotLK  

## Credit:
https://github.com/anhility/WhatsTraining_WotLK for the 3.3.5 fork that I used as a starting point.  
https://github.com/fusionpit/WhatsTraining for the original addon.  
ChatGPT for actually writing the code... lol  

## Alternatives:  
https://github.com/XDeltaTango/WhatsTraining-Plus - I thought this fork didn't work when I started making my fork, turns out it does work. But compared to What's Training? Epoch it looks a lot less like the original addon, so I continued making What's Training? Epoch anyway, but functionally they are both very similar.


## License
MIT — see LICENSE.
