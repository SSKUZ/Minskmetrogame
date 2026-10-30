const freeze=o=>{for(const v of Object.values(o))if(v&&typeof v==='object')freeze(v);return Object.freeze(o)};
export const V106_PROFILE=freeze({
  "id": "v106-compat-box-1",
  "version": 1,
  "assetCommit": "9a1a17bd68039a47e5ea0742bccd285dc100bf16",
  "units": "m",
  "formation": [
    "81-717",
    "81-714",
    "81-714",
    "81-717"
  ],
  "rail": {
    "headY": 0,
    "centerOffsets": [
      -0.9,
      0.9
    ],
    "width": 0.12,
    "height": 0.16
  },
  "train": {
    "placementY": 0.22,
    "frontOffsetZ": 9.603,
    "nominalLength": 79.224,
    "fullBounds": {
      "min": [
        -1.5464999985694885,
        1.6093254090465692e-08,
        -0.4520003051757815
      ],
      "max": [
        1.5464999985694874,
        3.916589231491089,
        79.67600030517578
      ]
    },
    "wheelCount": 32,
    "doorLeafCount": 64,
    "contactLocalY": -0.22,
    "thresholdLocalTopY": 0.9605,
    "thresholdAbsX": 1.3005,
    "bandHalfWidth": 1.337000012397767,
    "wheelLocalZ": [
      -7.35,
      -5.65,
      5.65,
      7.35
    ]
  },
  "platform": {
    "topY": 1.1805,
    "edgeOffset": 1.37,
    "slabThickness": 0.2
  },
  "validation": {
    "epsilon": 0.001,
    "lateralBudget": 0.01,
    "verticalBudget": 0.005,
    "minimumResidualClearance": 0.022,
    "portAngleTolerance": 0.1
  },
  "door": {
    "routeHalfWidth": 0.59,
    "leafTravel": 0.6,
    "openProjectionWidth": 1.203,
    "animationSeconds": 1.55
  },
  "doors": [
    {
      "id": "c0-minus-door-0",
      "car": 0,
      "localSide": -1,
      "z": 3.303
    },
    {
      "id": "c0-minus-door-1",
      "car": 0,
      "localSide": -1,
      "z": 7.753
    },
    {
      "id": "c0-minus-door-2",
      "car": 0,
      "localSide": -1,
      "z": 12.152999999999999
    },
    {
      "id": "c0-minus-door-3",
      "car": 0,
      "localSide": -1,
      "z": 16.603
    },
    {
      "id": "c1-minus-door-0",
      "car": 1,
      "localSide": -1,
      "z": 22.964
    },
    {
      "id": "c1-minus-door-1",
      "car": 1,
      "localSide": -1,
      "z": 27.394
    },
    {
      "id": "c1-minus-door-2",
      "car": 1,
      "localSide": -1,
      "z": 31.823999999999998
    },
    {
      "id": "c1-minus-door-3",
      "car": 1,
      "localSide": -1,
      "z": 36.254
    },
    {
      "id": "c2-minus-door-0",
      "car": 2,
      "localSide": -1,
      "z": 42.970000000000006
    },
    {
      "id": "c2-minus-door-1",
      "car": 2,
      "localSide": -1,
      "z": 47.4
    },
    {
      "id": "c2-minus-door-2",
      "car": 2,
      "localSide": -1,
      "z": 51.830000000000005
    },
    {
      "id": "c2-minus-door-3",
      "car": 2,
      "localSide": -1,
      "z": 56.26
    },
    {
      "id": "c3-minus-door-0",
      "car": 3,
      "localSide": 1,
      "z": 62.621
    },
    {
      "id": "c3-minus-door-1",
      "car": 3,
      "localSide": 1,
      "z": 67.071
    },
    {
      "id": "c3-minus-door-2",
      "car": 3,
      "localSide": 1,
      "z": 71.471
    },
    {
      "id": "c3-minus-door-3",
      "car": 3,
      "localSide": 1,
      "z": 75.92099999999999
    }
  ],
  "trackGeometry": {
    "bed": {
      "width": 3,
      "height": 0.12,
      "centerY": -0.3
    },
    "sleepers": {
      "width": 2.3,
      "height": 0.1,
      "depth": 0.2,
      "pitch": 0.65,
      "centerY": -0.2
    }
  }
});
