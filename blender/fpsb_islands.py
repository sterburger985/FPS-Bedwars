"""FPS Bedwars island kit generator (Blender 5.2).

Builds every island-type mesh for the map from code so it can be regenerated:
team islands x5, center island, resource platform base, outcrop pool, the center
arch and distant horizon islands.

Conventions (see docs/superpowers/specs/2026-10-25-map-design.md):
- 1 Blender unit = 1 stud. Blender +Z is up.
- Island-local front (toward the map centre) is Blender -Y. Back is +Y.
- Island origin = island top centre (top plane at Z = 0).
- Every object name ends in a material key (_Sand, _Rock, _RockDark, _Concrete, _Steel).
- Each object stays under 20,000 triangles.

Run inside Blender:  exec(open(r"C:\\Roblox Dev\\FPS Bedwars\\blender\\fpsb_islands.py").read())
"""

import math
import random

import bmesh
import bpy
from mathutils import Vector, noise

TRI_LIMIT = 20000
COLLECTION = "FPSB_Islands"

# Team island: flat build zone 120 x 96, pushed 6 studs toward the back (+Y).
TEAM_BUILD = (120.0, 96.0)
TEAM_BUILD_OFFSET_Y = 6.0
TEAM_HALF = (78.0, 66.0)  # p=4 superellipse that encloses the build zone + 6-stud margin
TEAM_SEEDS = [11, 23, 37, 41, 59]

CENTER_HALF = (82.0, 82.0)
CENTER_FLAT_RADIUS = 72.0

ANGLES = 300  # samples around an outline (~1.5 studs apart)


# ---------------------------------------------------------------- helpers

def n1(x, y=0.0, z=0.0):
    """Perlin noise in [-1, 1]."""
    return noise.noise(Vector((x, y, z)))


def fbm(x, y, z, octaves=3):
    total, amp, freq, norm = 0.0, 1.0, 1.0, 0.0
    for _ in range(octaves):
        total += amp * n1(x * freq, y * freq, z * freq)
        norm += amp
        amp *= 0.5
        freq *= 2.0
    return total / norm


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def superellipse(theta, a, b, p):
    c, s = math.cos(theta), math.sin(theta)
    r = (abs(c / a) ** p + abs(s / b) ** p) ** (-1.0 / p)
    return r * c, r * s


def get_collection():
    col = bpy.data.collections.get(COLLECTION)
    if col is None:
        col = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(col)
    return col


def clear_collection():
    col = get_collection()
    for ob in list(col.objects):
        mesh = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        if mesh and mesh.users == 0:
            bpy.data.meshes.remove(mesh)


def make_object(name, bm, smooth_angle=None, parent=None, recalc=False):
    mesh = bpy.data.meshes.new(name)
    if recalc:  # only safe for closed meshes
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new(name, mesh)
    get_collection().objects.link(ob)
    if parent is not None:
        ob.parent = parent
    if smooth_angle is None:
        for poly in mesh.polygons:
            poly.use_smooth = False
    else:
        mesh.shade_smooth()
        mesh.set_sharp_from_angle(angle=math.radians(smooth_angle))
    return ob


def make_empty(name):
    ob = bpy.data.objects.new(name, None)
    get_collection().objects.link(ob)
    return ob


def loft_rings(bm, rings, flip=False, cap_last=None, cap_first=None):
    """rings: list of closed loops (lists of Vector), all the same length, angle increasing CCW.
    Connects consecutive rings with quads. Winding is explicit so open surfaces face the
    right way: flip=False gives outward faces when rings move inward/up, flip=True when
    rings move downward (cliffs, undersides). cap_last / cap_first close the end loops
    with a fan to a point."""
    vrings = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(vrings[:-1], vrings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], b[i], b[j], a[j]) if flip else (a[i], a[j], b[j], b[i]))
    if cap_last is not None:
        tip = bm.verts.new(cap_last)
        last = vrings[-1]
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((last[i], tip, last[j]) if flip else (last[i], last[j], tip))
    if cap_first is not None:
        top = bm.verts.new(cap_first)
        first = vrings[0]
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((top, first[i], first[j]) if flip else (top, first[j], first[i]))
    return vrings


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


