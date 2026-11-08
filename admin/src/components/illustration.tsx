/* eslint-disable @next/next/no-img-element */
/**
 * Illustrations unDraw (licence libre, sans attribution) recolorées aux
 * couleurs Pokou : terre cuite, or, crème — et des personnages à la peau
 * brune, qui ressemblent aux gens qui utilisent l'app.
 */
export function Illustration({ name, className, alt = "" }: { name: string; className?: string; alt?: string }) {
  return <img src={`/console/illustrations/${name}.svg`} alt={alt} className={className} draggable={false} />
}
