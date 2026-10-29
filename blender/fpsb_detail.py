"""Detail pass for the FPS Bedwars map (Sterling, 2026-10-28, design board "FPS Bedwars Map Upgrade Plan").

Generates, from axis-aligned boxes (classic blocky look, few meshes):
  UXTeam / UXCentre / UXPlatform : extra stepped stone under the existing island templates (GLBIsland,
                                   GLBCentre, GLBPlatform) so islands read as thick floating chunks.
                                   Same origin as the island template; non-colliding in Roblox.
  CoverRock                      : 7 x 6 x 6 blocky boulder (cover kit)
  RimRockA / RimRockB            : small rim rocks (terrain detail)
  BeaconCrystal / BeaconHalo     : the centre's Amethyst Beacon crystal and halo ring
  DistMountainA..D               : far blocky mountain ranges (scenery, non-colliding)
  DistIsletA..C                  : small blocky islets (scenery, non-colliding)
Meshes: GD_<Template>_<material>, joined per (template, material).

Run in Blender (the island templates must be loaded: FPSB_GLBTemplates, FPSB_GLBCentreTemplates,
FPSB_GLBDispenserTemplates):
  ns = {}; exec(open(r"C:\\Roblox Dev\\FPS Bedwars\\blender\\fpsb_detail.py").read(), ns)
  ns["build"](); ns["export"](fbx_path, json_path)
"""

import json
import math

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

OUT = "FPSB_DetailTemplates"

# island template -> (output template, cell size, max extra depth, depth bands, material prefix)
UNDERSIDES = {
    "GLBIsland": ("UXTeam", 6.0, 50.0, (-50.0, -80.0), "rock"),
    "GLBCentre": ("UXCentre", 8.0, 55.0, (-75.0, -110.0), "crock"),
    "GLBPlatform": ("UXPlatform", 4.0, 30.0, (-44.0, -56.0), "crock"),
}


def hash01(*v):
    """Deterministic pseudo-random in [0, 1) from numbers."""
    h = 2166136261
    for x in v:
        for ch in f"{x:.3f}":
            h = ((h ^ ord(ch)) * 16777619) & 0xFFFFFFFF
    return (h % 100000) / 100000.0


