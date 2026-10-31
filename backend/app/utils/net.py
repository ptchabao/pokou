"""Garde-fous réseau partagés."""
import ipaddress
import socket
from urllib.parse import urlparse


def is_publicly_routable_url(url: str) -> bool:
    """Basic anti-SSRF guard: http(s) only, and the hostname must resolve to
    a public IP (rejects localhost, private/link-local/loopback/reserved
    ranges, and anything that fails to resolve). Not a full SSRF defense
    (doesn't cover DNS rebinding between check-time and request-time) but
    stops the obvious cases for a self-service "any public URL" webhook."""
    try:
        parsed = urlparse(url)
        if parsed.scheme not in ("http", "https"):
            return False
        host = parsed.hostname
        if not host:
            return False
        if host in ("localhost",):
            return False
        ip = ipaddress.ip_address(socket.gethostbyname(host))
        if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved or ip.is_multicast:
            return False
        return True
    except (socket.gaierror, ValueError, UnicodeError):
        return False

