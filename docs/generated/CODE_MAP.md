# 파일 구조와 코드 위치

자동 생성: `python3 tools/docs/maintain.py --write`. 이 checkout의 위치 지도이며 구현 검증 보고서가 아니에요.
수정 진입점은 [START_HERE](../START_HERE.md), 데이터 관계는 [DATA_MODEL](../DATA_MODEL.md)를 읽어요.

## 디렉터리 트리

```text
ssok/
  project.godot
  scenes/
    main.gd
  src/
    assembly/  (3 GDScript files)
    blocks/  (1 GDScript files)
    core/  (8 GDScript files)
    profiles/  (1 GDScript files)
    runtime/  (19 GDScript files)
    ui/  (16 GDScript files)
  presets/
  assets/
    blender/
    branding/
    construction_kit/
    fonts/
    humanoid/
    icons/
    kenney/
    learning_biped/
    locales/
    materials/
    meshes/
    modular_humanoid/
    parts/
    policies/
  addons/
    beehave/
    godot_state_charts/
  tests/
    fixtures/
  tools/
    app_control/
    blender/
    ci/
    docs/
    godot/
    localization/
    motion_lab/
    release/
    rl_lab/
  .github/
    workflows/
  docs/
    START_HERE.md / STATUS.md
    DATA_MODEL.md / FLOWS.md
    POLICIES.md / MAINTENANCE.md
    context.json
    adr/
    generated/
    evidence/  (open only relevant reports)
```

## 자체 GDScript 클래스 위치

서드파티 내부와 빌드 산출물은 펼치지 않아요. `.uid`는 클래스 본문이 아니에요.

