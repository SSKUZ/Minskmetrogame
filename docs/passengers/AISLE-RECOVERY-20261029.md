# Passenger aisle conflict recovery — 29 October 2026

Parent checkpoint: 33c275fce6d263c5d40b8f18f5d63bc134bbe839.
Scope: passenger navigation only. Temporary carriage/V106/cab geometry is not changed.

## Confirmed defect and correction

A stationary passenger can occupy an intermediate aisle route marker. The old
planner tries to reach that exact point, including when the actual destination
is farther down an otherwise usable aisle. Local steering circles the occupant;
A* cannot enter the occupant's exclusion circle. A controlled two-agent case
remained unfinished at 60 simulated seconds. With recovery it reaches the same
final destination in less than 8 simulated seconds at the unchanged walking speed.

After sustained lack of progress, navigation may replace an unreachable aisle
marker with a collision-checked route to the following marker. The agent's
current point, discarded marker and following marker must all be inside the
navigation rectangle provided by the carriage adapter. The generated detour
uses the existing swept obstacle check. This does not remove the final reserved
place or bypass a mandatory leg outside the aisle, including the door-jamb turn.
No passenger is teleported or moved aside by the path planner.

An impossible destination inside another obstacle's exclusion circle is rejected
before exhausting the search grid when the approaching passenger is outside that
circle. Existing gradual escape from an initial overlap remains supported.

## Last-centimetre collision gap

The old waypoint-completion shortcut snapped up to 4.5 cm without checking the
same people/obstacles as normal walking. Separate tests reproduce entering a
person's exclusion circle and a static obstacle during that shortcut. Waypoint
completion now uses the same clearance predicate as ordinary steering; blocked
points remain pending. Distance-driven walking animation also counts these final
centimetres. The walking speed and door crossing/counting rules are unchanged.

## Regression coverage

Six focused scenarios cover an occupied intermediate marker, a detour around an
injected obstacle, retaining an occupied final destination, retaining the
mandatory door turn, and final-centimetre clearance against a person and obstacle.
The existing 3-seed/12-stop tests retain their 150 s deadline. Full-suite and
actual-browser results are recorded in the next progress entry after completion.

This correction resolves a navigation defect; it does not claim all dense crowds
now exchange within a short real metro dwell. The previous continuous-waypoint
speed experiment remains rejected. Further throughput work must retain the same
collision, doorway, identity and family guarantees.
