# See companion prototype for geometry-only baseline.
#!/usr/bin/env python3
"""Experimental ONLY. Extract one GLB mesh and decimate to geometry-only PLY.
Requires numpy, vtk. Never use output as production GLB.
Usage: python v106_lod1_mesh289_experiment.py input.glb output.ply [mesh_index]
"""
import json,struct,sys
import numpy as np
import vtk
from vtk.util.numpy_support import numpy_to_vtk,numpy_to_vtkIdTypeArray
src,dst=sys.argv[1:3];mi=int(sys.argv[3]) if len(sys.argv)>3 else 289
b=open(src,'rb').read();jl=struct.unpack_from('<I',b,12)[0];d=json.loads(b[20:20+jl]);raw=memoryview(b)[20+jl+8:]
def get(i):
 a=d['accessors'][i];v=d['bufferViews'][a['bufferView']]
 dt=np.dtype({5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]);k={'SCALAR':1,'VEC2':2,'VEC3':3}[a['type']]
 return np.ndarray((a['count'],k),dtype=dt,buffer=raw,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',k*dt.itemsize),dt.itemsize)).copy()
pr=d['meshes'][mi]['primitives'][0]
assert pr.get('mode',4)==4 and 'indices' in pr
vertices=get(pr['attributes']['POSITION']).astype(np.float64)
faces=get(pr['indices']).reshape(-1,3).astype(np.int64)
points=vtk.vtkPoints();points.SetData(numpy_to_vtk(vertices,deep=True))
cells=vtk.vtkCellArray();cells.SetCells(len(faces),numpy_to_vtkIdTypeArray(np.column_stack((np.full(len(faces),3),faces)).ravel(),deep=True))
poly=vtk.vtkPolyData();poly.SetPoints(points);poly.SetPolys(cells)
clean=vtk.vtkCleanPolyData();clean.SetInputData(poly)
dec=vtk.vtkQuadricDecimation();dec.SetInputConnection(clean.GetOutputPort());dec.SetTargetReduction(0.35);dec.Update()
writer=vtk.vtkPLYWriter();writer.SetFileName(dst);writer.SetInputData(dec.GetOutput());writer.SetFileTypeToBinary();assert writer.Write()
print(f"mesh {mi}: {len(faces)} -> {dec.GetOutput().GetNumberOfPolys()} triangles (geometry-only prototype)")
