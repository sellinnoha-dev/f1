"""
Tsunami Critters : fabrique les modèles 3D des créatures (fichier .glb pour Roblox Studio).

Chaque créature est décrite par des formes (sphères, capsules, boîtes arrondies...)
fondues ensemble comme de la pâte à modeler, puis transformée en vrai maillage 3D lisse.

Lancer :  python3 tools/creatures/make_creatures.py
Résultat : models/TsunamiCritters.glb (toutes les créatures) + models/preview.png
"""

import math
import os
import sys

import numpy as np
import trimesh
from PIL import Image, ImageDraw, ImageFont
from skimage import measure
import fast_simplification

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "models")

# ----------------------------------------------------------------------------
# Formes de base (distance signée : négatif = dedans)
# ----------------------------------------------------------------------------


def sphere(c, r):
    c = np.array(c, float)
    return lambda p: np.linalg.norm(p - c, axis=-1) - r


def ellipsoid(c, radii):
    c = np.array(c, float)
    radii = np.array(radii, float)

    def f(p):
        q = (p - c) / radii
        k0 = np.linalg.norm(q, axis=-1)
        k1 = np.linalg.norm(q / radii, axis=-1)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)

    return f


def capsule(a, b, r):
    a = np.array(a, float)
    b = np.array(b, float)
    ab = b - a

    def f(p):
        t = np.clip(((p - a) @ ab) / (ab @ ab), 0.0, 1.0)
        return np.linalg.norm(p - (a + t[..., None] * ab), axis=-1) - r

    return f


def cone(a, b, ra, rb):
    """Tronc de cône arrondi entre a (rayon ra) et b (rayon rb)."""
    a = np.array(a, float)
    b = np.array(b, float)
    ab = b - a
    length = np.linalg.norm(ab)

    def f(p):
        t = np.clip(((p - a) @ ab) / (ab @ ab), 0.0, 1.0)
        r = ra + (rb - ra) * t
        return np.linalg.norm(p - (a + t[..., None] * ab), axis=-1) - r

    return f


def rounded_box(c, half, r, rot=None):
    c = np.array(c, float)
    half = np.array(half, float)

    def f(p):
        q = p - c
        if rot is not None:
            q = q @ rot
        q = np.abs(q) - (half - r)
        return np.linalg.norm(np.maximum(q, 0.0), axis=-1) + np.minimum(np.max(q, axis=-1), 0.0) - r

    return f


def torus(c, big, small, axis="y"):
    c = np.array(c, float)

    def f(p):
        q = p - c
        if axis == "y":
            x, y, z = q[..., 0], q[..., 1], q[..., 2]
        elif axis == "z":
            x, y, z = q[..., 0], q[..., 2], q[..., 1]
        else:
            x, y, z = q[..., 1], q[..., 0], q[..., 2]
        return np.sqrt((np.sqrt(x * x + z * z) - big) ** 2 + y * y) - small

    return f


def rot_z(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])


def rot_x(deg):
    a = math.radians(deg)
    return np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


# ----------------------------------------------------------------------------
# Une créature = une liste de pièces (forme, couleur, douceur de la soudure)
# ----------------------------------------------------------------------------


class Critter:
    def __init__(self, name):
        self.name = name
        self.parts = []  # (sdf, color, blend, bounds_center, bounds_radius)

    def add(self, sdf, color, center, radius, blend=0.0):
        self.parts.append((sdf, tuple(int(v) for v in color), blend, np.array(center, float), radius))

    def bounds(self):
        lo = np.min([c - r for _, _, _, c, r in self.parts], axis=0) - 0.15
        hi = np.max([c + r for _, _, _, c, r in self.parts], axis=0) + 0.15
        return lo, hi

    def field(self, p):
        d = None
        for sdf, _, blend, _, _ in self.parts:
            v = sdf(p)
            d = v if d is None else smin(d, v, blend)
        return d

    def colors_at(self, p):
        values = np.stack([sdf(p) for sdf, _, _, _, _ in self.parts], axis=-1)
        return np.argmin(values, axis=-1)