# ---------------------------------------------------------------- island

class Blocks:
    """Piecewise-constant offsets around a closed outline: gives vertical fractures and
    blocky faces. Each block spans `wmin..wmax` samples; offsets in [-amp, amp]."""

    def __init__(self, n, seed, amp, wmin=4, wmax=10, bias=0.0):
        rng = random.Random(seed)
        self.vals = [0.0] * n
        i = rng.randrange(n)
        start = i
        covered = 0
        while covered < n:
            w = rng.randint(wmin, wmax)
            v = rng.uniform(-amp, amp) + bias
            for k in range(w):
                if covered >= n:
                    break
                self.vals[(i + k) % n] = v
                covered += 1
            i = (i + w) % n

    def __getitem__(self, i):
        return self.vals[i % len(self.vals)]


def smax(a, b, k):
    return 0.5 * (a + b + math.sqrt((a - b) ** 2 + k * k))


def outline_points(half, exponent, centre_y, seed, wobble, inner_min, calm_front=False, lobe_count=3):
    """Irregular closed outline with bays and promontories. Returns list of (x, y, theta).
    `inner_min(theta)` is a soft minimum radius (keeps the build zone safe).
    calm_front keeps the edge facing the map centre (Blender -Y) even, so every team's
    bridge distance to the centre is the same."""
    rng = random.Random(seed * 17)
    lobes = []
    while len(lobes) < lobe_count:
        ang = rng.uniform(-math.pi, math.pi)
        if calm_front and not (math.radians(25) < ang < math.radians(155)):
            continue  # team islands: promontories only on the back half, keeps side gaps even
        lobes.append((ang, rng.uniform(6, 13), rng.uniform(0.16, 0.3)))
    pts = []
    for i in range(ANGLES):
        th = 2 * math.pi * i / ANGLES
        x, y = superellipse(th, half[0], half[1], exponent)
        r = math.hypot(x, y)
        k = math.cos(th), math.sin(th)
        # outward-only variation: the base shape already encloses the safe zone
        off = wobble * (0.55 + 0.45 * fbm(k[0] * 1.4 + seed, k[1] * 1.4 - seed, seed * 0.37, 3))
        off += 0.3 * wobble * fbm(k[0] * 4.0 - seed, k[1] * 4.0 + seed, 1.7, 2)
        for (ang, amp, w) in lobes:
            d = math.atan2(math.sin(th - ang), math.cos(th - ang))
            off += amp * math.exp(-(d / w) ** 2)
        if calm_front:
            d = abs(math.atan2(math.sin(th + math.pi / 2), math.cos(th + math.pi / 2)))
            off *= 0.3 + 0.7 * smoothstep(math.radians(25), math.radians(50), d)
        r = smax(r + off, inner_min(th), 5.0)
        pts.append((r * k[0], r * k[1] + centre_y, th))
    return pts


def add_hanging_rock(bm, top, size, seed, taper_k=0.75):
    """Adds a closed, downward-pointing rock mass to bm, its top at `top`.
    The icosphere is created with outward winding and only scaled positively, so
    no normal recalculation is needed."""
    res = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    for v in res["verts"]:
        d = v.co.normalized()
        f = 1.0 + 0.42 * fbm(d.x * 1.9 + seed, d.y * 1.9, d.z * 1.9 - seed, 3)
        f += 0.12 * n1(d.x * 5 + seed, d.y * 5, d.z * 5)
        z = d.z
        taper = 1.0 if z > 0 else max(0.08, 1.0 + z * taper_k)
        p = Vector((d.x * size[0] / 2 * taper, d.y * size[1] / 2 * taper, z * size[2] / 2)) * f
        step = 3.0
        p.z = 0.55 * round(p.z / step) * step + 0.45 * p.z  # terraced strata
        v.co = top + Vector((p.x, p.y, p.z - size[2] / 2))


