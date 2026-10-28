"""Turns the imported team-island GLB (imports/team-island-blocky.glb) into Roblox-ready templates.

Decisions (Sterling, 2026-10-27): keep the GLB's own buildings, add our bed in the hut, remove the
hut door and the ramp, scale x1.75, keep the GLB's flat colours.

Output objects (collection FPSB_GLBTemplates), all with origin = island top centre (0, 0, 0):
  GLBIsland  : plateau, underside, floating rocks, trees, bushes, crates, fence, water tower
  GLBHut     : the bed hut (bed_base) without its door
  GLBShop    : the shop
  GLBBanner  : the banner
Meshes are joined per (template, GLB material) and named  GI_<Template>_<material>.
The red banner cloth is renamed to material "Cloth" so MapBuilder can recolour it per team.

Orientation: rotated 180 degrees about Z so the banner and fence face Blender -Y (Roblox -Z, the
map centre) and the hut sits on the back half.

Run in Blender after importing the GLB into collection FPSB_GLBIsland:
  exec(open(r"C:\\Roblox Dev\\FPS Bedwars\\blender\\fpsb_glb_island.py").read())
"""

import json
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

SCALE = 1.75
SRC_COLLECTION = "FPSB_GLBIsland"
OUT_COLLECTION = "FPSB_GLBTemplates"
DROP = ("ramp", "base_door", "base_door_handle")       # removed objects (and their children)
GROUPS = {"bed_base": "GLBHut", "shop": "GLBShop", "banner": "GLBBanner"}  # everything else -> GLBIsland
MATERIAL_RENAME = {"banner_red": "Cloth"}


def top_level_group(ob, root):
    """Name of the child of the GLB root that `ob` belongs to."""
    cur = ob
    while cur.parent is not None and cur.parent != root:
        cur = cur.parent
    return cur.name


def dropped(ob):
    """True if the object or any ancestor is in DROP (the ramp group, the hut door + handle)."""
    cur = ob
    while cur is not None:
        if cur.name.split(".")[0] in DROP:
            return True
        cur = cur.parent
    return False


def build():
    src = bpy.data.collections[SRC_COLLECTION]
    root = next(o for o in src.objects if o.parent is None)
    out = bpy.data.collections.get(OUT_COLLECTION)
    if out is None:
        out = bpy.data.collections.new(OUT_COLLECTION)
        bpy.context.scene.collection.children.link(out)
    for ob in list(out.objects):
        me = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        if me and me.users == 0:
            bpy.data.meshes.remove(me)

    # plateau top in world space (sand slab top) -> becomes Z = 0
    sand = next(o for o in src.objects if o.name.split(".")[0] == "plateau_sand")
    top_z = max((sand.matrix_world @ v.co).z for v in sand.data.vertices)
    xf = (Matrix.Rotation(math.pi, 4, 'Z') @ Matrix.Scale(SCALE, 4)
          @ Matrix.Translation((0, 0, -top_z)))

    buckets = {}  # (template, material) -> bmesh
    dropped_names = []
    for ob in src.objects:
        if ob.type != 'MESH':
            continue
        if dropped(ob):
            dropped_names.append(ob.name)
            continue
        grp = top_level_group(ob, root).split(".")[0]
        tmpl = GROUPS.get(grp, "GLBIsland")
        M = xf @ ob.matrix_world
        me = ob.data
        for poly in me.polygons:
            mat = me.materials[poly.material_index].name.split(".")[0] if me.materials else "rock"
            mat = MATERIAL_RENAME.get(mat, mat)
            key = (tmpl, mat)
            bm = buckets.get(key)
            if bm is None:
                bm = bmesh.new()
                buckets[key] = bm
            # rotation + uniform scale + translation keeps winding (det > 0)
            bm.faces.new([bm.verts.new(M @ me.vertices[i].co) for i in poly.vertices])
    report = {"dropped": len(dropped_names), "objects": {}}
    roots = {}
    for tmpl in ("GLBIsland", "GLBHut", "GLBShop", "GLBBanner"):
        e = bpy.data.objects.new(tmpl, None)
        out.objects.link(e)
        roots[tmpl] = e
    for (tmpl, mat), bm in sorted(buckets.items()):
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        name = f"GI_{tmpl[3:]}_{mat}"
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(name, me)
        out.objects.link(ob)
        ob.parent = roots[tmpl]
        report["objects"][name] = len(me.polygons) * 2
    return report


def key_points():
    """Positions (template space) that MapBuilder needs: hut interior + doorway, shop sign."""
    out = {}
    hut = [o for o in bpy.data.objects if o.name.startswith("GI_Hut_")]
    vs = [o.matrix_world @ v.co for o in hut for v in o.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    out["hut_min"] = list(mn)
    out["hut_max"] = list(mx)
    return out


def export_fbx(path):
    out = bpy.data.collections[OUT_COLLECTION]
    bpy.ops.object.select_all(action='DESELECT')
    for ob in out.objects:
        ob.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={'EMPTY', 'MESH'},
        apply_unit_scale=True, apply_scale_options='FBX_SCALE_NONE', global_scale=0.01,
        axis_forward='-Z', axis_up='Y', bake_space_transform=False, mesh_smooth_type='FACE',
        add_leaf_bones=False, bake_anim=False)


def origins_json(path):
    data = {}
    for ob in bpy.data.collections[OUT_COLLECTION].objects:
        if ob.type != 'MESH':
            continue
        vs = [v.co for v in ob.data.vertices]
        c = [(min(v[a] for v in vs) + max(v[a] for v in vs)) / 2 for a in range(3)]
        data[ob.name] = {"c": [round(x, 4) for x in c], "root": ob.parent.name}
    with open(path, "w") as f:
        json.dump(data, f, indent=1)
    return data
