"""
Tests: Order domain and application layer.

Executed in Phase 5 (dependency-ordered testing).
Leaf tests (domain) run before caller tests (application).
"""

import pytest
from app.domain.order import Order, OrderItem, OrderStatus, OrderDomainService
from app.application.order_service import OrderService
from app.infrastructure.order_repository import InMemoryOrderRepository
from app.infrastructure.user_repository import InMemoryUserRepository
from app.domain.user import User


# ---------------------------------------------------------------------------
# Leaf: Domain layer tests
# ---------------------------------------------------------------------------

class TestOrderEntity:
    def _make_order(self):
        return Order(
            id="o1",
            user_id="u1",
            items=[OrderItem(product_id="p1", quantity=2, unit_price=10.0)],
        )

    def test_total(self):
        order = self._make_order()
        assert order.total == 20.0

    def test_confirm(self):
        order = self._make_order()
        order.confirm()
        assert order.status == OrderStatus.CONFIRMED

    def test_confirm_empty_raises(self):
        order = Order(id="o1", user_id="u1")
        with pytest.raises(ValueError, match="empty"):
            order.confirm()

    def test_cancel(self):
        order = self._make_order()
        order.cancel()
        assert order.status == OrderStatus.CANCELLED

    def test_cancel_shipped_raises(self):
        order = self._make_order()
        order.confirm()
        order.status = OrderStatus.SHIPPED
        with pytest.raises(ValueError):
            order.cancel()


class TestOrderDomainService:
    def setup_method(self):
        self.svc = OrderDomainService()

    def _make_order(self, status=OrderStatus.PENDING):
        o = Order(
            id="o1",
            user_id="u1",
            items=[OrderItem(product_id="p1", quantity=1, unit_price=5.0)],
        )
        o.status = status
        return o

    def test_can_cancel_pending(self):
        ok, _ = self.svc.can_cancel(self._make_order(OrderStatus.PENDING))
        assert ok

    def test_cannot_cancel_shipped(self):
        ok, reason = self.svc.can_cancel(self._make_order(OrderStatus.SHIPPED))
        assert not ok
        assert "shipped" in reason.lower()

    def test_calculate_discount(self):
        order = self._make_order()
        discounted = self.svc.calculate_discount(order, 0.1)
        assert abs(discounted - 4.5) < 0.001

    def test_discount_out_of_range(self):
        order = self._make_order()
        with pytest.raises(ValueError):
            self.svc.calculate_discount(order, 1.5)


# ---------------------------------------------------------------------------
# Caller: Application layer tests
# ---------------------------------------------------------------------------

class TestOrderService:
    def setup_method(self):
        self.order_repo = InMemoryOrderRepository()
        self.user_repo = InMemoryUserRepository()
        self.service = OrderService(
            self.order_repo, self.user_repo, OrderDomainService()
        )
        # seed a user
        self.user = User(id="u1", email="a@b.com", name="Alice")
        self.user_repo.save(self.user)

    def _items(self):
        return [{"product_id": "p1", "quantity": 2, "unit_price": 15.0}]

    def test_create_order(self):
        order = self.service.create_order("u1", self._items())
        assert order.user_id == "u1"
        assert order.total == 30.0

    def test_create_order_inactive_user(self):
        self.user.deactivate()
        self.user_repo.save(self.user)
        with pytest.raises(ValueError, match="inactive"):
            self.service.create_order("u1", self._items())

    def test_confirm_order(self):
        order = self.service.create_order("u1", self._items())
        confirmed = self.service.confirm_order(order.id)
        assert confirmed.status == OrderStatus.CONFIRMED

    def test_cancel_order(self):
        order = self.service.create_order("u1", self._items())
        cancelled = self.service.cancel_order(order.id)
        assert cancelled.status == OrderStatus.CANCELLED

    def test_cancel_confirmed_order(self):
        order = self.service.create_order("u1", self._items())
        self.service.confirm_order(order.id)
        cancelled = self.service.cancel_order(order.id)
        assert cancelled.status == OrderStatus.CANCELLED

    def test_get_user_orders(self):
        self.service.create_order("u1", self._items())
        self.service.create_order("u1", self._items())
        orders = self.service.get_user_orders("u1")
        assert len(orders) == 2
