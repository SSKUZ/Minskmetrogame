export function animateDoorLeaves(leaves,open){for(const d of leaves)d.leaf.position.z=d.doorZ+d.half*(.53+(open?1.03:0))}
export function animateCarriageDoors(leaves,open){for(const d of leaves)d.leaf.position.z=d.leafZ+(open?d.half*.92:0)}
export function canOpenDoors(speed,dist){return speed<1.5&&Math.abs(dist)<32}