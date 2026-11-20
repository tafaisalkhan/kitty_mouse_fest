"""Build deterministic, editable campaign generation instructions (no player saves)."""
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'levels' / 'campaign'
MODULES = {
    'switch_gate': 'Land on the pressure switch to open the gate below.',
    'rotating_wheel': 'Guide kittens around or through the rotating wheel.',
    'stone_bee_trap': 'Release the side stone onto the bee before opening its tunnel.',
    'moving_platform': 'Choose a safe descent beside the moving platform and plant.',
    'garden_gate': 'Follow the winding route to the garden switch; avoid the plant.',
}


def recipe(n):
    if n <= 29:
        path = next(ROOT.glob(f'levels/*/level_{n:03d}.json'))
        data = json.loads(path.read_text(encoding='utf-8'))
        return dict(recipe_version=1, number=n, mode='authored',
                    source='res://' + path.relative_to(ROOT).as_posix(),
                    screen_count=data.get('sections', 1),
                    kitten_count=len(data['kittens']),
                    mechanics=sorted({x['type'] for x in data['obstacles']}),
                    challenge='Learn digging, safe landings, hazards, and base transitions.')
    rng = random.Random(71809 * n)
    tier = min(10, 1 + (n - 1) // 100)
    screens = 2 if n < 100 else 3 if n < 250 else 4 if n < 500 else 5
    milestone = n % 10 == 0
    if milestone:
        screens = min(5, screens + 1)
    pool = list(MODULES)[:3 if n < 60 else 4 if n < 100 else 5]
    order = []
    for index in range(screens):
        choices = [x for x in pool if not order or x != order[-1]]
        order.append(rng.choice(choices))
    # Every level combines a route gate with another mechanic.
    if not any(x in ('switch_gate', 'garden_gate') for x in order):
        order[0] = 'switch_gate'
    if n == 60:
        order[-1] = 'moving_platform'
    if n == 100:
        order[-1] = 'garden_gate'
    return dict(
        recipe_version=1, number=n, mode='generated', seed=n * 71809,
        name=f"{'Challenge' if milestone else 'Rescue'} {n}: " + order[-1].replace('_', ' ').title(),
        difficulty_tier=tier, milestone=milestone,
        screen_count=screens, kitten_count=3 if n >= 200 else 2,
        brush_radius=round(86 - 1.4 * tier - (2 if milestone else 0), 1),
        mirror=bool(rng.randrange(2)),
        layout_offset_x=round(rng.uniform(-20, 20), 3),
        wheel_speed=round(0.35 + tier * 0.035, 3),
        platform_speed=round(0.65 + tier * 0.065, 3),
        platform_distance=40 + tier,
        bee_chase_speed=210 + tier * 7,
        extra_hazards_per_screen=1 if n < 400 else 2,
        screens=[dict(module=x, challenge=MODULES[x]) for x in order],
        objectives=dict(rescue_all=True, target_time_seconds=screens * (42 - tier),
                        target_dig_distance=screens * (1300 - tier * 20)),
        retry_policy='Preserve screens and mechanics; widen routes and slow machinery if proof fails.',
    )


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    entries = []
    for n in range(1, 1001):
        data = recipe(n)
        (DEST / f'level_{n:04d}.json').write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
        entries.append(dict(number=n, recipe=f'res://levels/campaign/level_{n:04d}.json',
                            screens=data['screen_count'], mode=data['mode']))
    (DEST / 'manifest.json').write_text(json.dumps(dict(recipe_version=1, count=1000,
        endless_after_campaign=True, levels=entries), indent=2) + '\n', encoding='utf-8')
    print('Wrote 1,000 campaign recipes and manifest.')


if __name__ == '__main__':
    main()
