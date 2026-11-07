#!/usr/bin/env python3
"""Penaltı Ustası karakter üreticisi.

Kemik iskeleti üzerinde yumuşak birleşimli (smooth-union) SDF ile tek parça, organik
bir insan gövdesi kurar; marching cubes ile ağ çıkarır; her köşeye bölge (ten, forma,
şort, çorap, krampon, saç, eldiven, yaka) ve ortam kapatması (AO) yazar; kemik
ağırlıklarını hesaplar ve iskeletli glTF 2.0 (.glb) olarak kaydeder.

Kullanım: python3 tools/make_characters.py  ->  assets/models/player.glb, keeper.glb
"""
import json, os, struct, math
import numpy as np
from skimage import measure

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "models")

# bölge kodları (COLOR_0.r = kod / 10)
SKIN, SHIRT, SHORTS, SOCKS, BOOTS, HAIR, GLOVES, TRIM = 0, 1, 2, 3, 4, 5, 6, 7


# ---------------- SDF yardımcıları ----------------
def sd_round_cone(p, a, b, ra, rb):
    a = np.asarray(a, np.float32); b = np.asarray(b, np.float32)
    ba = b - a
    l2 = float(ba @ ba)
    pa = p - a
    h = np.clip((pa @ ba) / l2, 0.0, 1.0)
    d = np.linalg.norm(pa - h[:, None] * ba, axis=1)
    return d - (ra + (rb - ra) * h)


