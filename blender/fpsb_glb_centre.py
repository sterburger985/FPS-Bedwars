"""Turns the imported central-island GLB (imports/bedwars-central-island.glb) into Roblox templates.

Decisions (Sterling, 2026-10-27): scale x2, the GLB's gem "dropper" is the high-tier dispenser,
side island + bridge removed, floating trees/objects fixed, hut doors removed so players can go in.

Steps
  1. Weld each GLB mesh, split into loose boxes, assign them to a group (name prefix, e.g. "trees").
  2. Drop the side island, the bridge and every prop box that isn't over the main island.
  3. Huts: the GLB huts are solid blocks with a door panel on the outside. Each hut body is rebuilt
     as 4 hollow walls with a doorway where the door panel was; the panel is removed.
  4. Floating props: props are clustered (touching boxes in the same group = one prop, e.g. trunk +
     leaves). Each prop is lowered onto whatever is below its feet; props over nothing are deleted.
  5. Scale x2 about the GLB origin, put the main top (sand, GLB y 59.6) at Z = 0, join per
     template + material:  GC_Centre_<material>  and  GC_Dropper_<material>;
     hut boxes are one mesh each: GC_Hut<Name><nn>_<material>.

Run in Blender after importing the GLB into collection FPSB_GLBCentre:
  exec(open(r"C:\\Roblox Dev\\FPS Bedwars\\blender\\fpsb_glb_centre.py").read()); build()
"""

import json
import math

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

SRC = "FPSB_GLBCentre"
OUT = "FPSB_GLBCentreTemplates"
SCALE = 2.0
MATERIALS = ("rock_dark", "rock", "dirt_path", "sand", "grass", "stone_tile", "gold_trim", "metal",
             "amethyst_glow", "wood_dark", "wood", "roof", "lamp_glow", "banner", "leaves")
TERRAIN = ("island_underside", "cliffs_ledges", "cliffs", "topsoil", "plateau", "plateau_steps",
           "tower_plinth", "dropper_plaza")
DROP_GROUPS = ("side_island", "side_island_underside", "bridge")
HUTS = ("hut_west", "hut_east", "hut_plateau")
WALL = 0.35          # hut wall thickness (GLB units)
EPS = 1e-3


def split_name(name):
    """'hut_west_wood_dark.001' -> ('hut_west', 'wood_dark')"""
    base = name.split(".")[0]
    for m in sorted(MATERIALS, key=len, reverse=True):
        if base.endswith("_" + m):
            return base[: -len(m) - 1], m
    return base, "rock"


class Box:
    """One loose piece: world-space polygons (lists of Vector) + bounds."""

    def __init__(self, group, mat, polys):
        self.group, self.mat, self.polys = group, mat, polys
        vs = [v for p in polys for v in p]
        self.mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        self.mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))

    def centre(self):
        return (self.mn + self.mx) / 2

    def move(self, d):
        self.polys = [[v + d for v in p] for p in self.polys]
        self.mn += d
        self.mx += d


def load_boxes():
    boxes = []
    for ob in bpy.data.collections[SRC].objects:
        if ob.type != 'MESH':
            continue
        group, mat = split_name(ob.name)
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.transform(ob.matrix_world)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        bm.faces.ensure_lookup_table()
        seen = set()
        for f in bm.faces:
            if f.index in seen:
                continue
            comp, stack = [], [f]
            seen.add(f.index)
            while stack:
                g = stack.pop()
                comp.append([v.co.copy() for v in g.verts])
                for e in g.edges:
                    for h in e.link_faces:
                        if h.index not in seen:
                            seen.add(h.index)
                            stack.append(h)
            boxes.append(Box(group, mat, comp))
        bm.free()
    return boxes


def bvh_of(boxes):
    verts, polys = [], []
    for b in boxes:
        for p in b.polys:
            base = len(verts)
            verts.extend(p)
            polys.append(list(range(base, base + len(p))))
    return BVHTree.FromPolygons(verts, polys) if polys else None


def is_terrain(b):
    return b.group in TERRAIN


# ---------------------------------------------------------------- huts

def outward(poly, box_verts):
    """Return the polygon wound so its normal points away from the box centre."""
    c = sum(box_verts, Vector()) / len(box_verts)
    fc = sum(poly, Vector()) / len(poly)
    n = (poly[1] - poly[0]).cross(poly[2] - poly[1])
    return poly if n.dot(fc - c) > 0 else list(reversed(poly))


