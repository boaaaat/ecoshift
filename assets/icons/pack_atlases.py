"""Pack generated art for Roblox and produce human visual-review sheets.

This is asset preparation, not an image generator: it only slices, pads and
resizes existing AI artwork. It never draws or recolors item illustrations.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
PLAN = ROOT / "atlas-plan.json"
TILE = 256


def gutters(image, axis):
    """Find the actual transparent gutters near the requested quarter grid."""
    alpha = image.getchannel("A")
    length = image.height if axis == "y" else image.width
    scores = []
    for p in range(length):
        strip = alpha.crop((0, p, image.width, p + 1) if axis == "y" else (p, 0, p + 1, image.height))
        scores.append(sum(strip.histogram()[16:]))
    cuts = [0]
    for quarter in range(1, 4):
        center = length * quarter / 4
        lo, hi = round(center - length * .05), round(center + length * .05)
        minimum = min(scores[lo:hi])
        runs = []
        start = None
        for p in range(lo, hi + 1):
            empty = p < hi and scores[p] <= minimum + 1
            if empty and start is None:
                start = p
            elif not empty and start is not None:
                runs.append((start, p))
                start = None
        a, b = max(runs, key=lambda run: (run[1] - run[0], -abs((run[0] + run[1]) / 2 - center)))
        cuts.append((a + b) // 2)
    return cuts + [length]


def prepare():
    sheets = json.loads(PLAN.read_text(encoding="utf-8"))
    output = ROOT / "published"
    review = ROOT / "review"
    output.mkdir(exist_ok=True)
    review.mkdir(exist_ok=True)
    font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 12)
    overview = Image.new("RGB", (1152, 1840), "#19211d")
    overview_draw = ImageDraw.Draw(overview)
    overview_index = 0
    for sheet in sheets:
        source = ROOT / (sheet["key"] + ".png")
        if not source.exists():
            continue
        image = Image.open(source).convert("RGBA")
        rows = gutters(image, "y")
        atlas = Image.new("RGBA", (TILE * 4, TILE * 4))
        preview = Image.new("RGB", (768, 440), "#19211d")
        draw = ImageDraw.Draw(preview)
        draw.text((16, 10), sheet["key"] + " | 64px and 40px actual-size previews", font=font, fill="#ebe9d3")
        for index, item_id in enumerate(sheet["ids"]):
            col, row = index % 4, index // 4
            strip = image.crop((0, rows[row], image.width, rows[row + 1]))
            columns = gutters(strip, "x")
            cell = strip.crop((columns[col], 0, columns[col + 1], strip.height))
            # Keep every nontransparent pixel. Alpha is preserved; no keying.
            bounds = cell.getchannel("A").getbbox()
            if bounds:
                cell = cell.crop(bounds)
            cell.thumbnail((224, 224), Image.Resampling.LANCZOS)
            tile = Image.new("RGBA", (TILE, TILE))
            tile.alpha_composite(cell, ((TILE - cell.width) // 2, (TILE - cell.height) // 2))
            atlas.alpha_composite(tile, (col * TILE, row * TILE))
            ox, oy = (overview_index % 12) * 96, (overview_index // 12) * 58
            tiny = tile.resize((48, 48), Image.Resampling.LANCZOS)
            overview.paste(tiny, (ox + 24, oy), tiny)
            overview_draw.text((ox + 3, oy + 47), item_id[:16], font=font, fill="#ebe9d3")
            overview_index += 1
            x, y = col * 192 + 14, row * 100 + 36
            draw.rounded_rectangle((x, y, x + 70, y + 70), 8, fill="#2f392e")
            draw.rounded_rectangle((x + 81, y + 22, x + 125, y + 66), 6, fill="#ebe7d1")
            preview.paste(tile.resize((64, 64), Image.Resampling.LANCZOS), (x + 3, y + 3), tile.resize((64, 64), Image.Resampling.LANCZOS))
            small = tile.resize((40, 40), Image.Resampling.LANCZOS)
            preview.paste(small, (x + 83, y + 24), small)
            draw.text((x, y + 73), item_id, font=font, fill="#ebe9d3")
        atlas.save(output / (sheet["key"] + ".png"))
        preview.save(review / (sheet["key"] + ".png"))
        print(sheet["key"], image.size, "-> 1024px atlas; review ready")
    overview.save(review / "all-items.png")


if __name__ == "__main__":
    prepare()