DARK = (28, 28, 34)
WHITE = (250, 250, 250)
GOLD = (255, 200, 40)
MOUTH = (90, 25, 30)


def build(name, body, size, color, accent, eyes, extras):
    """Même idée que buildCreature dans le jeu, mais en vraie 3D lisse."""
    s = size
    c = Critter(name)
    extras = set(extras)
    # Corps
    if body == "block":
        h = s * 0.9
        c.add(rounded_box((0, h / 2, 0), (s / 2, h / 2, s * 0.4), s * 0.18), color, (0, h / 2, 0), s * 0.75)
        front = -s * 0.4
    elif body == "cylinder":
        h = s * 1.3
        c.add(capsule((0, s * 0.4, 0), (0, h - s * 0.4, 0), s * 0.4), color, (0, h / 2, 0), h * 0.6)
        front = -s * 0.4
    else:
        h = s
        c.add(ellipsoid((0, h * 0.5, 0), (s * 0.52, s * 0.5, s * 0.48)), color, (0, h / 2, 0), s * 0.55)
        front = -s * 0.46
    top = h
    eye_y = h * 0.62
    eye_x = {1: [0.0], 2: [-0.2, 0.2], 3: [-0.27, 0.0, 0.27]}[max(1, min(3, eyes))]

    # Yeux : blanc + pupille + reflet
    for x in eye_x:
        z = front + s * 0.03
        c.add(sphere((x * s, eye_y, z), s * 0.15), WHITE, (x * s, eye_y, z), s * 0.16)
        c.add(sphere((x * s, eye_y, z - s * 0.1), s * 0.08), DARK, (x * s, eye_y, z - s * 0.1), s * 0.09)
        c.add(sphere((x * s + s * 0.03, eye_y + s * 0.04, z - s * 0.16), s * 0.025), WHITE,
              (x * s, eye_y, z - s * 0.16), s * 0.03)
    # Bouche souriante : un arc de petites capsules
    points = []
    for i in range(7):
        t = -1 + i / 3
        points.append((t * s * 0.13, h * 0.36 + (t * t) * s * 0.06, front - s * 0.01 + abs(t) * s * 0.02))
    for a, b in zip(points, points[1:]):
        c.add(capsule(a, b, s * 0.028), MOUTH, (0, h * 0.38, front), s * 0.18)
    # Joues roses
    for side in (-1, 1):
        c.add(sphere((side * s * 0.33, h * 0.45, front + s * 0.08), s * 0.07), (255, 140, 160),
              (side * s * 0.33, h * 0.45, front), s * 0.08)

    if "antenna" in extras:
        c.add(capsule((0, top - s * 0.05, 0), (s * 0.1, top + s * 0.45, 0), s * 0.03), DARK, (0, top + s * 0.2, 0), s * 0.3)
        c.add(sphere((s * 0.1, top + s * 0.5, 0), s * 0.1), accent, (s * 0.1, top + s * 0.5, 0), s * 0.11)
        top += s * 0.55
    if "feet" in extras:
        for side in (-1, 1):
            c.add(ellipsoid((side * s * 0.22, s * 0.06, -s * 0.12), (s * 0.15, s * 0.08, s * 0.2)), accent,
                  (side * s * 0.22, s * 0.06, -s * 0.12), s * 0.2, blend=s * 0.04)
    if "mustache" in extras:
        for side in (-1, 1):
            c.add(capsule((side * s * 0.03, h * 0.46, front - s * 0.05), (side * s * 0.22, h * 0.5, front - s * 0.02), s * 0.045),
                  DARK, (side * s * 0.12, h * 0.48, front), s * 0.15)
    if "brows" in extras:
        for x in eye_x:
            side = -1 if x < 0 else (1 if x > 0 else 0)
            c.add(capsule((x * s - s * 0.1, eye_y + s * 0.15 - side * s * 0.03, front - s * 0.04),
                          (x * s + s * 0.1, eye_y + s * 0.15 + side * s * 0.03, front - s * 0.04), s * 0.03),
                  DARK, (x * s, eye_y + s * 0.15, front), s * 0.13)
    if "shades" in extras:
        width = 0.5 if len(eye_x) == 3 else 0.38
        c.add(rounded_box((0, eye_y, front - s * 0.15), (s * width, s * 0.09, s * 0.03), s * 0.03), DARK,
              (0, eye_y, front - s * 0.15), s * 0.5)
    if "headband" in extras:
        c.add(torus((0, h * 0.84, 0), s * 0.4, s * 0.05), accent, (0, h * 0.84, 0), s * 0.46)
        c.add(capsule((0, h * 0.84, s * 0.4), (s * 0.15, h * 0.7, s * 0.65), s * 0.04), accent, (0, h * 0.8, s * 0.5), s * 0.25)
    if "tophat" in extras:
        c.add(capsule((0, top, 0), (0, top + 0.001, 0), s * 0.42), DARK if accent == DARK else accent,
              (0, top, 0), s * 0.45)
        c.add(rounded_box((0, top + s * 0.25, 0), (s * 0.24, s * 0.25, s * 0.24), s * 0.08), accent, (0, top + s * 0.25, 0), s * 0.4)
        c.add(torus((0, top + s * 0.08, 0), s * 0.24, s * 0.035), (220, 40, 50), (0, top + s * 0.08, 0), s * 0.28)
        top += s * 0.5
    if "wizardhat" in extras:
        c.add(torus((0, top - s * 0.02, 0), s * 0.32, s * 0.06), accent, (0, top, 0), s * 0.4)
        c.add(cone((0, top - s * 0.05, 0), (s * 0.12, top + s * 0.8, s * 0.1), s * 0.3, s * 0.02), accent,
              (0, top + s * 0.38, 0), s * 0.5)
        c.add(sphere((s * 0.12, top + s * 0.82, s * 0.1), s * 0.07), GOLD, (s * 0.12, top + s * 0.82, s * 0.1), s * 0.08)
        top += s * 0.85
    if "crown" in extras:
        c.add(cone((0, top - s * 0.05, 0), (0, top + s * 0.15, 0), s * 0.26, s * 0.3), GOLD, (0, top + s * 0.05, 0), s * 0.35)
        for i in range(5):
            a = i / 5 * math.tau
            px, pz = math.cos(a) * s * 0.26, math.sin(a) * s * 0.26
            c.add(cone((px, top + s * 0.1, pz), (px * 1.05, top + s * 0.38, pz * 1.05), s * 0.06, s * 0.015), GOLD,
                  (px, top + s * 0.24, pz), s * 0.17)
        c.add(sphere((0, top + s * 0.06, -s * 0.29), s * 0.06), (230, 30, 60), (0, top + s * 0.06, -s * 0.29), s * 0.07)
        top += s * 0.38
    if "propeller" in extras:
        c.add(capsule((0, top - s * 0.05, 0), (0, top + s * 0.22, 0), s * 0.035), DARK, (0, top + s * 0.1, 0), s * 0.2)
        for angle in (0, 90):
            a = math.radians(angle)
            d = np.array([math.cos(a), 0, math.sin(a)]) * s * 0.5
            p = np.array([0, top + s * 0.24, 0])
            c.add(capsule(p - d, p + d, s * 0.05), accent, p, s * 0.55)
        top += s * 0.3
    if "shell" in extras:
        c.add(sphere((0, h * 0.62, s * 0.4), s * 0.42), accent, (0, h * 0.62, s * 0.4), s * 0.43, blend=s * 0.05)
        c.add(torus((s * 0.38, h * 0.62, s * 0.4), s * 0.16, s * 0.05, axis="x"), WHITE, (s * 0.38, h * 0.62, s * 0.4), s * 0.22)
        for side in (-1, 1):
            c.add(capsule((side * s * 0.15, h * 0.35, s * 0.75), (side * s * 0.15, h * 0.35, s * 0.98), s * 0.07),
                  (190, 190, 200), (side * s * 0.15, h * 0.35, s * 0.86), s * 0.15)
    if "cape" in extras:
        c.add(rounded_box((0, h * 0.45, s * 0.5), (s * 0.45, h * 0.42, s * 0.03), s * 0.03, rot=rot_x(12)), accent,
              (0, h * 0.45, s * 0.5), h * 0.6)
        c.add(sphere((0, h * 0.86, s * 0.42), s * 0.08), GOLD, (0, h * 0.86, s * 0.42), s * 0.09)
    if "wings" in extras:
        for side in (-1, 1):
            base = np.array([side * s * 0.4, h * 0.6, s * 0.2])
            tip = base + np.array([side * s * 0.55, s * 0.35, s * 0.15])
            c.add(ellipsoid((base + tip) / 2, (s * 0.33, s * 0.2, s * 0.05)), WHITE, (base + tip) / 2, s * 0.4,
                  blend=s * 0.03)
    if "horns" in extras:
        for side in (-1, 1):
            c.add(cone((side * s * 0.2, h * 0.9, 0), (side * s * 0.38, h + s * 0.32, -s * 0.05), s * 0.09, s * 0.015), accent,
                  (side * s * 0.3, h + s * 0.1, 0), s * 0.3)
    if "halo" in extras:
        c.add(torus((0, top + s * 0.28, 0), s * 0.3, s * 0.045), (255, 240, 120), (0, top + s * 0.28, 0), s * 0.36)
        top += s * 0.35
    if "staff" in extras:
        c.add(capsule((s * 0.7, 0.02, -s * 0.1), (s * 0.7, h * 1.35, -s * 0.1), s * 0.05), (120, 80, 45),
              (s * 0.7, h * 0.7, -s * 0.1), h * 0.7)
        c.add(sphere((s * 0.7, h * 1.4, -s * 0.1), s * 0.15), accent, (s * 0.7, h * 1.4, -s * 0.1), s * 0.16)
    if "monocle" in extras:
        x = eye_x[-1] * s
        c.add(torus((x, eye_y, front - s * 0.13), s * 0.15, s * 0.025, axis="z"), GOLD, (x, eye_y, front - s * 0.13), s * 0.2)
    if "tail" in extras:
        c.add(cone((0, h * 0.3, s * 0.35), (0, h * 0.45, s * 0.95), s * 0.12, s * 0.04), color, (0, h * 0.38, s * 0.65), s * 0.4,
              blend=s * 0.05)
        c.add(sphere((0, h * 0.47, s * 0.98), s * 0.1), accent, (0, h * 0.47, s * 0.98), s * 0.11)
    if "flames" in extras:
        for i, off in enumerate((-0.12, 0.0, 0.12)):
            c.add(cone((off * s, h * 0.35, s * 0.45), (off * s, h * (0.75 + 0.1 * (i == 1)), s * 0.75), s * 0.1, s * 0.01),
                  (255, 140 + 40 * i, 30), (off * s, h * 0.55, s * 0.6), s * 0.35)
    if "orbit" in extras:
        c.add(torus((0, h * 0.25, 0), s * 0.82, s * 0.025), accent, (0, h * 0.25, 0), s * 0.86)
        for i in range(4):
            a = i / 4 * math.tau + 0.4
            p = (math.cos(a) * s * 0.82, h * 0.25, math.sin(a) * s * 0.82)
            c.add(sphere(p, s * 0.09), accent, p, s * 0.1)
    return c


