import {buildCarriageShell} from './CarriageShell.js';
import {buildCarriageWindows} from './CarriageWindows.js';
import {buildCarriageSeats} from './CarriageSeats.js';
import {buildCarriageRails} from './CarriageRails.js';
import {buildCarriageLighting} from './CarriageLighting.js';
import {buildCarriageInformation} from './CarriageInformation.js';
import {createCarriageMaterials} from './CarriageMaterials.js';
// Passenger carriage geometry. All meshes belong to the supplied carriage group.
// Geometry is rebuilt in isolated modules; passenger and door state are unchanged.
export function buildCarriageInterior({THREE,carriage,box,getStationName}){
const {carCream,carWhite,carFloor,carSeat,carSteel,carBlack,carDoor,carGlass,carLight}=createCarriageMaterials(THREE);
buildCarriageShell({THREE,carriage,box,carFloor,carCream,carWhite,carSteel,carGlass});
for(const side of [-1,1])for(let j=0;j<8;j++){
 const z=1.1-j*2.75;
 if(side===-1&&[-3.2,-13].some(d=>Math.abs(z-d)<2.20))continue;
 buildCarriageWindows({carriage,box,side,z,carBlack,carGlass});
 buildCarriageSeats({THREE,carriage,box,side,z,carWhite,carSeat});
}
buildCarriageRails({THREE,carriage,box,carSteel,carCream,carLight});
buildCarriageLighting({THREE,carriage,box,carLight,carSteel,carWhite});
const updateCarriageStationDisplay=buildCarriageInformation({THREE,carriage,getStationName});

return {updateCarriageStationDisplay,materials:{carCream,carWhite,carFloor,carSeat,carSteel,carBlack,carDoor,carGlass,carLight}};
}