def build_island(prefix, seed, half, exponent, centre_y, flat_fn, rim_strata, under_depth,
                 wobble=5.0, inner_min=lambda th: 0.0, top_amp=1.0, calm_front=False, hang=4,
                 lobe_count=3, hang_scale=1.0):
    random.seed(seed)
    outline = outline_points(half, exponent, centre_y, seed, wobble, inner_min, calm_front, lobe_count)
    n = len(outline)
    C = Vector((0.0, centre_y, 0.0))

    # --- top surface: radial loft from outline to centre fan
    ts = [1.0, 0.975, 0.95, 0.92, 0.88, 0.83, 0.77, 0.69, 0.6, 0.5, 0.39, 0.27, 0.15]
    rings = []
    for t in ts:
        ring = []
        for (x, y, th) in outline:
            px = C.x + t * (x - C.x)
            py = C.y + t * (y - C.y)
            d_out = flat_fn(px, py)  # >0 outside the flat zone (studs)
            edge = smoothstep(0.0, 0.07, 1.0 - t)  # 0 at the outline
            z = 0.0
            if d_out > 0:
                z = top_amp * fbm(px * 0.045 + seed, py * 0.045, seed * 1.3, 3)
                z += 0.6 * top_amp * max(0.0, fbm(px * 0.09, py * 0.09 + seed, 2.0, 2))
                z *= smoothstep(0.0, 8.0, d_out) * edge
            ring.append(Vector((px, py, z)))
        rings.append(ring)
    bm = bmesh.new()
    loft_rings(bm, rings, cap_last=Vector((C.x, C.y, 0.0)))
    top = make_object(f"{prefix}_Top_Sand", bm, smooth_angle=60)

    def radial(x, y):
        v = Vector((x - C.x, y - C.y, 0.0))
        return v.normalized() if v.length > 1e-6 else Vector((1, 0, 0))

    dirs = [radial(x, y) for (x, y, th) in outline]
    base_pts = [Vector((x, y, 0.0)) for (x, y, th) in outline]
    # vertical fractures that run through several strata, plus per-stratum blocks
    columns = Blocks(n, seed * 3 + 1, amp=1.6, wmin=5, wmax=12)

    # --- rim: chunky sedimentary cliff, blocky strata starting at the outline (z = 0)
    rim_rings = [list(base_pts)]
    z = 0.0
    shrink = 0.0
    for s in range(rim_strata):
        h = random.uniform(3.0, 6.5)
        lip = random.uniform(0.6, 2.0)
        under = random.uniform(1.2, 3.0)
        shrink += random.uniform(0.4, 1.4)
        blocks = Blocks(n, seed * 31 + s * 7, amp=1.4, wmin=3, wmax=9)
        for (dz, dr) in ((0.6, lip), (h * 0.82, lip - 0.5), (h, -under)):
            ring = []
            for i in range(n):
                th = outline[i][2]
                k = (math.cos(th), math.sin(th))
                ledge = 2.0 * fbm(k[0] * 2.3 + s * 3.1, k[1] * 2.3 + seed, s * 0.7, 3)
                chip = 0.35 * n1(k[0] * 18 + s, k[1] * 18 + seed, z * 0.3)
                off = dr + ledge + chip + columns[i] + blocks[i] - shrink
                zz = z - dz + 0.5 * blocks[i + 2] * (dz / h)
                ring.append(base_pts[i] + dirs[i] * off + Vector((0, 0, zz)))
            rim_rings.append(ring)
        z -= h
    bm = bmesh.new()
    loft_rings(bm, rim_rings, flip=True)
    rim = make_object(f"{prefix}_Rim_Rock", bm, smooth_angle=None)

    # --- underside: stepped inverted ledges, chunky blocks, bulbous then pointed
    last = rim_rings[-1]
    z_prev = [p.z for p in last]
    last_rel = [Vector((p.x - C.x, p.y - C.y, 0.0)) for p in last]
    prev_rel = list(last_rel)
    steps = 9
    zmin_rim = min(z_prev)
    heights = [random.uniform(0.75, 1.25) * (1.0 + 0.1 * k) for k in range(steps)]
    hs = sum(heights)
    heights = [h / hs * (under_depth + zmin_rim) for h in heights]
    upper, lower = [last], []
    for k in range(steps):
        t1 = (k + 1) / steps
        sc1 = max(0.04, (1.0 - t1 ** 1.7) ** 0.9)
        wide = Blocks(n, seed * 53 + k * 11, amp=0.07, wmin=6, wmax=16)
        drop = Blocks(n, seed * 59 + k * 13, amp=heights[k] * 0.25 * t1, wmin=6, wmax=16,
                      bias=heights[k] * 0.25 * t1)
        inset = random.uniform(0.88, 0.95)
        ring_a, ring_b, zb_list = [], [], []
        for i in range(n):
            ra = prev_rel[i] * inset
            za = z_prev[i] - 0.9
            rb = last_rel[i] * (sc1 * (1.0 + wide[i]))
            if rb.length > ra.length * 0.97:  # never flare out past the ledge above
                rb = rb.normalized() * ra.length * 0.97
            zb = z_prev[i] - heights[k] - drop[i]
            ring_a.append(Vector((C.x + ra.x, C.y + ra.y, za)))
            ring_b.append(Vector((C.x + rb.x, C.y + rb.y, zb)))
            zb_list.append(zb)
        prev_rel = [Vector((p.x - C.x, p.y - C.y, 0.0)) for p in ring_b]
        z_prev = zb_list
        target = upper if t1 <= 0.34 else lower
        target.append(ring_a)
        target.append(ring_b)
    tip = Vector((C.x + random.uniform(-4, 4), C.y + random.uniform(-4, 4), min(z_prev) - 10))
    bm = bmesh.new()
    loft_rings(bm, upper, flip=True)
    under_a = make_object(f"{prefix}_Under_Rock", bm, smooth_angle=None)
    bm = bmesh.new()
    loft_rings(bm, [upper[-1]] + lower, flip=True, cap_last=tip)
    # hanging rock masses for a broken, chunky silhouette
    rr = max(v.length for v in last_rel)
    for h in range(hang):
        ang = random.uniform(0, 2 * math.pi)
        dist = random.uniform(0.25, 0.5) * rr
        size = (random.uniform(12, 22) * hang_scale, random.uniform(10, 18) * hang_scale,
                random.uniform(24, 40) * hang_scale)
        top_z = zmin_rim - random.uniform(6, 16)
        add_hanging_rock(bm, Vector((C.x + math.cos(ang) * dist, C.y + math.sin(ang) * dist, top_z)),
                         size, seed * 7 + h)
    under_b = make_object(f"{prefix}_Under_RockDark", bm, smooth_angle=None)
    return [top, rim, under_a, under_b]


