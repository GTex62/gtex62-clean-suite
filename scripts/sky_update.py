#!/usr/bin/env python3
import math, os, subprocess, sys
import ephem

HOME = os.path.expanduser("~")
OUT  = os.path.join(HOME, ".cache", "conky", "sky.vars")

def run_station_latlon():
    """
    Try to reuse your suite's station_latlon.sh if it prints lat/lon.
    Accepts output like:
      "32.9 -96.8"
      "LAT=32.9 LON=-96.8"
      "32.9,-96.8"
    """
    sh = os.path.join(HOME, ".config", "conky", "gtex62-clean-suite", "scripts", "station_latlon.sh")
    if not (os.path.exists(sh) and os.access(sh, os.X_OK)):
        return None

    try:
        out = subprocess.check_output([sh], text=True).strip()
    except Exception:
        return None

    # Extract first two floats from output
    parts = []
    for tok in out.replace(",", " ").replace("=", " ").split():
        try:
            parts.append(float(tok))
        except ValueError:
            pass
    if len(parts) >= 2:
        return parts[0], parts[1]
    return None

def deg(x): return float(x) * 180.0 / math.pi

def az_to_theta(az_deg):
    """
    Map azimuth degrees (0=N,90=E,180=S,270=W) to an "arc theta" where:
      E(90) -> 0,  S(180) -> 90,  W(270) -> 180
    This matches the common horizon-arc convention used in your owm.lua (it can accept *_AZ too).
    """
    t = az_deg - 90.0
    while t < 0: t += 360.0
    while t >= 360: t -= 360.0
    return t

def write_vars(lat, lon):
    obs = ephem.Observer()
    obs.lat = str(lat)
    obs.lon = str(lon)
    obs.elevation = 0
    obs.date = ephem.now()

    # Bodies
    bodies = {
        "MOON": ephem.Moon(),
        "VENUS": ephem.Venus(),
        "MARS": ephem.Mars(),
        "JUPITER": ephem.Jupiter(),
        "SATURN": ephem.Saturn(),
        "MERCURY": ephem.Mercury(),
    }

    lines = []
    lines.append(f"LAT={lat}")
    lines.append(f"LON={lon}")
    import time
    lines.append(f"TS={int(time.time())}")  # lightweight marker; not used by lua

    for name, body in bodies.items():
        body.compute(obs)
        az  = deg(body.az)
        alt = deg(body.alt)
        th  = az_to_theta(az)

        if name == "MOON":
            lines.append(f"MOON_AZ={az:.3f}")
            lines.append(f"MOON_ALT={alt:.3f}")
            lines.append(f"MOON_THETA={th:.3f}")
        else:
            # owm.lua can read either *_THETA or *_AZ; we provide both for safety.
            lines.append(f"{name}_AZ={az:.3f}")
            lines.append(f"{name}_ALT={alt:.3f}")
            lines.append(f"{name}_THETA={th:.3f}")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    tmp = OUT + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    os.replace(tmp, OUT)

def main():
    # 1) Try your existing station_latlon.sh
    ll = run_station_latlon()

    # 2) Fallback: use environment variables if set
    if ll is None:
        try:
            ll = (float(os.environ["LAT"]), float(os.environ["LON"]))
        except Exception:
            ll = None

    if ll is None:
        print("ERROR: Couldn't determine LAT/LON.")
        print("Fix: ensure scripts/station_latlon.sh outputs lat lon, or run with LAT=.. LON=..")
        sys.exit(2)

    lat, lon = ll
    write_vars(lat, lon)
    print(OUT)

if __name__ == "__main__":
    main()
