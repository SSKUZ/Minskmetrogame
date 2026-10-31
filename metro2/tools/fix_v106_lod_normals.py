#!/usr/bin/env python3
"""Normalize NORMAL vectors of experimental mesh 289, without modifying other GLB data."""
import sys,struct,json,hashlib
import numpy as np
src,dst=sys.argv[1:]
raw=bytearray(open(src,'rb').read())
length=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+length])
base=20+length+8
primitive=doc['meshes'][289]['primitives'][0]
acc=doc['accessors'][primitive['attributes']['NORMAL']]
view=doc['bufferViews'][acc['bufferView']]
assert acc['componentType']==5126 and acc['type']=='VEC3' and view.get('byteStride',12)==12
normals=np.ndarray((acc['count'],3),dtype='<f4',buffer=raw,
 offset=base+view.get('byteOffset',0)+acc.get('byteOffset',0))
magnitudes=np.linalg.norm(normals,axis=1)
assert np.isfinite(magnitudes).all() and (magnitudes>1e-8).all()
count=int(np.count_nonzero(np.abs(magnitudes-1)>.01))
normals[:]=normals/magnitudes[:,None]
open(dst,'wb').write(raw)
print('Corrected',count,'normals; sha256',hashlib.sha256(raw).hexdigest())
