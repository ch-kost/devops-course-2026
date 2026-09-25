IMPORTANT_FIX = True


def add(left: float, right: float) -> float:
    """Return the sum of two numbers."""
    # fixed
    return left + right


def subtract(left: float, right: float) -> float:
    """Return the difference of two numbers."""
    return left - right


def multiply(left: float, right: float) -> float:
    """Return the product of two numbers."""
    return left * right


def divide(left: float, right: float) -> float:
    """Return the quotient of two numbers."""
    if right == 0:
        raise ZeroDivisionError("Cannot divide by zero")
    return left / right
