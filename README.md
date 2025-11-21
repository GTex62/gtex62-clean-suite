# gtex62-clean-suite

A modular, minimalist Conky desktop suite for Linux Mint (and other
distros), inspired by several Rainmeter skins and rebuilt for Conky
using Lua, custom widgets, themed slash bars, GPU/VRAM bars, weather
arc, calendar, notes, and more.

This is a complete desktop system monitor and information panel set
while keeping everything text-first, elegant, and unobtrusive.

## Screenshots

### Full Suite
![Clean Conky Suite](screenshots/gtex62-clean-suite.png)

### Weather + Horizon Arc
![Time and Weather](screenshots/time-and-weather.png)

### System Info
![System Info](screenshots/sys-info.png)

### Network Info
![Network Info](screenshots/network-info.png)

### Notes Widget
![Notes](screenshots/notes.png)

### Calendar Widget
![Calendar](screenshots/calendar.png)


## Wallpapers

This Conky suite includes original wallpapers created by **Geoffrey Greene**.  
They are optional, but recommended to match the aesthetic shown in screenshots.
7680x2170

Files:

- `wallpapers/painted-canvas-bw-01.png` – Black & White
- `wallpapers/painted-canvas-db-01.png` – Dark Blue
- `wallpapers/painted-canvas-g-01.png`  – Green

These wallpapers are licensed for **personal, non-commercial use**.


## Features

### System Information (sys-info.conky.conf)

-   CPU usage, load, and temperatures\
-   RAM usage\
-   Disk usage per mount\
-   OS, kernel, uptime, hostname\
-   System firmware info\
-   Logging of network interfaces\
-   Live throughput graph\
-   Fully configurable via `theme.lua`

### GPU Widget

-   GPU usage slash bar\
-   VRAM usage slash bar\
-   Temperature\
-   Fan percentage\
-   Power draw (W)\
-   Driver version\
-   Automatic detection for NVIDIA (via `nvidia-smi`)

### Weather Widget

-   Weather arc inspired by ASTROweather\
-   Current METAR, TAF, AIRMET/SIGMET + OWM blended\
-   5-day forecast\
-   Sunrise/sunset\
-   Wind, humidity, pressure\
-   Icons + text\
-   Everything styled through Lua

### Calendar Widget

-   Month calendar with current day highlight\
-   Clean typography\
-   Minimalist layout

### Notes Widget

-   Simple and elegant notes panel\
-   Readable right-hand column\
-   Monospaced or themed fonts

### Shared Theme System

The `theme.lua` file controls: - Font family\
- Font size\
- Colors\
- Slash bar width & style\
- Column positions\
- Spacing and separators
- Optional per-widget tweaks
---

## Folder Structure

Expected layout in your home directory:

```text
~/.config/conky/
  calendar.conky.conf
  date-time.conky.conf
  net-sys.conky.conf
  notes.conky.conf
  sys-info.conky.conf
  weather.conky.conf
  theme.lua
  lua/
  scripts/
  screenshots/
  wallpapers/
  owm.env.example
  owm.vars.example
  (your own) owm.env
  (your own) owm.vars
```

---

## Requirements

- Conky (with Lua support) — e.g. `conky-all` on Debian/Ubuntu/Mint  
- `curl`  
- `jq`  
- `lm-sensors` (for temperatures)  
- For GPU widget:
  - NVIDIA GPU
  - Working `nvidia-smi` command

---

## Installation

### 1. Install Conky + dependencies

``` bash
sudo apt install conky-all curl jq lm-sensors
sudo sensors-detect
```

### 2. Clone this repo

``` bash
cd ~/.config
git clone https://github.com/YOURNAME/conky-suitename.git conky
```

---

### 3. Configure OpenWeather variables

There are two files involved:

- `owm.env` — holds your OpenWeather API key (and optionally some settings)
- `owm.vars` — holds cache paths and other variables for the forecast logic

Start from the provided examples:

```bash
cd ~/.config/conky
cp owm.env.example  owm.env
cp owm.vars.example owm.vars
```

Then edit them:

```bash
xed owm.env
xed owm.vars
```

In `owm.env`:

- Replace `YOUR_OPENWEATHER_API_KEY_HERE` with your actual API key.  
  (Do **not** commit the real key to Git.)

In `owm.vars`:

- Change `YOURUSERNAME` in  
  `OWM_DAILY_CACHE=/home/YOURUSERNAME/.cache/conky/owm_forecast.json`  
  to your actual Linux username (or full path).  
- Optionally adjust LAT/LON/UNITS/LANG to match your location.

> **Note:** `owm.env` and `owm.vars` are intentionally `.gitignore`d, so your real API key and paths are never pushed to GitHub.

---

### 4. Start widgets

The suite includes a helper script to start all widgets at once:
```bash
~/.config/conky/scripts/start-conky.sh &
```

You can also start individual widgets manually if you prefer:
``` bash
conky -c ~/.config/conky/sys-info.conky.conf &
conky -c ~/.config/conky/weather.conky.conf &
conky -c ~/.config/conky/calendar.conky.conf &
conky -c ~/.config/conky/date-time.conky.conf &
conky -c ~/.config/conky/notes.conky.conf &
```
Add the script to your desktop environment’s startup applications to launch the suite automatically on login.

---

### Screen alignment and positioning

Each `.conky.conf` file has its own `alignment`, `gap_x`, and `gap_y` settings tuned for a dual-monitor setup on the original system (right-side secondary display).

If widgets appear off-screen or stacked incorrectly:

1. Open the `.conky.conf` file for the widget you want to move.  
2. Look for these lines near the top:
   ```lua
   alignment = 'top_right',
   gap_x = 2780,
   gap_y = 50,
   ```
3. Adjust `alignment` (`top_left`, `top_right`, `bottom_left`, `bottom_right`, etc.) and `gap_x` / `gap_y` until the widget sits where you want it.  
4. Save and reload that widget:
   ```bash
   pkill conky
   ~/.config/conky/scripts/start-conky.sh &
   ```

Tip: You can experiment interactively by changing the numbers in small steps (e.g., ±50 px).

---

## Customization

Most of the visual behavior is controlled from:

```text
~/.config/conky/theme.lua
```

Things you can change there:

- Fonts (family, size)
- Colors (main text, accents)
- Slash bar style and width
- Column positions (for labels and values)
- Spacing for separators and sections
- Calendar spacing and padding
- Weather arc and planet styling options (if you enable planets)

Each `.conky.conf` file uses the same shared theme, so adjusting `theme.lua` lets you redesign the look of the entire suite without editing each widget individually.

---

## Credits & Inspirations

### Plainext (Rainmeter → Conky)

https://github.com/EnhancedJax/Plainext

### DesktopWidgets -- Network Info (Rainmeter)

https://www.deviantart.com/g3xter/art/DesktopWidgets-Network-Info-713140520

### ASTROweather (Rainmeter)

https://www.deviantart.com/xenium/art/ASTROWeather-Weather-Skin-776886670

### Amnio/Notes (Rainmeter)

https://github.com/JosephB2000/Amnio

## License

MIT License
