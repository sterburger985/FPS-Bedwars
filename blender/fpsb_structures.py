"""FPS Bedwars structure kit generator (Blender 5.2).

Starter shed, bed, banner mast, shop stall, resource dispenser and centre dispenser.

Conventions (docs/superpowers/specs/2026-10-25-map-design.md):
- 1 Blender unit = 1 stud, +Z up, front faces Blender -Y (-> Roblox -Z).
- Every model's origin is its bottom centre.
- Object names end in a material key used by Studio's PrepareAssets:
  _Rust _Steel _Concrete _Wood _Cloth (team colour) _Linen _Canvas _Glow _Glass
- All pieces are closed solids so normals can be recalculated safely.

Run inside Blender:  exec(open(r"C:\\Roblox Dev\\FPS Bedwars\\blender\\fpsb_structures.py").read())
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

COLLECTION = "FPSB_Structures"
SUFFIXES = ("_Rust", "_Steel", "_Concrete", "_Wood", "_Cloth", "_Linen", "_Canvas", "_Glow", "_Glass")

SHED = 24.0          # 2 x 2 grid cells of 12 studs
SHED_WALL_H = 12.0
DOOR_W, DOOR_H = 6.0, 9.0
SLAB_H = 1.0


# ---------------------------------------------------------------- helpers

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


class Piece:
    """Accumulates closed solids into one bmesh, then becomes one object."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()

    def box(self, center, size, rot_z=0.0):
        M = Matrix.Translation(Vector(center)) @ Matrix.Rotation(rot_z, 4, 'Z') @ Matrix.Diagonal((*size, 1.0))
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=M)
        return self

    def cyl(self, center, radius, height, segments=20, axis='Z'):
        R = Matrix.Identity(4)
        if axis == 'X':
            R = Matrix.Rotation(math.pi / 2, 4, 'Y')
        elif axis == 'Y':
            R = Matrix.Rotation(math.pi / 2, 4, 'X')
        M = Matrix.Translation(Vector(center)) @ R
        bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segments,
                              radius1=radius, radius2=radius, depth=height, matrix=M)
        return self

    def corrugated(self, M, width, height, thickness=0.25, period=1.2, amp=0.2, along='width'):
        """Closed corrugated sheet in local XZ (x: 0..width, z: 0..height, y ~ 0),
        ridges run along z (vertical) by default; transformed by M."""
        seg = max(4, int(width / period * 6))
        xs = [width * i / seg for i in range(seg + 1)]

        def c(x):
            return amp * math.sin(2 * math.pi * x / period)

        bm = self.bm
        fb = [bm.verts.new(M @ Vector((x, c(x) - thickness / 2, 0.0))) for x in xs]
        ft = [bm.verts.new(M @ Vector((x, c(x) - thickness / 2, height))) for x in xs]
        bb = [bm.verts.new(M @ Vector((x, c(x) + thickness / 2, 0.0))) for x in xs]
        bt = [bm.verts.new(M @ Vector((x, c(x) + thickness / 2, height))) for x in xs]
        for i in range(seg):
            bm.faces.new((fb[i], fb[i + 1], ft[i + 1], ft[i]))   # front (-y)
            bm.faces.new((bb[i + 1], bb[i], bt[i], bt[i + 1]))   # back (+y)
            bm.faces.new((ft[i], ft[i + 1], bt[i + 1], bt[i]))   # top edge
            bm.faces.new((fb[i + 1], fb[i], bb[i], bb[i + 1]))   # bottom edge
        bm.faces.new((fb[0], ft[0], bt[0], bb[0]))
        bm.faces.new((fb[-1], bb[-1], bt[-1], ft[-1]))
        return self

    def done(self, parent):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-4)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for p in mesh.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(self.name, mesh)
        get_collection().objects.link(ob)
        ob.parent = parent
        return ob


def root(name):
    ob = bpy.data.objects.new(name, None)
    get_collection().objects.link(ob)
    return ob


