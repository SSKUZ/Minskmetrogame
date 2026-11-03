export function nearestDoor(z,doors){return doors.reduce((best,d)=>Math.abs(d-z)<Math.abs(best-z)?d:best,doors[0])}
export function smoothProgress(elapsed,duration){const k=Math.max(0,Math.min(1,elapsed/duration));return k*k*(3-2*k)}
export function facingDirection(dx,dz){return Math.atan2(-dx,-dz)}
export function shortestTurn(from,to){return Math.atan2(Math.sin(to-from),Math.cos(to-from))}