export function recordBoarding(recorded,index,carriagePassenger,onCount){
 if(recorded.has(index))return false;
 recorded.add(index);carriagePassenger.settled=true;onCount();return true;
}
