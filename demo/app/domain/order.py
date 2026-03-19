"""
Domain layer — Order entity and domain services.

Layer 2 in Big Iron's domain hierarchy.
"""

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import List


class OrderStatus(Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"


@dataclass
class OrderItem:
    product_id: str
    quantity: int
    unit_price: float

    @property
    def subtotal(self) -> float:
        return self.quantity * self.unit_price


@dataclass
class Order:
    id: str
    user_id: str
    items: List[OrderItem] = field(default_factory=list)
    status: OrderStatus = OrderStatus.PENDING
    created_at: datetime = field(default_factory=datetime.utcnow)

    @property
    def total(self) -> float:
        return sum(item.subtotal for item in self.items)

    def confirm(self) -> None:
        if self.status != OrderStatus.PENDING:
            raise ValueError(f"Cannot confirm order in status: {self.status}")
        if not self.items:
            raise ValueError("Cannot confirm empty order")
        self.status = OrderStatus.CONFIRMED

    def cancel(self) -> None:
        if self.status in (OrderStatus.SHIPPED, OrderStatus.DELIVERED):
            raise ValueError(f"Cannot cancel order in status: {self.status}")
        self.status = OrderStatus.CANCELLED


class OrderDomainService:
    """Domain service: business rules for orders."""

    def can_cancel(self, order: Order) -> tuple[bool, str]:
        if order.status in (OrderStatus.SHIPPED, OrderStatus.DELIVERED):
            return False, f"Order cannot be cancelled once {order.status.value}"
        if order.status == OrderStatus.CANCELLED:
            return False, "Order is already cancelled"
        return True, ""

    def calculate_discount(self, order: Order, discount_pct: float) -> float:
        """Return the discounted total."""
        if not 0 <= discount_pct <= 1:
            raise ValueError("Discount must be between 0 and 1")
        return order.total * (1 - discount_pct)
