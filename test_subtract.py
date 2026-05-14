import subprocess
import sys


def run_subtract(text):
    proc = subprocess.run(
        [sys.executable, "subtract.py"],
        input=text,
        text=True,
        capture_output=True,
        check=True,
    )
    return proc.stdout.strip()


def test_subtracts_following_values_from_first():
    assert run_subtract("10 3 2\n") == "5"


def test_empty_input_is_zero():
    assert run_subtract("\n") == "0"


if __name__ == "__main__":
    test_subtracts_following_values_from_first()
    test_empty_input_is_zero()
