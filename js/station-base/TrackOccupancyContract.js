export const TRACK_STATES=Object.freeze(['EMPTY','APPROACHING','STOPPED','BOARDING','DEPARTING']);
const next={EMPTY:['APPROACHING'],APPROACHING:['STOPPED'],STOPPED:['BOARDING','DEPARTING'],BOARDING:['STOPPED','DEPARTING'],DEPARTING:['EMPTY']};
export function createTrackOccupancyContract(stop){return {trackId:stop.trackId,stopId:stop.id,state:'EMPTY',trainId:null,mode:'interface-only-no-AI'};}
export function transitionTrack(record,state,trainId=record.trainId){if(!TRACK_STATES.includes(state)||!next[record.state]?.includes(state))throw new Error(`Invalid track transition ${record.state} -> ${state}`);if(state!=='EMPTY'&&!trainId)throw new Error('trainId required');return {...record,state,trainId:state==='EMPTY'?null:trainId};}
export function setStaticOccupancy(record,trainId){return {...record,state:trainId?'STOPPED':'EMPTY',trainId:trainId??null,mode:'static-viewer-placement'};}
