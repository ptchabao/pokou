"use client"

import * as React from "react"
import { useRouter } from "next/navigation"

import { api, ApiError, setToken } from "@/lib/api"
import { useAuth } from "@/lib/auth"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Illustration } from "@/components/illustration"

/** Connexion de l'équipe : e-mail et mot de passe de la console, jamais le
 * numéro de téléphone de l'app. */
export default function LoginPage() {
  const router = useRouter()
  const { refresh } = useAuth()
  const [email, setEmail] = React.useState("")
  const [password, setPassword] = React.useState("")
  const [busy, setBusy] = React.useState(false)
  const [error, setError] = React.useState<string | null>(null)

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      const r = await api<{ access_token: string }>("/admin/auth/login", {
        body: { email: email.trim(), password },
      })
      setToken(r.access_token)
      await refresh()
      router.replace("/dashboard/")
    } catch (err) {
      setToken(null)
      setError(err instanceof ApiError && err.status === 403
        ? "Ce compte n'a pas accès à la console."
        : (err as Error).message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="grid min-h-svh bg-background lg:grid-cols-2">
      <div className="hidden flex-col justify-center gap-6 bg-secondary p-12 lg:flex">
        <Illustration name="login" className="mx-auto h-72" />
        <div className="mx-auto max-w-md text-center">
          <h2 className="text-xl font-semibold">L&apos;équipe Pokou</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Modération, services et équipe, au même endroit. Chaque action est tracée dans le journal d&apos;audit.
          </p>
        </div>
      </div>
      <div className="flex items-center justify-center p-4">
        <Card className="w-full max-w-sm">
          <CardHeader>
            <div className="mb-2 flex size-10 items-center justify-center rounded-xl bg-primary text-lg font-bold text-primary-foreground">
              P
            </div>
            <CardTitle>Console Pokou</CardTitle>
            <CardDescription>Connecte-toi avec ton e-mail d&apos;équipe et ton mot de passe.</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={submit} className="flex flex-col gap-4">
              <div className="grid gap-2">
                <Label htmlFor="email">E-mail</Label>
                <Input id="email" type="email" autoFocus autoComplete="username"
                  value={email} onChange={(e) => setEmail(e.target.value)} required />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="password">Mot de passe</Label>
                <Input id="password" type="password" autoComplete="current-password"
                  value={password} onChange={(e) => setPassword(e.target.value)} required />
              </div>
              {error && (
                <Alert variant="destructive">
                  <AlertDescription>{error}</AlertDescription>
                </Alert>
              )}
              <Button type="submit" disabled={busy}>{busy ? "Un instant…" : "Se connecter"}</Button>
              <p className="text-center text-xs text-muted-foreground">
                Mot de passe perdu ? Un super-administrateur peut t&apos;en donner un nouveau.
              </p>
            </form>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
