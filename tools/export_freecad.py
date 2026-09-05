"""FreeCAD bundled Python: export saved CAD solids as a self-contained glTF."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import struct
import traceback
import FreeCAD as App

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/cad/prototype_02/Formula_Prototype_02.FCStd'
OUTPUT = ROOT / 'formula_simulator/assets/vehicles/prototype_02.gltf'


def export(source, output):
    source_bytes = source.read_bytes()
    doc = App.openDocument(str(source))
    data = bytearray()
    gltf = dict(asset={'version': '2.0', 'generator': 'Formula CAD bridge'},
                scene=0, scenes=[{'nodes': []}], nodes=[], meshes=[], materials=[],
                buffers=[], bufferViews=[], accessors=[])

    def accessor(values):
        flat = [v for xyz in values for v in xyz]
        start = len(data)
        data.extend(struct.pack('<%sf' % len(flat), *flat))
        view = len(gltf['bufferViews'])
        gltf['bufferViews'].append(dict(buffer=0, byteOffset=start, byteLength=len(data)-start))
        index = len(gltf['accessors'])
        gltf['accessors'].append(dict(bufferView=view, componentType=5126, count=len(values),
            type='VEC3', min=[min(v[i] for v in values) for i in range(3)],
            max=[max(v[i] for v in values) for i in range(3)]))
        return index

    triangles = 0
    for obj in doc.Objects:
        if not hasattr(obj, 'Shape') or obj.Shape.isNull():
            continue
        if not obj.Shape.isValid():
            raise ValueError('Invalid CAD shape: ' + obj.Name)
        vertices, faces = obj.Shape.tessellate(2.0)
        positions, normals = [], []
        for face in faces:
            # CAD mm / Z up -> metres / Y up. Nose is negative Godot Z.
            p = [App.Vector(-vertices[i].y/1000, vertices[i].z/1000,
                            (vertices[i].x-2250)/1000) for i in (face[0], face[2], face[1])]
            # The axis mapping reflects handedness: reverse winding for outward normals.
            normal = (p[1]-p[0]).cross(p[2]-p[0])
            if normal.Length < 1e-12:
                continue
            normal.normalize()
            positions.extend([tuple(v) for v in p])
            normals.extend([tuple(normal)] * 3)
        if not positions:
            continue
        color = [0.12, 0.32, 0.65, 1]
        if 'Tire' in obj.Name:
            color = [0.035, 0.035, 0.04, 1]
        elif 'Rim' in obj.Name:
            color = [0.55, 0.58, 0.63, 1]
        elif any(s in obj.Name for s in ['Floor', 'Seat', 'Upper', 'Lower', 'main', 'support', 'hoop']):
            color = [0.08, 0.09, 0.12, 1]
        index = len(gltf['nodes'])
        gltf['materials'].append({'pbrMetallicRoughness': {'baseColorFactor': color,
            'metallicFactor': 0.1, 'roughnessFactor': 0.7}})
        gltf['meshes'].append({'name': obj.Name, 'primitives': [{'attributes': {
            'POSITION': accessor(positions), 'NORMAL': accessor(normals)}, 'material': index}]})
        gltf['nodes'].append({'name': obj.Name, 'mesh': index})
        gltf['scenes'][0]['nodes'].append(index)
        triangles += len(positions)//3
    if not gltf['nodes']:
        raise ValueError('CAD document contains no exportable shapes')
    if source.read_bytes() != source_bytes:
        raise RuntimeError('CAD file changed during export; save and retry')
    gltf['buffers'] = [{'byteLength': len(data), 'uri':
        'data:application/octet-stream;base64,' + base64.b64encode(data).decode()}]
    gltf['extras'] = {'source_sha256': hashlib.sha256(source_bytes).hexdigest(),
                     'parts': len(gltf['nodes']), 'triangles': triangles}
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix('.tmp')
    temporary.write_text(json.dumps(gltf, separators=(',', ':')), encoding='utf-8')
    os.replace(temporary, output)
    App.closeDocument(doc.Name)
    return gltf['extras']


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=SOURCE)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--status', type=Path)
    args = parser.parse_args()
    try:
        result = dict(ok=True, **export(args.source, args.output))
    except Exception:
        result = dict(ok=False, error=traceback.format_exc())
    if args.status:
        args.status.write_text(json.dumps(result), encoding='utf-8')
    print(json.dumps(result))
    raise SystemExit(0 if result['ok'] else 1)
