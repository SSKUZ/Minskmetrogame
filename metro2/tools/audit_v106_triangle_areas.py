#!/usr/bin/env python3
"""Read-only spatial/area audit of large indexed GLB meshes. Requires numpy."""
import json,struct,sys
import numpy as np
DT={5121:np.uint8,5123:np.uint16,5125:np.uint32,5126:np.float32}
for filename in sys.argv[1:]:
    data=open(filename,"rb").read()
    assert data[:4]==b"glTF"
    n=struct.unpack_from("<I",data,12)[0]
    doc=json.loads(data[20:20+n])
    binary=memoryview(data)[20+n+8:]
    def get(i):
        a=doc["accessors"][i];v=doc["bufferViews"][a["bufferView"]]
        dtype=np.dtype(DT[a["componentType"]])
        dims={"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4}[a["type"]]
        off=v.get("byteOffset",0)+a.get("byteOffset",0)
        stride=v.get("byteStride",dims*dtype.itemsize)
        return np.ndarray((a["count"],dims),dtype=dtype,buffer=binary,
                          offset=off,strides=(stride,dtype.itemsize))
    rows=[]
    for mi,mesh in enumerate(doc.get("meshes",[])):
        for prim in mesh["primitives"]:
            if prim.get("mode",4)!=4 or "indices" not in prim:continue
            idx=get(prim["indices"]).reshape(-1,3)
            if len(idx)<20000:continue
            pos=get(prim["attributes"]["POSITION"])
            tri=pos[idx]
            areas2=np.linalg.norm(np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]),axis=1)
            rows.append({"mesh":mi,"triangles":len(idx),"material":prim.get("material"),
                "bounds_m":np.ptp(pos,axis=0).round(3).tolist(),
                "tiny_area_below_5e-6_m2":int(np.count_nonzero(areas2<1e-5)),
                "zero_area_below_5e-9_m2":int(np.count_nonzero(areas2<1e-8))})
    print(filename,json.dumps(sorted(rows,key=lambda x:-x["triangles"])[:20],ensure_ascii=False))
