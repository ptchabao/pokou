import type { NextConfig } from "next"

// L'espace d'administration est servi par l'API elle-même, sous /console
// (même origine : pas de CORS, le jeton ne quitte pas le domaine).
const nextConfig: NextConfig = {
  output: "export",
  basePath: "/console",
  trailingSlash: true,
  images: { unoptimized: true },
  eslint: { ignoreDuringBuilds: true },
}

export default nextConfig
