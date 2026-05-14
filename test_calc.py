import subprocess
import sys


def run_calc(text):
    proc = subprocess.run(
        [sys.executable, "calc.py"],
        input=text,
        text=True,
        capture_output=True,
        check=True,
    )
    return proc.stdout.strip()


def test_multiplies_whitespace_separated_ints():
    assert run_calc("2 3\n4\n") == "24"


def test_empty_input_is_one():
    assert run_calc("\n") == "1"


if __name__ == "__main__":
    test_multiplies_whitespace_separated_ints()
    test_empty_input_is_one()
