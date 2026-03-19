"""
Infrastructure layer — User persistence.

Layer 3 in Big Iron's domain hierarchy.
Provides storage capabilities consumed by the application layer.
Must not call: Layer 0, 1, or 2.
"""

from typing import Dict, Optional
from app.domain.user import User, UserCredentials
import hashlib


class InMemoryUserRepository:
    """In-memory user store. Replace with a real DB adapter in production."""

    def __init__(self) -> None:
        self._users: Dict[str, User] = {}
        self._credentials: Dict[str, UserCredentials] = {}

    def save(self, user: User) -> None:
        self._users[user.id] = user

    def find_by_id(self, user_id: str) -> Optional[User]:
        return self._users.get(user_id)

    def find_by_email(self, email: str) -> Optional[User]:
        return next(
            (u for u in self._users.values() if u.email == email),
            None
        )

    def delete(self, user_id: str) -> None:
        self._users.pop(user_id, None)
        self._credentials.pop(user_id, None)

    def save_credentials(self, creds: UserCredentials) -> None:
        self._credentials[creds.user_id] = creds

    def find_credentials(self, user_id: str) -> Optional[UserCredentials]:
        return self._credentials.get(user_id)

    @staticmethod
    def hash_password(password: str) -> str:
        return hashlib.sha256(password.encode()).hexdigest()
