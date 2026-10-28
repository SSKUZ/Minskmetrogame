import assert from 'node:assert/strict';

export function checkContinuity(diagnostics,version){
 const d=diagnostics;
 assert.ok(d&&Number.isFinite(d.maximumRoofStep20mm),'Continuity measurements unavailable');
 if(version<90)return {status:'diagnostic-only',knownDefects:['Overlapping roof shells','300 mm eave drop','Different cab/body outer planes'],measurements:d};
 assert.equal(d.roofOverlapSamples,0,'Multiple roof surfaces occupy the same X/Z sample');
 assert.ok(d.maximumRoofStep20mm<=.0075,`Abrupt roof step: ${d.maximumRoofStep20mm} m / 20 mm`);
 assert.ok(d.roofCapGap<=.00005,`Open roof/cap seam: ${d.roofCapGap} m`);
 assert.ok(d.roofCapNormalAngle<=.1,`Roof/brow tangent planes differ: ${d.roofCapNormalAngle} degrees`);
 assert.ok(d.cabBodyPlaneDifference<=.001,'Cab and passenger side planes do not coincide');
 assert.ok(d.sideBottomDifference<=.0011,'Cab and passenger lower body lines differ');
 assert.equal(d.nearCoincidentCabSkins,1,'Duplicate exterior cab skins remain');
 assert.ok(d.roofWallGap<=.00005,'Roof edge and sidewall have a gap');
 assert.equal(d.invertedOuterFaces,0,'A structural face has reversed normals');
 if(version>=91)assert.ok(Math.abs(d.cabCrown-d.mainCrown)<=.05,'Cab crown remains disproportionate to the main roof');
 return {status:'pass',measurements:d,limits:'Structural surface sampling, not a general continuous collision proof. Window/door/saloon positions and six front lamps are checked separately.'};
}