# ----------------------------------------------------------------------------
# Maillage : surface lisse, couleurs par palette, export .glb
# ----------------------------------------------------------------------------


def mesh_critter(critter, palette, resolution=140, max_faces=15000):
    lo, hi = critter.bounds()
    step = float(np.max(hi - lo)) / resolution
    xs = np.arange(lo[0], hi[0] + step, step)
    ys = np.arange(lo[1], hi[1] + step, step)
    zs = np.arange(lo[2], hi[2] + step, step)
    grid = np.stack(np.meshgrid(xs, ys, zs, indexing="ij"), axis=-1)
    values = critter.field(grid.reshape(-1, 3)).reshape(grid.shape[:3])
    verts, faces, _, _ = measure.marching_cubes(values, 0.0, spacing=(step, step, step))
    verts += lo
    faces = faces[:, ::-1]  # faces tournées vers l'extérieur
    if len(faces) > max_faces:
        verts, faces = fast_simplification.simplify(verts.astype(np.float32), faces.astype(np.int64),
                                                    target_reduction=1 - max_faces / len(faces))
    # Normales lisses : pente de la surface
    eps = step * 0.5
    grad = np.stack([
        critter.field(verts + np.array([eps, 0, 0])) - critter.field(verts - np.array([eps, 0, 0])),
        critter.field(verts + np.array([0, eps, 0])) - critter.field(verts - np.array([0, eps, 0])),
        critter.field(verts + np.array([0, 0, eps])) - critter.field(verts - np.array([0, 0, eps])),
    ], axis=-1)
    normals = grad / np.maximum(np.linalg.norm(grad, axis=-1, keepdims=True), 1e-9)

    # Couleur de chaque triangle = pièce la plus proche de son centre
    centers = verts[faces].mean(axis=1)
    owner = critter.colors_at(centers)
    face_colors = [critter.parts[i][1] for i in owner]

    # On duplique les sommets entre deux couleurs pour garder des bords nets
    new_verts, new_normals, new_uvs, new_faces, key_to_index = [], [], [], [], {}
    for f, color in zip(faces, face_colors):
        if color not in palette:
            palette[color] = len(palette)
        tri = []
        for v in f:
            key = (int(v), color)
            index = key_to_index.get(key)
            if index is None:
                index = len(new_verts)
                key_to_index[key] = index
                new_verts.append(verts[v])
                new_normals.append(normals[v])
                new_uvs.append(palette_uv(palette[color]))
            tri.append(index)
        new_faces.append(tri)
    return (np.array(new_verts), np.array(new_faces), np.array(new_normals), np.array(new_uvs),
            [critter.parts[i][1] for i in owner])


