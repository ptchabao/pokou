import logging
from typing import Optional, Dict, Any
from sqlalchemy.orm import Session
from app.models import AuditLog

logger = logging.getLogger(__name__)


class AuditLogger:
    """Handle audit logging for sensitive operations."""
    
    @staticmethod
    async def log(
        db: Session,
        user_id: int,
        action: str,
        entity_type: str,
        entity_id: Optional[int] = None,
        changes: Optional[Dict[str, Any]] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None
    ) -> AuditLog:
        """Log an audit event."""
        
        audit_log = AuditLog(
            user_id=user_id,
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            changes=changes,
            ip_address=ip_address,
            user_agent=user_agent
        )
        
        db.add(audit_log)
        db.commit()
        db.refresh(audit_log)
        
        logger.info(
            f"Audit: User {user_id} performed {action} on {entity_type} (id={entity_id})",
            extra={
                "user_id": user_id,
                "action": action,
                "entity_type": entity_type,
                "entity_id": entity_id,
                "ip_address": ip_address
            }
        )
        
        return audit_log
    
    @staticmethod
    async def log_batch(
        db: Session,
        user_id: int,
        action: str,
        entity_type: str,
        changes: Dict[str, Any],
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None
    ) -> None:
        """Log multiple related audit events at once."""
        
        audit_log = AuditLog(
            user_id=user_id,
            action=action,
            entity_type=entity_type,
            changes=changes,
            ip_address=ip_address,
            user_agent=user_agent
        )
        
        db.add(audit_log)
        db.commit()
