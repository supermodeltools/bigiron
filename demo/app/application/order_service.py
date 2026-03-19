"""
Application layer — Order use cases.

Layer 1 in Big Iron's domain hierarchy.
"""

import uuid
from typing import List
from app.domain.order import Order, OrderItem, OrderDomainService
from app.infrastructure.order_repository import InMemoryOrderRepository
from app.infrastructure.user_repository import InMemoryUserRepository


class OrderService:
    """Orchestrates order-related use cases."""

    def __init__(
        self,
        order_repo: InMemoryOrderRepository,
        user_repo: InMemoryUserRepository,
        domain_service: OrderDomainService,
    ) -> None:
        self._orders = order_repo
        self._users = user_repo
        self._domain = domain_service

    def create_order(self, user_id: str, items: List[dict]) -> Order:
        """Create a new order for a user."""
        user = self._users.find_by_id(user_id)
        if not user or not user.is_active:
            raise ValueError(f"User not found or inactive: {user_id}")

        order_items = [
            OrderItem(
                product_id=i["product_id"],
                quantity=i["quantity"],
                unit_price=i["unit_price"],
            )
            for i in items
        ]

        order = Order(id=str(uuid.uuid4()), user_id=user_id, items=order_items)
        self._orders.save(order)
        return order

    def confirm_order(self, order_id: str) -> Order:
        order = self._orders.find_by_id(order_id)
        if not order:
            raise ValueError(f"Order not found: {order_id}")
        order.confirm()
        self._orders.save(order)
        return order

    def cancel_order(self, order_id: str) -> Order:
        order = self._orders.find_by_id(order_id)
        if not order:
            raise ValueError(f"Order not found: {order_id}")

        allowed, reason = self._domain.can_cancel(order)
        if not allowed:
            raise ValueError(reason)

        order.cancel()
        self._orders.save(order)
        return order

    def get_user_orders(self, user_id: str) -> List[Order]:
        return self._orders.find_by_user(user_id)