PALETTE_CELLS = 16  # 16 x 16 couleurs
CELL = 8  # pixels par couleur


def palette_uv(index):
    cx, cy = index % PALETTE_CELLS, index // PALETTE_CELLS
    u = (cx + 0.5) / PALETTE_CELLS
    v = 1 - (cy + 0.5) / PALETTE_CELLS
    return (u, v)


def palette_image(palette):
    image = Image.new("RGB", (PALETTE_CELLS * CELL, PALETTE_CELLS * CELL), (255, 0, 255))
    draw = ImageDraw.Draw(image)
    for color, index in palette.items():
        cx, cy = index % PALETTE_CELLS, index // PALETTE_CELLS
        draw.rectangle([cx * CELL, cy * CELL, cx * CELL + CELL - 1, cy * CELL + CELL - 1], fill=color)
    return image


# ----------------------------------------------------------------------------
# Aperçu : petit rendu logiciel (z-buffer) pour vérifier sans Roblox
# ----------------------------------------------------------------------------


def render(verts, faces, normals, colors, size=320):
    image = np.zeros((size, size, 3), float)
    image[:] = (0.16, 0.2, 0.3)
    depth = np.full((size, size), np.inf)
    # Caméra : vue de face un peu de côté et d'en haut (la créature regarde vers -Z)
    yaw, pitch = math.radians(-22), math.radians(12)
    ry = np.array([[math.cos(yaw), 0, math.sin(yaw)], [0, 1, 0], [-math.sin(yaw), 0, math.cos(yaw)]])
    rx = np.array([[1, 0, 0], [0, math.cos(pitch), -math.sin(pitch)], [0, math.sin(pitch), math.cos(pitch)]])
    rot = rx @ ry
    p = verts @ rot.T
    n = normals @ rot.T
    center = (p.max(axis=0) + p.min(axis=0)) / 2
    scale = 0.8 * size / np.max(p.max(axis=0)[:2] - p.min(axis=0)[:2])
    sx = (p[:, 0] - center[0]) * scale + size / 2
    sy = size / 2 - (p[:, 1] - center[1]) * scale
    sz = p[:, 2]
    light = np.array([-0.4, 0.7, -0.6])
    light /= np.linalg.norm(light)
    for f, color in zip(faces, colors):
        a, b, c = f
        x0, x1, x2 = sx[a], sx[b], sx[c]
        y0, y1, y2 = sy[a], sy[b], sy[c]
        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        if abs(area) < 1e-9:
            continue
        minx, maxx = int(max(min(x0, x1, x2), 0)), int(min(max(x0, x1, x2) + 1, size))
        miny, maxy = int(max(min(y0, y1, y2), 0)), int(min(max(y0, y1, y2) + 1, size))
        if minx >= maxx or miny >= maxy:
            continue
        gx, gy = np.meshgrid(np.arange(minx, maxx) + 0.5, np.arange(miny, maxy) + 0.5)
        w0 = ((x1 - gx) * (y2 - gy) - (x2 - gx) * (y1 - gy)) / area
        w1 = ((x2 - gx) * (y0 - gy) - (x0 - gx) * (y2 - gy)) / area
        w2 = 1 - w0 - w1
        inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        if not inside.any():
            continue
        z = w0 * sz[a] + w1 * sz[b] + w2 * sz[c]
        nn = w0[..., None] * n[a] + w1[..., None] * n[b] + w2[..., None] * n[c]
        nn /= np.maximum(np.linalg.norm(nn, axis=-1, keepdims=True), 1e-9)
        shade = 0.62 + 0.5 * np.clip(-(nn @ light), 0, 1)
        sub = depth[miny:maxy, minx:maxx]
        closer = inside & (z < sub)
        sub[closer] = z[closer]
        rgb = np.array(color, float) / 255
        image[miny:maxy, minx:maxx][closer] = np.clip(rgb * shade[closer][..., None], 0, 1)
    return Image.fromarray((image * 255).astype(np.uint8))


