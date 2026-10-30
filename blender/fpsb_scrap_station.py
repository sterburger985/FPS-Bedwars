"""Turns Sterling's scrap dropper OBJ (imports/scrap-dropper.obj + .mtl) into Roblox templates for the
team-island scrap station, which replaces the old shop stall (Sterling, 2026-10-30: x1, native size).

The model is a claw-machine scrap dropper (pavilion, claw, glowing output pad) joined to a small shop
deck with two vending machines (Guns, Materials).

Output (collection FPSB_ScrapStationTemplates). Every template shares the station origin: the dropper's
floor bottom centre (OBJ 0,0,0), so they are all placed with the same CFrame. ScrapPickup is the exception:
it is the decorative scrap pile from the pad, moved so its bottom centre is the origin, and becomes the
collectable scrap pickup.
  ScrapStation   pavilion, roof, lamps, claw carriage, output pad, shop deck, wall, railings
  ScrapClaw      claw piston, head and fingers (animated on clients when scrap drops)
  VendGuns       the Guns vending machine and its label
  VendMaterials  the Materials vending machine and its label
  ScrapPickup    scrap pile (2 materials)
Meshes are joined per (template, material): GS_<Template>_<material>.

Run in Blender:
  ns = {}; exec(open(r"C:\\Roblox Dev\\FPS Bedwars\\blender\\fpsb_scrap_station.py").read(), ns)
  ns["build"](); ns["export"](fbx_path, json_path)
"""

import json

import bmesh
import bpy
from mathutils import Matrix, Vector

OBJ = r"C:\Roblox Dev\FPS Bedwars\imports\scrap-dropper.obj"
SRC = "FPSB_ScrapStationSrc"
OUT = "FPSB_ScrapStationTemplates"
SCALE = 1.0
TEMPLATES = ("ScrapStation", "ScrapClaw", "VendGuns", "VendMaterials", "ScrapPickup")


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
    if base.startswith(("claw_piston", "claw_head", "claw_fingers")):
        return "ScrapClaw"
    if base.startswith("vending_guns"):
        return "VendGuns"
    if base.startswith("vending_materials"):
        return "VendMaterials"
    if base.startswith("scrap_pile"):
        return "ScrapPickup"
    return "ScrapStation"


def build():
    n_in = import_obj()
    src = bpy.data.collections[SRC]
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
    for t in TEMPLATES:
        e = bpy.data.objects.new(t, None)
        out.objects.link(e)
        roots[t] = e

    # the pickup is re-centred on its own bottom centre
    pile = [o for o in src.objects if o.type == 'MESH' and template_of(o.name) == "ScrapPickup"]
    pts = [o.matrix_world @ v.co for o in pile for v in o.data.vertices]
    pmin = Vector([min(p[a] for p in pts) for a in range(3)])
    pmax = Vector([max(p[a] for p in pts) for a in range(3)])
    pile_shift = Matrix.Translation((-(pmin.x + pmax.x) / 2, -(pmin.y + pmax.y) / 2, -pmin.z))

    buckets = {}
    for ob in src.objects:
        if ob.type != 'MESH':
            continue
        tmpl = template_of(ob.name)
        M = Matrix.Scale(SCALE, 4) @ ob.matrix_world
        if tmpl == "ScrapPickup":
            M = Matrix.Scale(SCALE, 4) @ pile_shift @ ob.matrix_world
        me = ob.data
        for poly in me.polygons:
            mat = me.materials[poly.material_index].name.split(".")[0] if me.materials else "metal_dark"
            bm = buckets.setdefault((tmpl, mat), bmesh.new())
            bm.faces.new([bm.verts.new(M @ me.vertices[i].co) for i in poly.vertices])
    report = {}
    for (tmpl, mat), bm in sorted(buckets.items()):
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        name = f"GS_{tmpl}_{mat}"
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(name, me)
        out.objects.link(ob)
        ob.parent = roots[tmpl]
        report[name] = sum(len(p.vertices) - 2 for p in me.polygons)
    return {"objects_in": n_in, "meshes": report, "pile_size": list(pmax - pmin)}


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