def wall_matrix(x0, y, z0, rot):
    """Sheet starting at (x0, y, z0) running along +X before rotation `rot` about Z
    (around the world origin)."""
    return Matrix.Rotation(rot, 4, 'Z') @ Matrix.Translation((x0, y, z0))


# ---------------------------------------------------------------- starter shed

def build_shed():
    r = root("StarterShed")
    h = SHED / 2
    slab = Piece("Shed_Slab_Concrete").box((0, 0, SLAB_H / 2), (SHED + 1, SHED + 1, SLAB_H))
    steel = Piece("Shed_Frame_Steel")
    for sx in (-1, 1):
        for sy in (-1, 1):
            steel.box((sx * (h - 0.5), sy * (h - 0.5), SLAB_H + SHED_WALL_H / 2), (1.0, 1.0, SHED_WALL_H))
    top = SLAB_H + SHED_WALL_H
    for sy in (-1, 1):  # eave beams
        steel.box((0, sy * (h - 0.5), top - 0.4), (SHED, 0.8, 0.8))
    for sx in (-1, 1):
        steel.box((sx * (h - 0.5), 0, top - 0.4), (0.8, SHED, 0.8))
    # door frame
    steel.box((-(DOOR_W / 2 + 0.3), -(h - 0.4), SLAB_H + DOOR_H / 2), (0.6, 0.9, DOOR_H))
    steel.box(((DOOR_W / 2 + 0.3), -(h - 0.4), SLAB_H + DOOR_H / 2), (0.6, 0.9, DOOR_H))
    steel.box((0, -(h - 0.4), SLAB_H + DOOR_H + 0.3), (DOOR_W + 1.2, 0.9, 0.6))
    # small lamp housing over the door
    steel.box((0, -(h + 0.5), SLAB_H + DOOR_H + 1.4), (1.6, 1.2, 0.5))
    lamp = Piece("Shed_Lamp_Glow").box((0, -(h + 0.6), SLAB_H + DOOR_H + 1.05), (1.2, 0.8, 0.2))

    rust = Piece("Shed_Walls_Rust")
    wall_h = SHED_WALL_H - 0.8
    inner = SHED - 1.0           # between the corner posts
    y_out = h - 0.35
    # back (+Y), left (-X), right (+X): full panels
    for rot in (math.pi, math.pi / 2, -math.pi / 2):
        rust.corrugated(wall_matrix(-inner / 2, -y_out, SLAB_H, rot), inner, wall_h)
    # front (-Y) with the 6 x 9 doorway
    side = (inner - DOOR_W - 1.2) / 2
    rust.corrugated(wall_matrix(-inner / 2, -y_out, SLAB_H, 0.0), side, wall_h)
    rust.corrugated(wall_matrix(DOOR_W / 2 + 0.6, -y_out, SLAB_H, 0.0), side, wall_h)
    rust.corrugated(wall_matrix(-(DOOR_W / 2 + 0.6), -y_out, SLAB_H + DOOR_H + 0.6, 0.0),
                    DOOR_W + 1.2, wall_h - DOOR_H - 0.6)
    # roof: corrugated sheet, ridges front-to-back, slight fall toward the back
    roof_w = SHED + 2.0
    fall = math.atan2(0.8, roof_w)
    M = (Matrix.Translation((-roof_w / 2, -roof_w / 2, top + 0.4)) @ Matrix.Rotation(-fall, 4, 'X')
         @ Matrix.Rotation(-math.pi / 2, 4, 'X'))  # sheet local z -> +Y (front to back)
    rust.corrugated(M, roof_w, roof_w, thickness=0.3, period=1.4, amp=0.22)
    for p in (slab, steel, lamp, rust):
        p.done(r)
    return r


# ---------------------------------------------------------------- bed

