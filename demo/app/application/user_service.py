"""
Application layer — User use cases.

Layer 1 in Big Iron's domain hierarchy.
May call: Layer 2 (domain), Layer 3 (infrastructure).
Must not call: Layer 0 (orchestration).
"""

import uuid
from app.domain.user import User, UserCredentials, UserDomainService
from app.infrastructure.user_repository import InMemoryUserRepository


class UserService:
    """Orchestrates user-related use cases."""

    def __init__(
        self,
        repo: InMemoryUserRepository,
        domain_service: UserDomainService,
    ) -> None:
        self._repo = repo
        self._domain = domain_service

    def register(self, email: str, name: str, password: str) -> User:
        """Register a new user. Raises ValueError on invalid input."""
        if not self._domain.validate_email(email):
            raise ValueError(f"Invalid email: {email}")

        if self._repo.find_by_email(email):
            raise ValueError(f"Email already registered: {email}")

        user = User(id=str(uuid.uuid4()), email=email, name=name)
        creds = UserCredentials(
            user_id=user.id,
            password_hash=InMemoryUserRepository.hash_password(password),
        )
        self._repo.save(user)
        self._repo.save_credentials(creds)
        return user

    def authenticate(self, email: str, password: str) -> User:
        """Authenticate a user by email and password. Raises on failure."""
        user = self._repo.find_by_email(email)
        if not user or not user.is_active:
            raise ValueError("Invalid credentials")

        creds = self._repo.find_credentials(user.id)
        expected_hash = InMemoryUserRepository.hash_password(password)
        if not creds or creds.password_hash != expected_hash:
            raise ValueError("Invalid credentials")

        creds.record_login()
        return user

    def deactivate(self, user_id: str) -> None:
        """Deactivate a user account."""
        user = self._repo.find_by_id(user_id)
        if not user:
            raise ValueError(f"User not found: {user_id}")

        allowed, reason = self._domain.can_deactivate(user)
        if not allowed:
            raise ValueError(reason)

        user.deactivate()
        self._repo.save(user)

    def get_user(self, user_id: str) -> User:
        user = self._repo.find_by_id(user_id)
        if not user:
            raise ValueError(f"User not found: {user_id}")
        return user
