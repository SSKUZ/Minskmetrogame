extends Node3D
const Spawner=preload("res://scripts/passengers/passenger_spawner.gd")
const Layout=preload("res://scripts/passengers/passenger_train_adapter.gd")
const Navigation=preload("res://scripts/passengers/passenger_navigation.gd")
const Boarding=preload("res://scripts/passengers/passenger_boarding.gd")
@export_range(0,200) var passenger_count := 18
@export_range(0,200) var boarding_count := 18
var agents: Array=[]
var layout=Layout.new()
var navigation=Navigation.new()
var spawner=Spawner.new()
var boarding=Boarding.new()
var clock := 0.0
var speed := 0.0
var acceleration := 0.0
var exchange_enabled := false

func configure(train: Node3D,doors: Node,stop_offset: float,obstacles: Array[Rect2]) -> void:
    layout.configure(train,doors)
    navigation.obstacles=obstacles
    agents=spawner.spawn(self,passenger_count,navigation,layout.doors)
    for a in agents:
        a.navigation=navigation
        a.wants_board=a.id<boarding_count
        if not a.wants_board:a.position.x=-3.3-float(a.id%2)*0.7
    boarding.layout=layout;boarding.navigation=navigation;boarding.platform_root=self
    boarding.assign(agents,stop_offset)

func request_alight() -> void:
    boarding.request_alight(agents)

func complete() -> bool:
    return boarding.complete(agents)

func _physics_process(delta: float) -> void:
    var dt:=minf(delta,0.1)
    clock+=dt
    for a in agents:
        a.idle(dt,speed,acceleration)
        if a.state=="standingUp" and a.animation.finished():
            a.visual.position=Vector3.ZERO
            a.state="exitQueued";a.animation.play("Idle")
        elif a.state=="sittingDown" and a.animation.finished():
            a.state="seated";a.animation.play("Sit idle (chair)")
        if a.path.is_empty(): continue
        # Closed doors pause only doorway crossing, waiting people may still stroll.
        if a.state in ["boarding","alighting"] and not exchange_enabled: continue
        if not a.step(dt,agents): continue
        match a.state:
            "queueing":a.state="queued";a.animation.play("Idle")
            "settling":
                if a.slot.get("seated",false):
                    a.rotation.y=a.slot.heading
                    a.state="sittingDown";a.animation.play("Sit down (chair)",false)
                else:a.state="riding";a.animation.play("Idle")
            "leaving":a.state="waitingNextTrain";a.animation.play("Idle")
    boarding.update(agents,exchange_enabled)

func doors_clear() -> bool:
    for d in layout.doors:
        if d.active!=null:return false
    for a in agents:
        if a.state in ["boarding","alighting","returning"]:return false
    return true