def hollow_hut(boxes, hut):
    """Replace the solid body of `hut` with 4 walls + a doorway at the door panel. Returns a report."""
    body = [b for b in boxes if b.group == hut and b.mat == "wood"]
    # the body is the lowest wood box; the second one is the gable/attic block on top
    body.sort(key=lambda b: b.mn.z)
    core = body[0]
    door = [b for b in boxes if b.group == hut and b.mat == "wood_dark"
            and abs((b.mx.z - b.mn.z) - 4.0) < 0.05]
    if not door:
        return {"hut": hut, "error": "no door panel found"}
    dc = sum((d.centre() for d in door), Vector()) / len(door)
    z0, z1 = core.mn.z, core.mx.z
    # body footprint corners (the box may be rotated about Z)
    pts = {}
    for p in core.polys:
        for v in p:
            pts[(round(v.x, 3), round(v.y, 3))] = Vector((v.x, v.y, 0))
    corners = list(pts.values())
    c = sum(corners, Vector()) / len(corners)
    corners.sort(key=lambda v: math.atan2(v.y - c.y, v.x - c.x))
    if len(corners) != 4:
        return {"hut": hut, "error": f"body has {len(corners)} footprint corners"}
    # which side faces the door?
    sides = [(corners[i], corners[(i + 1) % 4]) for i in range(4)]
    def side_dist(s):
        a, b = s
        m = (a + b) / 2
        return (Vector((dc.x, dc.y, 0)) - m).length
    door_side = min(range(4), key=lambda i: side_dist(sides[i]))
    # door width along its wall and height
    a, b = sides[door_side]
    u = (b - a).normalized()
    dvs = [v for d in door for p in d.polys for v in p]
    ts = [(Vector((v.x, v.y, 0)) - a).dot(u) for v in dvs]
    t0, t1 = min(ts) - 0.15, max(ts) + 0.15
    dz1 = max(v.z for v in dvs) + 0.1
    new = []
    for i, (p, q) in enumerate(sides):
        su = (q - p)
        L = su.length
        su.normalize()
        inward = (c - (p + q) / 2)
        inward = (inward - su * inward.dot(su)).normalized()
        segs = [(0.0, L, z0, z1)]
        if i == door_side:
            segs = [(0.0, t0, z0, z1), (t1, L, z0, z1), (t0, t1, dz1, z1)]
        for (s0, s1, za, zb) in segs:
            if s1 - s0 < 0.05 or zb - za < 0.05:
                continue
            o = p + su * s0
            e = su * (s1 - s0)
            w = inward * WALL
            quad = [o, o + e, o + e + w, o + w]
            bot = [Vector((v.x, v.y, za)) for v in quad]
            top = [Vector((v.x, v.y, zb)) for v in quad]
            polys = [bot, top]
            for k in range(4):
                polys.append([bot[k], bot[(k + 1) % 4], top[(k + 1) % 4], top[k]])
            new.append(Box(hut, "wood", [outward(poly, bot + top) for poly in polys]))
    for d in door:
        boxes.remove(d)
    boxes.remove(core)
    boxes.extend(new)
    return {"hut": hut, "doorway_width": round(t1 - t0, 2), "doorway_height": round(dz1 - z0, 2),
            "walls": len(new)}


# ---------------------------------------------------------------- props