def build_bed():
    r = root("Bed")
    wood = Piece("Bed_Frame_Wood")
    wood.box((0, 0, 0.75), (4.4, 7.4, 0.5))
    for sx in (-1, 1):
        for sy in (-1, 1):
            wood.box((sx * 1.95, sy * 3.45, 0.4), (0.5, 0.5, 0.8))
    wood.box((0, 3.55, 1.6), (4.4, 0.4, 3.2))     # headboard (+Y, against the back wall)
    wood.box((0, -3.55, 1.1), (4.4, 0.4, 1.4))    # footboard
    cloth = Piece("Bed_Blanket_Cloth").box((0, -0.6, 1.4), (4.0, 5.6, 0.8))
    linen = Piece("Bed_Pillow_Linen").box((0, 2.6, 1.55), (3.2, 1.3, 0.6))
    for p in (wood, cloth, linen):
        p.done(r)
    return r


# ---------------------------------------------------------------- banner mast

def build_banner():
    r = root("BannerMast")
    base = Piece("Banner_Base_Concrete").box((0, 0, 0.3), (3.0, 3.0, 0.6))
    steel = Piece("Banner_Pole_Steel")
    steel.box((0, 0, 12.3), (0.8, 0.8, 24.0))
    steel.box((0, 0, 23.6), (6.4, 0.5, 0.5))
    for sx in (-1, 1):
        steel.box((sx * 0.9, 0, 1.2), (1.0, 1.4, 1.2))
    # flag hangs from the crossbar, gentle sway folds
    flag = Piece("Banner_Flag_Cloth")
    bm = flag.bm
    W, H, cols, rows = 5.2, 7.5, 12, 8
    grid_f, grid_b = [], []
    for j in range(rows + 1):
        rf, rb = [], []
        for i in range(cols + 1):
            x = -W / 2 + W * i / cols
            z = 23.3 - H * j / rows
            y = 0.35 * math.sin(i / cols * math.pi * 2.2) * (0.4 + 0.6 * j / rows)
            rf.append(bm.verts.new((x, y - 0.08, z)))
            rb.append(bm.verts.new((x, y + 0.08, z)))
        grid_f.append(rf)
        grid_b.append(rb)
    for j in range(rows):
        for i in range(cols):
            bm.faces.new((grid_f[j][i], grid_f[j + 1][i], grid_f[j + 1][i + 1], grid_f[j][i + 1]))
            bm.faces.new((grid_b[j][i + 1], grid_b[j + 1][i + 1], grid_b[j + 1][i], grid_b[j][i]))
    for i in range(cols):  # top and bottom edges
        bm.faces.new((grid_f[0][i], grid_f[0][i + 1], grid_b[0][i + 1], grid_b[0][i]))
        bm.faces.new((grid_f[rows][i + 1], grid_f[rows][i], grid_b[rows][i], grid_b[rows][i + 1]))
    for j in range(rows):  # side edges
        bm.faces.new((grid_f[j + 1][0], grid_f[j][0], grid_b[j][0], grid_b[j + 1][0]))
        bm.faces.new((grid_f[j][cols], grid_f[j + 1][cols], grid_b[j + 1][cols], grid_b[j][cols]))
    for p in (base, steel, flag):
        p.done(r)
    return r


# ---------------------------------------------------------------- shop stall

