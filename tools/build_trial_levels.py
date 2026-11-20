"""Author the five reproducible trial JSONs. Run TrialCampaignChecks to verify them."""
import json
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "levels/trial"
NAMES = ["Crescent Chase", "Blast Switchback", "Laser Steps", "Bee Garden", "Deep Adventure"]
COUNTS = [1, 1, 2, 3, 5]
LESSONS = [1, 2, 5, 8, 10]
# Authored coordinates, not random offsets of the same three holes.
LAYOUTS = [
    [[[250, 520], [455, 940]]],
    [[[445, 475], [245, 790], [400, 1030]]],
    [[[265, 495], [440, 980]], [[365, 450], [420, 465], [315, 825], [420, 1040]]],
    [[[285, 500], [440, 1020]], [[300, 500], [355, 515], [410, 500]],
     [[430, 440], [300, 635], [410, 830], [295, 1040]]],
    [[[360, 500], [425, 785], [330, 1030]], [[330, 500], [440, 785], [300, 1030]],
     [[280, 500], [440, 805], [330, 1030]],
     [[280, 500], [335, 520], [390, 500], [445, 520]], [[365, 480], [320, 1030]]]
]
GROUPS = {(3, 1): 2, (4, 1): 3, (5, 3): 4}
INSTRUCTIONS = ["Two mice. Carve a curved slope, then land safely at the base.",
    "Dig beneath the bomb. Let it roll onto stone and blast a way through.",
    "Touch the switch to turn off the laser. Different prey await below.",
    "Guide the physical bombs onto stone and the bee cover. Avoid garden hazards.",
    "Five different rooms: bombs, a rock switch, portals, water and hazards. Land to finish."]

