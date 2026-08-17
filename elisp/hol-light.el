;;; hol-light.el --- Interaction with the HOL Light proof assistant -*- lexical-binding: t; -*-

;;; Commentary:

;; HOL Light sources are OCaml, so `tuareg-mode' is the major mode for them and
;; this file only adds what the OCaml tooling cannot give: a toplevel with HOL
;; Light preloaded, commands that step statements/goals/tactics into it, and
;; lookup of HOL Light's own documentation.
;;
;; `hol-light-mode' is a minor mode layered on top of `tuareg-mode';
;; `hol-light-tuareg-setup' turns it on for files under `hol-light-directory'
;; and is meant for `tuareg-mode-hook'.
;;
;; The behaviour deliberately follows the HOL Light VS Code extension
;; (https://github.com/monadius/vscode-hol-light), so that the two agree on the
;; things that are matters of convention rather than taste:
;;
;; * A sent region is highlighted while the toplevel is working on it, then
;;   recoloured according to whether the toplevel accepted it -- the extension's
;;   pending/success/failure decorations.  Only the newest settled region stays
;;   highlighted, and `hol-light-back' clears it, as `repl_back_proof' does.
;;
;; * A tactic ends at `;;', at a `;' outside brackets, at an unmatched closing
;;   bracket, or where a THEN/THENL leaves bracket depth zero -- see
;;   `hol-light--tactic-bounds', ported from the extension's `selectTactic'.  A
;;   tactic that ends at `;' is one element of a THENL list, so it is applied
;;   with `er' rather than `e' to rotate to the next subgoal.
;;
;; * Documentation comes from the `.hlp' files in HOL Light's Help directory,
;;   indexed by the name in their `\DOC' line rather than by file name.  That
;;   matters: 20 entries disagree, because a case-insensitive file system cannot
;;   hold both `alpha.hlp' and `ALPHA.hlp' (hence `ALPHA_UPPERCASE.hlp') and
;;   because a file cannot be named `insert''.
;;
;; Two properties of a HOL Light checkout shape the rest:
;;
;; * The toplevel is started through HOL Light's own `hol.sh' rather than a bare
;;   `ocaml'.  A HOL Light session is a purpose-built toplevel (`ocaml-hol',
;;   produced by `make') driven by the camlp5 parser in `pa_j.cmo' that adds the
;;   backquoted term quotations, and `hol.sh' also selects the checkout's local
;;   opam switch itself.  `hol.sh' runs the toplevel as "$LINE_EDITOR ocaml-hol
;;   ...", where the default `ledit' supplies the line editing that comint
;;   already provides, so `hol-light-line-editor' replaces it with a wrapper that
;;   merely execs its arguments.  Note it cannot be `cat', which would print the
;;   toplevel and its arguments instead of running them.
;;
;; * Loading `hol.ml' takes minutes, so one toplevel is started and reused.
;;   Input sent while it is still loading is buffered and runs once the load
;;   finishes, so there is no need to wait before sending the first phrase.

;;; Code:

(require 'cl-lib)
(require 'comint)
(require 'subr-x)
(require 'xref)

(defgroup hol-light nil
  "Interaction with the HOL Light proof assistant."
  :group 'languages
  :prefix "hol-light-")

(defcustom hol-light-directory (expand-file-name "~/Code/hol-light/")
  "Directory of the HOL Light checkout.
Files under it get `hol-light-mode' via `hol-light-tuareg-setup'; its
`hol.sh' is what `hol-light-run' starts, its Help directory is what
`hol-light-help' reads, and its sources are what \\[xref-find-definitions]
searches."
  :type 'directory)

(defcustom hol-light-buffer-name "*hol-light*"
  "Name of the buffer running the HOL Light toplevel."
  :type 'string)

(defcustom hol-light-line-editor "env"
  "Value given to $LINE_EDITOR when running HOL Light's `hol.sh'.
The script runs the toplevel as \"$LINE_EDITOR ocaml-hol ...\", so this
must name a program that execs its arguments.  The default `ledit' is
replaced because comint provides the line editing itself."
  :type 'string)

(defcustom hol-light-tactic-max-lines 30
  "Number of lines a multi-line tactic may span.
Used by `hol-light-send-tactic' with a prefix argument."
  :type 'integer)

