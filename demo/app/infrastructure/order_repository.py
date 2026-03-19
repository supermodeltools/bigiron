"""
Infrastructure layer — Order persistence.

Layer 3 in Big Iron's domain hierarchy.
"""

from typing import Dict, List, Optional
from app.domain.order import Order, OrderStatus


class InMemoryOrderRepository:
    """In-memory order store."""

    def __init__(self) -> None:
        self._orders: Dict[str, Order] = {}

    def save(self, order: Order) -> None:
        self._orders[order.id] = order

    def find_by_id(self, order_id: str) -> Optional[Order]:
        return self._orders.get(order_id)

    def find_by_user(self, user_id: str) -> List[Order]:
        return [o for o in self._orders.values() if o.user_id == user_id]

    def find_by_status(self, status: OrderStatus) -> List[Order]:
        return [o for o in self._orders.values() if o.status == status]

    def delete(self, order_id: str) -> None:
        self._orders.pop(order_id, None)