def build_shop():
    r = root("ShopStall")
    W, D = 24.0, 16.0
    hw, hd = W / 2, D / 2
    front_h, back_h = 11.5, 9.5
    floor = Piece("Shop_Floor_Concrete").box((0, 0, 0.3), (W, D, 0.6))
    steel = Piece("Shop_Frame_Steel")
    for sx in (-1, 1):
        steel.box((sx * (hw - 0.5), -(hd - 0.5), front_h / 2), (0.9, 0.9, front_h))
        steel.box((sx * (hw - 0.5), (hd - 0.5), back_h / 2), (0.9, 0.9, back_h))
    steel.box((0, -(hd - 0.5), front_h - 0.4), (W, 0.8, 0.8))  # front beam
    # sign board on two short poles above the front beam
    for sx in (-1, 1):
        steel.box((sx * 4.0, -(hd - 0.3), front_h + 1.2), (0.4, 0.4, 2.4))
    steel.box((0, -(hd - 0.2), front_h + 3.2), (11.0, 0.5, 3.4))
    sign = Piece("Shop_SignFace_Steel").box((0, -(hd + 0.1), front_h + 3.2), (10.2, 0.12, 2.8))
    rust = Piece("Shop_Walls_Rust")
    wall_in = W - 1.0
    rust.corrugated(wall_matrix(-wall_in / 2, -(hd - 0.35), 0.6, math.pi), wall_in, back_h - 1.0)
    # half-depth side walls on the back half (+Y) of both sides
    rust.corrugated(Matrix.Rotation(math.pi / 2, 4, 'Z') @ Matrix.Translation((0.0, -(hw - 0.35), 0.6)),
                    hd - 1.0, back_h - 1.4)   # right (+X): local x -> +Y
    rust.corrugated(Matrix.Rotation(-math.pi / 2, 4, 'Z') @ Matrix.Translation((-(hd - 1.0), -(hw - 0.35), 0.6)),
                    hd - 1.0, back_h - 1.4)   # left (-X): local x -> -Y, so start at -(hd-1)
    slope = math.atan2(front_h - back_h, D)
    roof_w, roof_d = W + 2.0, D + 2.5
    M = (Matrix.Translation((-roof_w / 2, -(hd + 1.5), front_h + 0.4)) @ Matrix.Rotation(-slope, 4, 'X')
         @ Matrix.Rotation(-math.pi / 2, 4, 'X'))
    rust.corrugated(M, roof_w, roof_d, thickness=0.3, period=1.4, amp=0.22)
    wood = Piece("Shop_Fittings_Wood")
    wood.box((0, -2.2, 1.9), (18.0, 2.2, 2.6))                  # counter body
    for z in (3.6, 6.2):                                         # back shelves
        wood.box((0, hd - 1.6, z), (16.0, 1.8, 0.35))
    for sx in (-1, 1):
        wood.box((sx * 8.2, hd - 1.6, 3.6), (0.4, 1.8, 6.0))
    for (x, y, z, s) in ((-6, hd - 1.6, 4.9, 2.2), (-2.5, hd - 1.6, 4.85, 2.0), (4, hd - 1.6, 7.5, 2.2),
                         (10.2, -hd + 2.0, 1.85, 2.5), (10.4, -hd + 4.7, 1.6, 2.0), (-10.3, -hd + 2.2, 1.85, 2.5)):
        wood.box((x, y, z), (s, s, s))
    steel_top = Piece("Shop_CounterTop_Steel").box((0, -2.2, 3.3), (18.4, 2.6, 0.2))
    lamps = Piece("Shop_Lights_Glow")
    for x in (-6, 6):
        lamps.box((x, -1.0, back_h + 0.7), (5.0, 0.35, 0.18))
    for p in (floor, steel, sign, rust, wood, steel_top, lamps):
        p.done(r)
    return r


# ---------------------------------------------------------------- dispensers

