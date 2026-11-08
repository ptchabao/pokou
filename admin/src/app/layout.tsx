import type { Metadata } from "next"
import "./globals.css"
import { AuthProvider } from "@/lib/auth"
import { TooltipProvider } from "@/components/ui/tooltip"
import { Toaster } from "@/components/ui/sonner"

export const metadata: Metadata = {
  title: "Pokou · Console",
  description: "Espace d'administration de l'équipe Pokou",
}

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="fr">
      <body className="font-sans antialiased">
        <AuthProvider>
          <TooltipProvider delayDuration={0}>{children}</TooltipProvider>
        </AuthProvider>
        <Toaster richColors position="top-right" />
      </body>
    </html>
  )
}