def sd_ellipsoid(p, c, r):
    q = (p - np.asarray(c, np.float32)) / np.asarray(r, np.float32)
    k0 = np.linalg.norm(q, axis=1)
    k1 = np.linalg.norm(q / np.asarray(r, np.float32), axis=1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


# ---------------- iskelet ----------------
def skeleton(keeper):
    s = 1.04 if keeper else 1.0
    J = {
        "Hips": (0, 0.98, 0), "Spine": (0, 1.10, 0), "Chest": (0, 1.28, 0), "Neck": (0, 1.49, 0.0), "Head": (0, 1.585, 0.01),
        "Shoulder.L": (0.06, 1.44, 0), "UpperArm.L": (0.195, 1.435, -0.005), "ForeArm.L": (0.235, 1.165, -0.01), "Hand.L": (0.265, 0.925, 0.01),
        "UpLeg.L": (0.095, 0.95, 0), "Leg.L": (0.105, 0.52, 0.01), "Foot.L": (0.11, 0.095, -0.02),
    }
    for k in list(J.keys()):
        if k.endswith(".L"):
            x, y, z = J[k]
            J[k[:-2] + ".R"] = (-x, y, z)
    J = {k: (v[0] * s, v[1] * s, v[2] * s) for k, v in J.items()}
    parent = {
        "Hips": None, "Spine": "Hips", "Chest": "Spine", "Neck": "Chest", "Head": "Neck",
        "UpLeg.L": "Hips", "Leg.L": "UpLeg.L", "Foot.L": "Leg.L",
        "UpLeg.R": "Hips", "Leg.R": "UpLeg.R", "Foot.R": "Leg.R",
        "Shoulder.L": "Chest", "UpperArm.L": "Shoulder.L", "ForeArm.L": "UpperArm.L", "Hand.L": "ForeArm.L",
        "Shoulder.R": "Chest", "UpperArm.R": "Shoulder.R", "ForeArm.R": "UpperArm.R", "Hand.R": "ForeArm.R",
    }
    ends = {"Head": (0, 1.80 * s, 0.01), "Hand.L": (0.28 * s, 0.82 * s, 0.025), "Hand.R": (-0.28 * s, 0.82 * s, 0.025),
            "Foot.L": (0.115 * s, 0.03, 0.15 * s), "Foot.R": (-0.115 * s, 0.03, 0.15 * s)}
    return J, parent, ends


def body_parts(p, J, keeper):
    g = lambda n: np.array(J[n], np.float32)
    s = 1.04 if keeper else 1.0
    k = 0.035
    parts = {}
    # gövde
    d = sd_ellipsoid(p, (0, 1.31 * s, -0.005), (0.165 * s, 0.17 * s, 0.11 * s))           # göğüs
    d = smin(d, sd_ellipsoid(p, (0, 1.14 * s, 0.0), (0.14 * s, 0.14 * s, 0.098 * s)), k)    # karın
    d = smin(d, sd_ellipsoid(p, (0, 0.975 * s, -0.005), (0.152 * s, 0.10 * s, 0.105 * s)), k)  # kalça
    d = smin(d, sd_ellipsoid(p, (0, 0.96 * s, -0.06 * s), (0.13 * s, 0.085 * s, 0.07 * s)), k)  # kalça arkası
    d = smin(d, sd_ellipsoid(p, (0, 1.30 * s, 0.07 * s), (0.13 * s, 0.09 * s, 0.05 * s)), k)    # göğüs kası
    d = smin(d, sd_ellipsoid(p, (0, 1.36 * s, -0.06 * s), (0.15 * s, 0.11 * s, 0.06 * s)), k)   # sırt / kanat
    for side in (1, -1):
        sh = np.array([0.17 * side * s, 1.43 * s, -0.005], np.float32)
        d = smin(d, sd_ellipsoid(p, sh, (0.07 * s, 0.06 * s, 0.065 * s)), 0.03)              # omuz (deltoid)
        d = smin(d, sd_round_cone(p, (0.05 * side * s, 1.45 * s, -0.01), sh, 0.06 * s, 0.05 * s), 0.04)  # trapez
    # şort kalçası
    for side in (1, -1):
        d = smin(d, sd_round_cone(p, (0.07 * side * s, 0.97 * s, 0), (0.09 * side * s, 0.86 * s, 0.005), 0.085 * s, 0.085 * s), 0.02)
    parts["torso"] = d
    # boyun ve baş
    d = sd_round_cone(p, g("Neck") - [0, 0.03, 0], g("Head") + [0, 0.02, 0], 0.056 * s, 0.05 * s)
    hc = g("Head")
    head = sd_ellipsoid(p, hc + [0, 0.10 * s, 0.0], (0.087 * s, 0.112 * s, 0.10 * s))
    head = smin(head, sd_ellipsoid(p, hc + [0, 0.045 * s, 0.028 * s], (0.066 * s, 0.06 * s, 0.072 * s)), 0.03)  # çene
    head = smin(head, sd_ellipsoid(p, hc + [0, 0.125 * s, 0.083 * s], (0.068 * s, 0.017 * s, 0.022 * s)), 0.012)  # kaş kemiği
    head = smin(head, sd_round_cone(p, hc + [0, 0.105 * s, 0.098 * s], hc + [0, 0.075 * s, 0.118 * s], 0.010 * s, 0.017 * s), 0.012)  # burun
    for side in (1, -1):
        head = smin(head, sd_ellipsoid(p, hc + [0.086 * side * s, 0.095 * s, -0.005], (0.014 * s, 0.03 * s, 0.022 * s)), 0.008)  # kulak
        head = smin(head, sd_ellipsoid(p, hc + [0.045 * side * s, 0.075 * s, 0.075 * s], (0.03 * s, 0.022 * s, 0.025 * s)), 0.02)  # elmacık
    # saç (kafanın üstünde hafif hacim)
    hair = sd_ellipsoid(p, hc + [0, 0.13 * s, -0.008], (0.093 * s, 0.09 * s, 0.106 * s))
    hair = np.maximum(hair, -(p[:, 1] - (hc[1] + 0.105 * s)))  # yalnız üst kısım
    head = smin(head, hair, 0.01)
    parts["head"] = smin(d, head, 0.02)
    # kollar
    for side in ("L", "R"):
        ua, fa, ha = g("UpperArm." + side), g("ForeArm." + side), g("Hand." + side)
        sx = 1 if side == "L" else -1
        arm = sd_round_cone(p, ua, fa, 0.05 * s, 0.04 * s)
        arm = smin(arm, sd_ellipsoid(p, ua * 0.45 + fa * 0.55 + [0, 0, 0.012], (0.042 * s, 0.075 * s, 0.045 * s)), 0.02)  # pazı
        arm = smin(arm, sd_round_cone(p, fa, ha, 0.041 * s, 0.028 * s), 0.025)
        arm = smin(arm, sd_ellipsoid(p, fa * 0.7 + ha * 0.3 + [0, 0, 0.005], (0.04 * s, 0.07 * s, 0.038 * s)), 0.02)  # ön kol kası
        hand_c = ha + np.array([0.008 * sx, -0.055 * s, 0.012], np.float32)
        hr = (0.03 * s, 0.058 * s, 0.045 * s) if keeper else (0.022 * s, 0.05 * s, 0.038 * s)
        arm = smin(arm, sd_ellipsoid(p, hand_c, hr), 0.02)
        arm = smin(arm, sd_ellipsoid(p, ha + [-0.0 * sx, -0.035 * s, 0.04 * s], (0.012 * s, 0.03 * s, 0.012 * s)), 0.01)  # başparmak
        parts["arm" + side] = arm
    # bacaklar
    for side in ("L", "R"):
        ul, lg, ft = g("UpLeg." + side), g("Leg." + side), g("Foot." + side)
        leg = sd_round_cone(p, ul, lg, 0.078 * s, 0.05 * s)
        leg = smin(leg, sd_ellipsoid(p, ul * 0.55 + lg * 0.45 + [0, 0, 0.02], (0.07 * s, 0.15 * s, 0.07 * s)), 0.03)  # uyluk kası
        leg = smin(leg, sd_round_cone(p, lg, ft, 0.05 * s, 0.033 * s), 0.025)
        leg = smin(leg, sd_ellipsoid(p, lg * 0.72 + ft * 0.28 + [0, 0, -0.03], (0.048 * s, 0.10 * s, 0.05 * s)), 0.03)  # baldır
        toe = np.array(J["Foot." + side], np.float32) + [0, -0.055, 0.17 * s]
        leg = smin(leg, sd_round_cone(p, ft + [0, -0.04, -0.035], toe, 0.042 * s, 0.035 * s), 0.02)  # krampon
        sx = 1 if side == "L" else -1
        leg = smin(leg, sd_round_cone(p, (0.1 * sx * s, 0.86 * s, 0.005), (0.11 * sx * s, 0.76 * s, 0.01), 0.086 * s, 0.083 * s), 0.02)  # şort paçası
        parts["leg" + side] = leg
    return parts


PART_ORDER = ["torso", "head", "armL", "armR", "legL", "legR"]


def body_sdf(p, J, keeper):
    parts = body_parts(p, J, keeper)
    d = parts["torso"]
    d = smin(d, parts["head"], 0.02)
    for k in ("armL", "armR"):
        d = smin(d, parts[k], 0.03)
    for k in ("legL", "legR"):
        d = smin(d, parts[k], 0.035)
    return d


def part_index(v, J, keeper):
    parts = body_parts(v, J, keeper)
    M = np.stack([parts[k] for k in PART_ORDER], 1)
    return np.argmin(M, axis=1)


def regions(v, J, keeper):
    s = 1.04 if keeper else 1.0
    y, x, z = v[:, 1], v[:, 0], v[:, 2]
    r = np.full(len(v), SKIN, np.int32)
    head_y = J["Head"][1]
    torso = (y > 0.99 * s) & (y < 1.465 * s) & (np.abs(x) < 0.215 * s)
    r[torso] = SHIRT
    # kollar: dış futbolcu kısa kol, kaleci uzun kol
    for side in (1, -1):
        ua = np.array(J["UpperArm." + ("L" if side == 1 else "R")]); fa = np.array(J["ForeArm." + ("L" if side == 1 else "R")])
        ha = np.array(J["Hand." + ("L" if side == 1 else "R")])
        on_side = (x * side) > 0.15 * s
        if keeper:
            sleeve_end = ha[1] + 0.02
        else:
            sleeve_end = ua[1] - (ua[1] - fa[1]) * 0.48
        r[on_side & (y > sleeve_end) & (y < 1.5 * s) & (y > 1.0 * s)] = SHIRT
        if keeper:
            r[on_side & (y <= ha[1] + 0.02) & (y > 0.75 * s) & ((x * side) > 0.2 * s)] = GLOVES
        # kol ağzı şeridi
        band = np.abs(y - sleeve_end) < 0.012
        r[on_side & band & (y > 0.9 * s)] = TRIM
    # yaka: boynun çevresinde ince şerit
    rad = np.sqrt(x ** 2 + (z - 0.0) ** 2)
    collar = (y > 1.445 * s) & (y < 1.478 * s) & (rad < 0.1 * s) & (rad > 0.045 * s)
    r[collar] = TRIM
    r[(y >= 1.478 * s) & (y < 1.5 * s) & (rad < 0.1 * s) & (rad > 0.07 * s)] = TRIM
    # şort (yalnız kalça ve bacaklar; eller hariç)
    shorts = (y <= 1.0 * s) & (y > 0.735 * s) & (np.abs(x) < 0.215 * s)
    r[shorts & (r != GLOVES)] = SHORTS
    # çorap ve krampon
    legs = np.abs(x) < 0.2 * s
    r[legs & (y <= 0.47 * s) & (y > 0.115)] = SOCKS
    r[legs & (y <= 0.115)] = BOOTS
    # saç
    hc = np.array(J["Head"])
    hy = y - hc[1]
    hair = (y > head_y + 0.05) & (((hy > 0.115 * s) & (z < 0.07 * s)) | ((hy > 0.07 * s) & (z < -0.035 * s)) | ((hy > 0.135 * s)))
    hair &= np.abs(x) < 0.11 * s
    r[hair] = HAIR
    # sakal gölgesi (çene altı) yok; dudak bölgesi gölgeleme shader'da
    return r


def ao(v, n, J, keeper):
    acc = np.zeros(len(v), np.float32)
    for i, dist in enumerate((0.015, 0.035, 0.07)):
        d = body_sdf(v + n * dist, J, keeper)
        acc += np.clip((dist - d) / dist, 0, 1) * (0.5 ** i)
    return np.clip(1.0 - acc * 0.55, 0.25, 1.0)


ALLOWED = {
    "torso": ["Hips", "Spine", "Chest", "Neck", "Shoulder.L", "Shoulder.R", "UpLeg.L", "UpLeg.R"],
    "head": ["Neck", "Head", "Chest"],
    "armL": ["Shoulder.L", "UpperArm.L", "ForeArm.L", "Hand.L", "Chest"],
    "armR": ["Shoulder.R", "UpperArm.R", "ForeArm.R", "Hand.R", "Chest"],
    "legL": ["Hips", "UpLeg.L", "Leg.L", "Foot.L"],
    "legR": ["Hips", "UpLeg.R", "Leg.R", "Foot.R"],
}


def skin_weights(v, J, parent, ends, names, part=None):
    segs = []
    for nm in names:
        a = np.array(J[nm], np.float32)
        kids = [c for c, p in parent.items() if p == nm]
        if nm in ends:
            b = np.array(ends[nm], np.float32)
        elif nm == "Hips":
            b = np.array(J["Spine"], np.float32)
        elif nm == "Chest":
            b = np.array(J["Neck"], np.float32)
        elif nm.startswith("Shoulder"):
            b = np.array(J["UpperArm" + nm[-2:]], np.float32)
        elif len(kids) == 1:
            b = np.array(J[kids[0]], np.float32)
        else:
            b = a + np.array([0, 0.1, 0], np.float32)
        segs.append((a, b))
    D = np.zeros((len(v), len(names)), np.float32)
    for j, (a, b) in enumerate(segs):
        ba = b - a
        h = np.clip(((v - a) @ ba) / max(float(ba @ ba), 1e-6), 0, 1)
        D[:, j] = np.linalg.norm(v - a - h[:, None] * ba, axis=1)
    # bölgesel kısıtlar: bacak köşeleri kola, kol köşeleri bacağa bağlanmasın
    idx = {n: i for i, n in enumerate(names)}
    big = 10.0
    for side, sx in (("L", 1), ("R", -1)):
        arm_ids = [idx["Shoulder." + side], idx["UpperArm." + side], idx["ForeArm." + side], idx["Hand." + side]]
        leg_ids = [idx["UpLeg." + side], idx["Leg." + side], idx["Foot." + side]]
        wrong_side = (v[:, 0] * sx) < -0.02
        for j in arm_ids + leg_ids:
            D[wrong_side, j] += big
        below_hip = v[:, 1] < 0.9
        for j in arm_ids:
            D[below_hip & (np.abs(v[:, 0]) < 0.2), j] += big
    if part is not None:
        for pi, pname in enumerate(PART_ORDER):
            sel = part == pi
            for j, nm in enumerate(names):
                if nm not in ALLOWED[pname]:
                    D[sel, j] += big
        # gövdedeki kalça bölgesi uyluklara yalnız alt kısımda bağlansın
        torso_sel = part == 0
        for side in ("L", "R"):
            D[torso_sel & (v[:, 1] > 0.9), idx["UpLeg." + side]] += big
            D[torso_sel & (v[:, 1] < 1.38), idx["Shoulder." + side]] += big
    mind = D.min(axis=1, keepdims=True)
    W = np.exp(-((D - mind) / 0.02) ** 2)
    order = np.argsort(-W, axis=1)[:, :4]
    w4 = np.take_along_axis(W, order, axis=1)
    w4 = w4 / w4.sum(axis=1, keepdims=True)
    return order.astype(np.uint16), w4.astype(np.float32)


# ---------------- glTF yazıcı ----------------
def write_glb(path, verts, norms, colors, faces, joints, weights, J, parent, names, uvs, uv2):
    bin_parts = []
    accessors, views = [], []

    def add(arr, comp, typ, target=None, minmax=False):
        data = arr.tobytes()
        off = sum(len(b) for b in bin_parts)
        pad = (-len(data)) % 4
        bin_parts.append(data + b"\x00" * pad)
        view = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target:
            view["target"] = target
        views.append(view)
        acc = {"bufferView": len(views) - 1, "componentType": comp, "count": int(arr.shape[0]), "type": typ}
        if minmax:
            acc["min"] = arr.min(axis=0).tolist()
            acc["max"] = arr.max(axis=0).tolist()
        accessors.append(acc)
        return len(accessors) - 1

    a_pos = add(verts.astype(np.float32), 5126, "VEC3", 34962, True)
    a_nrm = add(norms.astype(np.float32), 5126, "VEC3", 34962)
    a_col = add(colors.astype(np.float32), 5126, "VEC4", 34962)
    a_uv = add(uvs.astype(np.float32), 5126, "VEC2", 34962)
    a_uv2 = add(uv2.astype(np.float32), 5126, "VEC2", 34962)
    a_jnt = add(joints.astype(np.uint16), 5123, "VEC4", 34962)
    a_wgt = add(weights.astype(np.float32), 5126, "VEC4", 34962)
    a_idx = add(faces.astype(np.uint32).reshape(-1), 5125, "SCALAR", 34963)
    # düğümler: 0 = kök, 1 = mesh, 2.. = kemikler
    nodes = [{"name": "Character", "children": [1, 2]}, {"name": "Body", "mesh": 0, "skin": 0}]
    bone_node = {n: 2 + i for i, n in enumerate(names)}
    for n in names:
        p = parent[n]
        t = np.array(J[n]) - (np.array(J[p]) if p else 0)
        nd = {"name": n, "translation": [float(x) for x in t]}
        kids = [bone_node[c] for c in names if parent[c] == n]
        if kids:
            nd["children"] = kids
        nodes.append(nd)
    ibm = np.zeros((len(names), 16), np.float32)
    for i, n in enumerate(names):
        m = np.eye(4, dtype=np.float32)
        m[:3, 3] = -np.array(J[n], np.float32)
        ibm[i] = m.T.reshape(-1)  # sütun öncelikli
    a_ibm = add(ibm, 5126, "MAT4")
    gltf = {
        "asset": {"version": "2.0", "generator": "penalti-ustasi make_characters.py"},
        "scene": 0, "scenes": [{"nodes": [0]}], "nodes": nodes,
        "meshes": [{"name": "Body", "primitives": [{"attributes": {"POSITION": a_pos, "NORMAL": a_nrm, "TEXCOORD_0": a_uv, "TEXCOORD_1": a_uv2,
                    "JOINTS_0": a_jnt, "WEIGHTS_0": a_wgt}, "indices": a_idx, "material": 0}]}],
        "materials": [{"name": "Kit", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0, "roughnessFactor": 0.7}}],
        "skins": [{"joints": [bone_node[n] for n in names], "inverseBindMatrices": a_ibm, "skeleton": bone_node["Hips"]}],
        "accessors": accessors, "bufferViews": views,
    }
    binb = b"".join(bin_parts)
    gltf["buffers"] = [{"byteLength": len(binb)}]
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * ((-len(js)) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binb)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack("<II", len(binb), 0x004E4942)); f.write(binb)


