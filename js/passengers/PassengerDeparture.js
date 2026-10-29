export function requestPassengerDeparture(system){
 if(!system.simulation.boarding.opened)return true;
 system.requestFinishBoarding();system.closeRequested=!(system.passengerExchangeComplete&&system.doorsSafeToClose);return !system.closeRequested;
}
export function consumePassengerDeparture(system){
 if(!system.closeRequested||!system.passengerExchangeComplete||!system.doorsSafeToClose)return false;
 system.closeRequested=false;return true;
}
