"""Create explicit cat-and-mouse campaign instructions; never touches saves."""
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'levels/hunt_recipes'
MODULES = ['burrow_bend', 'switch_gate', 'wheel_bypass', 'stone_bee_trap',
           'moving_catch', 'timed_garden', 'size_order_fork']


def recipe(n):
    rng = random.Random(n * 104729)
    tier = min(10, 1 + (n - 1) // 100)
    count = 1 if n < 30 else 2 if n < 100 else 3 if n < 250 else 4 if n < 500 else 5
    challenge = n >= 20 and n % 10 == 0
    if challenge:
        count = min(5, count + 1)
    pool = MODULES[:1 if n < 8 else 2 if n < 20 else 3 if n < 40 else
                   4 if n < 70 else 5 if n < 100 else 6 if n < 150 else 7]
    screens = []
    for section in range(count):
        choices = [m for m in pool if not screens or m != screens[-1]['module']] or pool
        module = rng.choice(choices)
        # Introductions are guaranteed, rather than dependent on a random draw.
        if section == 0 and n in (8, 20, 40, 70, 100, 150):
            module = MODULES[(8, 20, 40, 70, 100, 150).index(n) + 1]
        screens.append(dict(module=module, mirror=bool(rng.randrange(2)),
                            offset_x=round(rng.uniform(-18, 18), 2),
                            hole_y=[rng.randint(455, 495), rng.randint(710, 755), rng.randint(1005, 1035)],
                            escape_direction=rng.choice([-1, 1])))
    return dict(recipe_version=2, mode='mouse_hunt_recipe', number=n, seed=n * 104729,
                source_recipe=f'res://levels/campaign/level_{n:04d}.json',
                name=f"{'Challenge' if challenge else 'Mouse Maze'} {n}",
                difficulty_tier=tier, challenge=challenge, screen_count=count,
                starting_radius=25, brush_radius=round(85 - tier * 1.1 - (2 if challenge else 0), 1),
                flee_speed=40 + tier * 3, escape_distance=18 + tier * 2,
                screens=screens, prey_order=['small', 'small', 'big'],
                growth_per_mouse=1, growth_needed_for_big=2,
                objective='Eat every required mouse; complete each burrow before descending.',
                target_time_seconds=count * (48 - tier), target_dig_distance=count * (1700 - tier * 25),
                repair_policy='Keep modules, mouse count and screen count; widen digging and shorten escape paths.')


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for n in range(1, 1001):
        (DEST / f'level_{n:04d}.json').write_text(json.dumps(recipe(n), indent=2) + '\n', encoding='utf-8')
    print('Created 1,000 hunting recipes with growth, burrows, escape paths and ordered mechanics.')


if __name__ == '__main__':
    main()
