// Pure, frame-rate-independent longitudinal motion model (km/h, seconds).
export function stepTrainMotion(speed, lever, dt) {
  const v = Math.max(0, Math.min(90, Number(speed) || 0));
  const u = Math.max(-1, Math.min(1, Number(lever) || 0));
  const seconds = Math.max(0, Math.min(.05, Number(dt) || 0));
  if (!seconds) return v;
  let acceleration;
  if (u > .015) {
    const target = 90 * Math.pow(u, Math.log(2 / 3) / Math.log(.5));
    // Acceleration tapers as the train approaches the selected speed.
    acceleration = v < target ? Math.min(18 * u, (target - v) / seconds) :
      -Math.min(3.0, (v - target) / seconds);
  } else if (u < -.015) {
    // Service brake: progressive braking up to 1.25 m/s².
    acceleration = -(0.7 + 3.8 * (-u));
  } else {
    // Free coasting with gentle rolling and aerodynamic resistance.
    acceleration = -(0.45 + .00013 * v * v);
  }
  return Math.max(0, Math.min(90, v + acceleration * seconds));
}
