import type { SVGProps } from 'react'

// The Orunbase mark (small build), drawn for the primary-coloured button it
// sits on: the dome takes the text colour, the earth the amber for that surface.
export function OrunbaseMarkIcon(props: SVGProps<SVGSVGElement>) {
  return (
    <svg aria-hidden="true" viewBox="0 0 48 48" {...props}>
      <path d="M5.06 31.58 A20.4 20.4 0 1 1 42.94 31.58 Z" fill="currentColor" />
      <path
        className="fill-[#E3B34C] dark:fill-[#B8862F]"
        d="M10.43 39.23 A20.4 20.4 0 0 0 37.57 39.23 Z"
      />
    </svg>
  )
}
