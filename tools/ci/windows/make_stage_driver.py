#!/usr/bin/env python3
"""Run existing Stage acceptance checks against an exported Windows PCK and capture it."""

import argparse
from pathlib import Path
import uuid

PROJECT = Path(__file__).resolve().parents[3]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    source = (PROJECT / 'tests/stage_authoring_check.gd').read_text()
    initialization = 'func _initialize() -> void:\n\t_run.call_deferred()'
    marker = '\t\tprint("STAGE_RESULT ", stage.id, " ", JSON.stringify(main.stages.evaluator.result()))'
    if initialization not in source or marker not in source:
        parser.error('Stage check changed; review this exported-app driver before adapting it')
    source = source.replace(initialization, 'func _initialize() -> void:\n'
                            '\tProjectSettings.set_setting("application/config/use_custom_user_dir", true)\n'
                            f'\tProjectSettings.set_setting("application/config/custom_user_dir_name", "ssok-desktop-check-{uuid.uuid4().hex}")\n'
                            '\t_run.call_deferred()')
    source = source.replace(marker, '\t\tawait process_frame\n\t\tawait RenderingServer.frame_post_draw\n'
                            '\t\tvar image: Image = root.get_texture().get_image()\n'
                            '\t\timage.save_png(OS.get_cmdline_user_args()[0].path_join("stage-" + str(stage.id) + ".png"))\n' + marker)
    args.output.write_text(source)


if __name__ == '__main__':
    main()
