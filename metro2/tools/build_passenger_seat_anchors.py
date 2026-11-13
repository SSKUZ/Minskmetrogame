#!/usr/bin/env python3
"""Read merged original GLB upholstery and save physical cushion anchors.
No geometry modification, engine launch or game/visual test.
"""
import hashlib,itertools,json,struct
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
MODELS=['assets/v106_lod1/v106_car01_lod1_mesh289_normals_fixed.glb','assets/v106_original/car02/v106_car_02.glb','assets/v106_original/car03/v106_car_03.glb','assets/v106_original/car04/v106_car_04.glb']
result={'source':'Horizontal cushion surfaces of the original merged V106 upholstery','cars':{}}
for number,name in enumerate(MODELS,1):
    raw=(ROOT/name).read_bytes();jlen=struct.unpack_from('<I',raw,12)[0]
    gltf=json.loads(raw[20:20+jlen]);binary=raw[28+jlen:]
    def accessor(index):
        a=gltf['accessors'][index];view=gltf['bufferViews'][a['bufferView']]
        dtype=np.dtype({5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']])
        width={'SCALAR':1,'VEC3':3}[a['type']]
        return np.ndarray((a['count'],width),dtype=dtype,buffer=binary,offset=view.get('byteOffset',0)+a.get('byteOffset',0),strides=(view.get('byteStride',width*dtype.itemsize),dtype.itemsize)).copy()
    surfaces={-1:[],1:[]}
    def walk(index,parent):
        node=gltf['nodes'][index]
        transform=np.array(node.get('matrix',np.eye(4).T.flatten())).reshape(4,4).T
        world=parent@transform
        if 'mesh' in node:
            for primitive in gltf['meshes'][node['mesh']]['primitives']:
                material=gltf['materials'][primitive.get('material',0)]
                color=material.get('pbrMetallicRoughness',{}).get('baseColorFactor',[1,1,1,1])
                if abs(color[0]-.0295568)>.006 or abs(color[2]-.0953075)>.006:continue
                vertices=accessor(primitive['attributes']['POSITION'])
                vertices=(np.c_[vertices,np.ones(len(vertices))]@world.T)[:,:3]
                indices=accessor(primitive['indices']).reshape(-1,3)
                triangles=vertices[indices]
                normals=np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0])
                lengths=np.linalg.norm(normals,axis=1)
                up=np.abs(normals[:,1])/np.maximum(lengths,1e-12)
                centers=triangles.mean(axis=1)
                mask=(up>.95)&(centers[:,1]>1.43)&(centers[:,1]<1.65)&(np.abs(centers[:,0])>.65)&(np.abs(centers[:,0])<1.25)
                for triangle,center in zip(triangles[mask],centers[mask]):
                    surfaces[-1 if center[0]<0 else 1].append(triangle)
        for child in node.get('children',[]):walk(child,world)
    for index in gltf['scenes'][gltf.get('scene',0)]['nodes']:walk(index,np.eye(4))
    anchors=[]
    for side,triangles in surfaces.items():
        intervals=sorted(((float(t[:,2].min()),float(t[:,2].max()),t) for t in triangles),key=lambda item:(item[0],item[1]))
        benches=[]
        for lo,hi,t in intervals:
            if not benches or lo>benches[-1]['hi']+.10:benches.append({'lo':lo,'hi':hi,'triangles':[t]})
            else:benches[-1]['hi']=max(benches[-1]['hi'],hi);benches[-1]['triangles'].append(t)
        for bench in benches:
            span=bench['hi']-bench['lo']
            if span<.38:continue
            points=np.concatenate(bench['triangles'])
            x=float((points[:,0].min()+points[:,0].max())*.5)
            height=float(np.median(points[:,1]))
            count=max(1,int((span+.02)/.54))
            for k in range(count):
                z=bench['lo']+(k+.5)*span/count
                anchors.append({'position':[round(x,4),1.033,round(z,4)],'height':round(height,4),'heading':round(-np.pi/2 if side>0 else np.pi/2,6)})
    result['cars'][f'OriginalV106Car{number:02d}']={'model':name,'sha256':hashlib.sha256(raw).hexdigest(),'seats':anchors}
out=ROOT/'modules/passengers/v106_seats.json'
out.write_text(json.dumps(result,indent=2)+'\n')
print('Original cushion anchors:',{name:len(info['seats']) for name,info in result['cars'].items()})
