"""
Domain layer — User entity and domain services.

Layer 2 in Big Iron's domain hierarchy.
May call: Layer 3 (infrastructure).
Must not call: Layer 0 (orchestration) or Layer 1 (application).
"""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


@dataclass
class User:
    id: str
    email: str
    name: str
    created_at: datetime = field(default_factory=datetime.utcnow)
    is_active: bool = True

    def deactivate(self) -> None:
        self.is_active = False

    def rename(self, new_name: str) -> None:
        if not new_name.strip():
            raise ValueError("Name cannot be empty")
        self.name = new_name.strip()


@dataclass
class UserCredentials:
    user_id: str
    password_hash: str
    last_login: Optional[datetime] = None

    def record_login(self) -> None:
        self.last_login = datetime.utcnow()


class UserDomainService:
    """Domain service: business rules that operate on User entities."""

    def validate_email(self, email: str) -> bool:
        """Basic email format validation."""
        return "@" in email and "." in email.split("@")[-1]

    def can_deactivate(self, user: User) -> tuple[bool, str]:
        """Check if a user can be deactivated. Returns (allowed, reason)."""
        if not user.is_active:
            return False, "User is already inactive"
        return True, ""
