#!/usr/bin/env python3
"""Experimental UV/normal-aware LOD for a single mesh in a full GLB.
Requires numpy, vtk. Appends buffers (NOT size-optimized); never replace original.
Usage: python v106_lod1_preserve_material.py in.glb out.glb [mesh=289] [reduction=.25]
"""
import sys,json,struct
import numpy as np,vtk
from vtk.util.numpy_support import numpy_to_vtk,numpy_to_vtkIdTypeArray,vtk_to_numpy
source,out=sys.argv[1:3];mi=int(sys.argv[3]) if len(sys.argv)>3 else 289
fraction=float(sys.argv[4]) if len(sys.argv)>4 else .25
assert 0<fraction<.6
raw=open(source,'rb').read();assert raw[:4]==b'glTF'
n=struct.unpack_from('<I',raw,12)[0];d=json.loads(raw[20:20+n]);offset=20+n
buf=bytearray(raw[offset+8:offset+8+struct.unpack_from('<I',raw,offset)[0]])
assert len(d['buffers'])==1
def get(i):
 a=d['accessors'][i];v=d['bufferViews'][a['bufferView']]
 dtype=np.dtype({5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']])
 dim={'SCALAR':1,'VEC2':2,'VEC3':3}[a['type']]
 return np.ndarray((a['count'],dim),dtype=dtype,buffer=raw,
 offset=offset+8+v.get('byteOffset',0)+a.get('byteOffset',0),
 strides=(v.get('byteStride',dim*dtype.itemsize),dtype.itemsize)).copy()
p=d['meshes'][mi]['primitives'];assert len(p)==1;p=p[0]
assert p.get('mode',4)==4 and set(p['attributes'])=={'POSITION','NORMAL','TEXCOORD_0'}
xyz=get(p['attributes']['POSITION']).astype('float64')
normal=get(p['attributes']['NORMAL']).astype('float64')
uv=get(p['attributes']['TEXCOORD_0']).astype('float64')
faces=get(p['indices']).reshape(-1,3).astype('int64')
mesh=vtk.vtkPolyData();points=vtk.vtkPoints();points.SetData(numpy_to_vtk(xyz,deep=True));mesh.SetPoints(points)
cells=vtk.vtkCellArray();cells.SetCells(len(faces),numpy_to_vtkIdTypeArray(
 np.column_stack((np.full(len(faces),3,dtype='int64'),faces)).ravel(),deep=True))
mesh.SetPolys(cells);mesh.GetPointData().SetNormals(numpy_to_vtk(normal,deep=True))
mesh.GetPointData().SetTCoords(numpy_to_vtk(uv,deep=True))
dec=vtk.vtkQuadricDecimation();dec.SetInputData(mesh);dec.SetTargetReduction(fraction)
dec.AttributeErrorMetricOn();dec.NormalsAttributeOn();dec.TCoordsAttributeOn()
dec.SetTCoordsWeight(10.0);dec.Update();r=dec.GetOutput()
P=vtk_to_numpy(r.GetPoints().GetData()).astype('<f4')
N=vtk_to_numpy(r.GetPointData().GetNormals()).astype('<f4')
U=vtk_to_numpy(r.GetPointData().GetTCoords()).astype('<f4')
I=vtk_to_numpy(r.GetPolys().GetData()).reshape(-1,4)[:,1:].astype('<u4').reshape(-1,1)
def append(a,typ,component,target):
 buf.extend(b'\0'*(-len(buf)%4));start=len(buf);buf.extend(a.tobytes())
 d['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':a.nbytes,'target':target})
 acc={'bufferView':len(d['bufferViews'])-1,'componentType':component,'count':len(a),'type':typ}
 if typ=='VEC3':acc.update({'min':a.min(axis=0).tolist(),'max':a.max(axis=0).tolist()})
 d['accessors'].append(acc);return len(d['accessors'])-1
p['attributes']={'POSITION':append(P,'VEC3',5126,34962),
 'NORMAL':append(N,'VEC3',5126,34962),'TEXCOORD_0':append(U,'VEC2',5126,34962)}
p['indices']=append(I,'SCALAR',5125,34963)
buf.extend(b'\0'*(-len(buf)%4));d['buffers'][0]['byteLength']=len(buf)
js=json.dumps(d,ensure_ascii=False,separators=(',',':')).encode()
js+=b' '*(-len(js)%4);size=12+8+len(js)+8+len(buf)
with open(out,'wb') as f:
 f.write(struct.pack('<4sII',b'glTF',2,size))
 f.write(struct.pack('<I4s',len(js),b'JSON'));f.write(js)
 f.write(struct.pack('<I4s',len(buf),b'BIN\0'));f.write(buf)
print('mesh',mi,'triangles',len(faces),'->',len(I)//3,'GLB bytes',size)
