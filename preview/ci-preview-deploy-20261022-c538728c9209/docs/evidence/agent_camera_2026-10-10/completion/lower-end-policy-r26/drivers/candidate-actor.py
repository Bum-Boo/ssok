"""DEBUG-r26: isolated actor stop preference, never an installed operator change."""
from pathlib import Path
import hashlib
import json
import sys

REPO = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
sys.path.insert(0, str(REPO))
from tools.app_control import run_goal

REPLACEMENTS = [
    ('If the observed span already meets the goal, stop without an extra forward step.',
     'If the observed span meets the goal interval, prefer stopping near its lower end '
     '(24–26 pixels for this goal). This is a policy preference within the original '
     '24–38-pixel acceptance interval, not a replacement success criterion. Before '
     'another forward step, compare the most recent settled-image changes; use only '
     'one tick if it is reasonably likely to stay inside that original interval. '
     'Otherwise stop now; never cross its lower bound deliberately.'),
    ('Aim for the middle of the requested interval rather than its uncertain edge.',
     'Prefer the lower end of the requested interval while accounting for pixel '
     'uncertainty; stop if uncertain rather than forcing this preference.')
]

def candidate_prompt(original):
    result = original
    for before, after in REPLACEMENTS:
        assert result.count(before) == 1, 'Stock actor policy changed; do not apply experiment'
        result = result.replace(before, after, 1)
    return result

def main():
    factory = run_goal.codex_command
    def command(executable, root, working, output, python, **kwargs):
        path = working / 'actor.md'
        before = path.read_text(encoding='utf8')
        after = candidate_prompt(before)
        assert 'scene metrics or credentials' in after
        assert 'Observe after EVERY action' in after
        assert 'No retries after any error.' in after
        path.write_text(after, encoding='utf8')
        output.mkdir(exist_ok=True)
        (output / 'policy.json').write_text(json.dumps({
            'experiment': 'DEBUG-r26-lower-end-stop-preference',
            'stock_actor_prompt_sha256': hashlib.sha256(before.encode()).hexdigest(),
            'candidate_actor_prompt_sha256': hashlib.sha256(after.encode()).hexdigest(),
            'replacements': REPLACEMENTS, 'operator_installed': False,
            'acceptance_interval_pixels': [24, 38], 'preferred_stop_pixels': [24, 26],
            'goal_unchanged': True, 'physical_inputs': False
        }, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
        return factory(executable, root, working, output, python, **kwargs)
    run_goal.codex_command = command
    try:
        return run_goal.main()
    finally:
        run_goal.codex_command = factory

if __name__ == '__main__':
    raise SystemExit(main())
