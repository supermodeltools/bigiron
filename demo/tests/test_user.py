"""
Tests: User domain and application layer.

Executed in Phase 5 (dependency-ordered testing).
Leaf tests (domain) run before caller tests (application).
"""

import pytest
from app.domain.user import User, UserCredentials, UserDomainService
from app.application.user_service import UserService
from app.infrastructure.user_repository import InMemoryUserRepository


# ---------------------------------------------------------------------------
# Leaf: Domain layer tests (run first — no callers above this)
# ---------------------------------------------------------------------------

class TestUserEntity:
    def test_deactivate(self):
        user = User(id="1", email="a@b.com", name="Alice")
        assert user.is_active
        user.deactivate()
        assert not user.is_active

    def test_rename(self):
        user = User(id="1", email="a@b.com", name="Alice")
        user.rename("Bob")
        assert user.name == "Bob"

    def test_rename_empty_raises(self):
        user = User(id="1", email="a@b.com", name="Alice")
        with pytest.raises(ValueError):
            user.rename("   ")


class TestUserDomainService:
    def setup_method(self):
        self.svc = UserDomainService()

    def test_validate_email_valid(self):
        assert self.svc.validate_email("user@example.com")

    def test_validate_email_invalid(self):
        assert not self.svc.validate_email("notanemail")

    def test_can_deactivate_active(self):
        user = User(id="1", email="a@b.com", name="Alice")
        ok, _ = self.svc.can_deactivate(user)
        assert ok

    def test_can_deactivate_already_inactive(self):
        user = User(id="1", email="a@b.com", name="Alice", is_active=False)
        ok, reason = self.svc.can_deactivate(user)
        assert not ok
        assert "already" in reason


# ---------------------------------------------------------------------------
# Caller: Application layer tests (run after domain tests pass)
# ---------------------------------------------------------------------------

class TestUserService:
    def setup_method(self):
        self.repo = InMemoryUserRepository()
        self.service = UserService(self.repo, UserDomainService())

    def test_register_success(self):
        user = self.service.register("alice@example.com", "Alice", "secret")
        assert user.email == "alice@example.com"
        assert user.is_active

    def test_register_invalid_email(self):
        with pytest.raises(ValueError, match="Invalid email"):
            self.service.register("notanemail", "Alice", "secret")

    def test_register_duplicate_email(self):
        self.service.register("alice@example.com", "Alice", "secret")
        with pytest.raises(ValueError, match="already registered"):
            self.service.register("alice@example.com", "Alice2", "secret2")

    def test_authenticate_success(self):
        self.service.register("alice@example.com", "Alice", "secret")
        user = self.service.authenticate("alice@example.com", "secret")
        assert user.email == "alice@example.com"

    def test_authenticate_wrong_password(self):
        self.service.register("alice@example.com", "Alice", "secret")
        with pytest.raises(ValueError, match="Invalid credentials"):
            self.service.authenticate("alice@example.com", "wrong")

    def test_deactivate_user(self):
        user = self.service.register("alice@example.com", "Alice", "secret")
        self.service.deactivate(user.id)
        fetched = self.service.get_user(user.id)
        assert not fetched.is_active

    def test_deactivate_already_inactive(self):
        user = self.service.register("alice@example.com", "Alice", "secret")
        self.service.deactivate(user.id)
        with pytest.raises(ValueError, match="already"):
            self.service.deactivate(user.id)
