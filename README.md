# What's Training? Epoch (Server-agnostic)
### Although the name suggests this fork is for Epoch specifically, it was made to be server-agnostic and *should* work on any 3.3.5 server.  

A server‑agnostic rework of “What’s Training?” made to be used on Project Epoch primarily. But really it's for WotLK servers.  
It keeps the original What's Training? UI and scans for spells/abilities upon class trainer visit instead of coming pre-bundled with a static database.

## Differences compared to WhatsTraining_WotLK
- **Server-agnostic:** discovers spells by scanning class trainers and saves a per‑character cache and therefore should work on *all* 3.3.5 servers.  
- This fork of What's Training? requires visiting a trainer before the addon can display any information.  
- **Level‑up & Login summary:** posts available spells plus total cost in chat.  
- Minor UI tweaks.

## Usage Notes  
- Required: visit your class trainer once to populate the cache.  
- The “What can I train?” icon appears at the bottom of your Spellbook tabs.  

Demo: 
<video src='https://github.com/user-attachments/assets/404658a6-6a4c-4d7d-ae94-0be52e466c55' width=180 height=100/>
## Commands
- **/wte summary all | none | level | login** —  toggle when What's Trainer? summaries should appear (default: all)
- **/wte reset** — clear the per‑character cache
- **/wte icon** — toggle between "?" (default) icon and class icon for the spellbook tab button
- **/wte test** — show the current “Available now” summary from cache (requires cached trainer data + unlearned available spells)  
- **/wte scan** — force a trainer scan (use while a trainer window is open, shouldn't be necessary)  
- **/wte debug** — toggle debug logging  

## Installation
1. Download the addon from the green Code dropdown in the top right here on Github.  
2. Save the addon somewhere you can find it and extract it there.  
3. Locate the addon files by going as deep into the folders as you need, then go back one step.  
4. You should see a folder named `Whats-Training-Epoch-main`, rename it to `Whats-Training-Epoch`.  
5. Move the `Whats-Training-Epoch` folder into your game folder, more specifically into the Interface\AddOns\ folder.  
6. Done! If everything was done correctly, the addon will now  appear in the in-game Addons menu, and work in-game!  

Alternatively, here's a quick video guide on how to do it:
<video src='https://github.com/user-attachments/assets/7c1b2f47-c0f5-4185-bed2-82b3fa117463' width=180 height=100/>  

## Localization
Should *hopefully* work for: enUS (default), frFR, ruRU, zhCN, zhTW, deDE, koKR.  
The Localization is directly ripped from WhatsTraining_WotLK  

## Alternatives:  
https://github.com/XDeltaTango/WhatsTraining-Plus - I thought this fork didn't work when I started making my fork, turns out it does work. But compared to What's Training? Epoch it looks a lot less like the original addon, so I continued making What's Training? Epoch anyway, but functionally they are both very similar.  

## Credit:
https://github.com/anhility/WhatsTraining_WotLK for the 3.3.5 fork that I used as a starting point.  
https://github.com/fusionpit/WhatsTraining for the original addon.  
ChatGPT for actually writing the code... lol  


## License
MIT — see LICENSE.
