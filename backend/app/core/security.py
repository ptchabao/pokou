from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from jose import JWTError, jwt
import bcrypt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.core.config import get_settings
from app.core.database import get_db

# Using bcrypt directly, no passlib
settings = get_settings()


# JWT Security
# auto_error=False so callers without an Authorization header fall through
# to the cookie-based flow (used by admin/, see get_current_user) instead of
# HTTPBearer short-circuiting with a 403 before we get a chance to check it.
security = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    """Hash a password using bcrypt directly. Max: 72 bytes."""
    pwd_len = len(password.encode('utf-8'))
    if pwd_len > 72:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password exceeds 72 byte limit"
        )
    # Hash with bcrypt, cost=12
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(password.encode(), salt).decode('utf-8')


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a bcrypt password hash."""
    try:
        return bcrypt.checkpw(plain_password.encode(), hashed_password.encode())
    except ValueError:
        return False


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None, jti: Optional[str] = None) -> str:
    """Create a JWT access token. `jti` ties this token to a `Token` DB row
    so it can be revoked (see app/routes/auth.py's /login and /logout) —
    tokens minted without a jti (or issued before this existed) simply
    aren't revocable and remain valid until they expire naturally."""
    to_encode = data.copy()

    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.access_token_expire_minutes)

    to_encode.update({"exp": expire, "type": "access"})
    if jti:
        to_encode["jti"] = jti

    encoded_jwt = jwt.encode(
        to_encode,
        settings.secret_key,
        algorithm=settings.algorithm
    )

    return encoded_jwt


def create_refresh_token(data: dict, jti: Optional[str] = None) -> str:
    """Create a JWT refresh token. See create_access_token for `jti`."""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=settings.refresh_token_expire_days)

    to_encode.update({"exp": expire, "type": "refresh"})
    if jti:
        to_encode["jti"] = jti

    encoded_jwt = jwt.encode(
        to_encode,
        settings.secret_key,
        algorithm=settings.algorithm
    )

    return encoded_jwt


def verify_token(token: str, token_type: str = "access") -> Dict[str, Any]:
    """Verify and decode a JWT token."""
    try:
        payload = jwt.decode(
            token,
            settings.secret_key,
            algorithms=[settings.algorithm]
        )
        
        if payload.get("type") != token_type:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )


def _reject_if_revoked(db: Session, payload: Dict[str, Any]) -> None:
    """Tokens minted with a `jti` (see create_access_token) must map to a
    non-revoked Token row. Tokens without a jti (legacy, or minted before
    this existed) skip this check — they remain valid until they expire
    naturally, there's simply no way to revoke them early."""
    jti = payload.get("jti")
    if not jti:
        return

    from app.models import Token

    token_row = db.query(Token).filter(Token.jti == jti).first()
    if token_row is None or token_row.revoked_at is not None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session révoquée",
            headers={"WWW-Authenticate": "Bearer"},
        )


def get_current_user(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db),
) -> Dict[str, Any]:
    """Get the current user from the Authorization header, falling back to
    the `access_token` httpOnly cookie (used by admin/, which never reads
    the token in JS — see app/routes/auth.py's /login)."""
    token = credentials.credentials if credentials is not None else request.cookies.get("access_token")
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    payload = verify_token(token, "access")
    _reject_if_revoked(db, payload)
    return payload