def box_polys(mn, mx):
    """Six outward-wound quads of an axis-aligned box."""
    x0, y0, z0 = mn
    x1, y1, z1 = mx
    v = [Vector(p) for p in ((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                             (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
    idx = ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7))
    return [[v[i] for i in f] for f in idx]


def rot_z(polys, a, about=Vector((0, 0, 0))):
    m = Matrix.Rotation(a, 4, 'Z')
    return [[about + m @ (p - about) for p in poly] for poly in polys]


class Out:
    def __init__(self):
        self.buckets = {}

    def add(self, tmpl, mat, polys):
        self.buckets.setdefault((tmpl, mat), []).extend(polys)


def island_bvh(root_name):
    root = bpy.data.objects[root_name]
    verts, polys = [], []
    for ch in root.children:
        if ch.type != 'MESH':
            continue
        M = ch.matrix_world
        base = len(verts)
        verts.extend(M @ v.co for v in ch.data.vertices)
        polys.extend([base + i for i in p.vertices] for p in ch.data.polygons)
    return BVHTree.FromPolygons(verts, polys), verts


def undersides(out):
    report = {}
    for src, (tmpl, cell, max_extra, bands, pre) in UNDERSIDES.items():
        bvh, verts = island_bvh(src)
        xs = [v.x for v in verts]
        ys = [v.y for v in verts]
        cells = []
        x = math.floor(min(xs) / cell) * cell
        while x < max(xs):
            y = math.floor(min(ys) / cell) * cell
            while y < max(ys):
                c = Vector((x + cell / 2, y + cell / 2, -1000))
                hit = bvh.ray_cast(c, Vector((0, 0, 1)), 2000)
                if hit[0] is not None:
                    cells.append((x, y, hit[0].z))
                y += cell
            x += cell
        cx = sum(c[0] for c in cells) / len(cells) + cell / 2
        cy = sum(c[1] for c in cells) / len(cells) + cell / 2
        ax = max(abs(c[0] + cell / 2 - cx) for c in cells) + cell
        ay = max(abs(c[1] + cell / 2 - cy) for c in cells) + cell
        n = 0
        deepest = 0.0
        for (x, y, zb) in cells:
            r = math.sqrt(((x + cell / 2 - cx) / ax) ** 2 + ((y + cell / 2 - cy) / ay) ** 2)
            if r >= 1:
                continue
            noise = 0.7 + 0.6 * hash01(x, y, len(src))
            extra = max_extra * (1 - r) ** 1.25 * noise
            extra = math.floor(extra / 3.0) * 3.0
            if extra < 4:
                continue
            bottom = zb - extra
            deepest = min(deepest, bottom)
            tone = 1 if bottom > bands[0] else (2 if bottom > bands[1] else 3)
            out.add(tmpl, f"{pre}{tone}", box_polys((x, y, bottom), (x + cell, y + cell, zb + 2.0)))
            n += 1
        report[tmpl] = {"boxes": n, "deepest": round(deepest, 1)}
    return report


def rocks(out):
    # CoverRock 7 x 6 x 6 (x, y, z in Blender = width, depth, height)
    out.add("CoverRock", "coverrock", box_polys((-3.5, -3.0, 0), (3.5, 3.0, 3.8)))
    out.add("CoverRock", "coverrock_l", box_polys((-2.5, -2.2, 3.8), (2.0, 2.4, 5.4)))
    out.add("CoverRock", "coverrock_d", box_polys((1.2, -2.6, 3.8), (3.2, 0.6, 4.6)))
    out.add("CoverRock", "coverrock_l", box_polys((-1.6, -1.2, 5.4), (0.8, 1.4, 6.0)))
    # rim rocks
    out.add("RimRockA", "coverrock", box_polys((-1.6, -1.4, 0), (1.6, 1.4, 1.6)))
    out.add("RimRockA", "coverrock_l", box_polys((-1.0, -0.8, 1.6), (0.9, 0.9, 2.3)))
    out.add("RimRockB", "coverrock_d", box_polys((-1.0, -1.1, 0), (1.1, 0.9, 1.1)))
    out.add("RimRockB", "coverrock", box_polys((-0.6, -0.5, 1.1), (0.5, 0.5, 1.5)))


def beacon(out):
    # elongated octahedron crystal, base tip at origin
    w, h = 3.6, 16.0
    mid = h * 0.42
    ring = [Vector((math.cos(a) * w, math.sin(a) * w, mid)) for a in (math.pi / 4 + k * math.pi / 2 for k in range(4))]
    top, bot = Vector((0, 0, h)), Vector((0, 0, 0))
    polys = []
    for k in range(4):
        a, b = ring[k], ring[(k + 1) % 4]
        polys.append([a, b, top])
        polys.append([b, a, bot])
    out.add("BeaconCrystal", "crystal", polys)
    # small inner core band
    out.add("BeaconCrystal", "crystal_d", box_polys((-1.2, -1.2, mid - 1.0), (1.2, 1.2, mid + 1.0)))
    # halo: 16 tangent boxes, radius 9.5
    seg, r = 16, 9.5
    length = 2 * math.pi * r / seg + 0.25
    for k in range(seg):
        a = k * 2 * math.pi / seg
        p = box_polys((r - 0.45, -length / 2, -0.45), (r + 0.45, length / 2, 0.45))
        out.add("BeaconHalo", "gold", rot_z(p, a))


def mountain(out, tmpl, width, depth, height, peaks, seed):
    """Stepped blocky range: each peak is a stack of shrinking, jittered boxes."""
    for i in range(peaks):
        px = (i - (peaks - 1) / 2) * width / peaks + (hash01(seed, i) - 0.5) * width * 0.15
        ph = height * (0.6 + 0.4 * hash01(seed, i, 7))
        pw = width / peaks * (0.9 + 0.5 * hash01(seed, i, 3))
        pd = depth * (0.7 + 0.3 * hash01(seed, i, 5))
        layers = 6
        z = 0.0
        for L in range(layers):
            f = 1 - L / layers
            lw, ld = pw * f, pd * f
            lh = ph / layers
            ox = (hash01(seed, i, L) - 0.5) * pw * 0.12
            oy = (hash01(seed, i, L, 2) - 0.5) * pd * 0.12
            mat = "mtn_top" if L >= layers - 2 else "mtn"
            out.add(tmpl, mat, box_polys((px + ox - lw / 2, oy - ld / 2, z), (px + ox + lw / 2, oy + ld / 2, z + lh + 0.5)))
            z += lh


def islet(out, tmpl, size, seed):
    s = size
    out.add(tmpl, "islet_grass", box_polys((-s / 2, -s * 0.4, -1.5), (s / 2, s * 0.4, 0)))
    out.add(tmpl, "islet_sand", box_polys((-s / 2 - 1, -s * 0.4 - 1, -3.5), (s / 2 + 1, s * 0.4 + 1, -1.5)))
    z = -3.5
    w, d = s, s * 0.8
    for L in range(4):
        lh = s * 0.18
        f = 1 - (L + 1) * 0.2
        ox = (hash01(seed, L) - 0.5) * s * 0.15
        mat = "crock1" if L < 2 else "crock2"
        out.add(tmpl, mat, box_polys((ox - w * f / 2, -d * f / 2, z - lh), (ox + w * f / 2, d * f / 2, z)))
        z -= lh


def scenery(out):
    mountain(out, "DistMountainA", 900, 260, 420, 3, 11)
    mountain(out, "DistMountainB", 700, 220, 330, 2, 23)
    mountain(out, "DistMountainC", 1000, 300, 480, 4, 37)
    mountain(out, "DistMountainD", 600, 200, 260, 2, 41)
    islet(out, "DistIsletA", 40, 5)
    islet(out, "DistIsletB", 28, 9)
    islet(out, "DistIsletC", 56, 13)


def build():
    out_col = bpy.data.collections.get(OUT)
    if out_col is None:
        out_col = bpy.data.collections.new(OUT)
        bpy.context.scene.collection.children.link(out_col)
    for ob in list(out_col.objects):
        me = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        if me and me.users == 0:
            bpy.data.meshes.remove(me)
    out = Out()
    report = {"undersides": undersides(out)}
    rocks(out)
    beacon(out)
    scenery(out)
    roots = {}
    meshes = {}
    for (tmpl, mat), polys in sorted(out.buckets.items()):
        if tmpl not in roots:
            e = bpy.data.objects.new(tmpl, None)
            out_col.objects.link(e)
            roots[tmpl] = e
        bm = bmesh.new()
        for p in polys:
            bm.faces.new([bm.verts.new(v) for v in p])
        name = f"GD_{tmpl}_{mat}"
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(name, me)
        out_col.objects.link(ob)
        ob.parent = roots[tmpl]
        meshes[name] = sum(len(p.vertices) - 2 for p in me.polygons)
    report["meshes"] = meshes
    return report


def export(path_fbx, path_json):
    out = bpy.data.collections[OUT]
    bpy.ops.object.select_all(action='DESELECT')
    for ob in out.objects:
        ob.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=path_fbx, use_selection=True, object_types={'EMPTY', 'MESH'},
        apply_unit_scale=True, apply_scale_options='FBX_SCALE_NONE', global_scale=0.01,
        axis_forward='-Z', axis_up='Y', bake_space_transform=False, mesh_smooth_type='FACE',
        add_leaf_bones=False, bake_anim=False)
    data = {}
    for ob in out.objects:
        if ob.type != 'MESH':
            continue
        vs = [v.co for v in ob.data.vertices]
        c = [(min(v[a] for v in vs) + max(v[a] for v in vs)) / 2 for a in range(3)]
        data[ob.name] = {"c": [round(x, 4) for x in c], "root": ob.parent.name}
    with open(path_json, "w") as f:
        json.dump(data, f, indent=1)
    return data