| 파일 | 선언된 클래스 |
|---|---|
| [presets/biped.gd](../../presets/biped.gd) | BipedPreset |
| [presets/biped_gait.gd](../../presets/biped_gait.gd) | BipedGait |
| [presets/biped_motion.gd](../../presets/biped_motion.gd) | BipedMotion |
| [presets/construction_kit_humanoid.gd](../../presets/construction_kit_humanoid.gd) | ConstructionKitHumanoidPreset |
| [presets/humanoid.gd](../../presets/humanoid.gd) | HumanoidPreset |
| [presets/humanoid_motion.gd](../../presets/humanoid_motion.gd) | HumanoidMotion |
| [presets/modular_humanoid.gd](../../presets/modular_humanoid.gd) | ModularHumanoidPreset |
| [presets/robot_car.gd](../../presets/robot_car.gd) | RobotCarPreset |
| [presets/servo_arm.gd](../../presets/servo_arm.gd) | ServoArmPreset |
| [presets/yaw_biped.gd](../../presets/yaw_biped.gd) | YawBipedPreset |
| [scenes/main.gd](../../scenes/main.gd) | (scene script) |
| [src/assembly/assembly_mode.gd](../../src/assembly/assembly_mode.gd) | AssemblyMode |
| [src/assembly/part_node.gd](../../src/assembly/part_node.gd) | PartNode |
| [src/assembly/transform_gizmo.gd](../../src/assembly/transform_gizmo.gd) | TransformGizmo |
| [src/blocks/servo_program.gd](../../src/blocks/servo_program.gd) | ServoProgram |
| [src/core/app_controller.gd](../../src/core/app_controller.gd) | AppController |
| [src/core/board_profile.gd](../../src/core/board_profile.gd) | BoardProfile |
| [src/core/connection_graph.gd](../../src/core/connection_graph.gd) | ConnectionGraph |
| [src/core/part_def.gd](../../src/core/part_def.gd) | PartDef |
| [src/core/port.gd](../../src/core/port.gd) | Port |
| [src/core/project_store.gd](../../src/core/project_store.gd) | ProjectStore |
| [src/core/stage_catalog.gd](../../src/core/stage_catalog.gd) | StageCatalog |
| [src/core/stage_definition.gd](../../src/core/stage_definition.gd) | StageDefinition |
| [src/profiles/learner_program.gd](../../src/profiles/learner_program.gd) | LearnerProgram |
| [src/runtime/bundled_biped_motion.gd](../../src/runtime/bundled_biped_motion.gd) | BundledBipedMotion |
| [src/runtime/drive_motor.gd](../../src/runtime/drive_motor.gd) | DriveMotor |
| [src/runtime/kit_humanoid_motion.gd](../../src/runtime/kit_humanoid_motion.gd) | KitHumanoidMotion |
| [src/runtime/learned_biped_motion.gd](../../src/runtime/learned_biped_motion.gd) | LearnedBipedMotion |
| [src/runtime/manual_controller.gd](../../src/runtime/manual_controller.gd) | ManualController |
| [src/runtime/mini_runtime.gd](../../src/runtime/mini_runtime.gd) | MiniRuntime |
| [src/runtime/motion_lab_client.gd](../../src/runtime/motion_lab_client.gd) | MotionLabClient |
| [src/runtime/motion_policy.gd](../../src/runtime/motion_policy.gd) | MotionPolicy |
| [src/runtime/motion_snapshot.gd](../../src/runtime/motion_snapshot.gd) | MotionSnapshot |
| [src/runtime/motion_trial.gd](../../src/runtime/motion_trial.gd) | MotionTrial |
| [src/runtime/pickup_policy.gd](../../src/runtime/pickup_policy.gd) | PickupPolicy |
| [src/runtime/pickup_scenario_store.gd](../../src/runtime/pickup_scenario_store.gd) | PickupScenarioStore |
| [src/runtime/pickup_trial.gd](../../src/runtime/pickup_trial.gd) | PickupTrial |
| [src/runtime/robot_motion_program.gd](../../src/runtime/robot_motion_program.gd) | RobotMotionProgram |
| [src/runtime/run_mode.gd](../../src/runtime/run_mode.gd) | RunMode |
| [src/runtime/servo_drive.gd](../../src/runtime/servo_drive.gd) | ServoDrive |
| [src/runtime/sonar_sensor.gd](../../src/runtime/sonar_sensor.gd) | SonarSensor |
| [src/runtime/stage_evaluator.gd](../../src/runtime/stage_evaluator.gd) | StageEvaluator |
| [src/runtime/wiring.gd](../../src/runtime/wiring.gd) | Wiring |
| [src/ui/blender_camera.gd](../../src/ui/blender_camera.gd) | BlenderCamera |
| [src/ui/block_program_panel.gd](../../src/ui/block_program_panel.gd) | BlockProgramPanel |
| [src/ui/browser_evidence.gd](../../src/ui/browser_evidence.gd) | BrowserEvidence |
| [src/ui/flag_mission.gd](../../src/ui/flag_mission.gd) | FlagMission |
| [src/ui/fly_camera.gd](../../src/ui/fly_camera.gd) | FlyCamera |
| [src/ui/interface_preferences.gd](../../src/ui/interface_preferences.gd) | InterfacePreferences |
| [src/ui/motion_lab_panel.gd](../../src/ui/motion_lab_panel.gd) | MotionLabPanel |
| [src/ui/pickup_lab_panel.gd](../../src/ui/pickup_lab_panel.gd) | PickupLabPanel |
| [src/ui/project_panel.gd](../../src/ui/project_panel.gd) | ProjectPanel |
| [src/ui/settings_panel.gd](../../src/ui/settings_panel.gd) | SettingsPanel |
| [src/ui/ssok_locale.gd](../../src/ui/ssok_locale.gd) | SsokLocale |
| [src/ui/ssok_theme.gd](../../src/ui/ssok_theme.gd) | SsokTheme |
| [src/ui/stage_panel.gd](../../src/ui/stage_panel.gd) | StagePanel |
| [src/ui/tutorial_panel.gd](../../src/ui/tutorial_panel.gd) | TutorialPanel |
| [src/ui/web_clipboard.gd](../../src/ui/web_clipboard.gd) | WebClipboard |
| [src/ui/wiring_panel.gd](../../src/ui/wiring_panel.gd) | WiringPanel |

보드와 언어는 논리 계층이에요. 실제 BoardProfile은 `src/core/`, MiniRuntime은
`src/runtime/`에 있어요. `src/profiles/`의 폴더 존재만으로 구현을 판단하지 않아요.
