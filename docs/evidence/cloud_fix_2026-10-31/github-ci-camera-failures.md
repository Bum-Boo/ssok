# GitHub Actions verify logs: camera failures (excerpt)

Extracted 2026-10-31 from the `verify` job logs with the GitHub API; timestamps removed. Only PASS/FAIL summary lines, drift values and `drive_stop` progress rows are kept.

## run 39797157897 (feat/own-build-r3-20261022, 578ca79, 2026-10-22)

    FAIL agent_camera_rest_check (64.5s)
    idle_drift_m=0.01472027786076 delta=(0.01472, -0.000042, -0.000139)
    FAIL camera_evaluator_lifecycle_check-drive_stop (18.6s)
    LIFECYCLE_PROGRESS {"elapsed_msec":3061,"enabled":true,"episode_id":"0b7e5ec4899a4801627b22ee","evaluator_finished":false,"evaluator_started":false,"generation":1,"mode":"drive_stop","phase":"waiting_ready","physics_tick":3,"state":"settling"}
    LIFECYCLE_PROGRESS {"elapsed_msec":5911,"enabled":true,"episode_id":"0b7e5ec4899a4801627b22ee","evaluator_finished":false,"evaluator_started":true,"generation":1,"mode":"drive_stop","phase":"ready","physics_tick":36,"state":"ready"}
    LIFECYCLE_PROGRESS {"elapsed_msec":5916,"enabled":true,"episode_id":"0b7e5ec4899a4801627b22ee","evaluator_finished":false,"evaluator_started":true,"generation":1,"mode":"drive_stop","phase":"drive_step_0","physics_tick":36,"state":"driving"}
    LIFECYCLE_PROGRESS {"elapsed_msec":6002,"enabled":true,"episode_id":"0b7e5ec4899a4801627b22ee","evaluator_finished":false,"evaluator_started":true,"generation":1,"mode":"drive_stop","phase":"waiting_ready","physics_tick":37,"state":"driving"}
    LIFECYCLE_PROGRESS {"elapsed_msec":10978,"enabled":true,"episode_id":"0b7e5ec4899a4801627b22ee","evaluator_finished":false,"evaluator_started":true,"generation":1,"mode":"drive_stop","phase":"waiting_ready","physics_tick":97,"state":"settling"}
    LIFECYCLE_PROGRESS {"elapsed_msec":15972,"enabled":true,"episode_id":"0b7e5ec4899a4801627b22ee","evaluator_finished":false,"evaluator_started":true,"generation":1,"mode":"drive_stop","phase":"waiting_ready","physics_tick":157,"state":"settling"}
    LIFECYCLE_PROGRESS {"elapsed_msec":18045,"enabled":false,"episode_id":"0b7e5ec4899a4801627b22ee","evaluator_finished":false,"evaluator_started":true,"generation":2,"mode":"drive_stop","phase":"ready_fault","physics_tick":182,"state":"fault"}
    LIFECYCLE_FAIL: motor action reaches measured rest
    115 checks; 2 failures. Results: /home/runner/work/ssok/ssok/build/verification/SUMMARY.md

## run 38156164681 (release/0.3.1, b3570c6, 2026-10-11)

    FAIL agent_camera_loop_check-rendered (47.3s)
    FAIL agent_camera_rest_check (72.0s)
    idle_drift_m=0.01497287675738 delta=(0.014956, -0.000262, 0.00067)
    FAIL agent_goal_ui_check-rendered (61.2s)
    FAIL camera_evaluator_lifecycle_check-drive_stop (19.7s)
    LIFECYCLE_PROGRESS {"elapsed_msec":3424,"enabled":true,"episode_id":"c43b2a77755294d05b1ea602","evaluator_finished":false,"evaluator_started":false,"generation":1,"mode":"drive_stop","phase":"waiting_ready","physics_tick":3,"state":"settling"}
    LIFECYCLE_PROGRESS {"elapsed_msec":6705,"enabled":true,"episode_id":"c43b2a77755294d05b1ea602","evaluator_finished":false,"evaluator_started":true,"generation":1,"mode":"drive_stop","phase":"ready","physics_tick":36,"state":"ready"}
    LIFECYCLE_PROGRESS {"elapsed_msec":6710,"enabled":true,"episode_id":"c43b2a77755294d05b1ea602","evaluator_finished":false,"evaluator_started":true,"generation":1,"mode":"drive_stop","phase":"drive_step_0","physics_tick":36,"state":"driving"}
    LIFECYCLE_PROGRESS {"elapsed_msec":6807,"enabled":true,"episode_id":"c43b2a77755294d05b1ea602","evaluator_finished":false,"evaluator_started":true,"generation":1,"mode":"drive_stop","phase":"waiting_ready","physics_tick":37,"state":"driving"}
    LIFECYCLE_PROGRESS {"elapsed_msec":12496,"enabled":true,"episode_id":"c43b2a77755294d05b1ea602","evaluator_finished":false,"evaluator_started":true,"generation":1,"mode":"drive_stop","phase":"waiting_ready","physics_tick":97,"state":"settling"}
    LIFECYCLE_PROGRESS {"elapsed_msec":18208,"enabled":true,"episode_id":"c43b2a77755294d05b1ea602","evaluator_finished":false,"evaluator_started":true,"generation":1,"mode":"drive_stop","phase":"waiting_ready","physics_tick":157,"state":"settling"}
    LIFECYCLE_PROGRESS {"elapsed_msec":19164,"enabled":false,"episode_id":"c43b2a77755294d05b1ea602","evaluator_finished":false,"evaluator_started":true,"generation":2,"mode":"drive_stop","phase":"ready_fault","physics_tick":167,"state":"fault"}
    LIFECYCLE_FAIL: motor action reaches measured rest
    96 checks; 4 failures. Results: /home/runner/work/ssok/ssok/build/verification/SUMMARY.md
