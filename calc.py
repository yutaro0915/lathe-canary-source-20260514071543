import sys


def main():
    values = [int(part) for part in sys.stdin.read().split()]
    result = 1
    for value in values:
        result *= value
    print(result)


if __name__ == "__main__":
    main()
