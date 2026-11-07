"""Mixamo FBX -> Godot için tek .glb (karakter + tüm animasyonlar).

Blender içinde çalışır:
  blender -b --factory-startup -P tools/mixamo_to_glb.py -- <mixamo_klasörü> <çıktı.glb> <bilgi.json> [önizleme_klasörü]

- Karakter: klasördeki en büyük .fbx (ör. Remy.fbx, "with skin").
- Animasyonlar: aşağıdaki listedeki dosyalar; her birinin aksiyonu karakterin iskeletine eklenir.
- Dokular 1024 px'e küçültülür (APK boyutu için).
- Her animasyonun kök (Hips) yer değiştirmesi bilgi.json'a yazılır (dalış yönünü bulmak için).
- İsteğe bağlı: anahtar karelerin Cycles önizleme görüntüleri.
"""
import bpy, sys, os, json, glob, math

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT_GLB, OUT_JSON = argv[0], argv[1], argv[2]
PREVIEW = argv[3] if len(argv) > 3 else ""

# oyundaki ad -> Mixamo dosya adı
WANTED = {
    "idle": "offensive idle.fbx",
    "jog": "jog forward.fbx",
    "penalty_kick": "soccer penalty kick.fbx",
    "kick": "kick soccerball.fbx",
    "strike_jog": "strike foward jog.fbx",
    "header": "header soccerball.fbx",
    "fallen": "fallen idle.fbx",
    "stand_up": "standing up.fbx",
    "gk_idle": "goalkeeper idle.fbx",
    "gk_idle2": "goalkeeper idle (2).fbx",
    "gk_sidestep": "goalkeeper sidestep.fbx",
    "gk_sidestep2": "goalkeeper sidestep (2).fbx",
    "gk_dive": "goalkeeper diving save.fbx",
    "gk_dive2": "goalkeeper diving save (2).fbx",
    "gk_catch": "goalkeeper catch.fbx",
    "gk_catch2": "goalkeeper catch (2).fbx",
    "gk_catch3": "goalkeeper catch (3).fbx",
    "gk_catch4": "goalkeeper catch (4).fbx",
    "gk_scoop": "goalkeeper scoop.fbx",
    "gk_block": "goalkeeper body block.fbx",
    "gk_block2": "goalkeeper body block (2).fbx",
    "gk_block3": "goalkeeper body block (3).fbx",
    "gk_miss": "goalkeeper miss.fbx",
    "gk_directing": "goalkeeper directing.fbx",
}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def armature_of(objs):
    for o in objs:
        if o.type == "ARMATURE":
            return o
    return None


clear()
fbxs = sorted(glob.glob(os.path.join(SRC, "*.fbx")), key=os.path.getsize, reverse=True)
char_path = fbxs[0]
print("Karakter:", char_path)
bpy.ops.import_scene.fbx(filepath=char_path, automatic_bone_orientation=False)
char_objs = list(bpy.context.scene.objects)
arm = armature_of(char_objs)
assert arm is not None, "karakterde iskelet yok"
arm.name = "Armature"
if arm.animation_data and arm.animation_data.action:
    arm.animation_data.action.name = "tpose"

info = {"character": os.path.basename(char_path), "bones": [b.name for b in arm.data.bones], "anims": {}, "materials": []}

existing = set(bpy.context.scene.objects)
for name, fn in WANTED.items():
    p = os.path.join(SRC, fn)
    if not os.path.exists(p):
        print("YOK:", fn)
        continue
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=p, automatic_bone_orientation=False)
    new = [o for o in bpy.context.scene.objects if o not in before]
    a2 = armature_of(new)
    if a2 is None or a2.animation_data is None or a2.animation_data.action is None:
        print("aksiyon yok:", fn)
    else:
        act = a2.animation_data.action
        act.name = name
        act.use_fake_user = True
        # kök hareketi: Hips konumu ilk ve son kare
        fr = act.frame_range
        hips_fc = [fc for fc in act.fcurves if fc.data_path.endswith('"mixamorig:Hips"].location') or ('Hips' in fc.data_path and fc.data_path.endswith("location"))]
        disp = [0.0, 0.0, 0.0]
        for fc in hips_fc:
            disp[fc.array_index] = fc.evaluate(fr[1]) - fc.evaluate(fr[0])
        info["anims"][name] = {"file": fn, "frames": [fr[0], fr[1]], "seconds": (fr[1] - fr[0]) / 30.0, "hips_disp": disp}
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)

# tüm aksiyonları NLA şeritleri olarak karaktere bağla (glTF dışa aktarımı hepsini yazsın)
if arm.animation_data is None:
    arm.animation_data_create()
for act in bpy.data.actions:
    if act.name == "tpose":
        continue
    tr = arm.animation_data.nla_tracks.new()
    tr.name = act.name
    tr.strips.new(act.name, int(act.frame_range[0]), act)
    tr.mute = True
arm.animation_data.action = None

# dokuları küçült
for img in bpy.data.images:
    try:
        if img.size[0] > 1024:
            img.scale(1024, int(1024 * img.size[1] / max(1, img.size[0])))
            img.pack()
    except Exception as e:
        print("doku:", img.name, e)
for m in bpy.data.materials:
    info["materials"].append(m.name)
info["meshes"] = [o.name for o in bpy.context.scene.objects if o.type == "MESH"]

os.makedirs(os.path.dirname(OUT_GLB) or ".", exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT_GLB, export_format="GLB", export_yup=True, export_animations=True,
    export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_frame_step=1,
    export_image_format="JPEG", export_texcoords=True, export_normals=True, export_skins=True,
)
info["glb_bytes"] = os.path.getsize(OUT_GLB)
with open(OUT_JSON, "w") as f:
    json.dump(info, f, indent=1)
print("GLB yazıldı:", OUT_GLB, info["glb_bytes"])

# ---------------- önizleme ----------------
if PREVIEW:
    os.makedirs(PREVIEW, exist_ok=True)
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.samples = 12
    scn.cycles.device = "CPU"
    scn.render.resolution_x = 480
    scn.render.resolution_y = 480
    scn.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.color = (0.25, 0.3, 0.4)
    scn.world = world
    bpy.ops.object.light_add(type="SUN", location=(2, -3, 5))
    bpy.context.active_object.data.energy = 4.0
    bpy.ops.object.camera_add(location=(2.6, -3.6, 1.6))
    cam = bpy.context.active_object
    cam.rotation_euler = (math.radians(80), 0, math.radians(35))
    scn.camera = cam
    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
    shots = [("idle", 0.3), ("penalty_kick", 0.55), ("gk_idle", 0.3), ("gk_dive", 0.5), ("gk_dive2", 0.5), ("gk_catch", 0.5), ("gk_block", 0.5)]
    for name, t in shots:
        act = bpy.data.actions.get(name)
        if act is None:
            continue
        arm.animation_data.action = act
        f = act.frame_range[0] + (act.frame_range[1] - act.frame_range[0]) * t
        scn.frame_set(int(f))
        scn.render.filepath = os.path.join(PREVIEW, f"{name}.png")
        bpy.ops.render.render(write_still=True)
    arm.animation_data.action = None
    print("önizlemeler hazır")