def build_dispenser():
    r = root("ResourceDispenser")
    steel = Piece("Dispenser_Body_Steel")
    steel.box((0, 0, 0.5), (6.0, 6.0, 1.0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            steel.box((sx * 2.55, sy * 2.55, 4.25), (0.9, 0.9, 6.5))
    steel.box((0, 0, 7.6), (6.0, 6.0, 0.8))
    steel.cyl((0, 0, 1.3), 2.2, 0.6, 24)
    steel.cyl((0, 0, 7.0), 2.2, 0.5, 24)
    steel.box((0, -3.3, 1.3), (3.2, 1.2, 0.6))     # output tray at the front
    rust = Piece("Dispenser_Housing_Rust").box((0, 2.7, 4.3), (3.6, 0.6, 4.6))
    glass = Piece("Dispenser_Tube_Glass").cyl((0, 0, 4.15), 1.8, 5.2, 24)
    core = Piece("Dispenser_Core_Glow").cyl((0, 0, 4.15), 0.85, 4.6, 16)
    for p in (steel, rust, glass, core):
        p.done(r)
    return r


def build_center_dispenser():
    r = root("CenterDispenser")
    steel = Piece("CDisp_Body_Steel")
    steel.box((0, 0, 0.75), (12.0, 12.0, 1.5))
    for sx in (-1, 1):
        for sy in (-1, 1):
            steel.box((sx * 5.1, sy * 5.1, 6.75), (1.6, 1.6, 10.5))
    steel.box((0, 0, 12.8), (12.0, 12.0, 1.6))
    for z in (2.2, 11.6):
        steel.cyl((0, 0, z), 4.1, 0.8, 32)
    steel.cyl((0, 0, 6.9), 3.95, 0.4, 32)              # mid band
    steel.box((0, -6.6, 1.9), (5.0, 1.6, 0.8))          # output tray
    # gantry canopy
    G, GH = 22.0, 18.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            steel.box((sx * (G / 2 - 0.5), sy * (G / 2 - 0.5), GH / 2), (1.0, 1.0, GH))
    for sy in (-1, 1):
        steel.box((0, sy * (G / 2 - 0.5), GH - 0.5), (G, 0.9, 1.0))
    for sx in (-1, 1):
        steel.box((sx * (G / 2 - 0.5), 0, GH - 0.5), (0.9, G, 1.0))
    for x in (-4, 4):
        steel.box((x, 0, GH - 0.5), (0.6, G, 0.6))
    rust = Piece("CDisp_Roof_Rust")
    rw = G + 2.0
    M = Matrix.Translation((-rw / 2, -rw / 2, GH + 0.2)) @ Matrix.Rotation(-math.pi / 2, 4, 'X')
    rust.corrugated(M, rw, rw, thickness=0.3, period=1.4, amp=0.22)
    rust.box((0, 5.6, 6.8), (5.0, 0.8, 7.0))              # rear housing
    glass = Piece("CDisp_Tube_Glass").cyl((0, 0, 6.9), 3.6, 9.4, 32)
    core = Piece("CDisp_Core_Glow").cyl((0, 0, 6.9), 1.8, 8.8, 20)
    lamps = Piece("CDisp_Lights_Glow")
    for x in (-6, 6):
        lamps.box((x, -3, GH - 1.1), (0.35, 6.0, 0.18))
    canvas = Piece("CDisp_Banners_Canvas")
    for sx in (-1, 1):
        canvas.box((sx * (G / 2 - 0.5), -(G / 2 + 0.2), GH - 6.5), (3.2, 0.15, 9.0))
    for p in (steel, rust, glass, core, lamps, canvas):
        p.done(r)
    return r


# ---------------------------------------------------------------- main + checks

def build_all():
    clear_collection()
    builders = [build_shed, build_bed, build_banner, build_shop, build_dispenser, build_center_dispenser]
    roots = []
    for i, b in enumerate(builders):
        rt = b()
        rt.location.x = i * 40.0
        roots.append(rt)
    problems = []
    for ob in get_collection().objects:
        if ob.type == 'MESH' and not ob.name.endswith(SUFFIXES):
            problems.append(f"{ob.name}: missing material suffix")
    # doorway must be clear: no shed vertex inside the 6 x 9 opening
    for ob in bpy.data.objects["StarterShed"].children:
        if ob.name.endswith("_Concrete"):
            continue
        for v in ob.data.vertices:
            c = v.co
            if abs(c.x) < DOOR_W / 2 - 0.05 and -SHED / 2 - 1.0 < c.y < -SHED / 2 + 1.5 and SLAB_H + 0.05 < c.z < SLAB_H + DOOR_H - 0.05:
                problems.append(f"{ob.name}: vertex in doorway {tuple(round(a, 2) for a in c)}")
                break
    tris = {ob.name: sum(len(p.vertices) - 2 for p in ob.data.polygons)
            for ob in get_collection().objects if ob.type == 'MESH'}
    return {"roots": [r.name for r in roots], "problems": problems, "max_tris": max(tris.values())}


def export_fbx(path):
    roots = [o for o in get_collection().objects if o.parent is None]
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
