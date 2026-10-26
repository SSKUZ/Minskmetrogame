// Frame-rate-independent longitudinal train physics (speed in km/h, dt in seconds).
// Full traction: 4.5 km/h/s (twice the previous 2.25).
// Full service brake: 9 km/h/s (90 km/h to zero in 10 seconds).
// Neutral retains the existing long, gentle coast.
export function stepTrainMotion(speed, lever, dt) {
  const v = Math.max(0, Math.min(90, Number(speed) || 0));
  const u = Math.max(-1, Math.min(1, Number(lever) || 0));
  const seconds = Math.max(0, Math.min(.05, Number(dt) || 0));
  if (!seconds) return v;
  let rate;
  if (u > .015) {
    // 50% controller -> 60 km/h, 85-100% -> 90 km/h.
    const target = u >= .85 ? 90 :
      u > .5 ? 60 + (u - .5) / .35 * 30 :
      120 * u;
    // Double traction; never overshoot the selected speed.
    rate = v < target ? Math.min(4.5 * u, (target - v) / seconds) :
      -Math.min(.16, (v - target) / seconds);
  } else if (u < -.015) {
    // Brake force proportional to handle position; full brake = 9 km/h/s.
    rate = -9 * (-u);
  } else {
    rate = -(0.045 + 0.000016 * v * v);
  }
  return Math.max(0, Math.min(90, v + rate * seconds));
}