# ----------------------------------------------------------------------------
# Les créatures du jeu (mêmes noms que dans Config.luau)
# ----------------------------------------------------------------------------

C = lambda r, g, b: (r, g, b)  # noqa: E731

CRITTERS = [
    ("Bloop", "ball", 3, C(90, 200, 90), C(255, 230, 0), 2, ["antenna", "feet"]),
    ("Toasty", "block", 3, C(225, 180, 110), C(140, 90, 40), 2, ["feet", "brows"]),
    ("Pebble Pete", "ball", 3.2, C(150, 150, 155), C(60, 40, 30), 1, ["mustache", "feet"]),
    ("Captain Noodle", "cylinder", 3.2, C(250, 220, 100), C(30, 30, 35), 2, ["tophat", "mustache"]),
    ("Disco Potato", "ball", 3.4, C(170, 120, 70), C(255, 80, 200), 2, ["shades", "feet", "antenna"]),
    ("Grumpy Cloud", "ball", 3.6, C(240, 240, 250), C(80, 80, 100), 2, ["brows", "wings"]),
    ("Rocket Frog", "ball", 3.6, C(40, 160, 70), C(255, 90, 30), 2, ["propeller", "feet"]),
    ("Banana Ninja", "cylinder", 3.4, C(255, 225, 60), C(220, 30, 40), 2, ["headband", "brows", "feet"]),
    ("Cactus Cowboy", "cylinder", 3.6, C(60, 140, 70), C(130, 80, 40), 2, ["tophat", "mustache"]),
    ("Sir Wobbleton", "ball", 4.6, C(140, 70, 200), C(200, 30, 50), 2, ["crown", "mustache", "monocle", "cape", "feet"]),
    ("Pizza Wizard", "block", 4.4, C(240, 150, 50), C(60, 50, 180), 2, ["wizardhat", "brows", "staff", "cape"]),
    ("Turbo Snail", "ball", 4.4, C(120, 220, 200), C(255, 90, 30), 2, ["shell", "antenna", "shades", "flames"]),
    ("Lord Spaghetti", "cylinder", 5, C(250, 210, 120), C(200, 30, 30), 2, ["crown", "wings", "mustache", "cape", "staff"]),
    ("Cosmic Toast", "block", 5, C(80, 60, 160), C(0, 230, 255), 3, ["halo", "wings", "orbit"]),
    ("Dragon Pickle", "cylinder", 5.2, C(90, 170, 50), C(255, 120, 0), 2, ["horns", "wings", "brows", "tail", "flames"]),
    ("The Golden Duck", "ball", 5.5, C(255, 200, 30), C(255, 120, 0), 2, ["crown", "halo", "feet", "cape", "orbit"]),
    ("Glitch Cat", "block", 5.5, C(35, 35, 50), C(0, 255, 120), 3, ["horns", "antenna", "shades", "tail", "orbit"]),
    ("King Bloop", "ball", 6, C(0, 230, 200), C(255, 215, 0), 2, ["crown", "wings", "halo", "feet", "cape", "staff"]),
    ("Prism Prince", "ball", 6.5, C(235, 235, 255), C(255, 120, 255), 3, ["crown", "wings", "halo", "cape", "orbit", "staff"]),
    ("Astral Noodle", "cylinder", 6.5, C(60, 35, 130), C(255, 230, 120), 2, ["horns", "wings", "halo", "mustache", "tail", "flames", "orbit"]),
]