def team_flat_fn(px, py):
    hx, hy = TEAM_BUILD[0] / 2 + 2, TEAM_BUILD[1] / 2 + 2
    dx = abs(px) - hx
    dy = abs(py - TEAM_BUILD_OFFSET_Y) - hy
    return max(dx, dy)


def team_inner_min(th):
    # minimum outline radius (from the island's outline centre) so the build zone keeps >= 8 studs of margin
    hx, hy = TEAM_BUILD[0] / 2 + 6, TEAM_BUILD[1] / 2 + 6
    c, s = abs(math.cos(th)), abs(math.sin(th))
    return min(hx / c if c > 1e-6 else 1e9, hy / s if s > 1e-6 else 1e9)


def center_flat_fn(px, py):
    return math.hypot(px, py) - CENTER_FLAT_RADIUS


# ---------------------------------------------------------------- rocks

def rock_blob(name, size, seed, sink=0.6):
    """Angular, terraced outcrop with a flat-ish base; origin at the bottom centre."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    for v in bm.verts:
        d = v.co.normalized()
        f = 1.0 + 0.30 * fbm(d.x * 1.8 + seed, d.y * 1.8, d.z * 1.8 - seed, 3)
        f += 0.10 * n1(d.x * 7 + seed, d.y * 7, d.z * 7)
        p = Vector((d.x * size[0] / 2, d.y * size[1] / 2, d.z * size[2] / 2)) * f
        if p.z > 0:  # flatter, ledged top that still gives cover
            p.z = 0.6 * round(p.z / 1.4) * 1.4 + 0.4 * p.z
        p.z = max(p.z, -size[2] * 0.2)
        v.co = p
    zmin = min(v.co.z for v in bm.verts)
    for v in bm.verts:
        v.co.z -= zmin + sink
    return make_object(name, bm, smooth_angle=None, recalc=True)


def build_outcrops():
    # (width, depth, height): heights 4.5-8 so a 5-stud player can crouch behind them
    sizes = [(14, 9, 6.0), (10, 8, 7.5), (16, 9, 5.0), (8, 7, 8.0), (12, 10, 6.5),
             (18, 10, 5.5), (9, 7, 4.5), (13, 9, 7.0), (11, 11, 5.0), (15, 8, 6.0)]
    obs = []
    root = make_empty("Outcrops")
    for i, s in enumerate(sizes):
        ob = rock_blob(f"Outcrop_{i + 1:02d}_Rock", s, seed=101 + i * 7)
        ob.parent = root
        ob.location.x = (i - 4.5) * 24  # spread out in the template file only
        obs.append(ob)
    return root, obs


def build_arch(seed=313):
    """Low rock arch spanning local X, legs at x = +-13, clearance >= 14 under the apex."""
    R, h0 = 13.0, 4.5
    path = []
    for i in range(6):
        path.append(Vector((-R, 0, -2.0 + i * (h0 + 2.0) / 5)))
    for i in range(1, 41):
        a = math.pi - math.pi * i / 40
        path.append(Vector((R * math.cos(a), 0, h0 + R * math.sin(a))))
    for i in range(1, 6):
        path.append(Vector((R, 0, h0 - i * (h0 + 2.0) / 5)))
    sec_n = 12
    rings = []
    for k, p in enumerate(path):
        nxt = path[min(k + 1, len(path) - 1)]
        prv = path[max(k - 1, 0)]
        tan = (nxt - prv).normalized()
        nrm = tan.cross(Vector((0, 1, 0))).normalized()
        bi = Vector((0, 1, 0))
        ring = []
        for j in range(sec_n):
            a = 2 * math.pi * j / sec_n
            w = 3.6 + 1.3 * fbm(k * 0.18 + seed, j * 0.5, 1.0, 3) + 0.45 * n1(k * 0.9, j * 1.7 + seed, 3.0)
            d = 4.2 + 1.3 * fbm(k * 0.18, j * 0.5 + seed, 2.0, 3) + 0.45 * n1(k * 0.9 + seed, j * 1.7, 4.0)
            if k < 7 or k > len(path) - 8:  # thicker, splayed legs
                w += 1.6
                d += 1.2
            ring.append(p + nrm * math.cos(a) * w + bi * math.sin(a) * d)
        rings.append(ring)
    bm = bmesh.new()
    loft_rings(bm, rings, cap_last=path[-1] + Vector((0, 0, -1)), cap_first=path[0] + Vector((0, 0, -1)))
    return make_object("Arch_Rock", bm, smooth_angle=None, recalc=True)


# ---------------------------------------------------------------- platform

def octagon(size, chamfer):
    h = size / 2
    c = chamfer
    return [(-h + c, -h), (h - c, -h), (h, -h + c), (h, h - c), (h - c, h), (-h + c, h), (-h, h - c), (-h, -h + c)]


def prism(bm, pts2d, z0, z1, inset_top=0.0):
    n = len(pts2d)
    bot = [bm.verts.new((x, y, z0)) for (x, y) in pts2d]
    top = []
    for (x, y) in pts2d:
        v = Vector((x, y))
        if inset_top:
            v = v - v.normalized() * inset_top
        top.append(bm.verts.new((v.x, v.y, z1)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)


def build_platform(seed=707):
    root = make_empty("ResourcePlatform")
    bm = bmesh.new()
    prism(bm, octagon(36, 8), -2.0, 0.0)
    deck = make_object("Platform_Deck_Concrete", bm, recalc=True)
    # low steel lip, outside the 36 x 36 footprint so the walkable deck stays 36 x 36
    bm = bmesh.new()
    outer = octagon(37.6, 8.3)
    inner = octagon(36.0, 8.0)
    n = len(outer)
    vb_o = [bm.verts.new((x, y, -2.4)) for (x, y) in outer]
    vt_o = [bm.verts.new((x, y, 0.7)) for (x, y) in outer]
    vb_i = [bm.verts.new((x, y, -2.4)) for (x, y) in inner]
    vt_i = [bm.verts.new((x, y, 0.7)) for (x, y) in inner]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((vb_o[i], vb_o[j], vt_o[j], vt_o[i]))
        bm.faces.new((vt_i[i], vt_i[j], vb_i[j], vb_i[i]))
        bm.faces.new((vt_o[i], vt_o[j], vt_i[j], vt_i[i]))
        bm.faces.new((vb_i[i], vb_i[j], vb_o[j], vb_o[i]))
    lip = make_object("Platform_Rim_Steel", bm, recalc=True)
    # rock body underneath: same strata + stepped underside as the islands, just smaller
    parts = build_island("PLT", seed, (15.5, 15.5), 6.0, 0.0, lambda x, y: -1.0, rim_strata=2,
                         under_depth=30, wobble=1.5, hang=1, lobe_count=0, hang_scale=0.45)
    top_sand, rim, under_a, under_b = parts
    bpy.data.objects.remove(top_sand, do_unlink=True)  # the concrete deck is the walking surface
    for ob in (rim, under_a, under_b):
        for v in ob.data.vertices:
            v.co.z -= 2.0  # hang below the 2-stud deck
    rim.name = rim.data.name = "Platform_Rim_Rock"
    under_a.name = under_a.data.name = "Platform_Under_Rock"
    under_b.name = under_b.data.name = "Platform_Under_RockDark"
    under = rim
    for ob in (under_a, under_b):
        ob.parent = root
    for ob in (deck, lip, under):
        ob.parent = root
    return root


# ---------------------------------------------------------------- distant islands

def build_distant():
    root = make_empty("DistantIslands")
    for i in range(6):
        seed = 900 + i * 13
        bm = bmesh.new()
        n = 48
        rings = []
        heights = [0.0, 0.35, 0.7, 0.9, 1.0]
        for k, hh in enumerate(heights):
            ring = []
            for j in range(n):
                th = 2 * math.pi * j / n
                c = (math.cos(th), math.sin(th))
                r = (1.0 - 0.75 * hh ** 1.6) * (1 + 0.3 * fbm(c[0] * 1.5 + seed, c[1] * 1.5, hh, 3))
                ring.append(Vector((c[0] * r * 60, c[1] * r * 30, hh * (22 + 10 * fbm(c[0] + seed, c[1], 3.0, 2)))))
            rings.append(ring)
        loft_rings(bm, rings, cap_last=Vector((0, 0, 30)))
        ob = make_object(f"Distant_{i + 1:02d}_RockDark", bm)
        ob.parent = root
        ob.location.x = i * 160
    return root


# ---------------------------------------------------------------- main

def build_all():
    clear_collection()
    report = {}
    for n, seed in enumerate(TEAM_SEEDS, start=1):
        root = make_empty(f"TeamIsland_{n}")
        parts = build_island(f"TI{n}", seed, TEAM_HALF, 4.0, TEAM_BUILD_OFFSET_Y, team_flat_fn,
                             rim_strata=6, under_depth=86, wobble=5.0, inner_min=team_inner_min,
                             calm_front=True)
        for ob in parts:
            ob.parent = root
        root.location.x = (n - 3) * 220  # spread out in the template file only
    croot = make_empty("CenterIsland")
    cparts = build_island("CI", 77, CENTER_HALF, 2.0, 0.0, center_flat_fn, rim_strata=7, under_depth=100,
                          wobble=8.0, inner_min=lambda th: CENTER_FLAT_RADIUS + 8, hang=6)
    bm = bmesh.new()
    prism(bm, octagon(30, 8), -0.4, 0.35, inset_top=0.4)
    cparts.append(make_object("CI_Pad_Concrete", bm, recalc=True))
    for ob in cparts:
        ob.parent = croot
    croot.location.y = 320
    arch = build_arch()
    arch.location = (0, -260, 0)
    oroot, _ = build_outcrops()
    oroot.location.y = -340
    proot = build_platform()
    proot.location = (300, 320, 0)
    droot = build_distant()
    droot.location.y = -460

    # verification
    problems = []
    for ob in get_collection().objects:
        if ob.type != 'MESH':
            continue
        tc = tri_count(ob)
        report[ob.name] = tc
        if tc > TRI_LIMIT:
            problems.append(f"{ob.name}: {tc} tris > {TRI_LIMIT}")
        if not any(ob.name.endswith(k) for k in ("_Sand", "_Rock", "_RockDark", "_Concrete", "_Steel")):
            problems.append(f"{ob.name}: missing material suffix")
    # faces must point outward (Roblox culls back faces)
    for ob in get_collection().objects:
        if ob.type != 'MESH':
            continue
        me = ob.data
        cen = sum((v.co for v in me.vertices), Vector()) / max(1, len(me.vertices))
        if ob.name.endswith("_Top_Sand"):
            score = sum(p.normal.z * p.area for p in me.polygons)
        else:
            score = sum(p.normal.dot(p.center - cen) * p.area for p in me.polygons)
        if score <= 0:
            problems.append(f"{ob.name}: faces point inward (score {score:.1f})")
    for n in range(1, 6):
        ob = bpy.data.objects[f"TI{n}_Top_Sand"]
        hx, hy = TEAM_BUILD[0] / 2, TEAM_BUILD[1] / 2
        bad = [v.co for v in ob.data.vertices
               if abs(v.co.x) <= hx and abs(v.co.y - TEAM_BUILD_OFFSET_Y) <= hy and abs(v.co.z) > 0.01]
        if bad:
            problems.append(f"TI{n}_Top_Sand: {len(bad)} build-zone verts off the flat plane")
        rim = bpy.data.objects[f"TI{n}_Rim_Rock"]
        inside = [v.co for v in rim.data.vertices
                  if abs(v.co.x) < hx and abs(v.co.y - TEAM_BUILD_OFFSET_Y) < hy and v.co.z > -1]
        if inside:
            problems.append(f"TI{n}_Rim_Rock: {len(inside)} rim verts intrude into the build zone")
    return {"tris": report, "problems": problems}


def export_fbx(path, roots):
    bpy.ops.object.select_all(action='DESELECT')
    for r in roots:
        r.select_set(True)
        for c in r.children_recursive:
            c.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={'EMPTY', 'MESH'},
        apply_unit_scale=True, apply_scale_options='FBX_SCALE_NONE', global_scale=1.0,
        axis_forward='-Z', axis_up='Y', bake_space_transform=False,
        mesh_smooth_type='FACE', use_mesh_modifiers=True, add_leaf_bones=False,
        bake_anim=False, path_mode='AUTO')
