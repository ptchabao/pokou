"use client"

import * as React from "react"
import {
  IconChevronLeft,
  IconChevronRight,
  IconChevronsLeft,
  IconChevronsRight,
  IconSearch,
  IconSelector,
  IconSortAscending,
  IconSortDescending,
} from "@tabler/icons-react"

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Skeleton } from "@/components/ui/skeleton"
import { Illustration } from "@/components/illustration"

export type Column<T> = {
  header: string
  cell: (row: T) => React.ReactNode
  className?: string
  /** Valeur de tri : la colonne devient triable (données chargées en entier). */
  sortValue?: (row: T) => string | number | null | undefined
}

const PAGE_SIZES = [10, 20, 50, 100]

/** Le texte d'une ligne pour la recherche locale : toutes ses valeurs simples. */
function rowText(row: unknown): string {
  if (row == null) return ""
  if (typeof row !== "object") return String(row)
  return Object.values(row as Record<string, unknown>)
    .map((v) => (v != null && typeof v === "object" ? rowText(v) : v ?? ""))
    .join(" ")
    .toLowerCase()
}

/** Tableau de données de la console (bloc « data-table » de shadcn).
 *
 *  Deux modes :
 *  - pagination SERVEUR (`page`, `total`, `size`, `onPage`) : la page
 *    affiche ce que l'API rend, la recherche est celle de la page ;
 *  - pagination LOCALE (sans `onPage`) : recherche dans le tableau, tri par
 *    colonne et pages de 10 à 100 lignes. */
