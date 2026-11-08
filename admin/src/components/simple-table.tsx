"use client"

import * as React from "react"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Button } from "@/components/ui/button"
import { Illustration } from "@/components/illustration"

export type Column<T> = {
  header: string
  cell: (row: T) => React.ReactNode
  className?: string
}

/** Tableau de données de la console : en-têtes, lignes, état vide, pages. */
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
}) {
  const pages = total && size ? Math.max(1, Math.ceil(total / size)) : 1
  return (
    <div className="flex flex-col gap-3">
      <div className="overflow-hidden rounded-lg border">
        <Table>
          <TableHeader className="bg-muted">
            <TableRow>
              {columns.map((c) => (
                <TableHead key={c.header} className={c.className}>
                  {c.header}
                </TableHead>
              ))}
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows === null ? (
              <TableRow>
                <TableCell colSpan={columns.length} className="h-20 text-center text-muted-foreground">
                  Chargement…
                </TableCell>
              </TableRow>
            ) : rows.length === 0 ? (
              <TableRow>
                <TableCell colSpan={columns.length} className="py-10 text-center text-muted-foreground">
                  <Illustration name={illustration} className="mx-auto mb-3 h-36" />
                  {empty}
                </TableCell>
              </TableRow>
            ) : (
              rows.map((row, i) => (
                <TableRow
                  key={i}
                  className={onRowClick ? "cursor-pointer" : undefined}
                  onClick={onRowClick ? () => onRowClick(row) : undefined}
                >
                  {columns.map((c) => (
                    <TableCell key={c.header} className={c.className}>
                      {c.cell(row)}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>
      {onPage && pages > 1 && (
        <div className="flex items-center justify-end gap-2 text-sm text-muted-foreground">
          <span>
            Page {page} sur {pages} · {total} éléments
          </span>
          <Button variant="outline" size="sm" disabled={(page ?? 1) <= 1} onClick={() => onPage((page ?? 1) - 1)}>
            Précédent
          </Button>
          <Button variant="outline" size="sm" disabled={(page ?? 1) >= pages} onClick={() => onPage((page ?? 1) + 1)}>
            Suivant
          </Button>
        </div>
      )}
    </div>
  )
}
