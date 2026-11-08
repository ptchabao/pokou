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

type Step = "phone" | "code" | "pin" | "email"
type VerifyResponse = {
  access_token?: string
  two_step_required?: boolean
  verification_token?: string
}

/** Connexion de l'équipe : le même numéro et le même code SMS que l'app. */
export default function LoginPage() {
  const router = useRouter()
  const { refresh } = useAuth()
  const [step, setStep] = React.useState<Step>("phone")
  const [phone, setPhone] = React.useState("")
  const [code, setCode] = React.useState("")
  const [pin, setPin] = React.useState("")
  const [email, setEmail] = React.useState("")
  const [password, setPassword] = React.useState("")
  const [pending, setPending] = React.useState<string | null>(null)
  const [busy, setBusy] = React.useState(false)
  const [error, setError] = React.useState<string | null>(null)

  async function finish(token: string) {
    setToken(token)
    try {
      await api("/admin/me")
    } catch (e) {
      setToken(null)
      setStep(step === "email" ? "email" : "phone")
      setCode("")
      setPin("")
      throw e instanceof ApiError && e.status === 403
        ? new Error("Ce compte ne fait pas partie de l'équipe Pokou.")
        : e
    }
    await refresh()
    router.replace("/dashboard/")
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      if (step === "email") {
        const r = await api<VerifyResponse>("/admin/auth/login", { body: { email: email.trim(), password } })
        if (r.access_token) await finish(r.access_token)
      } else if (step === "phone") {
        await api("/auth/phone/request-otp", { body: { phone: phone.trim() } })
        setStep("code")
      } else if (step === "code") {
        const r = await api<VerifyResponse>("/auth/phone/verify-otp", {
          body: { phone: phone.trim(), code: code.trim() },
        })
        if (r.two_step_required && r.verification_token) {
          setPending(r.verification_token)
          setStep("pin")
        } else if (r.access_token) {
          await finish(r.access_token)
        }
      } else {
        const r = await api<VerifyResponse>("/auth/phone/two-step", {
          body: { verification_token: pending, pin: pin.trim() },
        })
        if (r.access_token) await finish(r.access_token)
      }
    } catch (err) {
      setError((err as Error).message)
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
          <CardDescription>
            {step === "phone" && "Connecte-toi avec le numéro de ton compte Pokou."}
            {step === "code" && `Saisis le code envoyé au ${phone}.`}
            {step === "pin" && "Saisis le code PIN de vérification en deux étapes."}
            {step === "email" && "Connecte-toi avec l'e-mail et le mot de passe de la console."}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={submit} className="flex flex-col gap-4">
            {step === "phone" && (
              <div className="grid gap-2">
                <Label htmlFor="phone">Numéro de téléphone</Label>
                <Input id="phone" type="tel" autoFocus placeholder="+229 01 00 00 00 00"
                  value={phone} onChange={(e) => setPhone(e.target.value)} required />
              </div>
            )}
            {step === "email" && (
              <>
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
              </>
            )}
            {step === "code" && (
              <div className="grid gap-2">
                <Label htmlFor="code">Code reçu</Label>
                <Input id="code" inputMode="numeric" autoComplete="one-time-code" autoFocus
                  value={code} onChange={(e) => setCode(e.target.value)} required minLength={4} />
              </div>
            )}
            {step === "pin" && (
              <div className="grid gap-2">
                <Label htmlFor="pin">Code PIN</Label>
                <Input id="pin" type="password" inputMode="numeric" autoFocus
                  value={pin} onChange={(e) => setPin(e.target.value)} required minLength={4} />
              </div>
            )}
            {error && (
              <Alert variant="destructive">
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            )}
            <Button type="submit" disabled={busy}>
              {busy ? "Un instant…" : step === "phone" ? "Recevoir le code" : "Se connecter"}
            </Button>
            {step === "phone" ? (
              <Button type="button" variant="ghost" onClick={() => { setStep("email"); setError(null) }}>
                Se connecter avec un e-mail
              </Button>
            ) : (
              <Button type="button" variant="ghost" onClick={() => { setStep("phone"); setError(null) }}>
                {step === "email" ? "Se connecter avec un numéro" : "Changer de numéro"}
              </Button>
            )}
          </form>
        </CardContent>
      </Card>
      </div>
    </div>
  )
}
