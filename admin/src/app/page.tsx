"use client"

import { useEffect } from "react"
import { useRouter } from "next/navigation"
import { useAuth } from "@/lib/auth"

export default function Home() {
  const { me, loading } = useAuth()
  const router = useRouter()
  useEffect(() => {
    if (!loading) router.replace(me ? "/dashboard/" : "/login/")
  }, [me, loading, router])
  return <div className="p-10 text-sm text-muted-foreground">Chargement…</div>
}
