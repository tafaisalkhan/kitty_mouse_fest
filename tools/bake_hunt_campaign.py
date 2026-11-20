"""Run independent offline Godot physics jobs, then publish only a complete campaign."""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GODOT = Path.home() / 'Downloads/Godot_Engine/Godot_v4.7.2-stable_win64.exe'
VERSION = 5


def publish():
    stage = ROOT / 'build/hunt-bake'
    layouts = []
    signatures = set()
    modules = {}
    for n in range(1, 1001):
        path = stage / f'level_{n:04d}.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        proof = data.get('verification', {})
        recipe = ROOT / f'levels/hunt_recipes/level_{n:04d}.json'
        assert data.get('verified') and data.get('mode') == 'mouse_hunt', n
        assert data['number'] == n and data['hunt_generation_version'] == VERSION, n
        assert proof['mice_eaten'] == proof['mouse_count'] == len(data['mice']), n
        assert proof.get('mechanics_verified'), n
        assert proof.get('idle_start_verified'), n
        assert data['recipe_hash'] == hashlib.sha256(recipe.read_bytes()).hexdigest(), n
        for module in data['modules']:
            modules[module] = modules.get(module, 0) + 1
        signature = json.dumps([data['terrain'], data['mice'], data['obstacles']], sort_keys=True)
        assert signature not in signatures, f'duplicate layout {n}'
        signatures.add(signature)
        layouts.append(dict(number=n, file=f'level_{n:04d}.json', screens=data['sections'],
                            mice=len(data['mice']), modules=data['modules'],
                            repair_attempt=proof['attempt'], sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    dest = ROOT / 'levels/hunt'
    dest.mkdir(parents=True, exist_ok=True)
    for item in layouts:
        shutil.copy2(stage / item['file'], dest / item['file'])
    manifest = dict(mode='mouse_hunt', generation_version=VERSION, count=1000,
                    unique_layouts=len(signatures), all_physics_verified=True,
                    validation='Actual Godot physics, touch input, eating order and section progression.',
                    module_counts=modules, levels=layouts)
    (dest / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    (ROOT / 'tests/hunt-campaign-verification.json').write_text(json.dumps(dict(
        generation_version=VERSION, physics_passed=1000, failures=0, unique_layouts=len(signatures),
        module_counts=modules, repaired_levels=sum(x['repair_attempt'] > 0 for x in layouts),
        levels=layouts), indent=2) + '\n', encoding='utf-8')
    print('Published 1,000 unique, physics-verified hunting layouts.', flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', type=Path, default=DEFAULT_GODOT)
    parser.add_argument('--workers', type=int, default=4)
    parser.add_argument('--publish-only', action='store_true')
    args = parser.parse_args()
    if args.publish_only:
        publish()
        return
    stage = ROOT / 'build/hunt-bake'
    stage.mkdir(parents=True, exist_ok=True)
    for old_report in stage.glob('report-*.json'):
        old_report.unlink()
    workers = max(1, min(4, args.workers))
    processes = []
    logs = []
    for index in range(workers):
        first = index * 1000 // workers + 1
        last = (index + 1) * 1000 // workers
        env = os.environ.copy()
        env['APPDATA'] = str(ROOT / f'.test-user/offline-bake-{index}')
        env['LOCALAPPDATA'] = str(ROOT / '.test-local')
        log = (stage / f'worker-{index}.stdout.log').open('w', encoding='utf-8')
        logs.append(log)
        command = [str(args.godot), '--headless', '--path', str(ROOT),
                   'res://tests/BakeHuntCampaign.tscn', '--fixed-fps', '60',
                   '--log-file', str(stage / f'worker-{index}.log'), '--',
                   f'--start={first}', f'--end={last}']
        processes.append(subprocess.Popen(command, cwd=ROOT, env=env, stdout=log,
            stderr=subprocess.STDOUT, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0)))
    began = time.monotonic()
    try:
        while any(p.poll() is None for p in processes):
            completed = 0
            failed = 0
            for report in stage.glob('report-*.json'):
                try:
                    data = json.loads(report.read_text(encoding='utf-8'))
                    completed += data['passed']
                    failed += data['failed']
                except (OSError, ValueError):
                    pass
            print(f'Offline physics: {completed}/1000 passed, {failed} failures; '
                  f'{time.monotonic()-began:.0f}s elapsed', flush=True)
            time.sleep(20)
        if any(p.returncode for p in processes):
            raise RuntimeError('Some layouts failed. Inspect build/hunt-bake/report-*.json; nothing was published.')
        publish()
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
        for log in logs:
            log.close()


if __name__ == '__main__':
    main()