(defcustom hol-light-advance-after-send t
  "Whether sending a statement or tactic moves point past it.
This is what makes repeated \\[hol-light-send-tactic] step through a proof."
  :type 'boolean)

(defface hol-light-term-face
  '((t :inherit font-lock-string-face))
  "Face for backquoted HOL Light term quotations.")

(defface hol-light-pending-face
  '((t :inherit secondary-selection :extend t))
  "Face for text sent to the toplevel and still awaiting a verdict.")

(defface hol-light-success-face
  '((t :inherit diff-added :extend t))
  "Face for the last statement or tactic the toplevel accepted.")

(defface hol-light-failure-face
  '((t :inherit diff-removed :extend t))
  "Face for the last statement or tactic the toplevel rejected.")


;;; The toplevel process

(defun hol-light--process ()
  "Return the live HOL Light toplevel process, or nil if there is none."
  (when-let* ((buffer (get-buffer hol-light-buffer-name))
              (process (get-buffer-process buffer)))
    (and (process-live-p process) process)))

(define-derived-mode hol-light-comint-mode comint-mode "HOL Light"
  "Major mode for the buffer running a HOL Light toplevel."
  (setq-local comint-prompt-regexp "^# ")
  ;; The toplevel does not echo what it is fed, so `hol-light--send' inserts the
  ;; input itself; telling comint otherwise would make it delete those lines.
  (setq-local comint-process-echoes nil)
  (add-hook 'comint-output-filter-functions #'hol-light--watch-output nil t))

(defun hol-light--start ()
  "Start the HOL Light toplevel and display its buffer.
Return the new process."
  (let* ((default-directory (file-name-as-directory
                             (expand-file-name hol-light-directory)))
         (script (expand-file-name "hol.sh" default-directory))
         (toplevel (expand-file-name "ocaml-hol" default-directory)))
    (unless (file-executable-p script)
      (user-error "No executable `hol.sh' in %s"
                  (abbreviate-file-name default-directory)))
    (unless (file-executable-p toplevel)
      (user-error "No `ocaml-hol' toplevel in %s; run `make' there first"
                  (abbreviate-file-name default-directory)))
    (let ((process-environment (cons (concat "LINE_EDITOR=" hol-light-line-editor)
                                     process-environment)))
      (with-current-buffer (make-comint-in-buffer "hol-light" hol-light-buffer-name
                                                  script)
        (hol-light-comint-mode)
        (display-buffer (current-buffer))))
    (message "Started HOL Light in %s; loading hol.ml takes a few minutes"
             (abbreviate-file-name default-directory))
    (hol-light--process)))

;;;###autoload
(defun hol-light-run ()
  "Start a HOL Light toplevel, or pop to the one already running."
  (interactive)
  (unless (hol-light--process)
    (hol-light--start))
  (pop-to-buffer hol-light-buffer-name))

(defun hol-light-interrupt ()
  "Interrupt the HOL Light toplevel, as C-c would at its own prompt."
  (interactive)
  (if-let* ((process (hol-light--process)))
      (progn
        (setq hol-light--awaiting nil)
        (interrupt-process process))
    (user-error "No HOL Light toplevel is running")))

(defun hol-light--summarize (text)
  "Return TEXT collapsed onto one echo-area line."
  (let ((line (replace-regexp-in-string "[ \t\n]+" " " (string-trim text))))
    (truncate-string-to-width line (max 20 (- (frame-width) 10)) nil nil t)))

(defun hol-light--send (text &optional beg end)
  "Send TEXT to the HOL Light toplevel, terminating it with `;;'.
Start the toplevel first if it is not running.  When BEG and END are given,
highlight that region until the toplevel reports back on it."
  (let ((text (string-trim text)))
    (when (string-empty-p text)
      (user-error "Nothing to send to HOL Light"))
    (unless (string-suffix-p ";;" text)
      (setq text (concat text ";;")))
    (let ((process (or (hol-light--process) (hol-light--start))))
      (when (and beg end)
        (hol-light--mark-pending beg end))
      (with-current-buffer (process-buffer process)
        (goto-char (point-max))
        (insert text)
        ;; ARTIFICIAL, so that comint does not treat this as typed input.
        (comint-send-input nil t)))
    (message "HOL Light: %s" (hol-light--summarize text))))


;;; Verdicts
;;
;; The toplevel prints one `# ' prompt per phrase it finishes, so each prompt
;; closes the output belonging to one sent region and settles its highlight.

(defvar hol-light--awaiting nil
  "Overlays for sent regions awaiting a verdict, oldest first.
Global rather than buffer-local: one toplevel serves every HOL Light buffer
and answers in the order it was fed.")

(defvar-local hol-light--output ""
  "Toplevel output accumulated since the last prompt.")

(defconst hol-light--error-regexp
  "^[ \t]*#?[ \t]*\\(?:Error\\|Exception\\|Parse error\\):"
  "Regexp matching a toplevel line that reports a rejected phrase.
The same test the VS Code extension applies to decide success or failure.")

(defun hol-light--watch-output (string)
  "Settle one pending region per prompt appearing in STRING.
For `comint-output-filter-functions' in the toplevel buffer."
  (setq hol-light--output (concat hol-light--output string))
  (while (string-match comint-prompt-regexp hol-light--output)
    (let ((segment (substring hol-light--output 0 (match-beginning 0))))
      (setq hol-light--output (substring hol-light--output (match-end 0)))
      (hol-light--settle (let ((case-fold-search t))
                           (and (string-match-p hol-light--error-regexp segment) t))))))


;;; Highlighting

(defvar-local hol-light--overlays nil
  "Overlays highlighting regions of this buffer sent to the toplevel.")