export function SimpleTable<T>({
  columns,
  rows,
  empty = "Rien à afficher.",
  illustration = "search_empty",
  onRowClick,
  page,
  total,
  size,
  onPage,
  searchable = true,
  searchPlaceholder = "Rechercher dans le tableau…",
  toolbar,
}: {
  columns: Column<T>[]
  rows: T[] | null
  empty?: string
  /** Nom d'une illustration de public/illustrations (sans .svg). */
  illustration?: string
  onRowClick?: (row: T) => void
  page?: number
  total?: number
  size?: number
  onPage?: (page: number) => void
  /** Recherche locale (mode local seulement). */
  searchable?: boolean
  searchPlaceholder?: string
  /** Filtres ou boutons à côté de la recherche. */
  toolbar?: React.ReactNode
}) {
  const server = Boolean(onPage)
  const [query, setQuery] = React.useState("")
  const [pageSize, setPageSize] = React.useState(20)
  const [localPage, setLocalPage] = React.useState(1)
  const [sort, setSort] = React.useState<{ col: number; dir: "asc" | "desc" } | null>(null)

  React.useEffect(() => setLocalPage(1), [query, pageSize, rows])

  const filtered = React.useMemo(() => {
    if (!rows) return null
    let out = rows
    if (!server && query.trim()) {
      const q = query.trim().toLowerCase()
      out = out.filter((r) => rowText(r).includes(q))
    }
    if (!server && sort && columns[sort.col]?.sortValue) {
      const get = columns[sort.col].sortValue!
      out = [...out].sort((a, b) => {
        const x = get(a), y = get(b)
        if (x == null && y == null) return 0
        if (x == null) return 1
        if (y == null) return -1
        const cmp = typeof x === "number" && typeof y === "number" ? x - y : String(x).localeCompare(String(y), "fr")
        return sort.dir === "asc" ? cmp : -cmp
      })
    }
    return out
  }, [rows, query, sort, columns, server])

  const count = server ? total ?? 0 : filtered?.length ?? 0
  const perPage = server ? size ?? (rows?.length || 1) : pageSize
  const pages = Math.max(1, Math.ceil(count / perPage))
  const current = server ? page ?? 1 : Math.min(localPage, pages)
  const visible = filtered === null ? null : server ? filtered : filtered.slice((current - 1) * perPage, current * perPage)
  const go = (p: number) => (server ? onPage!(p) : setLocalPage(p))

  function toggleSort(i: number) {
    if (server || !columns[i].sortValue) return
    setSort((s) => (s?.col !== i ? { col: i, dir: "asc" } : s.dir === "asc" ? { col: i, dir: "desc" } : null))
  }

  return (
    <div className="flex flex-col gap-3">
      {(toolbar || (!server && searchable)) && (
        <div className="flex flex-wrap items-center gap-2">
          {!server && searchable && (
            <div className="relative w-full max-w-xs">
              <IconSearch className="absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-muted-foreground" />
              <Input value={query} onChange={(e) => setQuery(e.target.value)} placeholder={searchPlaceholder} className="h-9 pl-8" />
            </div>
          )}
          {toolbar}
        </div>
      )}
      <div className="overflow-hidden rounded-lg border">
        <Table>
          <TableHeader className="sticky top-0 z-10 bg-muted">
            <TableRow>
              {columns.map((c, i) => {
                const sortable = !server && Boolean(c.sortValue)
                const dir = sort?.col === i ? sort.dir : null
                return (
                  <TableHead key={c.header || i} className={c.className}>
                    {sortable ? (
                      <button type="button" onClick={() => toggleSort(i)} className="-ml-1 inline-flex items-center gap-1 rounded px-1 hover:text-foreground">
                        {c.header}
                        {dir === "asc" ? <IconSortAscending className="size-3.5" /> : dir === "desc" ? <IconSortDescending className="size-3.5" /> : <IconSelector className="size-3.5 opacity-50" />}
                      </button>
                    ) : (
                      c.header
                    )}
                  </TableHead>
                )
              })}
            </TableRow>
          </TableHeader>
          <TableBody>
            {visible === null ? (
              Array.from({ length: 5 }).map((_, i) => (
                <TableRow key={i}>
                  {columns.map((c, j) => (
                    <TableCell key={j}><Skeleton className="h-4 w-full max-w-40" /></TableCell>
                  ))}
                </TableRow>
              ))
            ) : visible.length === 0 ? (
              <TableRow>
                <TableCell colSpan={columns.length} className="py-10 text-center text-muted-foreground">
                  <Illustration name={illustration} className="mx-auto mb-3 h-36" />
                  {query ? "Aucun résultat pour cette recherche." : empty}
                </TableCell>
              </TableRow>
            ) : (
              visible.map((row, i) => (
                <TableRow
                  key={i}
                  className={onRowClick ? "cursor-pointer" : undefined}
                  onClick={onRowClick ? () => onRowClick(row) : undefined}
                >
                  {columns.map((c, j) => (
                    <TableCell key={c.header || j} className={c.className}>
                      {c.cell(row)}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>
      {visible !== null && count > 0 && (
        <div className="flex flex-wrap items-center justify-between gap-3 px-1 text-sm text-muted-foreground">
          <span>
            {count} élément{count > 1 ? "s" : ""}
          </span>
          <div className="flex flex-wrap items-center gap-4 lg:gap-6">
            {!server && (
              <div className="flex items-center gap-2">
                <Label htmlFor="rows-per-page" className="text-sm font-medium">Lignes par page</Label>
                <Select value={`${pageSize}`} onValueChange={(v) => setPageSize(Number(v))}>
                  <SelectTrigger size="sm" className="w-20" id="rows-per-page"><SelectValue /></SelectTrigger>
                  <SelectContent side="top">
                    {PAGE_SIZES.map((s) => <SelectItem key={s} value={`${s}`}>{s}</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>
            )}
            <span className="font-medium text-foreground">Page {current} sur {pages}</span>
            <div className="flex items-center gap-1">
              <Button variant="outline" size="icon" className="hidden size-8 lg:flex" disabled={current <= 1} onClick={() => go(1)} aria-label="Première page"><IconChevronsLeft /></Button>
              <Button variant="outline" size="icon" className="size-8" disabled={current <= 1} onClick={() => go(current - 1)} aria-label="Page précédente"><IconChevronLeft /></Button>
              <Button variant="outline" size="icon" className="size-8" disabled={current >= pages} onClick={() => go(current + 1)} aria-label="Page suivante"><IconChevronRight /></Button>
              <Button variant="outline" size="icon" className="hidden size-8 lg:flex" disabled={current >= pages} onClick={() => go(pages)} aria-label="Dernière page"><IconChevronsRight /></Button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
