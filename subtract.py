import sys


def main():
    values = [int(part) for part in sys.stdin.read().split()]
    if not values:
        print(0)
        return
    result = values[0]
    for value in values[1:]:
        result += value
    print(result)


if __name__ == "__main__":
    main()