def main():
    only = sys.argv[1:]
    os.makedirs(OUT, exist_ok=True)
    palette = {}
    scene = trimesh.Scene()
    previews = []
    built = []
    for i, (name, body, size, color, accent, eyes, extras) in enumerate(CRITTERS):
        if only and name not in only:
            continue
        critter = build(name, body, size, color, accent, eyes, extras)
        verts, faces, normals, uvs, colors = mesh_critter(critter, palette)
        print(f"{name}: {len(faces)} triangles")
        built.append((name, verts, faces, normals, uvs))
        previews.append((name, render(verts, faces, normals, colors)))

    texture = palette_image(palette)
    texture.save(os.path.join(OUT, "palette.png"))
    for i, (name, verts, faces, normals, uvs) in enumerate(built):
        material = trimesh.visual.material.PBRMaterial(baseColorTexture=texture, metallicFactor=0.0, roughnessFactor=0.7)
        visual = trimesh.visual.TextureVisuals(uv=uvs, material=material)
        mesh = trimesh.Trimesh(vertices=verts, faces=faces, vertex_normals=normals, visual=visual, process=False)
        # Chaque créature est rangée à côté de la précédente (le jeu les replace de toute façon)
        transform = trimesh.transformations.translation_matrix([i * 10.0, 0, 0])
        scene.add_geometry(mesh, node_name=name, geom_name=name, transform=transform)
        single = trimesh.Scene()
        single.add_geometry(mesh, node_name=name, geom_name=name)
        single.export(os.path.join(OUT, "critters", name.replace(" ", "") + ".glb")) if os.makedirs(
            os.path.join(OUT, "critters"), exist_ok=True) is None else None
    scene.export(os.path.join(OUT, "TsunamiCritters.glb"))

    # Planche d'aperçu
    cols = 5
    rows = math.ceil(len(previews) / cols)
    sheet = Image.new("RGB", (cols * 320, rows * 350), (25, 30, 45))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
    except OSError:
        font = ImageFont.load_default()
    for i, (name, image) in enumerate(previews):
        x, y = (i % cols) * 320, (i // cols) * 350
        sheet.paste(image, (x, y))
        draw.text((x + 10, y + 322), name, fill=(255, 255, 255), font=font)
    sheet.save(os.path.join(OUT, "preview.png"))
    print("OK ->", OUT)


if __name__ == "__main__":
    main()
