// Longitudinal motion, expressed in km/h and seconds.
// Approximate metro-train dynamics, tuned for mobile gameplay.
// 100% traction: ~0.62 m/s²; full service brake: ~0.85 m/s².
// Neutral is true coasting: only modest rolling/aerodynamic resistance.
export function stepTrainMotion(speed, lever, dt) {
  const v = Math.max(0, Math.min(90, Number(speed) || 0));
  const u = Math.max(-1, Math.min(1, Number(lever) || 0));
  const seconds = Math.max(0, Math.min(.05, Number(dt) || 0));
  if (!seconds) return v;
  let rate; // km/h per second
  if (u > .015) {
    // Keep 50% traction at 60 km/h; reach 90 km/h at >=85% lever travel.
    // This also accommodates the on-screen controller's touch margins.
    const target = u >= .85 ? 90 :
      u > .5 ? 60 + (u - .5) / .35 * 30 :
      60 * Math.pow(u / .5, 1.0);
    // Train power fades gently toward the controller's selected speed.
    // Avoid automatic sharp braking when the lever is reduced.
    rate = v < target ? Math.min(2.25 * u, (target - v) / seconds) :
      -Math.min(.16, (v - target) / seconds);
  } else if (u < -.015) {
    const brake = -u;
    // Progressive service braking, 30% stronger: ~0.22–1.10 m/s².
    rate = -1.30 * (0.60 + 2.45 * brake);
  } else {
    // Coast for a long distance, especially at lower speeds.
    rate = -(0.045 + 0.000016 * v * v);
  }
  return Math.max(0, Math.min(90, v + rate * seconds));
}