def generate(number):
    trial_number = number
    count = COUNTS[number - 1]
    lesson = LESSONS[number - 1]
    eaten_before = 0
    source = {"schema_version": 2, "id": f"trial_{number:02}", "number": number,
              "name": NAMES[number - 1], "seed": 915001 + number * 7919,
              "difficulty": number, "bomb_mode": "physical", "kitty": {"position": [360, 280], "radius": 50},
              "resources": {"bombs": 0}, "instructions": INSTRUCTIONS[number - 1],
              "sections": [], "required_events": []}
    for index in range(count):
        y = index * 960
        prefix = f"t{number}_p{index+1}"
        points = [[x, yy+y] for x, yy in LAYOUTS[number-1][index]]
        part = {"id": prefix, "index": index, "name": f"ROOM {index+1} · {NAMES[number-1].upper()}",
                "bounds": [30, 190+y, 660, 960], "camera_center": [360, 640+y],
                "entry": [360, (330 if index == 0 else 200)+y], "exit_base": [360, 1150+y],
                "terrain": {"chambers": [{"position": [360, 240+y], "radius": 105}], "walls": [], "tunnels": []},
                "mice": [], "obstacles": [], "solution_digs": [], "solution_bombs": [], "solution_bomb_digs": [], "solution_steps": [],
                "completion": {"eat_all_mice": True, "reach_exit_base": True,
                               "next_section": f"t{number}_p{index+2}" if index+1<count else None}}
        def chamber(x, yy, radius):
            part["terrain"]["chambers"].append({"position": [x, yy+y], "radius": radius})
        def obstacle(kind, x, yy, **config):
            identity = f"{prefix}_{kind}_{len(part['obstacles'])}"
            item = {"id": identity, "type": kind, "position": [x, yy+y], **config}
            part["obstacles"].append(item)
            return identity
        def event(identity, action):
            source["required_events"].append({"id": identity, "event": action})
        def wall(yy, breakable=True):
            identity = f"{prefix}_wall_{len(part['terrain']['walls'])}"
            part["terrain"]["walls"].append({"id": identity, "rect": [80, yy+y, 560, 35], "breakable": breakable})
            if breakable:
                chamber(360, yy-120, 45)
                bomb = obstacle("bomb",360,yy-120,radius=25,blast_radius=145)
                event(bomb,"detonated")
                part["solution_bomb_digs"].append({"points":[[360,yy-105+y],[360,yy+5+y]],"wait_for_bomb":bomb})
                source["resources"]["bombs"] += 1
        def laser_and_switch(with_gate=False, rock=False):
            chamber(80,680,38)
            part["terrain"]["tunnels"].append({"points":[[80,680+y],[630,680+y]],"radius":12})
            laser = obstacle("laser", 80, 680, direction=[1, 0], length=560,
                             warning_seconds=1.6, active_seconds=1.0, cooldown_seconds=3.5,
                             phase_offset=number*0.17, beam_width=8)
            targets = [laser]
            if with_gate:
                gate = obstacle("gate", 360, 670, width=400)
                targets.append(gate)
                event(gate, "activated")
            event(laser, "activated")
            if rock:
                chamber(150, 470, 48)
                chamber(150, 670, 60)
                rock_id = obstacle("falling_rock", 150, 470, radius=28)
                event(rock_id, "fell")
                obstacle("pressure_switch", 150, 670, radius=26, rocks_only=True, targets=targets)
                part["solution_digs"].append({"points": [[150, 510+y], [150, 670+y]], "wait_ticks": 55})
            else:
                obstacle("pressure_switch", points[0][0], 555, radius=26, targets=targets)
        def bee_trap():
            chamber(630, 875, 50)
            part["terrain"]["walls"].append({"id": prefix+"_bee_cover", "rect": [590,820+y,80,30], "breakable": True})
            bee = obstacle("bee", 630, 875, radius=22, chase=True, chase_speed=240,
                            detection_radius=1200, patrol_width=15, repath_seconds=0.12)
            event(bee, "defeated")
            chamber(630,735,35)
            bomb = obstacle("bomb",630,735,radius=25,blast_radius=100)
            event(bomb,"detonated")
            part["solution_bomb_digs"].append({"points":[[630,755+y],[630,835+y]],"wait_for_bomb":bomb})
            source["resources"]["bombs"] += 1
        def portals():
            points[0] = [280, 500+y]
            points[1] = [440, 805+y]
            wall(690, False)
            part["terrain"]["walls"].append({"id":prefix+"_prey_divider", "rect":[345,805+y,30,155], "breakable":False})
            chamber(280, 620, 85)
            chamber(440, 830, 155)
            entry = obstacle("portal", 280, 620, radius=28, required_growth=eaten_before+1, wait_for_growth=True)
            exit_id = obstacle("portal", 440, 755, radius=28, exit_only=True)
            part["obstacles"][-2]["linked_to"] = exit_id
            event(entry, "used")
            return entry
        def moving_catch(distance=35, speed=0.65):
            platform = obstacle("moving_platform", points[1][0], 845, width=180, distance=distance, speed=speed)
            obstacle("pressure_switch", points[1][0], 820, radius=26, target=platform)
            event(platform, "activated")
        # Permanent shelves give the first route a real left-to-right bend.
        if number == 1:
            part["terrain"]["walls"].extend([
                {"id":prefix+"_upper_shelf", "rect":[435,410+y,255,45], "breakable":False},
                {"id":prefix+"_lower_shelf", "rect":[30,710+y,235,45], "breakable":False}])
        portal = None
        if lesson == 2: wall(655)
        if lesson == 3:
            bee_trap()
            chamber(560, 505, 48)
            obstacle("falling_rock", 560, 505, radius=30)
        if lesson == 4:
            gate = obstacle("gate", 360, 670, width=380)
            obstacle("pressure_switch", points[0][0], 555, radius=26, target=gate)
            event(gate, "activated")
            moving_catch()
        if lesson == 5:
            laser_and_switch()
            part["terrain"]["walls"].append({"id": prefix+"_cover", "rect": [570, 620+y, 45, 120], "breakable": False})
        if lesson == 6:
            event(obstacle("fan", points[0][0], 620, radius=65, force_x=100*(-1 if index%2 else 1), force_y=-450),"used")
            event(obstacle("water", points[1][0], 845, radius=100, current=-40),"used")
            chamber(590, 960, 65)
            obstacle("spikes", 590, 960, radius=25)
        if lesson == 7:
            if index == 0: portal = portals()
            elif index == 1:
                chamber(565, 650, 100)
                event(obstacle("rotating_wheel", 565, 650, radius=65, speed=0.75),"rotated")
            else: laser_and_switch()
        if lesson == 8:
            if index == 0: wall(650)
            elif index == 1: bee_trap()
            else:
                chamber(570, 650, 65)
                obstacle("dangerous_plant", 570, 650, radius=28)
            moving_catch(40,0.7)
        if lesson == 9:
            if index % 2 == 0: laser_and_switch(True, True)
            else:
                wall(650)
                chamber(565, 860, 90)
                event(obstacle("rotating_wheel", 565, 860, radius=60, speed=-0.65),"rotated")
        if lesson == 10:
            if index == 0:
                wall(650); bee_trap()
                part["solution_digs"].append({"points":[[360,350+y],[360,640+y]], "wait_ticks":90})
            elif index == 1: laser_and_switch(True, True)
            elif index == 2:
                portal = portals()
                event(obstacle("fan", 440, 880, radius=60, force_x=-80, force_y=-450),"used")
            elif index == 3:
                moving_catch(40,0.65)
                event(obstacle("water", points[1][0], 825, radius=90, current=35),"used")
                chamber(570, 630, 95)
                event(obstacle("rotating_wheel", 570, 630, radius=60, speed=0.65),"rotated")
            else:
                wall(650); bee_trap()
                chamber(135, 850, 75)
                obstacle("dangerous_plant", 135, 850, radius=27)
                chamber(580, 960, 60)
                obstacle("spikes", 580, 960, radius=25)
                chamber(135, 500, 45)
                obstacle("falling_rock", 135, 500, radius=28)
        part["solution_bomb_digs"].sort(key=lambda action: action["points"][0][0] != 630)
        group_count = GROUPS.get((number, index), 0)
        for i, point in enumerate(points):
            # Distinct silhouettes: circle, pill, oval, staggered pocket and mixed.
            radius = (95 if number == 1 else 80 if number in (2, 4) else 90)
            if i == len(points)-1: radius += 25
            chamber(point[0], point[1]-y, radius)
            if number in (2, 4):
                part["terrain"]["tunnels"].append({"points": [[point[0]-35,point[1]], [point[0]+35,point[1]]], "radius":radius})
            elif number == 3:
                chamber(point[0], point[1]-y+30, radius)
            elif number == 5 and index%2:
                chamber(point[0]+25, point[1]-y, radius)
            mouse_id = f"{prefix}_mouse_{i+1}"
            grouped = i < group_count
            part["mice"].append({"id": mouse_id, "position": point, "kind": "BIG" if i==len(points)-1 and not grouped else "SMALL",
                "required_growth": eaten_before+(len(points)-1 if i==len(points)-1 and not grouped else 0), "growth": 1, "radius": 35 if i==len(points)-1 and not grouped else 22,
                "flee_speed": 28+number, "escape_distance": 24})
        if group_count:
            members = part["mice"][:group_count]
            group_id = prefix+"_mouse_group"
            part["mouse_groups"] = [{"id":group_id,"count":group_count,"mouse_ids":[m["id"] for m in members]}]
            for member in members: member["group_id"] = group_id
        chamber(360, 1110, 135)
        route = [[360, (350 if index == 0 else 205)+y], *points, [360, 1140+y]]
        part["reference_route"] = route
        previous = route[0]
        for i, point in enumerate(points):
            if portal and i == 1:
                part["solution_steps"].append({"points": [previous, [280, 620+y]], "wait_for_portal": portal})
                previous = [440, 793+y]
            stroke = [previous, point]
            if portal and i == 2: stroke = [previous, [440,1060+y], [point[0],1060+y]]
            part["solution_steps"].append({"points": stroke, "wait_for_mouse": part["mice"][i]["id"]})
            previous = point
        part["solution_steps"].append({"points": [previous, [360, 1140+y]]})
        source["sections"].append(part)
        eaten_before += len(points)
    geometry = [{"terrain": s["terrain"], "mice": [m["position"] for m in s["mice"]], "obstacles": s["obstacles"]} for s in source["sections"]]
    source["layout_signature"] = hashlib.sha256(json.dumps(geometry, sort_keys=True).encode()).hexdigest()
    return source

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"schema_version": 2, "count": 5, "levels": []}
    for number in range(1, 6):
        source = generate(number)
        (OUT/f"trial_{number:02}.json").write_text(json.dumps(source, indent=2)+"\n", encoding="utf-8")
        manifest["levels"].append({"number": number, "name": source["name"], "sections": len(source["sections"]),
            "obstacles": sorted({o["type"] for s in source["sections"] for o in s["obstacles"]}),
            "layout_signature": source["layout_signature"]})
    (OUT/"manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    print("Authored 5 distinct trial JSONs; physics verification still required.")

if __name__ == "__main__": main()
