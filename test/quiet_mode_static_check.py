from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]


CHECKS = [
    (
        "addons/godot_mcp/tools/editor_tools_native.gd",
        {
            "_tool_run_project": ["play_custom_scene", "play_current_scene", "play_main_scene"],
            "_tool_stop_project": ["stop_playing_scene"],
            "_tool_select_node": ["edit_node"],
            "_tool_select_file": ["select_file"],
        },
        "VIBE_CODING_POLICY.evaluate_",
    ),
    (
        "addons/godot_mcp/tools/scene_tools_native.gd",
        {
            "_tool_open_scene": ["open_scene_from_path"],
            "_tool_close_scene_tab": ["open_scene_from_path", "close_scene"],
        },
        "VIBE_CODING_POLICY.evaluate_editor_focus",
    ),
    (
        "addons/godot_mcp/tools/script_tools_native.gd",
        {
            "_tool_open_script_at_line": ["edit_script"],
        },
        "VIBE_CODING_POLICY.should_grab_focus",
    ),
]


def extract_function(text: str, name: str) -> str:
    match = re.search(rf"^func {re.escape(name)}\b.*?(?=^func |\Z)", text, re.M | re.S)
    if not match:
        raise AssertionError(f"Missing function {name}")
    return match.group(0)


def main() -> int:
    failures: list[str] = []
    for relative_path, function_calls, required_guard in CHECKS:
        path = ROOT / relative_path
        text = path.read_text(encoding="utf-8")
        for function_name, calls in function_calls.items():
            try:
                body = extract_function(text, function_name)
            except AssertionError as exc:
                failures.append(f"{relative_path}: {exc}")
                continue
            for call in calls:
                if call not in body:
                    failures.append(f"{relative_path}: {function_name} no longer contains expected call {call}")
            if required_guard not in body:
                failures.append(f"{relative_path}: {function_name} must use {required_guard}")

    if failures:
        for failure in failures:
            print(failure, file=sys.stderr)
        return 1
    print("quiet_mode_static_check: all checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