def build(keeper, voxel=0.0085):
    J, parent, ends = skeleton(keeper)
    names = list(parent.keys())
    lo = np.array([-0.44, -0.01, -0.22], np.float32)
    hi = np.array([0.44, 1.92, 0.28], np.float32)
    shape = np.ceil((hi - lo) / voxel).astype(int) + 1
    xs = [lo[i] + np.arange(shape[i]) * voxel for i in range(3)]
    X, Y, Z = np.meshgrid(*xs, indexing="ij")
    P = np.stack([X.ravel(), Y.ravel(), Z.ravel()], 1).astype(np.float32)
    vol = np.empty(len(P), np.float32)
    CH = 400000
    for i in range(0, len(P), CH):
        vol[i:i + CH] = body_sdf(P[i:i + CH], J, keeper)
    vol = vol.reshape(shape)
    verts, faces, _, _ = measure.marching_cubes(vol, 0.0, spacing=(voxel,) * 3)
    verts = verts.astype(np.float32) + lo
    faces = faces.copy()  # skimage (descent) yüzleri zaten dışa dönük üretir
    # normaller: SDF gradyanı
    e = 0.002
    n = np.stack([
        body_sdf(verts + [e, 0, 0], J, keeper) - body_sdf(verts - [e, 0, 0], J, keeper),
        body_sdf(verts + [0, e, 0], J, keeper) - body_sdf(verts - [0, e, 0], J, keeper),
        body_sdf(verts + [0, 0, e], J, keeper) - body_sdf(verts - [0, 0, e], J, keeper)], 1)
    n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-9
    reg = regions(verts, J, keeper)
    occ = ao(verts, n, J, keeper)
    cols = np.stack([reg / 10.0, occ, np.zeros(len(verts)), np.ones(len(verts))], 1).astype(np.float32)
    uvs = np.stack([verts[:, 0], verts[:, 1]], 1).astype(np.float32)  # dinlenme konumu (desen kaymasın)
    uv2 = np.stack([reg / 10.0, occ], 1).astype(np.float32)  # bölge + AO (renk dönüşümünden etkilenmesin)
    part = part_index(verts, J, keeper)
    jw, ww = skin_weights(verts, J, parent, ends, names, part)
    os.makedirs(OUT, exist_ok=True)
    name = "keeper" if keeper else "player"
    write_glb(os.path.join(OUT, name + ".glb"), verts, n, cols, faces, jw, ww, J, parent, names, uvs, uv2)
    print(name, "köşe", len(verts), "üçgen", len(faces))
    return verts, faces, reg, occ, n


