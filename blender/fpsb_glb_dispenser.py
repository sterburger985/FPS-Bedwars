"""Turns Sterling's dispenser-island OBJ (imports/bedwars-dispenser-island.obj + .mtl) into Roblox templates
for the 5 resource platforms between the team islands.

Decisions (Sterling, 2026-10-28): scale x1 (53 x 53 studs, 45 x 45 deck), drop the 4 loose "already
dispensed" blocks/ingots on the trays, keep the crates and ore stacks as cover.

Output (collection FPSB_GLBDispenserTemplates), origin = deck top centre (0, 0, 0):
  GLBPlatform   : rock underside, deck, pillars, railings, lamps, crates, ore stacks
  GLBDispenser  : the machine (tower base, housing, core, hopper, nozzles, trays, spin ring)
Meshes are joined per (template, material): GP_<Template>_<material>.

Run in Blender:
  ns = {}; exec(open(r"C:\\Roblox Dev\\FPS Bedwars\\blender\\fpsb_glb_dispenser.py").read(), ns)
  ns["build"](); ns["export"](fbx_path, json_path)
"""

import json

import bmesh
import bpy
from mathutils import Matrix

OBJ = r"C:\Roblox Dev\FPS Bedwars\imports\bedwars-dispenser-island.obj"
SRC = "FPSB_GLBDispenser"
OUT = "FPSB_GLBDispenserTemplates"
SCALE = 1.0
DROP = ("dispensed_",)
DISPENSER = ("tower_base", "machine_", "dispenser_trays")
DECK_TOP_OBJECT = "platform_stone_tile"


def import_obj():
    col = bpy.data.collections.get(SRC)
    if col is None:
        col = bpy.data.collections.new(SRC)
        bpy.context.scene.collection.children.link(col)
    for ob in list(col.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=OBJ, forward_axis='NEGATIVE_Z', up_axis='Y')
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        col.objects.link(o)
    return len(new)


def template_of(name):
    base = name.split(".")[0]
    if base.startswith(DROP):
        return None
    if base.startswith(DISPENSER):
        return "GLBDispenser"
    return "GLBPlatform"


def build():
    n_in = import_obj()
    src = bpy.data.collections[SRC]
    deck = next(o for o in src.objects if o.name.split(".")[0] == DECK_TOP_OBJECT)
    top = max((deck.matrix_world @ v.co).z for v in deck.data.vertices)
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
    for t in ("GLBPlatform", "GLBDispenser"):
        e = bpy.data.objects.new(t, None)
        out.objects.link(e)
        roots[t] = e

    buckets, dropped = {}, []
    for ob in src.objects:
        if ob.type != 'MESH':
            continue
        tmpl = template_of(ob.name)
        if tmpl is None:
            dropped.append(ob.name)
            continue
        M = xf @ ob.matrix_world
        me = ob.data
        for poly in me.polygons:
            mat = me.materials[poly.material_index].name.split(".")[0] if me.materials else "rock"
            bm = buckets.setdefault((tmpl, mat), bmesh.new())
            # uniform scale + translation keep the OBJ's own winding
            bm.faces.new([bm.verts.new(M @ me.vertices[i].co) for i in poly.vertices])
    report = {}
    for (tmpl, mat), bm in sorted(buckets.items()):
        name = f"GP_{tmpl[3:]}_{mat}"
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(name, me)
        out.objects.link(ob)
        ob.parent = roots[tmpl]
        report[name] = sum(len(p.vertices) - 2 for p in me.polygons)
    return {"objects_in": n_in, "dropped": dropped, "deck_top": top, "meshes": report}


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