def clusters(boxes):
    """Union-find over prop boxes: same group + touching bounds."""
    props = [b for b in boxes if not is_terrain(b)]
    parent = list(range(len(props)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for i, a in enumerate(props):
        for j in range(i + 1, len(props)):
            b = props[j]
            if a.group != b.group:
                continue
            if all(a.mn[k] <= b.mx[k] + 0.02 and b.mn[k] <= a.mx[k] + 0.02 for k in range(3)):
                parent[find(i)] = find(j)
    out = {}
    for i, b in enumerate(props):
        out.setdefault(find(i), []).append(b)
    # huts, the watchtower and the dropper machine are single props whatever touches (the dropper's
    # frame, hopper and ring float above it on purpose)
    merged = {}
    for cl in out.values():
        g = cl[0].group
        if g in HUTS:
            key = g
        elif g.startswith("watchtower"):
            key = "watchtower"
        elif g.startswith("dropper"):
            key = "dropper"
        else:
            key = id(cl)
        merged.setdefault(key, []).extend(cl)
    return list(merged.values())


def settle(boxes, passes=3):
    moved, deleted = [], []
    for _ in range(passes):
        changed = False
        for cl in clusters(boxes):
            bottom = min(b.mn.z for b in cl)
            feet = [b for b in cl if b.mn.z < bottom + 0.05]
            others = [b for b in boxes if b not in cl]
            tree = bvh_of(others)
            best = None
            for f in feet:
                c = f.centre()
                # start a little above the feet so a prop sunk slightly into the ground still hits the
                # ground's top face (not its underside); the prop itself is not in `tree`
                hit = tree.ray_cast(Vector((c.x, c.y, bottom + 0.5)), Vector((0, 0, -1)), 80)
                if hit[0] is not None:
                    gap = bottom - hit[0].z
                    best = gap if best is None else min(best, gap)
            name = cl[0].group
            if best is None:
                for b in cl:
                    boxes.remove(b)
                deleted.append((name, [round(x, 1) for x in cl[0].centre()]))
                changed = True
            elif best > 0.05:
                for b in cl:
                    b.move(Vector((0, 0, -best)))
                moved.append((name, round(best, 2), [round(x, 1) for x in cl[0].centre()],
                              round(bottom, 2), [b.mat for b in feet]))
                changed = True
        if not changed:
            break
    return moved, deleted


# ---------------------------------------------------------------- main

def build():
    boxes = load_boxes()
    n0 = len(boxes)
    boxes = [b for b in boxes if b.group not in DROP_GROUPS]
    # props not over the main island (they stood on the side island)
    main = bvh_of([b for b in boxes if is_terrain(b)])
    off = []
    for b in list(boxes):
        if is_terrain(b):
            continue
        c = b.centre()
        if main.ray_cast(Vector((c.x, c.y, 200)), Vector((0, 0, -1)), 400)[0] is None:
            boxes.remove(b)
            off.append(b.group)
    huts = [hollow_hut(boxes, h) for h in HUTS]
    moved, deleted = settle(boxes)

    # winding check: a closed box wound outward has positive signed volume
    def signed_volume(b):
        v = 0.0
        for p in b.polys:
            for k in range(1, len(p) - 1):
                v += p[0].dot(p[k].cross(p[k + 1])) / 6.0
        return v
    inward_boxes = sum(1 for b in boxes if signed_volume(b) < -1e-6)

    top = max(b.mx.z for b in boxes if b.group == "topsoil" and b.mat == "sand")
    xf = Matrix.Scale(SCALE, 4) @ Matrix.Translation((0, 0, -top))
    out = bpy.data.collections.get(OUT)
    if out is None:
        out = bpy.data.collections.new(OUT)
        bpy.context.scene.collection.children.link(out)
    for ob in list(out.objects):
        me = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        if me and me.users == 0:
            bpy.data.meshes.remove(me)
    roots = {}
    for t in ("GLBCentre", "GLBDropper"):
        e = bpy.data.objects.new(t, None)
        out.objects.link(e)
        roots[t] = e
    buckets = {}
    hut_n = {}
    for b in boxes:
        tmpl = "GLBDropper" if (b.group.startswith("dropper") and b.group != "dropper_plaza") else "GLBCentre"
        part = tmpl[3:]
        if b.group in HUTS:
            # every hut box is its own mesh: Roblox's convex decomposition of a whole joined hut
            # material wraps hulls across the doorway (playtest 2026-10-27: the plateau hut door
            # was blocked by slanted collision). One box per mesh collides exactly.
            hn = "Hut" + "".join(w.capitalize() for w in b.group.split("_")[1:])
            hut_n[hn] = hut_n.get(hn, 0) + 1
            part = f"{hn}{hut_n[hn]:02d}"
        bm = buckets.setdefault((tmpl, part, b.mat), bmesh.new())
        for p in b.polys:
            bm.faces.new([bm.verts.new(xf @ v) for v in p])
    report = {}
    for (tmpl, part, mat), bm in sorted(buckets.items()):
        # no remove_doubles / recalc here: each box keeps the GLB's own (outward) winding, and
        # recalculating across thousands of touching boxes flips some faces
        name = f"GC_{part}_{mat}"
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(name, me)
        out.objects.link(ob)
        ob.parent = roots[tmpl]
        report[name] = len(me.polygons) * 2
    return {"boxes_in": n0, "boxes_out": len(boxes), "inward_boxes": inward_boxes,
            "off_main_island": len(off), "huts": huts,
            "moved": moved, "deleted": deleted, "meshes": report, "top": top}


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
