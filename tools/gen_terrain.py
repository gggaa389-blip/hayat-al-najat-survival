#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
أداة توليد التضاريس وخريطة العالم لمشروع «حياة النجاة»
تنتج:
  - data/heights.raw     : ارتفاعات f32 خام (1536x1536) لـ Terrain3D
  - data/splat.raw       : خريطة الخامات (u8): 0 عشب، 1 رمل، 2 تراب، 3 صخر
  - data/layout.json     : مواقع الطرق والمناطق والمباني واللوحات
  - assets/textures/*.png: خامات التضاريس (albedo + normal)
  - tools/preview_map.png: معاينة علوية للخريطة
"""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
TEX = os.path.join(ROOT, "assets", "textures")
os.makedirs(DATA, exist_ok=True)
os.makedirs(TEX, exist_ok=True)

N = 1536          # عدد النقاط لكل محور (1m / نقطة)
SIZE = 1536       # حجم الخريطة بالأمتار
rng = np.random.default_rng(20261016)

# ---------------------------------------------------------------- ضجيج fBm
def value_noise(res, size, seed):
    r = np.random.default_rng(seed)
    g = r.random((res + 1, res + 1))
    xs = np.linspace(0, res, size, endpoint=False)
    ys = np.linspace(0, res, size, endpoint=False)
    x0 = np.floor(xs).astype(int); y0 = np.floor(ys).astype(int)
    x1 = np.minimum(x0 + 1, res); y1 = np.minimum(y0 + 1, res)
    fx = (xs - x0)[None, :]; fy = (ys - y0)[:, None]
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)   # smoothstep
    a = g[np.ix_(y0, x0)]; b = g[np.ix_(y0, x1)]
    c = g[np.ix_(y1, x0)]; d = g[np.ix_(y1, x1)]
    return a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy

def fbm(size, octaves, base_res, seed):
    out = np.zeros((size, size)); amp = 1.0; tot = 0.0
    for o in range(octaves):
        out += amp * value_noise(min(base_res * 2 ** o, size // 2), size, seed + o * 77)
        tot += amp; amp *= 0.5
    return out / tot

yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)   # yy=Z, xx=X

# ---------------------------------------------------------------- مناطق الخريطة
TOWN   = (500, 800)     # مركز البلدة
MARKET = (1080, 900)    # مركز السوق (150x150)
FOREST = (320, 320)     # مركز الغابة (250x250)
LAKE_A = (1150, 300)    # البحيرة الكبيرة (جسر + سنارة)
LAKE_B = (320, 1150)    # البحيرة الصغيرة
HOUSE  = (620, 920)     # منزل اللاعب

def dist2(cx, cz):
    return np.sqrt((xx - cx) ** 2 + (yy - cz) ** 2)

def box_dist(cx, cz, hx, hz):
    dx = np.maximum(np.abs(xx - cx) - hx, 0)
    dz = np.maximum(np.abs(yy - cz) - hz, 0)
    return np.sqrt(dx * dx + dz * dz)

def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / max(e1 - e0, 1e-6), 0, 1)
    return t * t * (3 - 2 * t)

# ---------------------------------------------------------------- الارتفاعات
base = 3.0 + fbm(N, 5, 4, 11) * 6.0                      # تلال خفيفة 3..9
hills = fbm(N, 4, 2, 29) ** 2.0 * 34.0                    # هضاب كبيرة في الأطراف

# قناع الهضاب: قوي خارج المدن، ضعيف في المراكز
d_town = dist2(*TOWN); d_market = box_dist(MARKET[0], MARKET[1], 110, 110)
d_forest = box_dist(FOREST[0], FOREST[1], 130, 130); d_house = dist2(*HOUSE)
center_w = np.maximum.reduce([
    1.0 - smoothstep(120, 300, d_town),
    1.0 - smoothstep(60, 190, d_market),
    1.0 - smoothstep(40, 90, d_house),
])
hills *= (1.0 - 0.92 * center_w)
h = base + hills

# رفع خفيف في الغابة (تلال متوسطة 6-14م)
forest_w = 1.0 - smoothstep(120, 175, d_forest)
forest_h = 5.5 + fbm(N, 4, 6, 47) * 9.0
h = h * (1 - forest_w) + forest_h * forest_w

# منصات مسطحة: البلدة والسوق والمنزل
def plateau(h, target, mask):
    return h * (1 - mask) + target * mask

h = plateau(h, 4.0, 1.0 - smoothstep(120, 175, d_town))
h = plateau(h, 3.0, 1.0 - smoothstep(95, 130, d_market))
h = plateau(h, 4.2, 1.0 - smoothstep(30, 48, d_house))

# أحواض البحيرات
def lake_bowl(h, cx, cz, radius, bed):
    d = dist2(cx, cz)
    inner = 1.0 - smoothstep(radius * 0.45, radius, d)      # 1 داخل البحيرة
    bowl = bed + (1.0 - (d / (radius * 1.05)).clip(0, 1) ** 2) * 0.5
    return h * (1 - inner) + bowl * inner

h = lake_bowl(h, LAKE_A[0], LAKE_A[1], 88, -4.5)
h = lake_bowl(h, LAKE_B[0], LAKE_B[1], 70, -4.0)

# حواف الخريطة: جبال طبيعية تمنع الخروج
edge = np.minimum(np.minimum(xx, SIZE - 1 - xx), np.minimum(yy, SIZE - 1 - yy))
edge_w = 1.0 - smoothstep(30, 120, edge)
h += edge_w * (18.0 + fbm(N, 3, 3, 91) * 22.0)

# ---------------------------------------------------------------- الطرق
def catmull(points, samples_per_seg=16):
    pts = np.array(points, dtype=np.float64)
    if len(pts) < 3:
        return pts
    ext = np.vstack([pts[0] + (pts[0] - pts[1]), pts, pts[-1] + (pts[-1] - pts[-2])])
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for t in np.linspace(0, 1, samples_per_seg, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t +
                              (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
                              (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return np.array(out)

# (نقاط، عرض، نوع)  نوع: sand=رمل، dirt=طيني (الغابة)
ROADS = [
    # الطريق الرئيسي شرق-غرب
    ([(120, 795), (350, 800), (500, 800), (760, 805), (1000, 800), (1250, 795), (1440, 800)], 7.0, "sand"),
    # الطريق الرئيسي شمال-جنوب
    ([(505, 120), (500, 400), (500, 620), (500, 800), (505, 1050), (510, 1280), (505, 1450)], 7.0, "sand"),
    # طريق الغابة الطيني المتعرج
    ([(350, 800), (330, 720), (360, 640), (320, 560), (285, 490), (310, 445)], 5.0, "dirt"),
    # فرع البحيرة الكبيرة + الجسر
    ([(1150, 800), (1155, 640), (1148, 500), (1150, 420)], 5.5, "sand"),
    # فرع البحيرة الصغيرة
    ([(500, 1150), (430, 1155), (360, 1150), (300, 1145)], 5.0, "sand"),
    # فرع منزل اللاعب
    ([(620, 800), (620, 850), (620, 895)], 5.0, "sand"),
    # ساحة السوق
    ([(1005, 800), (1005, 860), (1005, 920)], 5.0, "sand"),
    # نجفة محطة الوقود الشمالية
    ([(510, 1250), (560, 1250)], 4.0, "sand"),
]

road_polys = []   # للاستخدام في splat + json
for pts, width, kind in ROADS:
    line = catmull(pts, 20)
    road_polys.append((line, width, kind))

# تنعيم الارتفاعات تحت الطرق (مقطع طولي منخفض التردد)
for line, width, kind in road_polys:
    # نأخذ ارتفاعات تقريبية على المحور ثم ننعّمها
    idx = np.clip(line.astype(int), 0, N - 1)
    h_along = h[idx[:, 1], idx[:, 0]]
    kernel = np.ones(41) / 41.0
    h_smooth = np.convolve(np.pad(h_along, 20, mode="edge"), kernel, mode="valid")
    # تأثير مخروطي حول الخط
    step = max(1, len(line) // 120)
    for i in range(0, len(line), step):
        px, pz = line[i]
        r = width * 2.2
        x0, x1 = int(max(0, px - r)), int(min(N, px + r + 1))
        z0, z1 = int(max(0, pz - r)), int(min(N, pz + r + 1))
        if x0 >= x1 or z0 >= z1:
            continue
        sub_x = xx[z0:z1, x0:x1] - px
        sub_z = yy[z0:z1, x0:x1] - pz
        d = np.sqrt(sub_x ** 2 + sub_z ** 2)
        w = (1.0 - smoothstep(width * 0.6, r, d)) * 0.9
        h[z0:z1, x0:x1] = h[z0:z1, x0:x1] * (1 - w) + h_smooth[i] * w

# ---------------------------------------------------------------- خريطة الخامات
splat = np.zeros((N, N), dtype=np.uint8)      # 0 عشب 1 رمل 2 تراب 3 صخر
# عشب افتراضي + تضاريس صخرية على المنحدرات الشديدة
gy, gx = np.gradient(h)
slope = np.sqrt(gx ** 2 + gy ** 2)
splat[slope > 0.55] = 3
# تراب الغابة
splat[(forest_w > 0.35) & (splat == 0)] = 2
# رمل قرب البحيرات (شواطئ)
for (cx, cz), r in [(LAKE_A, 88), (LAKE_B, 70)]:
    d = dist2(cx, cz)
    splat[(d < r * 1.18) & (d > r * 0.35) & (splat != 3)] = 1
# رمل قرب البلدة والسوق (الشوارع)
splat[(1.0 - smoothstep(120, 165, d_town) > 0.4) & (splat != 3)] = 1
splat[(1.0 - smoothstep(95, 128, d_market) > 0.4) & (splat != 3)] = 1
splat[(1.0 - smoothstep(28, 44, d_house) > 0.4) & (splat != 3)] = 1

# طلاء الطرق (بعد التضاريس)
for line, width, kind in road_polys:
    tid = 2 if kind == "dirt" else 1
    step = max(1, len(line) // 200)
    for i in range(0, len(line), step):
        px, pz = line[i]
        r = width
        x0, x1 = int(max(0, px - r - 2)), int(min(N, px + r + 3))
        z0, z1 = int(max(0, pz - r - 2)), int(min(N, pz + r + 3))
        if x0 >= x1 or z0 >= z1:
            continue
        sub_x = xx[z0:z1, x0:x1] - px
        sub_z = yy[z0:z1, x0:x1] - pz
        d = np.sqrt(sub_x ** 2 + sub_z ** 2)
        splat[z0:z1, x0:x1][d < width] = tid

# ---------------------------------------------------------------- خامات التضاريس
def make_texture(name, base_color, dark_color, noise_seed, scale=0.06, normal_strength=2.2):
    """ينشئ خامة قابلة للتكرار (albedo + normal)"""
    T = 256
    n1 = fbm(T, 4, 4, noise_seed)
    n2 = value_noise(32, T, noise_seed + 5)
    t = (n1 * 0.65 + n2 * 0.35)
    t = (t - t.min()) / (t.max() - t.min() + 1e-6)
    base_c = np.array(base_color, dtype=np.float32)
    dark_c = np.array(dark_color, dtype=np.float32)
    img = dark_c[None, None, :] + (base_c - dark_c)[None, None, :] * t[:, :, None]
    # تحبّب دقيق
    grain = (np.random.default_rng(noise_seed).random((T, T, 1)) - 0.5) * 14
    img = np.clip(img + grain, 0, 255).astype(np.uint8)
    Image.fromarray(img).save(os.path.join(TEX, f"{name}_albedo.png"))
    # خريطة عادية من التدرج
    hgt = t.astype(np.float32)
    gy2, gx2 = np.gradient(hgt)
    nx = -gx2 * normal_strength * 32
    ny = -gy2 * normal_strength * 32
    nz = np.ones_like(nx)
    ln = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    nimg = np.stack([(nx / ln * 0.5 + 0.5) * 255, (ny / ln * 0.5 + 0.5) * 255,
                     (nz / ln * 0.5 + 0.5) * 255], axis=-1).astype(np.uint8)
    Image.fromarray(nimg).save(os.path.join(TEX, f"{name}_normal.png"))

make_texture("grass", (106, 150, 72), (62, 102, 44), 3)
make_texture("sand",  (203, 178, 128), (168, 141, 96), 13)
make_texture("dirt",  (133, 98, 67), (94, 66, 44), 23)
make_texture("rock",  (122, 120, 118), (78, 76, 75), 33)

# ---------------------------------------------------------------- حفظ البيانات
h = np.clip(h, -12, 90)
h.astype("<f4").tofile(os.path.join(DATA, "heights.raw"))
splat.tofile(os.path.join(DATA, "splat.raw"))
np.save(os.path.join(DATA, "heights.npy"), h.astype(np.float32))

# ---------------------------------------------------------------- كثافة الأشجار
tree_mask = np.zeros((N, N), dtype=np.uint8)   # 0 لا شيء 1 متفرق 2 كثيف
rnd = np.random.default_rng(5).random((N, N))
tree_mask[(forest_w > 0.45) & (rnd < 0.16)] = 2
hill_zone = (hills > 9) & (slope < 0.5)
tree_mask[(hill_zone) & (rnd > 0.988) & (tree_mask == 0)] = 1
tree_mask[(tree_mask == 0) & (rnd > 0.9975)] = 1
# إزالة الأشجار من الطرق والمناطق المبنية
avoid = (1.0 - smoothstep(120, 165, d_town) > 0.25) | \
        (1.0 - smoothstep(95, 130, d_market) > 0.25) | \
        (1.0 - smoothstep(32, 48, d_house) > 0.25)
tree_mask[avoid] = 0
for line, width, kind in road_polys:
    step = max(1, len(line) // 150)
    for i in range(0, len(line), step):
        px, pz = line[i]
        r = width + 6
        x0, x1 = int(max(0, px - r)), int(min(N, px + r + 1))
        z0, z1 = int(max(0, pz - r)), int(min(N, pz + r + 1))
        if x0 >= x1 or z0 >= z1:
            continue
        d = np.sqrt((xx[z0:z1, x0:x1] - px) ** 2 + (yy[z0:z1, x0:x1] - pz) ** 2)
        tree_mask[z0:z1, x0:x1][d < r] = 0
# لا أشجار داخل البحيرات
for (cx, cz), r in [(LAKE_A, 95), (LAKE_B, 78)]:
    tree_mask[dist2(cx, cz) < r] = 0
tree_mask.tofile(os.path.join(DATA, "treemask.raw"))
Image.fromarray((tree_mask * 100).astype(np.uint8)).save(os.path.join(DATA, "treemask.png"))

# ---------------------------------------------------------------- layout.json
def road_json():
    out = []
    for line, width, kind in road_polys:
        pts = [[round(float(x), 1), round(float(z), 1)] for x, z in line[:: max(1, len(line) // 60)]]
        out.append({"points": pts, "width": width, "kind": kind})
    return out

# بيوت البلدة الملونة (شوارع داخلية)
houses = []
house_colors = ["#e8b06c", "#d97f6e", "#7fb5a2", "#c9a2e0", "#e8d27a", "#8ab6e8", "#e89ab0", "#b8d97f"]
hx0, hz0 = TOWN[0] - 175, TOWN[1] - 175
positions = []
for row in range(5):
    for col in range(5):
        x = hx0 + 55 + col * 78
        z = hz0 + 50 + row * 80
        d = math.hypot(x - TOWN[0], z - TOWN[1])
        if d > 178 or (abs(x - 500) < 26) or (abs(z - 800) < 24):
            continue     # لا نبني على الطرق الرئيسية
        if math.hypot(x - HOUSE[0], z - HOUSE[1]) < 48:
            continue
        positions.append((x, z))
for i, (x, z) in enumerate(positions):
    houses.append({
        "model": f"buildings/building-type-{chr(ord('a') + (i * 3) % 12)}.glb",
        "x": round(x + float(rng.uniform(-6, 6)), 1),
        "z": round(z + float(rng.uniform(-6, 6)), 1),
        "rot": float(rng.choice([0, 90, 180, 270])) if i % 3 else float(rng.uniform(-12, 12)),
        "color": house_colors[i % len(house_colors)],
    })

# محلات السوق (150x150) بمظلات ولوحات
market_shops = [
    {"model": "buildings/building-a.glb", "x": MARKET[0] - 42, "z": MARKET[1] - 48, "rot": 0,
     "sign": "متجر الطعام", "kind": "food"},
    {"model": "buildings/building-b.glb", "x": MARKET[0] + 8, "z": MARKET[1] - 48, "rot": 0,
     "sign": "متجر الماء", "kind": "water"},
    {"model": "buildings/building-c.glb", "x": MARKET[0] + 52, "z": MARKET[1] - 48, "rot": 0,
     "sign": "ترياق النوم", "kind": "sleep"},
    {"model": "buildings/building-d.glb", "x": MARKET[0] - 42, "z": MARKET[1] + 42, "rot": 180,
     "sign": "متجر الأسماك", "kind": "fish"},
    {"model": "buildings/building-a.glb", "x": MARKET[0] + 22, "z": MARKET[1] + 42, "rot": 180,
     "sign": "متجر الحيوانات", "kind": "animals"},
]
for s in market_shops:
    s["x"] = round(s["x"], 1); s["z"] = round(s["z"], 1)

# محطات الوقود الثلاث
gas_stations = [
    {"x": 985, "z": 745, "rot": 0, "sign": "محطة وقود – السوق"},
    {"x": 565, "z": 705, "rot": 90, "sign": "محطة وقود – البلدة"},
    {"x": 575, "z": 1255, "rot": 180, "sign": "محطة وقود – الشمال"},
]

# اللوحات الإرشادية
signs = [
    {"x": 500, "z": 700, "rot": 0, "text": "بلدة", "green": True},
    {"x": 1005, "z": 785, "rot": -90, "text": "السوق", "green": True},
    {"x": 352, "z": 745, "rot": 25, "text": "الغابة", "green": True},
    {"x": 1150, "z": 455, "rot": 180, "text": "البحيرة", "green": True},
    {"x": 370, "z": 1150, "rot": 90, "text": "البحيرة", "green": True},
    {"x": 640, "z": 878, "rot": 180, "text": "منزل اللاعب", "green": False},
]

layout = {
    "map_size": SIZE,
    "region_size": 512,
    "regions": [[x, z] for x in range(3) for z in range(3)],
    "town": {"center": list(TOWN), "radius": 175},
    "market": {"center": list(MARKET), "half": 75},
    "forest": {"center": list(FOREST), "half": 125},
    "lakes": [
        {"center": list(LAKE_A), "radius": 88, "water_y": 1.2, "bridge": True, "rod": True},
        {"center": list(LAKE_B), "radius": 70, "water_y": 1.6, "bridge": False, "rod": False},
    ],
    "house": {"center": list(HOUSE), "yard_half": 24, "gate_side": "south"},
    "roads": road_json(),
    "houses": houses,
    "market_shops": market_shops,
    "gas_stations": gas_stations,
    "signs": signs,
    "tree_density": {"forest": 0.16, "sparse": 0.008, "bush": 0.05, "rock": 0.012},
}
with open(os.path.join(DATA, "layout.json"), "w", encoding="utf-8") as f:
    json.dump(layout, f, ensure_ascii=False, indent=1)

# ---------------------------------------------------------------- معاينة علوية
print("جارٍ رسم المعاينة...")
prev = np.zeros((N, N, 3), dtype=np.uint8)
pal = {0: (106, 150, 72), 1: (203, 178, 128), 2: (133, 98, 67), 3: (122, 120, 118)}
for k, c in pal.items():
    prev[splat == k] = c
shade = np.clip(1.0 + (np.gradient(h)[0] + np.gradient(h)[1]) * 0.35, 0.55, 1.45)
prev = np.clip(prev * shade[:, :, None], 0, 255).astype(np.uint8)
# ماء البحيرات
for (cx, cz), r, wy in [(LAKE_A, 88, 1.2), (LAKE_B, 70, 1.6)]:
    m = (dist2(cx, cz) < r * 0.92) & (h < wy + 0.35)
    prev[m] = (52, 110, 170)
img = Image.fromarray(prev)
dr = ImageDraw.Draw(img)
for line, width, kind in road_polys:
    pts = [(float(x), float(z)) for x, z in line]
    col = (190, 165, 115) if kind == "sand" else (110, 82, 55)
    dr.line(pts, fill=col, width=int(width))
for hse in houses:
    dr.rectangle([hse["x"] - 7, hse["z"] - 7, hse["x"] + 7, hse["z"] + 7], fill=(210, 210, 210))
for s in market_shops:
    dr.rectangle([s["x"] - 10, s["z"] - 10, s["x"] + 10, s["z"] + 10], fill=(235, 200, 120))
for g in gas_stations:
    dr.rectangle([g["x"] - 12, g["z"] - 12, g["x"] + 12, g["z"] + 12], fill=(230, 90, 70))
dr.rectangle([HOUSE[0] - 24, HOUSE[1] - 24, HOUSE[0] + 24, HOUSE[1] + 24], outline=(255, 255, 255), width=3)
img = img.transpose(Image.FLIP_TOP_BOTTOM)   # z+ للأعلى
img.save(os.path.join(ROOT, "tools", "preview_map.png"))
print("تم! الملفات في data/ و assets/textures/ و tools/preview_map.png")
print(f"نطاق الارتفاعات: {h.min():.1f} .. {h.max():.1f} م")
