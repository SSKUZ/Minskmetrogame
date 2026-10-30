import {V106_PROFILE} from './TrainCompatibilityProfile.js';
import {createStationDefinition} from './StationDefinition.js';
import {createTrackModule} from './TrackModule.js';
import {createPlatformModule} from './PlatformModule.js';
import {createTrainStopModule} from './TrainStopModule.js';
import {createTunnelConnectors} from './TunnelConnector.js';
import {createCollisionModule} from './CollisionModule.js';
import {createPassengerStationContract} from './PassengerStationContract.js';
import {createDecorationInterface} from './DecorationInterface.js';
import {validateDefinition} from './Validation.js';
export function createStationBase(options={}){const profile=options.profile??V106_PROFILE,station=createStationDefinition({...options,profile});
 const modules={track:createTrackModule(station,profile),platform:createPlatformModule(station),stop:createTrainStopModule(station,profile),ports:createTunnelConnectors(station,profile),collision:createCollisionModule(station,profile)};
 modules.passengers=createPassengerStationContract(station,profile,modules.stop);modules.decoration=createDecorationInterface(station,modules.collision);
 const validation=validateDefinition(station,profile,modules);if(!validation.ok)throw new Error(validation.issues.join('; '));return {profile,station,modules,validation};}