def preview(verts, faces, reg, occ, n, path):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from mpl_toolkits.mplot3d.art3d import Poly3DCollection
    pal = {SKIN: (0.88, 0.67, 0.52), SHIRT: (0.85, 0.12, 0.15), SHORTS: (0.95, 0.95, 0.95), SOCKS: (0.85, 0.12, 0.15),
           BOOTS: (0.08, 0.08, 0.1), HAIR: (0.15, 0.1, 0.06), GLOVES: (0.2, 0.8, 0.4), TRIM: (1.0, 0.85, 0.1)}
    fig = plt.figure(figsize=(12, 8), dpi=110)
    light = np.array([0.4, 0.6, 0.7]); light /= np.linalg.norm(light)
    for k, (elev, az) in enumerate([(5, -90), (5, 0), (5, 90), (10, -60)]):
        ax = fig.add_subplot(1, 4, k + 1, projection="3d")
        tri = verts[faces]
        fn = n[faces].mean(1)
        rg = reg[faces[:, 0]]
        shade = np.clip(fn @ light, 0.15, 1) * occ[faces].mean(1)
        c = np.array([pal[int(r)] for r in rg]) * shade[:, None]
        pc = Poly3DCollection(tri[:, :, [0, 2, 1]], facecolors=np.clip(c, 0, 1), edgecolor="none")
        ax.add_collection3d(pc)
        ax.set_xlim(-0.5, 0.5); ax.set_ylim(-0.5, 0.5); ax.set_zlim(0, 1.9)
        ax.set_box_aspect((1, 1, 1.9))
        ax.view_init(elev, az)
        ax.axis("off")
    plt.tight_layout()
    plt.savefig(path)


if __name__ == "__main__":
    import sys
    for kp in (False, True):
        v, f, r, o, nn = build(kp)
        if "--preview" in sys.argv:
            preview(v, f, r, o, nn, f"/tmp/claude-0/char_{'keeper' if kp else 'player'}.png")
