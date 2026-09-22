"""An engine error must fail an ordinary suite even when the child exits zero."""

from contextlib import redirect_stdout
import io
from pathlib import Path
import sys
import tempfile
import unittest

from tools.ci.verify import Check, run


class VerifyProcessResultTest(unittest.TestCase):
    def test_process_exit_and_engine_diagnostics_both_control_success(self):
        cases = [
            ("ERROR: negative Rect2", 0, False, True),
            ("SCRIPT ERROR: invalid call", 0, False, True),
            ("WARNING: optional diagnostic", 0, True, False),
            ("ordinary assertion failed", 1, False, False),
        ]
        with tempfile.TemporaryDirectory(prefix="ssok-verify-runner-") as temporary:
            for index, (message, exit_code, passed, engine_error) in enumerate(cases):
                with self.subTest(message=message):
                    check = Check(f"ordinary-suite-{index}", [sys.executable, "-c",
                        "import sys; print(sys.argv[1], file=sys.stderr); sys.exit(int(sys.argv[2]))",
                        message, str(exit_code)])
                    # Expected child failures are inspected here, not emitted as test-runner errors.
                    with redirect_stdout(io.StringIO()):
                        result = run(check, Path(temporary), {})
                    self.assertEqual(result["passed"], passed)
                    self.assertEqual(result["engine_error"], engine_error)
                    self.assertEqual(result["exit_code"], exit_code)
                    self.assertIn(message, (Path(temporary) / result["log"]).read_text())


if __name__ == "__main__":
    unittest.main()
