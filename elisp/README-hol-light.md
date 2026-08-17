# hol-light.el

Emacs support for the [HOL Light](https://github.com/jrh13/hol-light) proof
assistant, layered on top of `tuareg-mode`.

HOL Light sources *are* OCaml, so `tuareg-mode` already edits them well. This
file adds only what the OCaml tooling cannot give: a toplevel with HOL Light
preloaded, commands that step statements, goals and tactics into it, HOL Light's
own reference documentation at point, and cross-file definition lookup.

It deliberately follows the [HOL Light VS Code
extension](https://github.com/monadius/vscode-hol-light) wherever behaviour is a
matter of convention rather than taste, so the two agree on what "the tactic at
point" means and on what a highlight colour signifies.

## Requirements

| | |
|---|---|
| `tuareg` | The major mode this hooks onto (MELPA). |
| A built HOL Light | `make` in `hol-light-directory`, so that `ocaml-hol` and `pa_j.cmo` exist. |
| `opam` | Only to build HOL Light; this file does not invoke it. |

Nothing here needs `ocaml-lsp-server`. HOL Light's backquoted term quotations
are camlp5 syntax that `ocamllsp` cannot parse, so LSP is best left switched off
in these buffers.

## Setup

`elisp/` is already on `load-path`, so this suffices:

```elisp
(use-package hol-light
  :ensure nil
  :commands (hol-light-run hol-light-mode hol-light-file-p)
  :hook (tuareg-mode . hol-light-tuareg-setup))
```

`hol-light-tuareg-setup` turns `hol-light-mode` on for files under
`hol-light-directory` and leaves every other OCaml buffer alone.

To get the documentation as a hovering childframe rather than in the echo area,
add `eldoc-box`:

```elisp
:hook ((tuareg-mode . hol-light-tuareg-setup)
       (hol-light-mode . (lambda () (eldoc-box-hover-mode (if hol-light-mode 1 -1)))))
```

The test matters: a minor mode's hook runs when the mode is switched *off* as
well as on.

## Keys

| Key | Command | |
|---|---|---|
| `C-c C-s` | `hol-light-run` | Start the toplevel, or pop to it |
| `C-c C-c` | `hol-light-interrupt` | Interrupt it, as `C-c` would at its own prompt |
| `C-c C-e` | `hol-light-send-statement` | Send the phrase at point, step past it |
| `C-c C-t` | `hol-light-send-tactic` | Apply the tactic on this line, step to the next; `C-u` lets it span lines |
| `C-c C-g` | `hol-light-set-goal` | Set the goal from the term at point |
| `C-c C-r` | `hol-light-send-region` | Send the region |
| `C-c C-l` | `hol-light-send-buffer` | Send the whole buffer |
| `C-c C-b` | `hol-light-send-before-point` | Send every phrase before point, one at a time |
| `C-c C-u` | `hol-light-back` | Undo the last tactic (`b()`) |
| `C-c C-p` | `hol-light-print-goal` | Print the goal state (`p()`) |
| `C-c C-n` | `hol-light-rotate` | Rotate to the next subgoal (`r 1`) |
| `C-c C-q` | `hol-light-top-thm` | Print the finished theorem (`top_thm()`) |
| `C-c C-a` | `hol-light-search-name` | List theorems whose name contains a string |
| `C-c C-d` | `hol-light-help` | Full documentation for a name, with completion |
| `C-c C-.` | `hol-light-jump-to-highlight` | Go to the end of the highlighted region |
| `C-c C-<backspace>` | `hol-light-remove-highlighting` | Clear the highlighting |

Definitions come from `xref`, so `M-.` and `M-?` work as usual — `M-?` falls
back to xref's own project-wide search. See [Caveats](#caveats) if you use Evil.

## What it does

### Stepping through a proof

The usual loop is `C-c C-g` on the goal term, then `C-c C-t` repeatedly: each
one applies the tactic on the current line and moves point to the next, so a
proof replays by holding one key.

Deciding where a tactic ends is the whole problem, and
`hol-light--tactic-bounds` is a port of the extension's `selectTactic`. A tactic
runs until

* `;;`,
* a `;` outside brackets,
* a closing bracket it never opened — the one closing the enclosing `prove`, or
* a `THEN`/`THENL` left at bracket depth zero by a line break.

Trailing sequencing, line breaks and unclosed brackets are then trimmed, and a
leading `[` or `THEN` is treated as belonging to the enclosing `THENL` list
rather than to the tactic. So on the last line of a proof,

```ocaml
  INDUCT_TAC THEN ASM_REWRITE_TAC[ADD]);;
```

`C-c C-t` sends `e(INDUCT_TAC THEN ASM_REWRITE_TAC[ADD])` — the `);;` closing
the `prove` is dropped, while the `;` inside `REWRITE_TAC[A; B]` is kept.

A tactic that ends at a `;` is one element of a `THENL` list, so it is applied
with `er` rather than `e`, which rotates to the next subgoal afterwards.

With a prefix argument the tactic may span up to `hol-light-tactic-max-lines`
lines, which is what you want when its brackets run across line breaks.

### Highlighting

A sent region is highlighted while the toplevel works on it
(`hol-light-pending-face`), then recoloured green (`hol-light-success-face`) or
red (`hol-light-failure-face`) depending on whether the toplevel accepted it.
Only the newest settled region stays highlighted.

The verdict comes from watching the toplevel's output: it prints one `# ` prompt
per phrase it finishes, so each prompt closes the output of one sent region,
which is then tested for `Error:`, `Exception:` or `Parse error:`.

`hol-light-back` clears the highlighting, since after `b()` the toplevel's state
no longer corresponds to any one region of the buffer.

### Documentation

`eldoc` shows the type and synopsis of the name at point; `C-c C-d` opens the
whole entry — description, failure conditions, examples, see-also — rendered
from HOL Light's `\DOC` markup into plain text.

Both read the `.hlp` files in HOL Light's `Help` directory, indexed by the name
on each file's `\DOC` line **rather than by file name**. That distinction is not
cosmetic: 20 entries disagree, and several are common.

* A case-insensitive file system cannot hold both `alpha.hlp` and `ALPHA.hlp`,
  so `ALPHA`, `CHOOSE`, `EXISTS`, `INST`, `REPEAT`, `MK_COMB` and friends live in
  `*_UPPERCASE.hlp`. Looking up `REPEAT.hlp` on macOS silently opens the
  documentation for the lowercase `repeat` instead.
* A file cannot be named `insert'`, so that lives in `insert_prime.hlp`.
* Six dot-prefixed files document operators: `.valmod.hlp` is `|->`,
  `.upto.hlp` is `--`, `.joinparsers.hlp` is `++`, `.orparser.hlp` is `|||`.
  `ls` does not show them.

Because of that last group, the name at point is taken as either an ordinary
symbol or a run of operator characters, so `|->` resolves as readily as
`REWRITE_TAC`.

The index is built on first use and cached; `hol-light-reload-documentation`
rebuilds it.

### Definitions

`hol-light-xref-backend` resolves `xref` requests by searching the `.ml` files
under `hol-light-directory` for `let NAME = ...` and `and NAME = ...`, including
the tuple bindings HOL Light uses for conjunction pairs (`let A,B = CONJ_PAIR
th`). Theorems, tactics and conversions are all just OCaml bindings, so this
covers them uniformly — including the many that have no `Help` entry.

## Customization

| Variable | Default | |
|---|---|---|
| `hol-light-directory` | `~/Code/hol-light/` | The checkout: its `hol.sh`, its `Help`, and the sources `xref` searches |
| `hol-light-buffer-name` | `*hol-light*` | Buffer running the toplevel |
| `hol-light-line-editor` | `env` | `$LINE_EDITOR` for `hol.sh` (see below) |
| `hol-light-tactic-max-lines` | `30` | Lines a prefixed `C-c C-t` may span |
| `hol-light-advance-after-send` | `t` | Whether sending moves point past what was sent |

Faces: `hol-light-term-face`, `hol-light-pending-face`,
`hol-light-success-face`, `hol-light-failure-face`.

## Design notes

**The toplevel is HOL Light's own `hol.sh`, not a bare `ocaml`.** A HOL Light
session is a purpose-built toplevel (`ocaml-hol`, produced by `make`) driven by
the camlp5 parser in `pa_j.cmo` that adds the backquoted term quotations, and
`hol.sh` also selects the checkout's local opam switch itself.

**`$LINE_EDITOR` is set to `env`.** `hol.sh` runs the toplevel as
`$LINE_EDITOR ocaml-hol ...`, where the default `ledit` supplies the line
editing that comint already provides. It has to be a program that execs its
arguments — notably *not* `cat`, which would print the toplevel and its
arguments instead of running them.

**Loading `hol.ml` takes minutes**, so one toplevel is started and reused. Input
sent while it is still loading is buffered and runs once the load finishes, so
there is no need to wait before sending the first phrase.

**Phrase boundaries are found by scanning `;;` directly**, skipping those inside
strings and comments, rather than by calling `tuareg-discover-phrase`. Tuareg's
OCaml parser loses its place across backquoted term quotations and then reports
several phrases as one.

## Caveats

* **Evil users:** `M-.` is bound to `evil-repeat-pop-next` in normal state, which
  shadows `xref-find-definitions`. Use `gd`, which Evil resolves through imenu
  and then `xref`, or rebind `M-.` for normal state. `M-?` is unaffected.
* Editing inside a highlighted region does not retract anything; the highlight
  records what was sent, not a locked prefix of the buffer. Use
  `hol-light-back` or `hol-light-remove-highlighting`.
* There is no separate goal window: goal states appear in the toplevel buffer,
  as they would in a terminal.
* Completion over documented names is offered by `hol-light-help` and by `xref`,
  but is not wired into `completion-at-point`.
