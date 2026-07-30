# Bundled typefaces

The Concourse Board world uses two families (see `DESIGN.md` in the web repo):

| Family | Role |
|---|---|
| **Martian Mono Board** | All board lettering — titles, labels, readouts, split-flap cells |
| **Archivo WS** | Prose and body copy only |

Both are [SIL OFL 1.1](https://scripts.sil.org/OFL) licensed; the license text
sits alongside the files.

These are **static instances**, not the upstream variable fonts. The web build
dials width with CSS `font-stretch`, which SwiftUI has no equivalent for, so the
widths are baked in here instead:

| Family | wdth | wght |
|---|---|---|
| Martian Mono Board | 82 | 400 / 600 / 700 |
| Archivo WS | 100 | 400 / 500 / 700 |

Regenerate with `fontTools.varLib.instancer` from the upstream variable fonts at
`google/fonts` (`ofl/martianmono`, `ofl/archivo`) if the widths need retuning.
Both the app and the widget extension bundle them, since an extension cannot
read the host app's registered fonts.
