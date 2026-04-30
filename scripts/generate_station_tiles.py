#!/usr/bin/env python3
"""Generate station tile images on Replicate.

Usage:
  python scripts/generate_station_tiles.py            # flux-schnell → assets/station_tiles
  python scripts/generate_station_tiles.py recraft    # recraft-v4   → assets/station_tiles_recraft

Run from repo root with REPLICATE_API_KEY in env or .env.
"""
import os, sys, time, json, urllib.request, urllib.parse, urllib.error, pathlib

PROFILES = {
    "flux": {
        "model": "black-forest-labs/flux-schnell",
        "out_dir": "assets/station_tiles",
        "input_extra": {
            "aspect_ratio": "1:1",
            "num_outputs": 1,
            "output_format": "webp",
            "output_quality": 90,
            "go_fast": True,
            "megapixels": "1",
            "num_inference_steps": 4,
        },
    },
    "recraft": {
        "model": "recraft-ai/recraft-v4",
        "out_dir": "assets/station_tiles_recraft",
        "input_extra": {
            "size": "1024x1024",
        },
    },
    "imagen": {
        "model": "google/imagen-4",
        "out_dir": "assets/station_tiles_imagen",
        "input_extra": {
            "aspect_ratio": "1:1",
            "image_size": "1K",
            "output_format": "jpg",
        },
    },
    "seedream": {
        "model": "bytedance/seedream-4.5",
        "out_dir": "assets/station_tiles_seedream",
        "input_extra": {
            "aspect_ratio": "1:1",
            "size": "2K",
        },
    },
}

# Shared style suffix for visual consistency across all tiles.
STYLE = (
    "minimalist square poster illustration, flat retro-modern graphic design, "
    "bold simple geometric shapes, warm muted color palette with one bright accent, "
    "soft gradients, generous negative space, subtle film grain, "
    "vinyl-era radio station aesthetic, centered composition, no text, no letters, no logos"
)

STATIONS = [
    ("iron-tempo",       "a stylised dumbbell with motion lines and sunrise rays behind it, deep red and orange palette"),
    ("golden-hour",      "a setting sun over a calm horizon with a single palm silhouette, warm yellow and peach palette"),
    ("midnight-drift",   "an empty highway curving toward a full moon, neon purple and indigo palette with soft taillight glow"),
    ("main-stage",       "abstract stage spotlights cutting through haze with confetti specks, magenta and gold palette"),
    ("the-study",        "an open book and a small desk lamp casting a warm pool of light, cream and forest green palette"),
    ("heartbreak-hotel", "a rainy window with a glowing neon heart sign outside at night, dusty pink and midnight blue palette"),
    ("highway-one",      "a long desert road vanishing into mountains under a wide sky, terracotta and turquoise palette"),
    ("sunday-morning",   "a steaming ceramic mug on a sunlit kitchen table beside a small plant, butter yellow and sage palette"),
    ("tidal-waves",      "a single rolling ocean wave curling under a gradient sky, teal and lavender palette"),
    ("the-underground",  "a glowing vinyl record half submerged in deep shadow with one warm ember of light, charcoal and amber palette"),
]


def load_env():
    p = pathlib.Path(".env")
    if not p.exists():
        return
    for line in p.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip())


def post(url, body, headers):
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(), headers=headers, method="POST"
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        return json.loads(resp.read())


def get(url, headers):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.loads(resp.read())


def download(url, dest):
    with urllib.request.urlopen(url, timeout=120) as resp:
        dest.write_bytes(resp.read())


def generate(api_url, station_id, scene, token, input_extra, out_dir):
    prompt = f"{scene}. {STYLE}"
    body = {"input": {"prompt": prompt, **input_extra}}
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Prefer": "wait",
    }
    pred = post(api_url, body, headers)
    while pred.get("status") in ("starting", "processing"):
        time.sleep(1)
        pred = get(pred["urls"]["get"], {"Authorization": f"Bearer {token}"})
    if pred.get("status") != "succeeded":
        raise RuntimeError(
            f"prediction failed: {pred.get('status')}: {pred.get('error')}"
        )
    out = pred["output"]
    if isinstance(out, list):
        out = out[0]
    # Detect extension from URL since recraft returns png/webp depending on model.
    ext = pathlib.Path(urllib.parse.urlparse(out).path).suffix or ".webp"
    dest = out_dir / f"{station_id}{ext}"
    download(out, dest)
    print(f"  ✓ {dest}  ({dest.stat().st_size // 1024} KiB)")


def main():
    profile_name = sys.argv[1] if len(sys.argv) > 1 else "flux"
    if profile_name not in PROFILES:
        print(f"unknown profile {profile_name!r}; choices: {list(PROFILES)}", file=sys.stderr)
        sys.exit(2)
    profile = PROFILES[profile_name]
    out_dir = pathlib.Path(profile["out_dir"])
    out_dir.mkdir(parents=True, exist_ok=True)
    api_url = f"https://api.replicate.com/v1/models/{profile['model']}/predictions"

    load_env()
    token = os.environ.get("REPLICATE_API_KEY") or os.environ.get(
        "REPLICATE_API_TOKEN"
    )
    if not token:
        print("REPLICATE_API_KEY not set", file=sys.stderr)
        sys.exit(1)
    print(f"profile={profile_name}  model={profile['model']}  out={out_dir}")
    for sid, scene in STATIONS:
        print(f"[{sid}]")
        try:
            generate(api_url, sid, scene, token, profile["input_extra"], out_dir)
        except Exception as e:
            print(f"  ✗ failed: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
