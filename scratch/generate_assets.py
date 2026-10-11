import math
from PIL import Image, ImageDraw, ImageFont

def draw_badge(size, is_transparent_bg=False, padding_ratio=0.08):
    scale = 4
    canvas_size = size * scale
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    s = canvas_size / 512.0
    pad = int(canvas_size * padding_ratio)
    
    if not is_transparent_bg:
        # Base rounded container (squircle)
        rect = [pad, pad, canvas_size - pad, canvas_size - pad]
        rx = int((canvas_size - 2 * pad) * 0.25)
        draw.rounded_rectangle(rect, radius=rx, fill=(11, 19, 43, 255), outline=(30, 41, 59, 255), width=max(1, int(3 * s)))

    cx = canvas_size / 2.0
    cy = canvas_size / 2.0

    # 1. Outer telemetry orbit
    r_orbit = 186 * s
    draw.ellipse([cx - r_orbit, cy - r_orbit, cx + r_orbit, cy + r_orbit], outline=(30, 41, 59, 180), width=max(1, int(3 * s)))

    # 2. Outer Active Radar Arc (270 degrees)
    r_arc = 138 * s
    draw.arc([cx - r_arc, cy - r_arc, cx + r_arc, cy + r_arc], start=135, end=405, fill=(0, 245, 212, 230), width=max(2, int(10 * s)))

    # 3. Inner telemetry target circle
    r_target = 88 * s
    draw.ellipse([cx - r_target, cy - r_target, cx + r_target, cy + r_target], outline=(14, 165, 233, 140), width=max(1, int(4 * s)))

    # 4. Stylized Monogram "T"
    # Horizontal top crossbar
    bar_w = 204 * s
    bar_h = 32 * s
    bx = cx - bar_w / 2.0
    by = 148 * s
    draw.rounded_rectangle([bx, by, bx + bar_w, by + bar_h], radius=int(bar_h / 2.0), fill=(0, 245, 212, 255))

    # Vertical stem of "T"
    stem_w = 28 * s
    stem_top = by + bar_h * 0.5
    stem_bot = 248 * s
    draw.rounded_rectangle([cx - stem_w / 2.0, stem_top, cx + stem_w / 2.0, stem_bot], radius=int(stem_w / 2.0), fill=(16, 185, 129, 255))

    # 5. Central target ping beacon (at cx, cy + 18*s = 274*s)
    beacon_cy = 274 * s
    r_beacon_out = 52 * s
    draw.ellipse([cx - r_beacon_out, beacon_cy - r_beacon_out, cx + r_beacon_out, beacon_cy + r_beacon_out], fill=(11, 19, 43, 255), outline=(0, 245, 212, 255), width=max(2, int(8 * s)))

    r_beacon_in = 26 * s
    draw.ellipse([cx - r_beacon_in, beacon_cy - r_beacon_in, cx + r_beacon_in, beacon_cy + r_beacon_in], fill=(0, 245, 212, 255))

    r_beacon_core = 10 * s
    draw.ellipse([cx - r_beacon_core, beacon_cy - r_beacon_core, cx + r_beacon_core, beacon_cy + r_beacon_core], fill=(255, 255, 255, 255))

    # 6. Cardinal telemetry tick marks
    notch_len = 34 * s
    notch_w = max(1, int(4 * s))
    draw.line([cx, 76 * s, cx, 76 * s + notch_len], fill=(0, 245, 212, 220), width=notch_w)
    draw.line([cx, (512 - 76 - 34) * s, cx, (512 - 76) * s], fill=(0, 245, 212, 220), width=notch_w)
    draw.line([76 * s, cy, 76 * s + notch_len, cy], fill=(0, 245, 212, 220), width=notch_w)
    draw.line([(512 - 76 - 34) * s, cy, (512 - 76) * s, cy], fill=(0, 245, 212, 220), width=notch_w)

    return img.resize((size, size), Image.Resampling.LANCZOS)

def draw_wordmark(width=640, height=160):
    scale = 4
    w = width * scale
    h = height * scale
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Left icon
    icon_size = int(120 * scale)
    icon_img = draw_badge(120, is_transparent_bg=False, padding_ratio=0.05).resize((icon_size, icon_size), Image.Resampling.LANCZOS)
    img.paste(icon_img, (int(20 * scale), int(20 * scale)), icon_img)

    # Fonts
    try:
        font_main = ImageFont.truetype("arialbd.ttf", int(44 * scale))
        font_sub = ImageFont.truetype("arial.ttf", int(16 * scale))
    except Exception:
        font_main = ImageFont.load_default()
        font_sub = ImageFont.load_default()

    # Draw "Tester"
    tx = int(160 * scale)
    ty = int(36 * scale)
    draw.text((tx, ty), "Tester", font=font_main, fill=(248, 250, 252, 255))
    
    # Calculate width of "Tester" to position "Track"
    bbox = draw.textbbox((tx, ty), "Tester", font=font_main)
    track_x = bbox[2] + int(2 * scale)
    draw.text((track_x, ty), "Track", font=font_main, fill=(0, 245, 212, 255))

    # Tagline
    tag_y = int(98 * scale)
    draw.text((tx + int(2 * scale), tag_y), "Know who is actually testing.", font=font_sub, fill=(148, 163, 184, 255))

    return img.resize((width, height), Image.Resampling.LANCZOS)

def main():
    print("Generating brand assets...")
    
    # 1. Favicon (64x64 PNG)
    favicon = draw_badge(64, is_transparent_bg=False, padding_ratio=0.08)
    favicon.save("dashboard/web/favicon.png", "PNG")
    print("[OK] dashboard/web/favicon.png")

    # 2. PWA Icon 192 (192x192 PNG)
    icon_192 = draw_badge(192, is_transparent_bg=False, padding_ratio=0.08)
    icon_192.save("dashboard/web/icons/Icon-192.png", "PNG")
    print("[OK] dashboard/web/icons/Icon-192.png")

    # 3. PWA Icon 512 (512x512 PNG)
    icon_512 = draw_badge(512, is_transparent_bg=False, padding_ratio=0.08)
    icon_512.save("dashboard/web/icons/Icon-512.png", "PNG")
    print("[OK] dashboard/web/icons/Icon-512.png")

    # 4. Maskable Icons (Safe zone padding 18%)
    maskable_192 = draw_badge(192, is_transparent_bg=False, padding_ratio=0.18)
    maskable_192.save("dashboard/web/icons/Icon-maskable-192.png", "PNG")
    maskable_512 = draw_badge(512, is_transparent_bg=False, padding_ratio=0.18)
    maskable_512.save("dashboard/web/icons/Icon-maskable-512.png", "PNG")
    print("[OK] dashboard/web/icons/Icon-maskable-*.png")

    # 5. Transparent-background logo for Flutter dashboard
    logo_transparent = draw_badge(512, is_transparent_bg=True, padding_ratio=0.05)
    logo_transparent.save("dashboard/assets/images/logo.png", "PNG")
    logo_transparent.save("dashboard/web/assets/logo.png", "PNG")
    print("[OK] dashboard/assets/images/logo.png")

    # 6. Wordmark with Tagline
    wordmark = draw_wordmark(640, 160)
    wordmark.save("dashboard/assets/images/logo_wordmark.png", "PNG")
    wordmark.save("dashboard/web/assets/logo_wordmark.png", "PNG")
    print("[OK] dashboard/assets/images/logo_wordmark.png")

    print("All assets successfully generated!")

if __name__ == "__main__":
    main()
