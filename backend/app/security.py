from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

hasher = PasswordHasher()

def hash_password(password):
    return hasher.hash(password)

def verify_password(password, hashed_password):
    try:
        hasher.verify(hashed_password, password)
        return True
    except VerifyMismatchError:
        return False
