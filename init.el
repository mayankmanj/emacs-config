;;; init.el --- Init -*- lexical-binding: t; -*-

;;; Before package

;; Ask the user whether to terminate asynchronous compilations on exit.
;; This prevents native compilation from leaving temporary files in /tmp.

(setq native-comp-async-query-on-exit t)

;; Allow for shorter responses: "y" for yes and "n" for no.
(setq read-answer-short t)
(if (boundp 'use-short-answers)
    (setq use-short-answers t)
  (advice-add 'yes-or-no-p :override #'y-or-n-p))

;;; Undo/redo

(setq undo-limit (* 13 160000)
      undo-strong-limit (* 13 240000)
      undo-outer-limit (* 13 24000000))

(setq package-enable-at-startup nil)

;;; straight.el
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name
        "straight/repos/straight.el/bootstrap.el"
        (or (bound-and-true-p straight-base-dir)
            user-emacs-directory)))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(straight-use-package 'use-package)
(setq straight-use-package-by-default t)

;; set use-package-verbose to t for interpreted .emacs,
;; and to nil for byte-compiled .emacs.elc.
;; Verbose when running interpreted (not byte-compiled); overrides early-init.
(eval-and-compile
  (setq use-package-verbose (not (bound-and-true-p byte-compile-current-file))))

(use-package emacs
  :config
;;; Minibuffer

  ;; Allow nested minibuffers
  (setq enable-recursive-minibuffers t)

  ;; Keep the cursor out of the read-only portions of the.minibuffer
  (setq minibuffer-prompt-properties
        '(read-only t intangible t cursor-intangible t face minibuffer-prompt))
  (add-hook 'minibuffer-setup-hook #'cursor-intangible-mode)

;;; User interface

  ;; By default, Emacs "updates" its ui more often than it needs to
  (setq which-func-update-delay 1.0)

  (defalias #'view-hello-file #'ignore) ; Never show the hello file

  ;; No beeping or blinking
  (setq visible-bell nil)
  (setq ring-bell-function #'ignore)

  ;; Misc
  (setq custom-buffer-done-kill t)

  (setq whitespace-line-column nil)     ; Use the value of `fill-column'.

  (setq truncate-string-ellipsis "…")

  ;; Disable truncation of printed s-expressions in the message buffer
  (setq eval-expression-print-length nil
        eval-expression-print-level nil)

  ;; Position underlines at the descent line instead of the baseline.
  (setq x-underline-at-descent-line t)

  ;; Disable auto-adding a new line at the bottom when scrolling.
  (setq next-line-add-newlines nil)
  ;; Delete by moving to trash in interactive mode
  (setq delete-by-moving-to-trash (not noninteractive))
  (setq remote-file-name-inhibit-delete-by-moving-to-trash t)

  ;; Ignoring this is acceptable since it will redirect to the buffer regardless.
  (setq find-file-suppress-same-file-warnings t)

  ;; Resolve symlinks so that operations are conducted from the file's directory
  (setq find-file-visit-truename t
        vc-follow-symlinks t)

  ;; Prefer vertical splits over horizontal ones
  (setq split-width-threshold 170
        split-height-threshold nil)

;;; Buffers

  (setq uniquify-buffer-name-style 'forward)

;;; comint (general command interpreter in a window)

  (setq ansi-color-for-comint-mode t
        comint-prompt-read-only t
        comint-buffer-maximum-size 4096)

;;; Compilation

  (setq compilation-ask-about-save nil
        compilation-always-kill t
        compilation-scroll-output 'first-error)

  ;; Skip confirmation prompts when creating a new file or buffer
  (setq confirm-nonexistent-file-or-buffer nil)

;;; Backup files

  ;; Avoid backups or lockfiles to prevent creating world-readable copies of files
  (setq create-lockfiles nil)
  (setq make-backup-files nil)

  (setq backup-directory-alist
        `(("." . ,(expand-file-name "backup" user-emacs-directory))))
  (setq tramp-backup-directory-alist backup-directory-alist)
  (setq backup-by-copying-when-linked t)
  (setq backup-by-copying t)            ; Backup by copying rather renaming
  (setq delete-old-versions t)          ; Delete excess backup versions silently
  (setq version-control t)              ; Use version numbers for backup files
  (setq kept-new-versions 5)
  (setq kept-old-versions 5)

  ;; Remove duplicates from the kill ring to reduce clutter
  (setq kill-do-not-save-duplicates t)

  ;; Auto-save
  ;; Enable auto-save to safeguard against crashes or data loss. The
  ;; `recover-file' or `recover-session' functions can be used to restore
  ;; auto-saved data.
  (setq auto-save-default t)
  (setq auto-save-no-message t)
  (setq auto-save-file-name-transforms
      '((".*" "~/.config/emacs/auto-save-files/\\1" t)))

  ;; Do not auto-disable auto-save after deleting large chunks of
  ;; text.
  (setq auto-save-include-big-deletions t)

  (setq auto-save-list-file-prefix
        (expand-file-name "autosave/" user-emacs-directory))
  (setq tramp-auto-save-directory
        (expand-file-name "tramp-autosave/" user-emacs-directory))

  ;; Auto save options
  ;; (setq kill-buffer-delete-auto-save-files t)

  ;; Auto-revert in Emacs is a feature that automatically updates the contents of
  ;; a buffer to reflect changes made to the underlying file.
  (setq revert-without-query (list ".") ; Do not prompt
        auto-revert-stop-on-user-input nil
        auto-revert-verbose t)

  ;; Revert other buffers (e.g, Dired)
  (setq global-auto-revert-non-file-buffers t)
  (setq global-auto-revert-ignore-modes '(Buffer-menu-mode)) ; Resolve issue #29

  ;; Start global-auto-revert mode
  (global-auto-revert-mode)

;;; Frames and windows

  ;; However, do not resize windows pixelwise, as this can cause crashes in some
  ;; cases when resizing too many windows at once or rapidly.
  (setq window-resize-pixelwise nil)

  (setq resize-mini-windows 'grow-only)

  ;; The native border "uses" a pixel of the fringe on the rightmost
  ;; splits, whereas `window-divider-mode' does not.
  (setq window-divider-default-bottom-width 1
        window-divider-default-places t
        window-divider-default-right-width 1)

;;; Fontification

  ;; Disable fontification during user input to reduce lag in large buffers.
  ;; Also helps marginally with scrolling performance.
  (setq redisplay-skip-fontification-on-input t)

;;; Scrolling

  ;; Enables faster scrolling. This may result in brief periods of inaccurate
  ;; syntax highlighting, which should quickly self-correct.
  (setq fast-but-imprecise-scrolling t)

  ;; Move point to top/bottom of buffer before signaling a scrolling error.
  (setq scroll-error-top-bottom t)

  ;; Keep screen position if scroll command moved it vertically out of the window.
  (setq scroll-preserve-screen-position t)

  ;; If `scroll-conservatively' is set above 100, the window is never
  ;; automatically recentered, which decreases the time spend recentering.
  (setq scroll-conservatively 101)

  ;; 1. Preventing automatic adjustments to `window-vscroll' for long lines.
  ;; 2. Resolving the issue of random half-screen jumps during scrolling.
  (setq auto-window-vscroll nil)

  ;; Number of lines of margin at the top and bottom of a window.
  (setq scroll-margin 0)

  ;; Number of lines of continuity when scrolling by screenfuls.
  (setq next-screen-context-lines 0)

  ;; Horizontal scrolling
  (setq hscroll-margin 2
        hscroll-step 1)

;;; Mouse

  (setq mouse-yank-at-point nil)

  ;; Emacs 29
  (when (memq 'context-menu my-emacs-ui-features)
    (when (and (display-graphic-p) (fboundp 'context-menu-mode))
      (add-hook 'after-init-hook #'context-menu-mode)))

;;; Cursor

  ;; The blinking cursor is distracting and interferes with cursor settings in
  ;; some minor modes that try to change it buffer-locally (e.g., Treemacs).
  (when (bound-and-true-p blink-cursor-mode)
    (blink-cursor-mode -1))

  ;; Don't blink the paren matching the one at point, it's too distracting.
  (setq blink-matching-paren nil)

  ;; Do not extend the cursor to fit wide characters
  (setq x-stretch-cursor nil)

  ;; Reduce rendering/line scan work by not rendering cursors or regions in
  ;; non-focused windows.
  (setq-default cursor-in-non-selected-windows nil)
  (setq highlight-nonselected-windows nil)

;;; Text editing, indent, font, and formatting

  ;; Avoid automatic frame resizing when adjusting settings.
  (setq global-text-scale-adjust-resizes-frames nil)

  ;; A longer delay can be annoying as it causes a noticeable pause after each
  ;; deletion, disrupting the flow of editing.
  (setq delete-pair-blink-delay 0.03)

  (setq-default left-fringe-width  8)
  (setq-default right-fringe-width 8)

  ;; Disable visual indicators in the fringe for buffer boundaries and empty lines
  (setq-default indicate-buffer-boundaries nil)
  (setq-default indicate-empty-lines nil)

  ;; Continue wrapped lines at whitespace rather than breaking in the
  ;; middle of a word.
  (setq-default word-wrap t)

  ;; Disable wrapping by default due to its performance cost.
  (setq-default truncate-lines t)

  ;; If enabled and `truncate-lines' is disabled, soft wrapping will not occur
  ;; when the window is narrower than `truncate-partial-width-windows' characters.
  (setq truncate-partial-width-windows nil)

  ;; Configure automatic indentation to be triggered exclusively by newline and
  ;; DEL (backspace) characters.
  (setq-default electric-indent-chars '(?\n ?\^?))

  ;; Prefer spaces over tabs. Spaces offer a more consistent default compared to
  ;; 8-space tabs. This setting can be adjusted on a per-mode basis as needed.
  (setq-default indent-tabs-mode nil
                tab-width 4)

  ;; Enable indentation and completion using the TAB key
  (setq tab-always-indent 'complete)
  (setq tab-first-completion 'word-or-paren-or-punct)

  ;; Perf: Reduce command completion overhead.
  (setq read-extended-command-predicate #'command-completion-default-include-p)

  ;; Enable multi-line commenting which ensures that `comment-indent-new-line'
  ;; properly continues comments onto new lines.
  (setq comment-multi-line t)

  ;; Ensures that empty lines within the commented region are also commented out.
  ;; This prevents unintended visual gaps and maintains a consistent appearance.
  (setq comment-empty-lines t)

  ;; We often split terminals and editor windows or place them side-by-side,
  ;; making use of the additional horizontal space.
  (setq-default fill-column 80)

  ;; Disable the obsolete practice of end-of-line spacing from the typewriter era.
  (setq sentence-end-double-space nil)

  ;; According to the POSIX, a line is defined as "a sequence of zero or more
  ;; non-newline characters followed by a terminating newline".
  (setq require-final-newline t)

  ;; Eliminate delay before highlighting search matches
  (setq lazy-highlight-initial-delay 0)

;;; Modeline

  ;; Makes Emacs omit the load average information from the mode line.
  (setq display-time-default-load-average nil)

;;; Filetype

  ;; Do not notify the user each time Python tries to guess the indentation offset
  (setq python-indent-guess-indent-offset-verbose nil)

  (setq sh-indent-after-continuation 'always)

  ;; Dired

  (setq dired-free-space nil
        dired-dwim-target t    ; Propose a target for intelligent moving/copying
        dired-deletion-confirmer 'y-or-n-p
        dired-filter-verbose nil
        dired-recursive-deletes 'top
        dired-recursive-copies 'always
        dired-vc-rename-file t
        dired-create-destination-dirs 'ask
        ;; Constrain vertical cursor movement to lines within the buffer
        dired-movement-style 'bounded-files
        ;; Suppress Dired buffer kill prompt for deleted dirs
        dired-clean-confirm-killing-deleted-buffers nil)

  ;; This is a higher-level predicate that wraps `dired-directory-changed-p'
  ;; with additional logic. This `dired-buffer-stale-p' predicate handles remote
  ;; files, wdired, unreadable dirs, and delegates to dired-directory-changed-p
  ;; for modification checks.
  (setq auto-revert-remote-files nil)
  (setq dired-auto-revert-buffer 'dired-buffer-stale-p)

  ;; dired-omit-mode
  (setq dired-omit-verbose nil
        dired-omit-files (concat "\\`[.]\\'"))

  (setq ls-lisp-verbosity nil)
  (setq ls-lisp-dirs-first t)

;;; Help

  ;; Enhance `apropos' and related functions to perform more extensive searches
  (setq apropos-do-all t)

  ;; Fixes #11: Prevents help command completion from triggering autoload.
  ;; Loading additional files for completion can slow down help commands and may
  ;; unintentionally execute initialization code from some libraries.
  (setq help-enable-completion-autoload nil)
  (setq help-enable-autoload nil)
  (setq help-enable-symbol-autoload nil)
  (setq help-window-select t) ;; Focus new help windows when opened

;;; abbrev
  ;; Ensure `abbrev_defs` is stored in the correct location when
  ;; `user-emacs-directory` is modified, as it defaults to ~/.emacs.d/abbrev_defs
  ;; regardless of the change.
  (setq abbrev-file-name (expand-file-name "abbrev_defs" user-emacs-directory))

  (setq save-abbrevs 'silently)

;;; Remove warnings from narrow-to-region, upcase-region...

  (dolist (cmd '(list-timers narrow-to-region upcase-region downcase-region
                             list-threads erase-buffer scroll-left
                             dired-find-alternate-file))
    (put cmd 'disabled nil))


  ;; Custom file
  (setq custom-file "~/.config/emacs/custom-settings.el")

  (load custom-file t)

  ;; Additional elisp files
  (add-to-list 'load-path "~/.config/emacs/elisp")

  ;; Personal Information
  (setq user-full-name "Mayank Manjrekar"
        user-mail-address "mayank.manjrekar2@arm.com")

  ;; System information
  (defvar macos-p
    (eq system-type 'darwin))
  (defvar linux-p
    (eq system-type 'gnu/linux))

  (when macos-p
    (setq mac-command-modifier 'meta)
    (setq mac-option-modifier 'meta))
  (when linux-p
    (setq x-alt-keysym 'meta)
    (setq x-super-keysym 'meta))

  (advice-add 'kill-region :around
    (lambda (fn &optional beg end region)
      "When called interactively with no active region, kill a single line instead."
      (interactive
       (if mark-active (list (region-beginning) (region-end))
         (list (line-beginning-position)
               (line-beginning-position 2))))
      (funcall fn beg end region))
    '((name . slick-cut)))

  ;; Misc settings
  (setq-default
   cursor-type '(bar . 3)
   bookmark-default-file (expand-file-name ".bookmarks.el" user-emacs-directory)
   buffers-menu-max-size 30
   case-fold-search t
   save-interprogram-paste-before-kill t
   set-mark-command-repeat-pop t
   tooltip-delay 1.5)

  ;; Emacs' default buffer placement algorithm is pretty disruptive if
  ;; you like setting up window layouts a certain way in your
  ;; workflow. The display-buffer-alist video controls this behavior and
  ;; you can customize it to prevent Emacs from popping up new windows
  ;; when you run commands.
  (setq display-buffer-base-action
        '(display-buffer-reuse-mode-window
          display-buffer-reuse-window
          display-buffer-same-window))

  ;; If a popup does happen, don't resize windows to be equal-sized
  (setq even-window-sizes nil)

  (prefer-coding-system 'utf-8)
  (when (display-graphic-p)
    (setq x-select-request-type '(UTF8_STRING COMPOUND_TEXT TEXT STRING)))

  (defun my-dabbrev-friend-buffer (other-buffer)
    (< (buffer-size other-buffer) (* 1 1024 1024)))
  (setq dabbrev-friend-buffer-function 'my-dabbrev-friend-buffer)
  (setq hippie-expand-try-functions-list
        '(yas-hippie-try-expand
          try-expand-all-abbrevs
          try-complete-file-name-partially
          try-complete-file-name
          try-expand-dabbrev
          try-expand-dabbrev-from-kill
          try-expand-dabbrev-all-buffers
          try-expand-list
          try-expand-line
          try-complete-lisp-symbol-partially
          try-complete-lisp-symbol))

  (setq epa-pinentry-mode 'loopback)

  (defun my-cleanup-on-save ()
    "Clean up whitespace before saving. Only runs in prog/text modes.
Skips untabify when the buffer uses tab indentation (e.g. Makefiles, Go)."
    (when (derived-mode-p 'prog-mode 'text-mode)
      (unless indent-tabs-mode
        (untabify (point-min) (point-max)))
      (whitespace-cleanup)))

  (add-hook 'before-save-hook 'my-cleanup-on-save)

  ;; (server-start)
  ) ;; Emacs

(use-package paren
  :config
  (message "init.el: loaded paren")
;;; Show-paren

  (setq show-paren-delay 0.1
        show-paren-highlight-openparen t
        show-paren-when-point-inside-paren t
        show-paren-when-point-in-periphery t)
  ) ;; show-paren


;;; Misc

(use-package display-line-numbers
  :hook ((text-mode prog-mode) . display-line-numbers-mode)
  :config
  (message "init.el: loaded display-line-numbers")
  ;; Can be activated with `display-line-numbers-mode'
  (setq-default display-line-numbers-width 3)
  (setq-default display-line-numbers-widen t)
  ) ;; display-line-numbers

(use-package tramp
  :config
  (message "init.el: loaded tramp")
  (setq tramp-verbose 1)
  (setq tramp-completion-reread-directory-timeout 50)
  (setq remote-file-name-inhibit-cache 50)
  ) ;; tramp

;; Automatically rescan the buffer for Imenu entries when `imenu' is invoked
;; This ensures the index reflects recent edits.
(use-package imenu
  :config
  (message "init.el: loaded imenu")
  (setq imenu-auto-rescan t)

  ;; Prevent truncation of long function names in `imenu' listings
  (setq imenu-max-item-length 160)
  ) ;; imenu

;;; Files


;;; VC

(use-package vc
  :config
  (message "init.el: loaded vc")
  (setq vc-git-print-log-follow t)
  (setq vc-make-backup-files nil)  ; Do not backup version controlled files
  (setq vc-git-diff-switches '("--histogram"))  ; Faster algorithm for diffing.
  ) ;; VC

;;; recentf

(use-package recentf
  :config
  (message "init.el: loaded recentf")
  ;; `recentf' is an that maintains a list of recently accessed files.
  (setq recentf-max-saved-items 300) ; default is 20
  (setq recentf-max-menu-items 15)
  (setq recentf-auto-cleanup 'mode)

  ;; Update recentf-exclude
  (setq recentf-exclude (list "^/\\(?:ssh\\|su\\|sudo\\)?:"))
  (recentf-mode)
  ) ;; recentf

;;; saveplace
(use-package saveplace
  :config
  (message "init.el: loaded saveplace")
  ;; Enables Emacs to remember the last location within a file upon reopening.
  (setq save-place-file (expand-file-name "saveplace" user-emacs-directory))
  (setq save-place-limit 600)
  (save-place-mode 1)
  ) ;; saveplace

;;; savehist
(use-package savehist
  :config
  (message "init.el: loaded savehist")
  ;; `savehist-mode' is an Emacs feature that preserves the minibuffer history
  ;; between sessions.
  (setq history-length 300)
  (setq savehist-save-minibuffer-history t)  ;; Default
  (setq savehist-additional-variables
        '(kill-ring                        ; clipboard
          register-alist                   ; macros
          mark-ring global-mark-ring       ; marks
          search-ring regexp-search-ring)) ; searches
  (setq savehist-file (expand-file-name "savehist" user-emacs-directory))
  (setq history-delete-duplicates t)
  (savehist-mode 1)
  ) ;; savehist

;;; Ediff

(use-package ediff
  :config
  (message "init.el: loaded ediff")
  ;; Configure Ediff to use a single frame and split windows horizontally
  (setq ediff-window-setup-function 'ediff-setup-windows-plain
        ediff-split-window-function 'split-window-horizontally)
  (defvar my-ediff-last-windows nil)

  (defun my-store-pre-ediff-winconfig ()
    "Store `current-window-configuration' in variable `my-ediff-last-windows'."
    (setq my-ediff-last-windows (current-window-configuration)))

  (defun my-restore-pre-ediff-winconfig ()
    "Restore window configuration to stored value in `my-ediff-last-windows'."
    (set-window-configuration my-ediff-last-windows))

  (add-hook 'ediff-before-setup-hook #'my-store-pre-ediff-winconfig)
  (add-hook 'ediff-quit-hook #'my-restore-pre-ediff-winconfig)
  ) ;; ediff

;;; Eglot

(use-package eglot
  :defer t
  :config
  (message "init.el: loaded eglot")
  ;; A setting of nil or 0 means Eglot will not block the UI at all, allowing
  ;; Emacs to remain fully responsive, although LSP features will only become
  ;; available once the connection is established in the background.
  (setq eglot-sync-connect 0)

  (setq eglot-autoshutdown t)  ; Shut down server after killing last managed buffer

  ;; Activate Eglot in cross-referenced non-project files
  (setq eglot-extend-to-xref t)

  ;; Eglot optimization
  (if my-emacs-debug
      (setq eglot-events-buffer-config '(:size 2000000 :format full))
    ;; This reduces log clutter to improves performance.
    (setq jsonrpc-event-hook nil)
    ;; Reduce memory usage and avoid cluttering *EGLOT events* buffer
    (setq eglot-events-buffer-size 0)  ; Deprecated
    (setq eglot-events-buffer-config '(:size 0 :format short)))

  (setq eglot-report-progress my-emacs-debug)  ; Prevent minibuffer spam
  ) ;; eglot

;;; Flymake
(use-package flymake
  :config
  (message "init.el: loaded flymake")
  (setq flymake-show-diagnostics-at-end-of-line nil)

  ;; Disable wrapping around when navigating Flymake errors.
  (setq flymake-wrap-around nil)
  ) ;; flymake

;;; hl-line-mode
(use-package hl-line
  :config
  (message "init.el: loaded hl-line")

  ;; Restrict `hl-line-mode' highlighting to the current window, reducing visual
  ;; clutter and slightly improving `hl-line-mode' performance.
  (setq hl-line-sticky-flag nil)
  (setq global-hl-line-sticky-flag nil)
  ) ;; hl-line

;;; icomplete
(use-package icomplete
  :config
  (message "init.el: loaded icomplete")
  ;; Do not delay displaying completion candidates in `fido-mode' or
  ;; `fido-vertical-mode'
  (setq icomplete-compute-delay 0.01)
  ) ;; icomplete

;;; flyspell
(use-package flyspell
  :config
  (message "init.el: loaded flyspell")

  (setq flyspell-issue-welcome-flag nil)

  ;; Improves flyspell performance by preventing messages from being displayed for
  ;; each word when checking the entire buffer.
  (setq flyspell-issue-message-flag nil)
  ) ;; flyspell

;;; ispell
(use-package ispell
  :config
  (message "init.el: loaded ispell")
  ;; In Emacs 30 and newer, disable Ispell completion to avoid annotation errors
  ;; when no `ispell' dictionary is set.
  (setq text-mode-ispell-word-completion nil)

  (setq ispell-silently-savep t)
  ) ;; ispell

;;; ibuffer
(use-package ibuffer
  :config
  (message "init.el: loaded ibuffer")
  (setq ibuffer-formats
        '((mark modified read-only locked
                " " (name 55 55 :left :elide)
                " " (size 8 -1 :right)
                " " (mode 18 18 :left :elide) " " filename-and-process)
          (mark " " (name 16 -1) " " filename)))
  ) ;; ibuffer

;;; xref
(use-package xref
  :config
  (message "init.el: loaded xref")
  ;; Enable completion in the minibuffer instead of the definitions buffer
  (setq xref-show-definitions-function 'xref-show-definitions-completing-read
        xref-show-xrefs-function 'xref-show-definitions-completing-read)
  ) ;; xref

;;; dabbrev
(use-package dabbrev
  :config
  (message "init.el: loaded dabbrev")
  (setq dabbrev-upcase-means-case-search t)

  (setq dabbrev-ignored-buffer-modes
        '(archive-mode image-mode docview-mode tags-table-mode pdf-view-mode))

  (setq dabbrev-ignored-buffer-regexps
        '(;; - Buffers starting with a space (internal or temporary buffers)
          "\\` "
          ;; Tags files such as ETAGS, GTAGS, RTAGS, TAGS, e?tags, and GPATH,
          ;; including versions with numeric extensions like <123>
          "\\(?:\\(?:[EG]?\\|GR\\)TAGS\\|e?tags\\|GPATH\\)\\(<[0-9]+>\\)?"))
  ) ;; dabbrev

;;; Diminish minor modes
(use-package diminish
  :config
  (message "loaded diminish")
  (diminish 'eldoc-mode)
  )

;;; Exec path:
(use-package exec-path-from-shell
  :hook (after-init . exec-path-from-shell-initialize)
  :if macos-p
  :config
  (dolist (var '("SSH_AUTH_SOCK"
                 "SSH_AGENT_PID"
                 "GPG_AGENT_INFO"
                 "LANG"
                 "LC_CTYPE"))
    (add-to-list 'exec-path-from-shell-variables var)))

;; Autocompile, but don't interrupt me with native compilation warnings.
(use-package auto-compile
  :config (auto-compile-on-load-mode))

;;; Replace selection on insert
(use-package delsel
  :init
  (delete-selection-mode 1)
  ) ;; delsel

(use-package vertico
  :after init
  :config
  (message "init.el: loaded vertico")
  (vertico-mode)

  ;; Add prompt indicator to `completing-read-multiple'.
  ;; We display [CRM<separator>], e.g., [CRM,] if the separator is a comma.
  (defun crm-indicator (args)
    (cons (format "[CRM%s] %s"
                  (replace-regexp-in-string
                   "\\`\\[.*?]\\*\\|\\[.*?]\\*\\'" ""
                   crm-separator)
                  (car args))
          (cdr args)))
  (advice-add #'completing-read-multiple :filter-args #'crm-indicator))

;; `orderless' completion style.
(use-package orderless
  :config
  ;; TODO: Configure a custom style dispatcher (see the Consult wiki)
  ;; (setq orderless-style-dispatchers '(+orderless-consult-dispatch orderless-affix-dispatch)
  ;;       orderless-component-separator #'orderless-escapable-split-on-space)
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles partial-completion)))))

(use-package consult
  :config
  (message "init.el: loaded consult")
  (defun consult-isearch ()
    "Call `consult-line` with the search string from the last `isearch`."
    (interactive)
    (consult-line isearch-string))

  (setq register-preview-delay 0
        register-preview-function #'consult-register-format)
  (setq consult-preview-key '(:debounce 0.2 any)
        consult-narrow-key "<"
        consult-project-root-function #'projectile-project-root)
  ) ;; consult

;; Enable rich annotations using the Marginalia package
(use-package marginalia
  ;; Bind `marginalia-cycle' locally in the minibuffer.  To make the binding
  ;; available in the *Completions* buffer, add it to the
  ;; `completion-list-mode-map'.
  :bind (:map minibuffer-local-map
         ("M-A" . marginalia-cycle))

  ;; The :init section is always executed.
  :init
  ;; Marginalia must be activated in the :init section of use-package such that
  ;; the mode gets enabled right away. Note that this forces loading the
  ;; package.
  (marginalia-mode)
  ) ;; marginalia

;;; Embark
(use-package embark
  :bind
  (("C-." . embark-act)         ;; pick some comfortable binding
   ("C-;" . embark-dwim)        ;; good alternative: M-.
   ("C-h B" . embark-bindings)) ;; alternative for `describe-bindings'

  :init

  ;; Optionally replace the key help with a completing-read interface
  (setq prefix-help-command #'embark-prefix-help-command)

  ;; Show the Embark target at point via Eldoc. You may adjust the
  ;; Eldoc strategy, if you want to see the documentation from
  ;; multiple providers. Beware that using this can be a little
  ;; jarring since the message shown in the minibuffer can be more
  ;; than one line, causing the modeline to move up and down:

  ;; (add-hook 'eldoc-documentation-functions #'embark-eldoc-first-target)
  ;; (setq eldoc-documentation-strategy #'eldoc-documentation-compose-eagerly)

  :config

  ;; Hide the mode line of the Embark live/completions buffers
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none))))
  ) ;; embark


;; Consult users will also want the embark-consult package.
(use-package embark-consult
  :hook
  (embark-collect-mode . consult-preview-at-point-mode)
  ) ;; embark-consult

(use-package corfu
  ;; Optional customizations
  ;; :custom
  ;; (corfu-cycle t)                ;; Enable cycling for `corfu-next/previous'
  ;; (corfu-auto t)                 ;; Enable auto completion
  ;; (corfu-separator ?\s)          ;; Orderless field separator
  ;; (corfu-quit-at-boundary nil)   ;; Never quit at completion boundary
  ;; (corfu-quit-no-match nil)      ;; Never quit, even if there is no match
  ;; (corfu-preview-current nil)    ;; Disable current candidate preview
  ;; (corfu-preselect 'prompt)      ;; Preselect the prompt
  ;; (corfu-on-exact-match nil)     ;; Configure handling of exact matches
  ;; (corfu-scroll-margin 5)        ;; Use scroll margin

  ;; Enable Corfu only for certain modes.
  ;; :hook ((prog-mode . corfu-mode)
  ;;        (shell-mode . corfu-mode)
  ;;        (eshell-mode . corfu-mode))

  ;; Recommended: Enable Corfu globally.  This is recommended since Dabbrev can
  ;; be used globally (M-/).  See also the customization variable
  ;; `global-corfu-modes' to exclude certain modes.
  :init
  (global-corfu-mode)
  ) ;; corfu

(use-package nerd-icons-corfu
  :after corfu
  :config
  (message "init.el: loaded nerd-icons-corfu")
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter)

  ;; Optionally:
  (setq nerd-icons-corfu-mapping
        '((array :style "cod" :icon "symbol_array" :face font-lock-type-face)
          (boolean :style "cod" :icon "symbol_boolean" :face font-lock-builtin-face)
          ;; You can alternatively specify a function to perform the mapping,
          ;; use this when knowing the exact completion candidate is important.
          ;; Don't pass `:face' if the function already returns string with the
          ;; face property, though.
          (file :fn nerd-icons-icon-for-file :face font-lock-string-face)
          ;; ...
          (t :style "cod" :icon "code" :face font-lock-warning-face)))
  ;; If you add an entry for t, the library uses that as fallback.
  ;; The default fallback (when it's not specified) is the ? symbol.

  ;; The Custom interface is also supported for tuning the variable above.
  )

;; Which key
(use-package which-key
  :diminish
  :after marginalia
  :config
  (message "init.el: loaded which-key")
  (setq which-key-separator " ")
  (setq which-key-prefix-prefix "+")
  (which-key-mode)
  ) ;; which-key

;;; Modus-themes
(use-package modus-themes
  :config
  (message "init.el: loaded modus-themes")
  ;; Add all your customizations prior to loading the themes
  (setq modus-themes-italic-constructs t
        modus-themes-bold-constructs nil)

  ;; Maybe define some palette overrides, such as by using our presets
  (setq modus-themes-common-palette-overrides
        modus-themes-preset-overrides-intense)

  ;; Load the theme of your choice.
  (load-theme 'modus-operandi-tinted)

  ;; fonts
  (defun my-set-font ()
    (set-face-attribute 'default nil
                        :font "JetBrainsMono Nerd Font:pixelsize=14:weight=semi-bold:slant=normal:width=normal:spacing=0:scalable=true"))

  (add-hook 'server-after-make-frame-hook #'my-set-font)
  (add-hook 'after-init-hook #'my-set-font)
 )  ;; modus-theme


(use-package doom-modeline
  :init (doom-modeline-mode 1)
  :config
  (setq doom-modeline-height 1)

  (setq nerd-icons-scale-factor 1.2)
  ;; *Messages* is created before doom-modeline loads, so its modeline
  ;; is never set via hooks — force it here.
  (with-current-buffer "*Messages*"
    (doom-modeline-set-main-modeline)))


(use-package session
  :preface
  ;;; Desktop save
  (defun my-save-shell-buffer (desktop-dirname)
    ;; we only need to save the current working directory
    default-directory)
  :config
  (message "init.el: loaded session")
  (setq session-save-file (expand-file-name ".session" user-emacs-directory))
  (setq session-name-disable-regexp "\\(?:\\`'/tmp\\|\\.git/[A-Z_]+\\'\\)")
  (setq session-save-file-coding-system 'utf-8)
  :hook
  ((after-init . session-initialize)
   (;; save all shell-mode buffers
    (shell-mode
      . (lambda ()
          (setq-local desktop-save-buffer #'my-save-shell-buffer))))))

;;; A simple visible bell which works in all terminal types
;; (use-package mode-line-bell
;;   :if macos-p
;;   :hook (after-init . mode-line-bell-mode)
;;   :config
;;   (message "init.el: loaded mode-line-bell")
;;   ) ;; modeline bell

(use-package beacon
  :custom
  (beacon-lighter "")
  (beacon-color "DarkGoldenrod2")
  (beacon-size 10)
  (beacon-blink-when-window-scrolls nil)
  :hook (after-init . beacon-mode)
  :config
  (message "init.el: loaded beacon")
  ) ;; beacon mode

;;; Iedit mode
(use-package iedit
  :config
  (message "init.el: loaded iedit")
  :bind ("C-c e" . iedit-mode)
  :diminish)

(use-package undo-tree
  :diminish undo-tree-mode
  :config
  (message "init.el: loaded undo-tree")
  (global-undo-tree-mode)
  ;; (setq undo-tree-visualizer-timestamps t)
  (setq undo-tree-auto-save-history nil)
  (setq undo-tree-visualizer-diff t)
  (setq undo-tree-history-directory-alist
        (list (cons "." (expand-file-name "backups/undo-tree" user-emacs-directory)))))

;;; Winner mode - undo and redo window configuration
(use-package winner
  :config
  (message "init.el: loaded winner")
  (setq winner-boring-buffers
        '("*Completions*"
          "*Compile-Log*"
          "*inferior-lisp*"
          "*Fuzzy Completions*"
          "*Apropos*"
          "*Help*"
          "*cvs*"
          "*Buffer List*"
          "*Ibuffer*"
          "*esh command on file*"))
  (winner-mode)
  ) ;; winner mode

(with-eval-after-load 'replace
  (keymap-set occur-mode-map "C-x C-q" #'occur-edit-mode))

(use-package winum
  :bind (:map winum-keymap
          ("C-`" . #'winum-select-window-by-number)
          ("C-²" . #'winum-select-window-by-number)
          ("M-0" . #'winum-select-window-0-or-10)
          ("M-1" . #'winum-select-window-1)
          ("M-2" . #'winum-select-window-2)
          ("M-3" . #'winum-select-window-3)
          ("M-4" . #'winum-select-window-4)
          ("M-5" . #'winum-select-window-5)
          ("M-6" . #'winum-select-window-6)
          ("M-7" . #'winum-select-window-7)
          ("M-8" . #'winum-select-window-8)
          ("M-9" . #'winum-select-window-9))
  :hook (after-init . winum-mode)
  :config
  (message "init.el: loaded winum")
  ;; (setq winum-auto-setup-mode-line t)
  ;; (winum-mode)
  ) ;; winum-mode

(use-package find-dired
  :after dired
  :config
  (message "init.el: loaded find-dired")
  (setq find-ls-option '("-print0 | xargs -0 ls -ld" . "-ld")))

(use-package yasnippet
  :diminish yas-minor-mode
  ;; :hook (prog-mode . yas-minor-mode)
  :config
  (message "init.el: loaded yasnippet")
  (push '(yasnippet backquote-change) warning-suppress-types)
  (setq yas-installed-snippets-dir (expand-file-name "elisp/yasnippet-snippets" user-emacs-directory))
  (setq yas-snippet-dirs `(,(expand-file-name "elisp/yasnippet-snippets" user-emacs-directory)))
  (setq yas-expand-only-for-last-commands nil)

  (yas-global-mode)
  (yas-reload-all)
  ) ;; yasnippet

;;; Magit
(use-package magit
  :bind (("C-x g" . magit-status))
  :config
  (message "init.el: loaded magit")
  ) ;; magit

(use-package git-gutter
  :diminish
  :hook (prog-mode . git-gutter-mode)
  :config
  (message "init.el: loaded git-gutter")
  (setq git-gutter:update-interval 0)
  ) ;; git-gutter

(use-package git-gutter-fringe
  :after git-gutter
  :config
  (message "init.el: loaded git-gutter-fringe")
  (define-fringe-bitmap 'git-gutter-fr:added [224] nil nil               '(center repeated))
  (define-fringe-bitmap 'git-gutter-fr:modified [224] nil nil            '(center repeated))
  (define-fringe-bitmap 'git-gutter-fr:deleted [128 192 224 240] nil nil 'bottom)
  (set-face-foreground  'git-gutter-fr:modified "orange1")
  ) ;; git-gutter-fringe


(use-package evil
  :hook (after-init . evil-mode)
  :config
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  (setq
   ;; evil-respect-visual-line-mode t
   evil-cross-lines t
   evil-want-fine-undo t
   ;; cursor-related `evil-mode' settings
   evil-move-cursor-back nil
   evil-move-beyond-eol t
   evil-highlight-closing-paren-at-point-states nil)
  (evil-set-undo-system 'undo-tree)
  (dolist (mode '(acl2-doc-mode
                  eshell-mode
                  shell-mode
                  neotree-mode
                  term-mode))
    (evil-set-initial-state mode 'emacs))
  (dolist (mode '(message-buffer-mode))
    (evil-set-initial-state mode 'normal))

  (setq evil-mode-line-format '(before . mode-line-front-space))
  (setq evil-emacs-state-cursor '(bar . 3))

  (setq evil-normal-state-tag
        (propertize "   N   "
                    ;; 'face `(:background ,(modus-themes-get-color-value 'bg-blue-subtle)
                    ;;                     :foreground ,(modus-themes-get-color-value 'fg-mode-line-active))
                    )
        evil-emacs-state-tag
        (propertize "---E---"
                    ;; 'face
                    ;; `(:background ,(modus-themes-get-color-value 'bg-red-intense)
                    ;;               :foreground ,(modus-themes-get-color-value 'fg-mode-line-active))
                    )
        evil-insert-state-tag
        (propertize "***I***"
                    ;; 'face
                    ;; `(:background ,(modus-themes-get-color-value 'bg-graph-green-1)
                    ;;               :foreground ,(modus-themes-get-color-value 'fg-mode-line-active))
                    )
        evil-motion-state-tag
        (propertize "   M   "
                    ;; 'face
                    ;; `(:background ,(modus-themes-get-color-value 'bg-lavender)
                    ;;               :foreground ,(modus-themes-get-color-value 'fg-mode-line-active))
                    )
        evil-visual-state-tag
        (propertize "   V   "
                    ;; 'face
                    ;; `(:background ,(modus-themes-get-color-value 'bg-lavender)
                    ;;               :foreground ,(modus-themes-get-color-value 'fg-mode-line-active))
                    )
        evil-operator-state-tag
        (propertize "   O   "
                    ;; 'face `(:background ,(modus-themes-get-color-value 'bg-lavender)
                    ;;                     :foreground ,(modus-themes-get-color-value 'fg-mode-line-active))
                    ))

  (evil-define-key '(normal insert motion) 'global (kbd "C-t") nil)
  (evil-define-key '(normal insert motion) 'global (kbd "C-w") nil)
  (evil-define-key '(normal insert motion) 'global (kbd "C-a") nil)
  (evil-define-key '(normal insert motion) 'global (kbd "C-e") nil)
  (evil-set-leader 'normal (kbd "SPC"))
  (evil-define-key 'normal 'global
                   (kbd "<leader>fs") #'save-buffer
                   (kbd "<leader>bb") #'consult-buffer)
  (evil-define-key 'insert 'global
                   (kbd "C-y") nil)
  (with-eval-after-load 'magit
    (evil-define-key 'normal magit-status-mode-map (kbd "M-1") nil)
    (evil-define-key 'normal magit-section-mode-map (kbd "M-1") nil)
    (evil-define-key 'normal magit-status-mode-map (kbd "M-2") nil)
    (evil-define-key 'normal magit-section-mode-map (kbd "M-2") nil)
    (evil-define-key 'normal magit-status-mode-map (kbd "M-3") nil)
    (evil-define-key 'normal magit-section-mode-map (kbd "M-3") nil)
    (evil-define-key 'normal magit-status-mode-map (kbd "M-4") nil)
    (evil-define-key 'normal magit-section-mode-map (kbd "M-4") nil))
   (evil-define-key 'insert 'global
                   (kbd "S-<right>") nil)
  (evil-define-key 'insert 'global
                   (kbd "S-<left>") nil)
  (evil-define-key 'insert 'global
                   (kbd "C-w") nil)

  (evil-declare-repeat 'evil-find-char)
  (evil-declare-repeat 'evil-find-char-to)

  ;;Change effect of entering into normal state
  (defun my-evil-normal-state (&rest args)
    (when mark-active
      (evil-visual-state)))
  (advice-add 'evil-normal-state :after #'my-evil-normal-state)

  )

;; (use-package evil-collection
;;   :diminish
;;   (evil-collection-unimpaired-mode)
;;   :after evil
;;   :ensure t
;;   :config
;;   (evil-collection-init))

(use-package easysession
  :diminish
  (easysession-save-mode)
  :ensure t
  :custom
  (easysession-save-interval (* 10 60))
  :init
  (add-hook 'emacs-startup-hook #'(lambda ()
                                    (let* ((env-session-name (getenv "EMACS_SESSION_NAME")))
                                      (when (and env-session-name (not (string-empty-p env-session-name)))
                                        (easysession-set-current-session-name env-session-name)
                                        (easysession-load-including-geometry))) 102))
  (add-hook 'emacs-startup-hook #'easysession-save-mode 103))

;;;;;;;;; Programming languages
(use-package auctex
  ;; :mode "\\.tex\\'"
  :config
  (message "init.el: loaded auctex")
  (setq TeX-view-program-selection '((output-pdf "displayline")))

  (setq TeX-view-program-list
        '(("displayline"
           "/Applications/Skim.app/Contents/SharedSupport/displayline -g %n %o %b"))))

(use-package markdown-mode
  :if macos-p
  :mode ("\\.\\(njk\\|md\\)\\'" . markdown-mode)
  :config
  (message "init.el: loaded markdown"))

(use-package tree-sitter
  :diminish
  :config
  (message "init.el: loaded tree-sitter")
  (global-tree-sitter-mode))
(use-package tree-sitter-langs
  :config
  (message "init.el: loaded tree-sitter-langs"))
(use-package treesit-auto
  :custom
  (treesit-auto-install 'prompt)
  :config
  (message "init.el: loaded treesit-auto")
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode))



(use-package session-async
  :if macos-p)

;;; YAML
(use-package yaml-mode
  :if macos-p
  :mode "\\.yml\\'")

;;; ACL2

(use-package init-acl2
  :if macos-p
  :straight (:type built-in)
  :hook ((lisp-mode . acl2-lisp-mode))
  :config
  (message "init.el: loaded acl2")
  ;; :mode ("\\.lisp\\'" . lisp-mode)
  )

;;; HOL4
;; (use-package sml-mode
;;   :mode ("\\.sml\\'" . sml-mode)
;;   :config
;;   (load "~/Code/HOL/tools/hol-mode")
;;   (load "~/Code/HOL/tools/hol-unicode"))

;; Verilog
(use-package verilog-ts-mode
  :mode "\\.s?vh?\\'")
(use-package verilog-ext
  :hook ((verilog-mode . verilog-ext-mode))
  :config
  (message "init.el: loaded verilog-ext")
  ;; Can also be set through `M-x RET customize-group RET verilog-ext':
  ;; Comment out/remove the ones you do not need
  (setq verilog-ext-feature-list
        '(font-lock
          xref
          ;; capf
          hierarchy
          eglot
          ;; lsp
          ;; lsp-bridge
          ;; lspce
          flycheck
          beautify
          navigation
          template
          formatter
          ;; compilation
          ;; imenu
          ;; which-func
          ;; hideshow
          ;; typedefs
          ;; time-stamp
          block-end-comments
          ports))
  (verilog-ext-mode-setup)
  )

(setq straight-host-usernames '((github . "mayankmanj")))
(use-package lean4-mode
  :straight (:type git
                   :host nil
                   :repo "git@github.com:mayankmanj/lean4-mode.git"
                   :branch "eglot-r"
                   ;;        :branch "eglot")
                   :files ("*.el" "data"))
  :commands (lean4-mode)
  :hook ((lean4-mode . corfu-popupinfo-mode)
         (lean4-mode . (lambda () (advice-add 'corfu-popupinfo--get-documentation :around #'lean4-corfu-popup))))
  :preface
  (defun lean4-newline-and-indent ()
    "Insert a newline and indent according to the previous line."
    (interactive)
    (let ((indentation (current-indentation)))
      (newline)
      (indent-line-to indentation)))
  (defun evil-lean4-newline-and-indent ()
    "Insert a newline and indent according to the previous line."
    (interactive)
    (evil-end-of-line 1)
    (lean4-newline-and-indent)
    (evil-insert 1))
  (defun lean4-corfu-popup-cand (candidate server)
    (when-let* ((item (get-text-property 0 'eglot--lsp-item candidate))
                (res (let ((inhibit-message t)
                           (message-log-max nil)
                           (inhibit-redisplay t)
                           ;; Reduce print length for elisp backend (#249)
                           (print-level 3)
                           (print-length (* corfu-popupinfo-max-width
                                            corfu-popupinfo-max-height)))
                       (plist-get
                        (jsonrpc-request server :completionItem/resolve item)
                        :detail))))
      (and (not (string-blank-p res)) res)))
  (defun lean4-corfu-popup (fun c)
    (if (eq major-mode 'lean4-mode)
        (lean4-corfu-popup-cand c (eglot--current-server-or-lose))
      (funcall fun c)))
  :config
  (message "init.el: loaded lean4")
  (setq lean4-info-plain nil)
  (with-eval-after-load 'evil
    (evil-define-key 'normal 'lean4-mode-map "o"
      #'evil-lean4-newline-and-indent))
  (add-hook 'lean4-mode-hook
            (lambda ()
              (local-set-key (kbd "RET") #'lean4-newline-and-indent)
              (local-set-key (kbd "<backtab>") #'lean4-eri-indent-reverse)))
  (setq corfu-popupinfo-delay 0.5))

(use-package indent-bars
  :straight (:type git :host github :repo "jdtsmith/indent-bars")
  :hook (lean4-mode . indent-bars-mode)
  :custom
  (indent-bars-treesit-support nil)   ; lean4 has no treesit grammar yet
  (indent-bars-width-frac 0.2)
  (indent-bars-pad-frac 0.1)
  (indent-bars-color '(highlight :face-bg t :blend 0.4)))

(use-package eldoc-box
  :hook (((lean4-info-mode) . eldoc-box-hover-mode)))


;; AI Config
(use-package gptel
  :commands (gptel gptel-send)
  :bind
  (("C-c RET" . gptel-send))
  :config
  (message "init.el: loaded gptel")
  (setq gptel-curl-extra-args '("-k"))
  ;; (setq gptel-curl-extra-args nil)
  (setq gptel-backend
        (gptel-make-openai "arm-proxy"
          :host "openai-api-proxy.geo.arm.com"
          :endpoint "/api/providers/openai-us/v1/chat/completions"
          :models '(gpt-5 gpt-thinking gpt-5-pro)
          :key (let ((_ (auth-source-forget-all-cached))
                     (entry (car (auth-source-search :host "openai-api-proxy.geo.arm.com" :user "mayank.manjrekar2@arm.com" :require '(:secret))))) ;
                 (if entry
                     (plist-get entry :secret)
                   (error "API key not found. Please check your auth-source configuration.")))))

  ;; Read a file
  (gptel-make-tool
   :name "read_file"
   :function (lambda (file)
               (unless (file-exists-p file)
                 (error "error: file %s does not exist." file))
               (with-temp-buffer
                 (insert-file-contents file)
                 (buffer-string)))
   :description "return the contents of a file"
   :args (list '(:name "file"
                       :type string
                       :description "the path of the file to be read"))
   :category "file")

  ;; Write a file
  (gptel-make-tool
   :name "write_file"
   :function (lambda (file content)
               (with-temp-file file
                 (insert content)))
   :description "write content to a file"
   :args (list '(:name "file"
                       :type string
                       :description "the path of the file to write to")
               '(:name "content"
                       :type string
                       :description "the content to be written to the file"))
   :category "file")

  ;; Read a buffer (this overlaps with your original example)
  (gptel-make-tool
   :name "read_buffer"
   :function (lambda (buffer)
               (unless (buffer-live-p (get-buffer buffer))
                 (error "error: buffer %s is not live." buffer))
               (with-current-buffer buffer
                 (buffer-substring-no-properties (point-min) (point-max))))
   :description "return the contents of an emacs buffer"
   :args (list '(:name "buffer"
                       :type string
                       :description "the name of the buffer whose contents are to be retrieved"))
   :category "emacs")

  ;; Modify a buffer
  (gptel-make-tool
   :name "modify_buffer"
   :function (lambda (buffer modification)
               (unless (buffer-live-p (get-buffer buffer))
                 (error "error: buffer %s is not live." buffer))
               (with-current-buffer buffer
                 (insert modification)))
   :description "modify the contents of an emacs buffer by appending text"
   :args (list '(:name "buffer"
                       :type string
                       :description "the name of the buffer to modify")
               '(:name "modification"
                       :type string
                       :description "the text to append to the buffer"))
   :category "emacs")

  ;; Search a code base using ripgrep
  (gptel-make-tool
   :name "search_codebase"
   :function (lambda (query directory)
               (unless (executable-find "rg")
                 (error "error: ripgrep is not installed."))
               (let ((default-directory directory))
                 (shell-command-to-string (format "rg %s" (shell-quote-argument query)))))
   :description "search a code base using ripgrep"
   :args (list '(:name "query"
                       :type string
                       :description "the search query")
               '(:name "directory"
                       :type string
                       :description "the directory to search in"))
   :category "search")

  ;; Make a directory
  (gptel-make-tool
   :name "make_directory"
   :function (lambda (directory)
               (make-directory directory t))
   :description "create a directory"
   :args (list '(:name "directory"
                       :type string
                       :description "the path of the directory to create"))
   :category "file")

  ;; List files in a directory
  (gptel-make-tool
   :name "list_files"
   :function (lambda (directory)
               (unless (file-directory-p directory)
                 (error "error: %s is not a directory." directory))
               (directory-files directory nil nil t))
   :description "list files in a directory"
   :args (list '(:name "directory"
                       :type string
                       :description "the directory whose files are to be listed"))
   :category "file")

  ;; Tool for
  (gptel-make-tool
   :name "run_shell_command"
   :function (lambda (cmd)
               (shell-command-to-string cmd))
   :description "run a shell command and return its output as a string"
   :args (list '(:name "cmd"
                       :type string
                       :description "the shell command to be executed"))
   :category "shell")


  (gptel-make-tool
   :name "search_replace_buffer"
   :function (lambda (buffer search replace)
               (unless (buffer-live-p (get-buffer buffer))
                 (error "error: buffer %s is not live." buffer))
               (with-current-buffer buffer
                 (goto-char (point-min))
                 (while (search-forward search nil t)
                   (replace-match replace))))
   :description "search and replace text in an emacs buffer"
   :args (list '(:name "buffer"
                       :type string
                       :description "the name of the buffer to modify")
               '(:name "search"
                       :type string
                       :description "the text to search for")
               '(:name "replace"
                       :type string
                       :description "the text to replace with"))
   :category "emacs")




  (gptel-make-tool
   :name "search_replace_file"
   :function (lambda (file search replace)
               (unless (file-exists-p file)
                 (error "error: file %s does not exist." file))
               (let ((content (with-temp-buffer
                                (insert-file-contents file)
                                (buffer-string))))
                 (with-temp-file file
                   (insert (replace-regexp-in-string (regexp-quote search) replace content)))))
   :description "search and replace text in a file system file"
   :args (list '(:name "file"
                       :type string
                       :description "the path of the file to modify")
               '(:name "search"
                       :type string
                       :description "the text to search for")
               '(:name "replace"
                       :type string
                       :description "the text to replace with"))
   :category "file")


  (defvar ai-gptel-buffer-name nil
    "The name of the gptel buffer used to send regions. This persists between invocations.")

  (defvar ai-original-region-info nil
    "Information about the original buffer and region positions.")

  (defun ai-send-region-to-gptel (start end &optional reset-buffer)
    "Send the selected region, wrapped with delimiters, along with the file name to a gptel buffer and place point after it.
If RESET-BUFFER is non-nil, ask for the buffer again."
    (interactive "r\nP")
    (let* ((region-text (buffer-substring-no-properties start end))
           (file-name (or (buffer-file-name) "no-file"))
           (buffer-name (buffer-name))
           ;; Store the original buffer name and region positions globally
           (gptel-buffer-name (or (and (not reset-buffer) ai-gptel-buffer-name)
                                  (setq ai-gptel-buffer-name
                                        (completing-read "Select gptel buffer: " (mapcar 'buffer-name (buffer-list))))))
           (prompt "Please review and edit the region using AI tools:\n")
           (final-text (format "%sIn file: %s\n\n-----BEGIN REGION-----\n%s\n-----END REGION-----\n"
                               prompt file-name region-text)))
      (setq ai-original-region-info (list buffer-name start end)) ;; Store region info
      (unless (get-buffer gptel-buffer-name)
        (error "Selected buffer does not exist"))
      (with-current-buffer gptel-buffer-name
        (goto-char (point-max))
        (insert final-text)
        (message "Sent region to gptel buffer."))
      ;; Check if the gptel buffer window is visible, and select it
      (let ((window (get-buffer-window gptel-buffer-name)))
        (if window
            (select-window window)
          (switch-to-buffer gptel-buffer-name)))
      (goto-char (point-max))))
  (gptel-make-tool
   :name "replace_region_in_original_buffer" ; Define the name of the tool
   :function (lambda (new-content) ; Lambda function to perform the replacement
               ;; Retrieve the stored information about the original region
               (let ((info ai-original-region-info))
                 ;; Ensure the original region information is available
                 (unless info
                   (error "Error: Original region information not found."))
                 ;; Extract buffer name and region positions from the stored info
                 (let ((buffer-name (nth 0 info))
                       (start (nth 1 info))
                       (end (nth 2 info)))
                   ;; Switch to the original buffer and replace the specified region
                   (with-current-buffer buffer-name
                     (save-excursion
                       (goto-char start) ; Move to the start of the region
                       (delete-region start end) ; Delete the existing region
                       (insert new-content)))))) ; Insert the new content in its place
   :description "Replace the original region in the buffer with new content" ; Description of the tool
   :args (list '(:name "new-content" ; Argument specification for the new content
                       :type string
                       :description "The new content to replace the region with"))
   :category "edit")        ; Categorize the tool as an edit operation

  )

(use-package agent-shell
  :ensure t
  ;; :ensure-system-package
  ;; ;; Add agent installation configs here
  ;; ((claude . "sudo port install claude-code")
  ;;  (claude-agent-acp . "npm install -g @zed-industries/claude-agent-acp"))
  )



(use-package neotree
  ;; :hook (neotree-mode . #'turn-off-evil-mode)
  :commands (neotree-toggle)
  :init
  (setq neo-theme (if (display-graphic-p) 'nerd-icons 'arrow))
  (add-hook 'neotree-mode-hook #'turn-off-evil-mode nil t)
  :config
  (message "init.el: loaded neotree")

  (defun winum-assign-0-to-neotree ()
    (when (string-match-p ".*\\*NeoTree\\*.*" (buffer-name)) 0))

  (with-eval-after-load 'winum
    (add-to-list 'winum-assign-functions #'winum-assign-0-to-neotree))
    )

;; Global keybindings:
(use-package emacs
  :preface
  ;;; Kill back to indentation
  (defun my-kill-back-to-indentation ()
    "Kill from point back to the first non-whitespace character on the line."
    (interactive)
    (let ((prev-pos (point)))
      (back-to-indentation)
      (kill-region (point) prev-pos)))
  ;; Escape cancels all
  (defun may/keyboard-escape-quit ()
    "Exit the current \"mode\" (in a generalized sense of the word).
This command can exit an interactive command such as `query-replace',
can clear out a prefix argument or a region,
can get out of the minibuffer or other recursive edit,
cancel the use of the current buffer (for special-purpose buffers)."
    (interactive)
    (cond ((eq last-command 'mode-exited) nil)
          ((region-active-p)
           (deactivate-mark))
          ((> (minibuffer-depth) 0)
           (abort-recursive-edit))
          (current-prefix-arg
           nil)
          ((> (recursion-depth) 0)
           (exit-recursive-edit))
          (buffer-quit-function
           (funcall buffer-quit-function))
          ((string-match "^ \\*" (buffer-name (current-buffer)))
           (bury-buffer))))

  (defun may/split-window-func-with-other-buffer (split-function)
    (lambda (&optional arg)
      "Split this window and switch to the new window unless ARG is provided."
      (interactive "P")
      (funcall split-function)
      (let ((target-window (next-window)))
        (set-window-buffer target-window (other-buffer))
        (unless arg
          (select-window target-window)))))
  (fset 'my-split-function-vertically
        (may/split-window-func-with-other-buffer 'split-window-vertically))
  (fset 'my-split-function-horizontally
        (may/split-window-func-with-other-buffer 'split-window-horizontally))

  (defun my-smarter-move-beginning-of-line (arg)
    "Move point back to indentation of beginning of line.

      Move point to the first non-whitespace character on this line.
      If point is already there, move to the beginning of the line.
      Effectively toggle between the first non-whitespace character and
      the beginning of the line.

      If ARG is not nil or 1, move forward ARG - 1 lines first.  If
      point reaches the beginning or end of the buffer, stop there."
    (interactive "^p")
    (setq arg (or arg 1))


    ;; Move lines first
    (when (/= arg 1)
      (let ((line-move-visual nil))
        (forward-line (1- arg))))

    (let ((orig-point (point)))
      (back-to-indentation)
      (when (= orig-point (point))
        (move-beginning-of-line 1))))
  :config
  (message "init.el: loaded global keymaps")
  (keymap-global-set "C-<return>" #'comment-indent-new-line)
  (keymap-global-set "C-x r x" #'consult-register)
  (keymap-global-set "C-x r b" #'consult-bookmark)
  (keymap-global-set "C-c k" #'consult-kmacro)
  (keymap-global-set "C-x M-:" #'consult-complex-command)
  (keymap-global-set "C-x 4 b" #'consult-buffer-other-window)
  (keymap-global-set "C-x 5 b" #'consult-buffer-other-frame)
  (keymap-global-set "M-#" #'consult-register-load)
  (keymap-global-set "M-'" #'consult-register-store)
  (keymap-global-set "C-M-#" #'consult-register)
  (keymap-global-set "M-g o" #'consult-outline)
  (keymap-global-set "M-g h" #'consult-org-heading)
  (keymap-global-set "M-g a" #'consult-org-agenda)
  (keymap-global-set "M-g m" #'consult-mark)
  (keymap-global-set "C-x b" #'consult-buffer)
  (keymap-global-set "M-g M-g" #'consult-goto-line)
  (keymap-global-set "M-g o" #'consult-outline)
  (keymap-global-set "M-g m" #'consult-mark)
  (keymap-global-set "M-g k" #'consult-global-mark)
  (keymap-global-set "M-g i" #'consult-imenu)
  (keymap-global-set "M-g I" #'consult-project-imenu)
  (keymap-global-set "M-g e" #'consult-error)
  ;; M-s bindings (search-map)
  (keymap-global-set "M-s f" #'consult-find)
  (keymap-global-set "M-s i" #'consult-info)
  (keymap-global-set "M-s L" #'consult-locate)
  (keymap-global-set "M-s g" #'consult-grep)
  (keymap-global-set "M-s G" #'consult-git-grep)
  (keymap-global-set "M-s r" #'consult-ripgrep)
  (keymap-global-set "M-s l" #'consult-line)
  (keymap-global-set "M-s m" #'consult-multi-occur)
  (keymap-global-set "M-s k" #'consult-keep-lines)
  (keymap-global-set "M-s u" #'consult-focus-lines)
  ;; Isearch integration
  (keymap-global-set "M-s e" #'consult-isearch)
  (keymap-global-set "M-g l" #'consult-line)
  (keymap-global-set "M-s m" #'consult-multi-occur)
  (keymap-global-set "C-x c o" #'consult-multi-occur)
  (keymap-global-set "C-x c SPC" #'consult-mark)
  (keymap-set isearch-mode-map "M-e" #'consult-isearch)
  (keymap-set isearch-mode-map "M-s e" #'consult-isearch)
  (keymap-set isearch-mode-map "M-s l" #'consult-line)

  (keymap-global-set "C-M-<backspace>" #'my-kill-back-to-indentation)
  ;; Modus themes
  ;; (keymap-global-set "<f5>" #'modus-themes-toggle)
  (keymap-global-set "<escape>" #'may/keyboard-escape-quit)
  (keymap-global-set "C-g" #'may/keyboard-escape-quit)
  (keymap-global-set "C-x 2" #'my-split-function-vertically)
  (keymap-global-set "C-x 3" #'my-split-function-horizontally)
  (keymap-global-set "C-x p" #'pop-to-mark-command)
  (keymap-global-set "M-o" #'other-window)
  (keymap-global-set "C-a" #'my-smarter-move-beginning-of-line)
  (keymap-global-set "M-/" #'hippie-expand)
  (keymap-global-set "<f8>" #'neotree-toggle)
  )


(add-to-list 'default-frame-alist '(fullscreen . maximized))
;;; Load post init
(setq my-emacs--success t)

(provide 'init)

;; Local variables:
;; byte-compile-warnings: (not obsolete free-vars)
;; End:

;;; init.el ends here