(defun hol-light--mark-pending (beg end)
  "Highlight BEG..END as sent but not yet answered for."
  ;; FRONT-ADVANCE so that typing at either edge leaves the overlay alone,
  ;; matching the extension's ClosedClosed decoration behaviour.
  (let ((overlay (make-overlay beg end nil t nil)))
    (overlay-put overlay 'hol-light t)
    (overlay-put overlay 'face 'hol-light-pending-face)
    ;; Negative, so the highlight sits under the region and other overlays.
    (overlay-put overlay 'priority -50)
    (push overlay hol-light--overlays)
    (setq hol-light--awaiting (append hol-light--awaiting (list overlay)))
    overlay))

(defun hol-light--settle (errorp)
  "Settle the oldest region awaiting a verdict; ERRORP if the toplevel rejected it."
  (when-let* ((overlay (pop hol-light--awaiting))
              (buffer (overlay-buffer overlay)))
    (with-current-buffer buffer
      ;; Only the newest settled region stays highlighted; regions still in
      ;; flight keep their pending highlight.
      (dolist (other hol-light--overlays)
        (unless (or (eq other overlay) (memq other hol-light--awaiting))
          (delete-overlay other)))
      (setq hol-light--overlays
            (cons overlay (seq-filter (lambda (o) (memq o hol-light--awaiting))
                                      hol-light--overlays)))
      (overlay-put overlay 'face
                   (if errorp 'hol-light-failure-face 'hol-light-success-face)))))

(defun hol-light-remove-highlighting ()
  "Remove the highlighting of regions sent from this buffer."
  (interactive)
  (mapc #'delete-overlay hol-light--overlays)
  (setq hol-light--overlays nil)
  (setq hol-light--awaiting
        (seq-remove (lambda (o) (null (overlay-buffer o))) hol-light--awaiting)))

(defun hol-light-jump-to-highlight ()
  "Move point to the end of the most recently highlighted region."
  (interactive)
  (if-let* ((overlay (car (seq-filter #'overlay-buffer hol-light--overlays))))
      (goto-char (overlay-end overlay))
    (user-error "Nothing is highlighted in this buffer")))


;;; Locating what to send

(defun hol-light--scan-terminator (backward)
  "Move over the nearest phrase terminator `;;' and return the position past it.
Search backward when BACKWARD is non-nil.  Terminators inside a string or a
comment are skipped.  Return nil when there is none, leaving point where the
search gave up."
  (let ((search (if backward #'search-backward #'search-forward))
        (result nil))
    (while (and (not result) (funcall search ";;" nil t))
      ;; `syntax-ppss' leaves point at the position it parsed to, so the search
      ;; position has to be remembered across the test.
      (let ((here (point))
            (start (match-beginning 0))
            (end (match-end 0)))
        (if (nth 8 (syntax-ppss start))
            (goto-char here)
          (setq result end))))
    (when result (goto-char result))
    result))

(defun hol-light--phrase-bounds ()
  "Return (BEG . END) bounding the `;;'-terminated phrase around point.
The terminators are scanned directly rather than through
`tuareg-discover-phrase', whose OCaml parser loses its place across
backquoted term quotations and then reports several phrases as one."
  (let ((origin (point)))
    (save-excursion
      ;; Begin the forward scan two characters back, so that a point just past a
      ;; `;;' counts as the end of that phrase instead of the start of the next.
      (goto-char (max (point-min) (- origin 2)))
      (let* ((end (or (hol-light--scan-terminator nil) (point-max)))
             (beg (progn (goto-char (max (point-min) (- end 2)))
                         (or (hol-light--scan-terminator t) (point-min)))))
        (cons beg end)))))

(defun hol-light--term-bounds ()
  "Return (BEG . END) bounding the backquoted term containing point.
The bounds include the backquotes, which HOL Light's parser needs.  Return
nil if point is not inside a term."
  (let ((origin (point)))
    (pcase-let ((`(,from . ,to) (hol-light--phrase-bounds)))
      (save-excursion
        (goto-char from)
        ;; Walk the backquotes pairwise so that a point sitting after a closing
        ;; backquote is not mistaken for one inside the term that follows.
        (catch 'found
          (while (search-forward "`" to t)
            (let ((beg (match-beginning 0))
                  (end (search-forward "`" to t)))
              (unless end
                (throw 'found nil))
              (when (and (<= beg origin) (<= origin end))
                (throw 'found (cons beg end)))))
          nil)))))

(defconst hol-light--tactic-token-regexp
  (concat "(\\*"                        ; comment
          "\\|[\"`]"                    ; string or term quotation
          "\\|[][()]"                   ; brackets
          "\\|;+"                       ; list separator or phrase terminator
          "\\|\\_<THENL?\\_>")          ; tactic sequencing
  "Regexp matching the tokens that can delimit a HOL Light tactic.")

(defun hol-light--skip-tactic-token ()
  "Move past the token matched by `hol-light--tactic-token-regexp'.
Return its kind: `comment', `text', `open', `close', `terminator',
`separator' or `then'."
  (let ((text (match-string 0))
        (end (match-end 0)))
    (cond
     ((equal text "(*")
      (goto-char (match-beginning 0))
      (or (forward-comment 1) (goto-char (line-end-position)))
      'comment)
     ((equal text "\"")
      ;; OCaml strings have escapes, so let the syntax table walk it.
      (goto-char (match-beginning 0))
      (condition-case nil (forward-sexp) (error (goto-char (line-end-position))))
      'text)
     ((equal text "`")
      ;; A term quotation ends at the next backquote; there are no escapes.
      (goto-char end)
      (unless (search-forward "`" nil t)
        (goto-char (line-end-position)))
      'text)
     (t
      (goto-char end)
      (cond
       ((member text '("(" "[")) 'open)
       ((member text '(")" "]")) 'close)
       ;; `;;' ends the phrase; a single `;' only separates list elements.
       ((string-prefix-p ";;" text) 'terminator)
       ((equal text ";") 'separator)
       (t 'then))))))

(defun hol-light--rest-of-line-insignificant-p ()
  "Return non-nil if nothing but punctuation follows point on this line.
Mirrors the extension's `checkNewline': brackets, `;', `;;' and THEN/THENL do
not count as content, so a tactic ending `TAC);;' still counts as ending its
line, while the `TAC1; TAC2' of a one-line THENL list does not."
  (save-excursion
    (catch 'result
      (while t
        (skip-chars-forward " \t")
        (cond
         ((eolp) (throw 'result t))
         ((looking-at hol-light--tactic-token-regexp)
          (when (eq (hol-light--skip-tactic-token) 'text)
            (throw 'result nil)))
         (t (throw 'result nil)))))))

(defun hol-light--tactic-ends-at-eol-p (history depth)
  "Return non-nil if HISTORY leaves the tactic finished at a line break.
HISTORY holds the tokens scanned so far, most recent first, and DEPTH is the
current bracket depth.  Walk back over trailing brackets as the extension
does: a THEN or THENL that they have not reopened ends the tactic, so a line
closing with `THENL [' ends one just as a bare `THENL' does."
  (let ((level depth))
    (catch 'result
      (pcase-dolist (`(,kind ,_ ,_) history)
        (pcase kind
          ('then (throw 'result (<= level 0)))
          ('open (setq level (1- level)))
          ('close (setq level (1+ level)))
          (_ (throw 'result nil))))
      nil)))

(defun hol-light--tactic-bounds (&optional max-lines)
  "Return (BEG END SEPARATORP NEWLINEP) for the tactic starting on this line.
Scan at most MAX-LINES lines, one by default.  SEPARATORP is non-nil when the
tactic ended at a `;', making it one element of a THENL list.  NEWLINEP is
non-nil when nothing but whitespace follows it on its last line, which is
what decides whether stepping moves to the next line or just past the
tactic.  Return nil when the lines hold no tactic text.

Ported from `selectTactic' in the HOL Light VS Code extension.  The tactic
runs until `;;', until a `;' outside brackets, until a closing bracket it
never opened -- the one closing the enclosing `prove' -- or until a
THEN/THENL is left at bracket depth zero by a line break.  Trailing
sequencing, line breaks and opening brackets are then trimmed off, and a
leading `[' or THEN belongs to the THENL list rather than to the tactic."
  (let* ((max-lines (or max-lines 1))
         (limit (save-excursion (forward-line max-lines) (point)))
         (depth 0)
         (history nil)                  ; (KIND START END), most recent first
         (separatorp nil)
         (newlinep t))
    (save-excursion
      (forward-line 0)
      (catch 'done
        (while t
          (skip-chars-forward " \t")
          (cond
           ((>= (point) limit) (throw 'done nil))
           ((eolp)
            (when (and history (hol-light--tactic-ends-at-eol-p history depth))
              (throw 'done nil))
            (when (eobp) (throw 'done nil))
            (push (list 'eol (point) (point)) history)
            (forward-char 1))
           ((looking-at hol-light--tactic-token-regexp)
            (let* ((start (point))
                   (token (match-string 0))
                   (kind (hol-light--skip-tactic-token)))
              (pcase kind
                ;; Comments are not part of any tactic.
                ('comment nil)
                ('terminator
                 (setq newlinep (hol-light--rest-of-line-insignificant-p))
                 (throw 'done nil))
                ('separator
                 (when (<= depth 0)
                   (setq separatorp t
                         newlinep (hol-light--rest-of-line-insignificant-p))
                   (throw 'done nil))
                 (push (list 'other start (point)) history))
                ('close
                 (when (<= depth 0)
                   (setq newlinep (hol-light--rest-of-line-insignificant-p))
                   (throw 'done nil))
                 (setq depth (1- depth))
                 (push (list 'close start (point)) history))
                ('open
                 ;; A `[' before any content opens the THENL list holding this
                 ;; tactic, so it is neither counted nor selected.
                 (unless (and (equal token "[") (null history))
                   (setq depth (1+ depth))
                   (push (list 'open start (point)) history)))
                ('then
                 ;; A THEN before any content sequences this tactic after the
                 ;; previous one; it is not part of either.
                 (when history
                   (push (list 'then start (point)) history)))
                (_ (push (list 'text start (point)) history)))))
           (t
            ;; Ordinary text up to the next token or the end of the line.
            (let ((start (point))
                  (next (save-excursion
                          (if (re-search-forward hol-light--tactic-token-regexp
                                                 (line-end-position) t)
                              (match-beginning 0)
                            (line-end-position)))))
              (goto-char (max next (1+ (point))))
              (push (list 'text start
                          (save-excursion (skip-chars-backward " \t") (point)))
                    history)))))))
    ;; Trim the sequencing, line breaks and unclosed brackets off the end.
    (while (and history (memq (caar history) '(then eol open)))
      (pop history))
    (when history
      (list (nth 1 (car (last history))) (nth 2 (car history)) separatorp newlinep))))

(defun hol-light--region-or (bounds-function what)
  "Return (BEG . END) for the active region, or from BOUNDS-FUNCTION.
WHAT names the construct being looked for, for the error message."
  (let ((bounds (if (use-region-p)
                    (cons (region-beginning) (region-end))
                  (funcall bounds-function))))
    (unless bounds
      (user-error "No %s at point" what))
    bounds))

(defun hol-light--quote-term (term)
  "Return TERM delimited by the backquotes HOL Light's parser expects."
  (if (and (> (length term) 1)
           (string-prefix-p "`" term)
           (string-suffix-p "`" term))
      term
    (concat "`" term "`")))

(defun hol-light--advance-to (position &optional next-line)
  "Move point to POSITION, or to the start of the line after it if NEXT-LINE.
Does nothing when `hol-light-advance-after-send' is nil."
  (when hol-light-advance-after-send
    (goto-char position)
    (when next-line
      (forward-line 1)
      (skip-chars-forward " \t"))))


;;; Sending commands

(defun hol-light-send-region (beg end)
  "Send the text between BEG and END to the HOL Light toplevel."
  (interactive "r")
  (hol-light--send (buffer-substring-no-properties beg end) beg end))

(defun hol-light-send-statement ()
  "Send the phrase around point to the toplevel and step past it."
  (interactive)
  (pcase-let ((`(,beg . ,end) (hol-light--phrase-bounds)))
    (hol-light-send-region beg end)
    (hol-light--advance-to end)))

(defun hol-light-send-buffer ()
  "Send the whole buffer to the HOL Light toplevel."
  (interactive)
  (hol-light-send-region (point-min) (point-max)))

(defun hol-light-send-before-point ()
  "Send every phrase between the start of the buffer and point, one at a time.
Each is highlighted and judged on its own, so a failure is easy to place.  A
phrase that point falls inside is left alone.

The terminators are walked directly rather than by repeatedly asking
`hol-light--phrase-bounds': that treats a point just past a `;;' as belonging
to the phrase it closes, which is right for stepping but would keep handing
back the phrase just sent."
  (interactive)
  (let ((target (point))
        (beg (point-min))
        (count 0))
    (save-excursion
      (goto-char (point-min))
      (catch 'done
        (while (< (point) target)
          (unless (hol-light--scan-terminator nil)
            (throw 'done nil))
          (let ((end (point)))
            (when (> end target)
              (throw 'done nil))
            ;; Start the highlight at the phrase's own text, not at the blank
            ;; lines separating it from the previous one.
            (save-excursion
              (goto-char beg)
              (skip-chars-forward " \t\n")
              (setq beg (point)))
            (unless (string-blank-p (buffer-substring-no-properties beg end))
              (hol-light--send (buffer-substring-no-properties beg end) beg end)
              (setq count (1+ count)))
            (setq beg end)))))
    (message "HOL Light: sent %d phrase%s" count (if (= count 1) "" "s"))))

(defun hol-light-set-goal ()
  "Set the HOL Light goal to the term at point, or to the region."
  (interactive)
  (pcase-let* ((`(,beg . ,end) (hol-light--region-or #'hol-light--term-bounds "term"))
               (term (string-trim (buffer-substring-no-properties beg end))))
    (hol-light--send (format "g(%s)" (hol-light--quote-term term)) beg end)
    (hol-light--advance-to end t)))

(defun hol-light-send-tactic (&optional multiline)
  "Apply the tactic on the current line to the goal, and step to the next.
With a prefix argument MULTILINE, let the tactic span up to
`hol-light-tactic-max-lines' lines.  An active region is used verbatim.

A tactic that ends at a `;' is one element of a THENL list, so it goes to
`er' rather than `e', which rotates to the next subgoal after applying it."
  (interactive "P")
  (if (use-region-p)
      (let ((beg (region-beginning))
            (end (region-end)))
        (hol-light--send
         (format "e(%s)" (hol-light--trim-tactic
                          (buffer-substring-no-properties beg end)))
         beg end)
        (hol-light--advance-to end t))
    (pcase (hol-light--tactic-bounds (and multiline hol-light-tactic-max-lines))
      (`(,beg ,end ,separatorp ,newlinep)
       (hol-light--send
        (format "%s(%s)" (if separatorp "er" "e")
                (buffer-substring-no-properties beg end))
        beg end)
       (if newlinep
           (hol-light--advance-to end t)
         ;; More of the line follows -- the rest of a one-line THENL list -- so
         ;; step just past this element to leave point on the next one.
         (hol-light--advance-to end)
         (when hol-light-advance-after-send
           (skip-chars-forward " \t")
           (when (eq (char-after) ?\;) (forward-char 1))
           (skip-chars-forward " \t"))))
      (_ (user-error "No tactic on this line")))))

(defun hol-light--trim-tactic (tactic)
  "Return TACTIC without the syntax that merely holds it in its proof script.
Used for an explicitly selected region, where the selection may take in the
THEN or THENL sequencing the tactic, a `;' or `,' from an enclosing list, or
the `)' and `;;' closing the surrounding `prove'."
  (let ((tactic (string-trim tactic))
        (done nil))
    (while (not done)
      (setq done t)
      (when (string-suffix-p ";;" tactic)
        (setq tactic (string-trim (substring tactic 0 -2))
              done nil))
      (when (string-match "\\(?:[;,]\\|\\_<THENL?\\_>\\)\\'" tactic)
        (setq tactic (string-trim (substring tactic 0 (match-beginning 0)))
              done nil))
      ;; A closer with no opener of its own belongs to the enclosing form, so
      ;; drop it -- but keep the balanced ones, such as a REWRITE_TAC[...] list.
      (when (and (string-match "[])]\\'" tactic)
                 (hol-light--unbalanced-closer-p tactic))
        (setq tactic (string-trim (substring tactic 0 -1))
              done nil)))
    tactic))

(defun hol-light--unbalanced-closer-p (text)
  "Return non-nil if TEXT closes more brackets than it opens."
  (let ((depth 0))
    (dolist (char (append text nil))
      (cond ((memq char '(?\( ?\[)) (setq depth (1+ depth)))
            ((memq char '(?\) ?\])) (setq depth (1- depth)))))
    (< depth 0)))

(defun hol-light-back ()
  "Undo the last tactic, HOL Light's `b()', and drop the highlighting.
The highlighting goes because the toplevel's state no longer corresponds to
any one region of the buffer."
  (interactive)
  (hol-light--send "b()")
  (hol-light-remove-highlighting))

(defun hol-light-print-goal ()
  "Print the current goal state, HOL Light's `p()'."
  (interactive)
  (hol-light--send "p()"))

(defun hol-light-rotate ()
  "Rotate to the next subgoal, HOL Light's `r 1'."
  (interactive)
  (hol-light--send "r 1"))

(defun hol-light-top-thm ()
  "Print the theorem proved by the completed goal, HOL Light's `top_thm()'."
  (interactive)
  (hol-light--send "top_thm()"))

(defun hol-light-search-name (name)
  "List the HOL Light theorems whose name contains NAME."
  (interactive "sTheorem name contains: ")
  (hol-light--send (format "search [name %S]" name)))


;;; Documentation
;;
;; HOL Light ships one `.hlp' file per documented name in its Help directory,
;; in the \DOC/\TYPE/\SYNOPSIS/... markup that its own `doc-to-help.sed' turns
;; into plain text.

(defconst hol-light--operator-chars "-+$&*/=>@^\\\\|~!?%<:."
  "Characters that HOL Light operator names are made of.
Taken from the VS Code extension, which falls back to scanning these when
the position is not on an ordinary word.")

(defvar hol-light--help-index nil
  "Hash table mapping a documented name to its `.hlp' file, or nil if unbuilt.")

(defvar hol-light--help-cache (make-hash-table :test #'equal)
  "Cache of parsed `.hlp' files, keyed by documented name.")

(defun hol-light--help-directory ()
  "Return HOL Light's Help directory, or nil when it is missing."
  (let ((directory (expand-file-name "Help" hol-light-directory)))
    (and (file-directory-p directory) directory)))

(defun hol-light--help-doc-name (file)
  "Return the name declared on FILE's \\DOC line, or nil."
  (with-temp-buffer
    ;; The \DOC line comes first, so there is no need to read the whole file.
    (ignore-errors (insert-file-contents file nil 0 200))
    (goto-char (point-min))
    (when (looking-at "\\\\DOC[ \t]+\\(.*?\\)[ \t]*$")
      (match-string 1))))

(defun hol-light--help-index ()
  "Return the index of documented names, building it on first use.
Keyed by the name on each file's \\DOC line rather than by file name: 20
entries disagree, among them common ones such as REPEAT and EXISTS, which
live in `*_UPPERCASE.hlp' because a case-insensitive file system cannot also
hold their lowercase namesakes."
  (or hol-light--help-index
      (when-let* ((directory (hol-light--help-directory)))
        (let ((index (make-hash-table :test #'equal)))
          (dolist (file (directory-files directory t "\\.hlp\\'" t))
            (when-let* ((name (hol-light--help-doc-name file)))
              (puthash name file index)))
          (setq hol-light--help-index index)))))

(defun hol-light-reload-documentation ()
  "Rebuild the index of HOL Light documentation from disk."
  (interactive)
  (setq hol-light--help-index nil)
  (clrhash hol-light--help-cache)
  (message "HOL Light: %d documented names"
           (hash-table-count (or (hol-light--help-index)
                                 (make-hash-table :test #'equal)))))

(defun hol-light--help-render-line (line)
  "Return LINE with HOL Light's help markup rendered as plain text.
Follows the substitutions in HOL Light's `doc-to-help.sed', with `{...}'
becoming the `code' quoting Emacs help buffers use.  The order matters: the
markup doubles its braces to mean literal ones, as in `\\end{{itemize}}' and
`{{\\em not}}', so those are hidden while single braces are rewritten and
only then restored and interpreted."
  (let ((line (replace-regexp-in-string "\\\\noindent[ \t]*" "" line)))
    (setq line (replace-regexp-in-string "``\\(.*?\\)''" "\u201c\\1\u201d" line))
    (setq line (replace-regexp-in-string "{{" "\0<" line))
    (setq line (replace-regexp-in-string "}}" "\0>" line))
    (setq line (replace-regexp-in-string "{\\(.*?\\)}" "`\\1'" line))
    (setq line (replace-regexp-in-string "\0<" "{" line))
    (setq line (replace-regexp-in-string "\0>" "}" line))
    (setq line (replace-regexp-in-string "{\\\\em \\(.*?\\)}" "*\\1*" line))
    (setq line (replace-regexp-in-string "\\\\\\(?:begin\\|end\\){itemize}" "" line))
    (setq line (replace-regexp-in-string "\\\\item\\b" "-" line))
    line))

(defun hol-light--help-sections (name)
  "Return the sections documenting NAME as an alist, or nil if undocumented.
Keys are the markup names -- \"DOC\", \"TYPE\", \"SYNOPSIS\" and so on -- in
the order they appear."
  (when-let* ((index (hol-light--help-index)))
    (if-let* ((cached (gethash name hol-light--help-cache)))
        (and (consp cached) cached)
      (let ((sections
             (when-let* ((file (gethash name index)))
               (with-temp-buffer
                 (insert-file-contents file)
                 (goto-char (point-min))
                 ;; The markers are upper case, and `\begin'/`\item' are not
                 ;; markers -- which case folding would blur.
                 (let ((case-fold-search nil)
                       (result nil) (section nil) (lines nil))
                   (cl-flet ((flush ()
                               (when section
                                 ;; Drop the blank lines each section ends with.
                                 (while (and lines (string-blank-p (car lines)))
                                   (pop lines))
                                 (push (cons section
                                             (string-join (nreverse lines) "\n"))
                                       result))
                               (setq section nil lines nil)))
                     (while (not (eobp))
                       (let ((line (buffer-substring-no-properties
                                    (line-beginning-position) (line-end-position))))
                         (if (string-match "\\`\\\\\\([A-Z_0-9]+\\)[ \t]*\\(.*\\)" line)
                             (let ((marker (match-string 1 line))
                                   (rest (match-string 2 line)))
                               (when (equal marker "ENDDOC")
                                 (goto-char (point-max)))
                               (unless (equal marker "ENDDOC")
                                 (flush)
                                 (setq section marker)
                                 (unless (string-empty-p rest)
                                   ;; The text sharing the marker's line needs
                                   ;; rendering as much as the lines below it --
                                   ;; \TYPE carries its whole signature here.
                                   (push (hol-light--help-render-line rest) lines))))
                           ;; A brace alone on a line delimits a code block; the
                           ;; block reads well enough without the braces.
                           (unless (string-match-p "\\`[{}][ \t]*\\'" line)
                             (push (hol-light--help-render-line line) lines))))
                       (forward-line 1))
                     (flush))
                   (nreverse result))))))
        ;; Cache misses too, so an undocumented symbol is not looked up again.
        (puthash name (or sections 'none) hol-light--help-cache)
        sections))))

(defun hol-light--symbol-at-point ()
  "Return the HOL Light identifier or operator around point."
  (or (thing-at-point 'symbol t)
      (save-excursion
        (let ((end (progn (skip-chars-forward hol-light--operator-chars) (point)))
              (beg (progn (skip-chars-backward hol-light--operator-chars) (point))))
          (and (< beg end) (buffer-substring-no-properties beg end))))))

(defun hol-light--help-summary (sections)
  "Return the one-glance documentation in SECTIONS: its type and synopsis."
  (let ((type (alist-get "TYPE" sections nil nil #'equal))
        (synopsis (alist-get "SYNOPSIS" sections nil nil #'equal)))
    ;; \TYPE wraps the whole signature in braces, which render as code quoting;
    ;; unwrap it, since the signature is the entire line here.
    (when type
      (setq type (string-trim type))
      (when (string-match "\\``\\(.*\\)'\\'" type)
        (setq type (match-string 1 type))))
    (string-join (delq nil (list type (and synopsis (string-trim synopsis))))
                 "\n")))

(defun hol-light-eldoc-function (callback &rest _)
  "Give CALLBACK the HOL Light documentation for the symbol at point.
For `eldoc-documentation-functions'."
  (when-let* ((name (hol-light--symbol-at-point))
              (sections (hol-light--help-sections name))
              (summary (hol-light--help-summary sections))
              ((not (string-empty-p summary))))
    (funcall callback summary
             :thing name
             :face 'font-lock-function-name-face)
    t))

(defun hol-light-help (name)
  "Show HOL Light's full documentation for NAME.
Interactively, offer the symbol at point, completing over every documented
name."
  (interactive
   (let* ((index (or (hol-light--help-index)
                     (user-error "No Help directory in %s"
                                 (abbreviate-file-name hol-light-directory))))
          (default (hol-light--symbol-at-point)))
     (list (completing-read (format-prompt "Describe HOL Light name" default)
                            index nil nil nil nil default))))
  (let ((sections (or (hol-light--help-sections name)
                      (user-error "HOL Light does not document `%s'" name))))
    (help-setup-xref (list #'hol-light-help name) (called-interactively-p 'interactive))
    (with-help-window (help-buffer)
      (princ name)
      (terpri)
      (terpri)
      (pcase-dolist (`(,section . ,text) sections)
        (unless (member section '("DOC"))
          (princ (if (equal section "TYPE") "TYPE\n" (concat section "\n")))
          (princ (replace-regexp-in-string "^" "  " (string-trim-right text)))
          (terpri)
          (terpri))))))


;;; Finding definitions

(defun hol-light--definition-regexp (name)
  "Return a regexp matching a definition of NAME in HOL Light's sources.
Covers `let NAME = ...' and `and NAME = ...', including the tuple bindings
used for conjunction pairs, as in `let A,B = CONJ_PAIR th'."
  (format "^[ \t]*\\(?:let\\|and\\)[ \t]+\\(?:rec[ \t]+\\)?\\(?:[][A-Za-z0-9_',() \t]*[,(][ \t]*\\)?%s\\b"
          (regexp-quote name)))

(defun hol-light-xref-backend ()
  "Return the `hol-light' xref backend for HOL Light sources."
  'hol-light)

(cl-defmethod xref-backend-identifier-at-point ((_backend (eql hol-light)))
  (hol-light--symbol-at-point))

(cl-defmethod xref-backend-identifier-completion-table ((_backend (eql hol-light)))
  ;; The documented names are the ones worth completing; anything else is found
  ;; by typing it out.
  (or (hol-light--help-index) (make-hash-table :test #'equal)))

(cl-defmethod xref-backend-definitions ((_backend (eql hol-light)) identifier)
  (xref-matches-in-directory (hol-light--definition-regexp identifier)
                             "*.ml" hol-light-directory
                             '("_opam/" "_build/")))


;;; Minor mode

(defvar-keymap hol-light-mode-map
  :doc "Keymap for `hol-light-mode'."
  "C-c C-s"         #'hol-light-run
  "C-c C-c"         #'hol-light-interrupt
  "C-c C-e"         #'hol-light-send-statement
  "C-c C-t"         #'hol-light-send-tactic
  "C-c C-g"         #'hol-light-set-goal
  "C-c C-r"         #'hol-light-send-region
  "C-c C-l"         #'hol-light-send-buffer
  "C-c C-b"         #'hol-light-send-before-point
  "C-c C-u"         #'hol-light-back
  "C-c C-p"         #'hol-light-print-goal
  "C-c C-n"         #'hol-light-rotate
  "C-c C-q"         #'hol-light-top-thm
  "C-c C-a"         #'hol-light-search-name
  "C-c C-d"         #'hol-light-help
  "C-c C-."         #'hol-light-jump-to-highlight
  "C-c C-<backspace>" #'hol-light-remove-highlighting)

(defvar hol-light--font-lock-keywords
  ;; OVERRIDE is t because tuareg has already fontified the term as OCaml, where
  ;; a backquote opens a polymorphic variant rather than a quotation.
  '(("`[^`]*`" 0 'hol-light-term-face t))
  "Additional `font-lock-keywords' highlighting HOL Light term quotations.")

;;;###autoload
(define-minor-mode hol-light-mode
  "Minor mode for editing HOL Light sources against a HOL Light toplevel.

Highlights backquoted term quotations, documents the symbol at point through
eldoc and \\<hol-light-mode-map>\\[hol-light-help], resolves
\\[xref-find-definitions] against HOL Light's sources, and binds the proof
commands below.  \\[hol-light-send-tactic] applies the tactic on the current
line and steps to the next, highlighting it green once the toplevel accepts
it and red if it does not.

\\{hol-light-mode-map}"
  :lighter " HOL"
  :keymap hol-light-mode-map
  (cond
   (hol-light-mode
    ;; Quotations run across lines, which plain keyword matching would stop at.
    (setq-local font-lock-multiline t)
    (font-lock-add-keywords nil hol-light--font-lock-keywords 'append)
    (add-hook 'eldoc-documentation-functions #'hol-light-eldoc-function nil t)
    (add-hook 'xref-backend-functions #'hol-light-xref-backend nil t))
   (t
    (font-lock-remove-keywords nil hol-light--font-lock-keywords)
    (remove-hook 'eldoc-documentation-functions #'hol-light-eldoc-function t)
    (remove-hook 'xref-backend-functions #'hol-light-xref-backend t)
    (hol-light-remove-highlighting)))
  (when font-lock-mode
    (font-lock-flush)))

;;;###autoload
(defun hol-light-file-p (&optional file)
  "Return non-nil if FILE, or the current buffer's file, is a HOL Light source."
  (when-let* ((file (or file buffer-file-name)))
    (string-prefix-p (file-name-as-directory (expand-file-name hol-light-directory))
                     (expand-file-name file))))

;;;###autoload
(defun hol-light-tuareg-setup ()
  "Turn on `hol-light-mode' for files under `hol-light-directory'.
Meant for `tuareg-mode-hook', where it leaves other OCaml buffers alone."
  (when (hol-light-file-p)
    (hol-light-mode)))

(provide 'hol-light)

;;; hol-light.el ends here
