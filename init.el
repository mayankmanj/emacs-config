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

;;; elpaca
(defvar elpaca-installer-version 0.12)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-sources-directory (expand-file-name "sources/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1 :inherit ignore
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca-activate)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-sources-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (<= emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                  ,@(when-let* ((depth (plist-get order :depth)))
                                                      (list (format "--depth=%d" depth) "--no-single-branch"))
                                                  ,(plist-get order :repo) ,repo))))
                  ((zerop (call-process "git" nil buffer t "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (let ((load-source-file-function nil)) (load "./elpaca-autoloads"))))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

;; use-package integration
(elpaca elpaca-use-package
  (elpaca-use-package-mode))
(elpaca-wait)

;; set use-package-verbose to t for interpreted .emacs,
;; and to nil for byte-compiled .emacs.elc.
;; Verbose when running interpreted (not byte-compiled); overrides early-init.
(eval-and-compile
  (setq use-package-verbose (not (bound-and-true-p byte-compile-current-file))))

(use-package compat)

(use-package emacs
  :ensure nil
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
  (setq tramp-histfile-override "~/.tramp_history")
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

  ;; Disable auto-save for remote (TRAMP) files — auto-saving over the
  ;; network is slow and can stall the UI on flaky connections.
  (setq remote-file-name-inhibit-auto-save t)
  (setq remote-file-name-inhibit-auto-save-visited t)

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

  ;; Truncate long lines everywhere, including text modes. Nothing soft-wraps
  ;; by default; toggle per buffer with `M-x visual-line-mode' (C-c w).
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

  (with-eval-after-load 'isearch
    (setq search-upper-case t))
  
  (defun my-cleanup-on-save ()
    "Clean up whitespace before saving. Only runs in prog/text modes.
Skips untabify when the buffer uses tab indentation (e.g. Makefiles, Go)."
    (when (derived-mode-p 'prog-mode 'text-mode)
      (unless indent-tabs-mode
        (untabify (point-min) (point-max)))
      (whitespace-cleanup)))
  
  ;; (add-hook 'before-save-hook 'my-cleanup-on-save)
  
  (server-start)
  ) ;; Emacs

(use-package paren
  :ensure nil
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
  :ensure nil
  :hook ((text-mode prog-mode) . display-line-numbers-mode)
  :config
  (message "init.el: loaded display-line-numbers")
  ;; Can be activated with `display-line-numbers-mode'
  (setq-default display-line-numbers-width 3)
  (setq-default display-line-numbers-widen t)
  ) ;; display-line-numbers

;; Indent soft-wrapped continuation lines to match their original line's
;; leading whitespace, so wrapped text doesn't reset to column 0.
(use-package adaptive-wrap
  :hook (visual-line-mode . adaptive-wrap-prefix-mode))

(use-package tramp
  ;; Install tramp from GNU ELPA (2.8.x) instead of the older built-in
  ;; (2.7.3.x): `tramp-rpc' below requires tramp >= 2.8.1.4.
  :ensure t
  :config
  (message "init.el: loaded tramp")
  (setq tramp-verbose 1)
  (setq tramp-completion-reread-directory-timeout 50)
  (setq remote-file-name-inhibit-cache 50)
  ;; Use the remote user's own $PATH so executables like `seg-prompt' are
  ;; found in TRAMP shells, instead of TRAMP's minimal hardcoded path.
  (add-to-list 'tramp-remote-path 'tramp-own-remote-path)
  ;; ~/.local/bin holds our own userspace installs on myvm (p4-rpc, claude-acp)
  ;; and is on none of the site login PATHs, so `tramp-own-remote-path' above
  ;; does not pick it up.  `agent-shell' needs it: acp.el locates the remote ACP
  ;; agent with `executable-find' against this list.
  (add-to-list 'tramp-remote-path "/home/mayankm/.local/bin")
  ;; TRAMP defaults to LC_CTYPE='' which perl and friends reject on some
  ;; hosts. Force a valid UTF-8 locale instead.
  (setq tramp-remote-process-environment
        (cons "LC_CTYPE=en_US.UTF-8"
              (seq-remove (lambda (s) (string-prefix-p "LC_CTYPE=" s))
                          tramp-remote-process-environment)))
  ;; Disable VC for remote files. VC's find-file and after-save hooks call out
  ;; to git to refresh state, which is slow over TRAMP and contributes to the
  ;; per-keystroke lag when editing large remote buffers.
  (setq vc-ignore-dir-regexp
        (format "%s\\|%s" vc-ignore-dir-regexp tramp-file-name-regexp))
  ;; Default `M-x shell' on myvm to tcsh, so it stops prompting for the shell
  ;; path with /bin/sh as the default. Scoped to that one host.
  ;; NOTE: only `explicit-shell-file-name' should be tcsh -- that's what
  ;; `M-x shell' reads. Keep `shell-file-name' POSIX (/bin/sh): TRAMP uses it
  ;; for `process-file'/`shell-command' AND eglot wraps remote LSP servers as
  ;; `shell-file-name -c "..."'. Pointing it at tcsh breaks those (csh syntax)
  ;; and leaks the tcsh login banner into eglot's stdio channel.
  (connection-local-set-profile-variables
   'myvm-tcsh
   '((explicit-shell-file-name . "/bin/tcsh")
     (explicit-tcsh-args . nil)
     (shell-file-name . "/bin/sh")
     (shell-command-switch . "-c")))
  (connection-local-set-profiles
   '(:machine "myvm") 'myvm-tcsh)
  ;; `tramp-integration' hangs `tramp-recentf-cleanup' on
  ;; `tramp-cleanup-connection-hook', which purges *every* `recentf-list' entry
  ;; for a host whenever that host's connection is torn down.  TRAMP tears one
  ;; down on its own whenever it finds the connection process dead or timed out
  ;; (VM sleep, dropped SSH, restarted tramp-rpc server), so in practice the
  ;; whole /rpc:myvm: history gets wiped several times a session and closed
  ;; remote files silently disappear from `consult-buffer's File source.
  ;; Stale entries are harmless: `recentf-keep-default-predicate' keeps
  ;; unconnected remote files as-is, and consult's file sources never stat them.
  (with-eval-after-load 'tramp-integration
    (remove-hook 'tramp-cleanup-connection-hook #'tramp-recentf-cleanup)
    (remove-hook 'tramp-cleanup-all-connections-hook #'tramp-recentf-cleanup-all))
  ) ;; tramp

;;; tramp-rpc — fast TRAMP backend over a binary (MessagePack) RPC server.
;; Edit remote files with the "rpc" method, e.g. /rpc:user@host:/path/to/file
;; Requires tramp >= 2.8.1.4 (installed from GNU ELPA above); the `msgpack'
;; dependency is pulled in automatically by elpaca. On the first connection to
;; a host, tramp-rpc auto-deploys a ~850KB Rust server binary there — built
;; locally with cargo if it is installed, otherwise downloaded from the
;; project's GitHub releases. See M-x tramp-rpc-deploy-status.
(use-package tramp-rpc
  :ensure (:host github :repo "ArthurHeymans/emacs-tramp-rpc"
           :files ("lisp/*.el"))
  :after tramp
  :config
  (message "init.el: loaded tramp-rpc")
  ;; We install tramp-rpc from a git checkout (elpaca), whose default deploy
  ;; policy builds the Rust server from source and never falls back to release
  ;; binaries. Cross-building an x86_64-linux server on this macOS machine would
  ;; need a cross-compilation toolchain, so download the prebuilt binary from
  ;; the project's GitHub releases instead.
  (setq tramp-rpc-deploy-git-build-policy 'release)

  ;; --- Make site CE/p4 tools work over the rpc method on myvm ---------------
  ;; The site CommonEnv (CE) environment (PATH->p4, GLOBAL_PATH, P4CONFIG, ...)
  ;; is only established by a tcsh LOGIN shell.  tramp-rpc launches its Rust
  ;; server with `ssh host <binary>' -- a NON-login `tcsh -c' -- so the server,
  ;; and every process.run child (p4 included), inherits none of it.  Two fixes
  ;; (both hook tramp-rpc internals, so revisit on package updates):
  ;;  1. Launch the server through ~/.local/bin/tramp-rpc-login-launch, a /bin/sh
  ;;     wrapper that captures the tcsh login env (via `tcsh -l' on stdin -- tcsh
  ;;     rejects `-l -c' and a `#!/bin/tcsh -l' shebang) and re-execs the server;
  ;;     children then inherit GLOBAL_PATH/P4CONFIG (the server merges its env).
  ;;  2. tramp-rpc's own `tramp-own-remote-path' probe also uses the broken
  ;;     `tcsh -l -c'; override it to feed `tcsh -l' on stdin so the computed
  ;;     remote PATH includes the site tool dir (.../daily/bin).
  ;; (p4 additionally must run as a child of a shell -- see `p4-executable-remote'.)
  (defun my-tramp-rpc-login-env-launch (orig vec binary-path &rest rest)
    "Launch the tramp-rpc server under a tcsh login env on myvm."
    (if (and (equal (tramp-file-name-method vec) "rpc")
             (equal (tramp-file-name-host vec) "myvm"))
        (apply orig vec
               (concat "/home/mayankm/.local/bin/tramp-rpc-login-launch " binary-path)
               rest)
      (apply orig vec binary-path rest)))
  (advice-add 'tramp-rpc--start-server-process :around #'my-tramp-rpc-login-env-launch)

  (defun my-tramp-rpc-fetch-remote-exec-path (vec)
    "Fetch the remote login PATH via `<login-shell> -l' reading stdin.
tcsh rejects `-l -c' (what upstream uses); feeding commands on stdin is the only
form that sources the login files, so `tramp-own-remote-path' sees the real PATH."
    (condition-case nil
        (let* ((marker (md5 (format "trpc-path-%s" (float-time))))
               (shell (tramp-rpc--get-remote-login-shell vec))
               (result (tramp-rpc--call vec "process.run"
                         `((cmd . ,shell)
                           (args . ["-l"])
                           (cwd . "/")
                           (stdin . ,(format "echo %s\nprintenv PATH\n" marker)))))
               (stdout (tramp-rpc--decode-output
                        (alist-get 'stdout result)
                        (alist-get 'stdout_encoding result))))
          (when (and stdout
                     (string-match (concat (regexp-quote marker) "\r?\n\\([^\r\n]+\\)") stdout))
            (split-string (string-trim (match-string 1 stdout)) ":" t)))
      (error nil)))
  (advice-add 'tramp-rpc--fetch-remote-exec-path :override #'my-tramp-rpc-fetch-remote-exec-path))

;; Automatically rescan the buffer for Imenu entries when `imenu' is invoked
;; This ensures the index reflects recent edits.
(use-package imenu
  :ensure nil
  :config
  (message "init.el: loaded imenu")
  (setq imenu-auto-rescan t)

  ;; Prevent truncation of long function names in `imenu' listings
  (setq imenu-max-item-length 160)
  ) ;; imenu

;;; Files


;;; VC

(use-package vc
  :ensure nil
  :config
  (message "init.el: loaded vc")
  (setq vc-git-print-log-follow t)
  (setq vc-make-backup-files nil)  ; Do not backup version controlled files
  (setq vc-git-diff-switches '("--histogram"))  ; Faster algorithm for diffing.
  ) ;; VC

;;; recentf

(use-package recentf
  :ensure nil
  :config
  (message "init.el: loaded recentf")
  ;; `recentf' is an that maintains a list of recently accessed files.
  (setq recentf-max-saved-items 300) ; default is 20
  (setq recentf-max-menu-items 15)
  (setq recentf-auto-cleanup 'mode)

  ;; Update recentf-exclude
  (setq recentf-exclude (list "^/\\(?:ssh\\|su\\|sudo\\)?:"))

  ;; `tramp-rpc' installs via elpaca, which loads it asynchronously -- often
  ;; *after* this `recentf-mode' call, since elpaca-managed packages queue
  ;; behind `after-init-hook' rather than loading inline like this `:ensure
  ;; nil' block.  `tramp-file-name-regexp' is built from the registered
  ;; method list, so until `tramp-rpc' registers "rpc", `file-remote-p'
  ;; doesn't recognize "/rpc:" paths; `recentf-keep-default-predicate' then
  ;; treats them as nonexistent local files, and the `recentf-cleanup' that
  ;; `recentf-auto-cleanup' runs on mode-enable (below) silently drops every
  ;; "/rpc:" entry loaded from `recentf-save-file'. Keep them unconditionally
  ;; instead of asking `file-remote-p'.
  (setq recentf-keep (cons "\\`/rpc:" recentf-keep))
  (recentf-mode)
  ) ;; recentf

;;; saveplace
(use-package saveplace
  :ensure nil
  :config
  (message "init.el: loaded saveplace")
  ;; Enables Emacs to remember the last location within a file upon reopening.
  (setq save-place-file (expand-file-name "saveplace" user-emacs-directory))
  (setq save-place-limit 600)
  (save-place-mode 1)
  ) ;; saveplace

;;; savehist
(use-package savehist
  :ensure nil
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
  ;; savehist-autosave is a timer that fires regardless of the current buffer.
  ;; If a TRAMP buffer is active, the inherited remote default-directory causes
  ;; savehist-save to stat buffer names (e.g. *scratch*) as remote paths.
  (advice-add 'savehist-autosave :around
              (lambda (orig &rest args)
                (let ((default-directory temporary-file-directory))
                  (apply orig args))))
  ) ;; savehist

;;; Ediff

(use-package ediff
  :ensure nil
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
  (add-hook 'ediff-quit-hook #'my-restore-pre-ediff-winconfig 90)
  ) ;; ediff

;;; Eglot

(use-package eglot
  :ensure nil
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
  ;; Pop the eldoc buffer on demand (hover docs + any diagnostic at point).
  (keymap-set eglot-mode-map "C-c d" #'eldoc-doc-buffer)
  ) ;; eglot

;;; Flymake
(use-package flymake
  :ensure nil
  :config
  (message "init.el: loaded flymake")
  (setq flymake-show-diagnostics-at-end-of-line nil)

  ;; Disable wrapping around when navigating Flymake errors.
  (setq flymake-wrap-around nil)
  ) ;; flymake

;;; hl-line-mode
(use-package hl-line
  :ensure nil
  :config
  (message "init.el: loaded hl-line")

  ;; Restrict `hl-line-mode' highlighting to the current window, reducing visual
  ;; clutter and slightly improving `hl-line-mode' performance.
  (setq hl-line-sticky-flag nil)
  (setq global-hl-line-sticky-flag nil)
  ) ;; hl-line

;;; icomplete
(use-package icomplete
  :ensure nil
  :config
  (message "init.el: loaded icomplete")
  ;; Do not delay displaying completion candidates in `fido-mode' or
  ;; `fido-vertical-mode'
  (setq icomplete-compute-delay 0.01)
  ) ;; icomplete

;;; flyspell
(use-package flyspell
  :ensure nil
  :config
  (message "init.el: loaded flyspell")

  (setq flyspell-issue-welcome-flag nil)

  ;; Improves flyspell performance by preventing messages from being displayed for
  ;; each word when checking the entire buffer.
  (setq flyspell-issue-message-flag nil)
  ) ;; flyspell

;;; ispell
(use-package ispell
  :ensure nil
  :config
  (message "init.el: loaded ispell")
  ;; In Emacs 30 and newer, disable Ispell completion to avoid annotation errors
  ;; when no `ispell' dictionary is set.
  (setq text-mode-ispell-word-completion nil)

  (setq ispell-silently-savep t)
  ) ;; ispell

;;; ibuffer
(use-package ibuffer
  :ensure nil
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
  :ensure nil
  :config
  (message "init.el: loaded xref")
  ;; Enable completion in the minibuffer instead of the definitions buffer
  (setq xref-show-definitions-function 'xref-show-definitions-completing-read
        xref-show-xrefs-function 'xref-show-definitions-completing-read)
  ) ;; xref

;;; dabbrev
(use-package dabbrev
  :ensure nil
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
  :if macos-p
  :config
  (dolist (var '("SSH_AUTH_SOCK"
                 "SSH_AGENT_PID"
                 "GPG_AGENT_INFO"
                 "LANG"
                 "LC_CTYPE"))
    (add-to-list 'exec-path-from-shell-variables var))
  (exec-path-from-shell-initialize))

;; Autocompile, but don't interrupt me with native compilation warnings.
(use-package auto-compile
  :config (auto-compile-on-load-mode))

;;; Replace selection on insert
(use-package delsel
  :ensure nil
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
  (setq consult-preview-key '(:debounce 1 any)
        consult-narrow-key "<"
        consult-project-root-function #'projectile-project-root)
  (setq consult-preview-key "M-.")

  ;; In remote (TRAMP) buffers, drop the project sources entirely — they call
  ;; projectile-project-root and iterate recentf-list for project membership,
  ;; both of which are slow over SSH even with non-essential set.  Hidden
  ;; sources are not exempt: `consult--multi' builds candidates for every
  ;; enabled source upfront, and narrowing only filters what is already there.
  ;; Also rebind `default-directory' to a local path so marginalia annotators
  ;; and other completion machinery don't make TRAMP round-trips while
  ;; building/showing candidates.
  ;;
  ;; Match on the symbol name rather than a literal list: consult renamed these
  ;; from `consult--source-project-*' to `consult-source-project-*', which
  ;; silently turned an earlier `memq' version of this advice into a no-op.
  (advice-add 'consult-buffer :around
              (lambda (orig &rest args)
                (if (file-remote-p default-directory)
                    (let ((consult-buffer-sources
                           (seq-remove (lambda (src)
                                         (and (symbolp src)
                                              (string-match-p
                                               "\\`consult-+source-project"
                                               (symbol-name src))))
                                       consult-buffer-sources))
                          (default-directory temporary-file-directory)
                          (non-essential t))
                      (apply orig args))
                    (apply orig args))))
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

;; Modus-themes
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
  (my-set-font)
 )  ;; modus-theme
;; (use-package gruvbox-theme
;;   :ensure t
;;   :config
;;   (load-theme 'gruvbox-dark-soft t)
;;
;;
;;   ;; fonts
;;   (defun my-set-font ()
;;     (set-face-attribute 'default nil
;;                         :font "JetBrainsMono Nerd Font:pixelsize=14:weight=semi-bold:slant=normal:width=normal:spacing=0:scalable=true"))
;;
;;   (add-hook 'server-after-make-frame-hook #'my-set-font)
;;   (my-set-font)
;;   )



;; (use-package doom-modeline
;;   :config
;;   (doom-modeline-mode 1)
;;   (setq doom-modeline-height 1)
;;
;;   (setq nerd-icons-scale-factor 1.2)
;;   ;; *Messages* is created before doom-modeline loads, so its modeline
;;   ;; is never set via hooks — force it here.
;;   (with-current-buffer "*Messages*"
;;     (doom-modeline-set-main-modeline))
;;
;;   ;; Match evil state indicator colors to cursor colors.
;;   ;; Dark backgrounds (maroon, sea-green, midnight-blue) get white fg;
;;   ;; orange gets black fg for contrast.
;;   ;; (set-face-attribute 'doom-modeline-evil-normal-state   nil :background "maroon"       :foreground "white")
;;   ;; (set-face-attribute 'doom-modeline-evil-insert-state   nil :background "sea green"    :foreground "white")
;;   ;; (set-face-attribute 'doom-modeline-evil-visual-state   nil :background "midnight blue" :foreground "white")
;;   ;; (set-face-attribute 'doom-modeline-evil-motion-state   nil :background "orange"       :foreground "black")
;;   ;; (set-face-attribute 'doom-modeline-evil-operator-state nil :background "orange"       :foreground "black")
;;   ;; (set-face-attribute 'doom-modeline-evil-emacs-state    nil :background "gray40"       :foreground "white")
;;   )

(use-package session
  :preface
  ;;; Desktop save
  (defun my-save-shell-buffer (desktop-dirname)
    ;; we only need to save the current working directory
    default-directory)
  :hook
  (shell-mode . (lambda ()
                  (setq-local desktop-save-buffer #'my-save-shell-buffer)))
  :config
  (message "init.el: loaded session")
  (setq session-save-file (expand-file-name ".session" user-emacs-directory))
  (setq session-name-disable-regexp "\\(?:\\`'/tmp\\|\\.git/[A-Z_]+\\'\\)")
  (setq session-save-file-coding-system 'utf-8)
  (session-initialize))

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
  :config
  (message "init.el: loaded beacon")
  (beacon-mode 1)
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
  :ensure nil
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
          ("M-0" . #'treemacs-select-window)
          ("M-1" . #'winum-select-window-1)
          ("M-2" . #'winum-select-window-2)
          ("M-3" . #'winum-select-window-3)
          ("M-4" . #'winum-select-window-4)
          ("M-5" . #'winum-select-window-5)
          ("M-6" . #'winum-select-window-6)
          ("M-7" . #'winum-select-window-7)
          ("M-8" . #'winum-select-window-8)
          ("M-9" . #'winum-select-window-9))
  :config
  (message "init.el: loaded winum")
  ;; (setq winum-auto-setup-mode-line t)
  (winum-mode)
  ) ;; winum-mode

(use-package find-dired
  :ensure nil
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

;;; transient (magit/gptel require >= 0.7.4; Emacs built-in is older)
(use-package transient
  :ensure t)

;;; Magit
(use-package magit
  :bind (("C-x g" . magit-status))
  :config
  (message "init.el: loaded magit")
  ) ;; magit

(use-package git-gutter
  :diminish
  :hook (prog-mode . my-maybe-enable-git-gutter)
  :config
  (message "init.el: loaded git-gutter")
  (setq git-gutter:update-interval 0)
  ;; Skip git-gutter in TRAMP buffers — with update-interval 0 it shells out
  ;; to `git diff' after every change, which is a remote SSH round-trip per
  ;; keystroke and makes editing large remote files unusable.
  (defun my-maybe-enable-git-gutter ()
    (unless (file-remote-p default-directory)
      (git-gutter-mode 1)))
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

;; Perforce:
(add-to-list 'load-path "~/Code/perforce-emacs")
(require 'p4)
;; On myvm the site `p4' is a CommonEnv wrapper that only behaves when spawned
;; as a child of a shell -- run directly by the tramp-rpc server it cd's to $HOME
;; and loses the client.  Route remote p4 through ~/.local/bin/p4-rpc
;; (#!/bin/sh; p4 "$@"), so p4 is a shell child.  Its CE env + PATH come from the
;; tramp-rpc server-launch/PATH fixes above.  Local p4 uses `p4-executable' and
;; is unaffected; this only applies when `default-directory' is remote.
(setq p4-executable-remote "/home/mayankm/.local/bin/p4-rpc")

;; `p4-edit' (and add/delete/revert/reopen/lock/unlock) finishes by running
;; `p4-refresh-buffer' -> `revert-buffer' -> `after-find-file', which recomputes
;; `buffer-read-only' from `file-writable-p'.  Two problems on a remote file:
;;
;;  1. That check is a lie.  tramp-rpc keeps its own `file.stat' cache
;;     (`tramp-rpc--file-stat-cache', 300s TTL) *in addition to* tramp's
;;     property cache, and its `process-file' handler invalidates only
;;     `default-directory' itself -- and there only the exact hash keys for that
;;     path and its parent, never the files inside it.  So p4 has already
;;     chmod'ed the file to 0664 on the host, yet `file-attributes' keeps
;;     reporting the pre-edit r--r--r-- for up to 5 minutes and the buffer stays
;;     read-only.  Flushing tramp's own properties is not enough: they get
;;     recomputed from the stale rpc stat cache.  (`file-writable-p',
;;     `file-modes' and `verify-visited-file-modtime' all route through
;;     `file-attributes', so all three need the flush.)
;;  2. The revert is pure waste for a command that only flips the write bit:
;;     re-reading a 4MB .sv over the rpc link and re-parsing it with tree-sitter
;;     costs ~45s.
;;
;; So: flush the file's cache entries, then -- for the commands that cannot
;; change file content, and only while the file on disk still matches what the
;; buffer read -- sync `buffer-read-only' instead of reverting.  Everything else
;; (`p4 revert', `p4 delete', a modified buffer, a file that changed underneath,
;; a local file) falls through to p4.el's revert.
(defvar my-p4--content-preserving-command nil
  "Non-nil while running a p4 command that cannot change file content.
Such a command needs only `buffer-read-only' resynced, not a revert.")

(defun my-p4-flush-remote-file-caches ()
  "Invalidate TRAMP caches for the visited remote file.
Needed before any `file-attributes'-derived check that must see
what a p4 command just did to the file on the host."
  (when-let* ((file buffer-file-name)
              ((file-remote-p file)))
    (when (fboundp 'tramp-rpc--invalidate-cache-for-path)
      (ignore-errors (tramp-rpc--invalidate-cache-for-path file)))
    (ignore-errors
      (with-parsed-tramp-file-name file nil
        (tramp-flush-file-properties v localname)))))

(defun my-p4-refresh-buffer-remote (orig)
  "Refresh a remote file buffer after a p4 command, avoiding a needless re-read.
ORIG is `p4-refresh-buffer', which is called for anything that
might genuinely need new content."
  (if (not (and buffer-file-name (file-remote-p buffer-file-name)))
      (funcall orig)
    (my-p4-flush-remote-file-caches)
    (if (and my-p4--content-preserving-command
             (not (buffer-modified-p))
             (verify-visited-file-modtime))
        ;; Same bytes on disk, only the mode changed.  `read-only-mode' rather
        ;; than `setq': it also runs `read-only-mode-hook' and leaves View mode
        ;; consistent, as `after-find-file' would have.
        (read-only-mode (if (file-writable-p buffer-file-name) -1 1))
      (funcall orig))))
(advice-add 'p4-refresh-buffer :around #'my-p4-refresh-buffer-remote)

(defun my-p4-content-preserving-command (orig &rest args)
  "Call ORIG with ARGS, marking it as unable to change file content."
  (let ((my-p4--content-preserving-command t))
    (apply orig args)))
;; These are all in `p4-synchronous-commands', and `p4-process-restart' forces
;; synchronous execution when `default-directory' is remote, so the refresh
;; callback runs inside this dynamic extent.  Should that ever stop holding, the
;; flag is merely nil at refresh time and we fall back to p4.el's revert.
(dolist (cmd '(p4-edit p4-add p4-lock p4-unlock p4-reopen))
  (advice-add cmd :around #'my-p4-content-preserving-command))

(use-package evil
  :init
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  :config
  (evil-mode 1)
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
                  dired-mode
                  shell-mode
                  neotree-mode
                  term-mode))
    (evil-set-initial-state mode 'emacs))
  (dolist (mode '(message-buffer-mode))
    (evil-set-initial-state mode 'normal))

  (setq evil-mode-line-format '(before . mode-line-front-space))
  ;; (setq evil-emacs-state-cursor   'box)
  (setq evil-normal-state-cursor  '("maroon" box))
  ;; (setq evil-insert-state-cursor  '("sea green" box))
  ;; (setq evil-visual-state-cursor  '("midnight blue" box))
  ;; (setq evil-motion-state-cursor  '("orange" box))
  ;; (setq evil-operator-state-cursor '("orange" box))

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

  ;; (with-eval-after-load 'magit
  ;;   (evil-define-key 'normal magit-status-mode-map (kbd "M-1") nil)
  ;;   (evil-define-key 'normal magit-section-mode-map (kbd "M-1") nil)
  ;;   (evil-define-key 'normal magit-status-mode-map (kbd "M-2") nil)
  ;;   (evil-define-key 'normal magit-section-mode-map (kbd "M-2") nil)
  ;;   (evil-define-key 'normal magit-status-mode-map (kbd "M-3") nil)
  ;;   (evil-define-key 'normal magit-section-mode-map (kbd "M-3") nil)
  ;;   (evil-define-key 'normal magit-status-mode-map (kbd "M-4") nil)
  ;;   (evil-define-key 'normal magit-section-mode-map (kbd "M-4") nil))
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
    ;; `evil-normal-state' is also called with a negative arg to *leave*
    ;; normal state -- notably from `evil-visual-state' itself, via
    ;; `evil-change-state'.  Recursing into `evil-visual-state' there makes
    ;; the visual selection get built twice, and since the backward-region
    ;; branch of `evil-visual-state' contracts the range each time, the last
    ;; character is dropped (e.g. `C-x h', which leaves point at point-min).
    ;; Only act when normal state was actually entered.
    (when (and (evil-normal-state-p) mark-active)
      (evil-visual-state)))
  (advice-add 'evil-normal-state :after #'my-evil-normal-state)

  )

(unless (display-graphic-p)
  (use-package evil-terminal-cursor-changer
    :init
    (message "init.el: loaded evil-terminal-cursor-changer")
    (evil-terminal-cursor-changer-activate)
    ))

(unless (display-graphic-p)
  (use-package clipetty
    :config
    (global-clipetty-mode)))


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
;; (use-package auctex
;;   ;; :mode "\\.tex\\'"
;;   :config
;;   (message "init.el: loaded auctex")
;;   (setq TeX-view-program-selection '((output-pdf "displayline")))
;;
;;   (setq TeX-view-program-list
;;         '(("displayline"
;;            "/Applications/Skim.app/Contents/SharedSupport/displayline -g %n %o %b"))))

;; (use-package markdown-mode
;;   :if macos-p
;;   :mode ("\\.\\(njk\\|md\\)\\'" . markdown-mode)
;;   :config
;;   (message "init.el: loaded markdown"))

(use-package treesit-auto
  :custom
  (treesit-auto-install 'prompt)
  :config
  (message "init.el: loaded treesit-auto")
  ;; Persist the install dir on `treesit-extra-load-path'. treesit-auto
  ;; installs grammars under ~/.config/emacs/tree-sitter/ but Emacs only
  ;; auto-searches treesit-extra-load-path + system paths, so without this
  ;; treesit-auto re-prompts to install every session.
  (add-to-list 'treesit-extra-load-path
               (expand-file-name "tree-sitter/" user-emacs-directory))
  ;; Exclude verilog/systemverilog from treesit-auto. Its recipe installs the
  ;; grammar under symbol `verilog' (file libtree-sitter-verilog.dylib), but
  ;; the upstream grammar exports `tree_sitter_systemverilog' and
  ;; `verilog-ts-mode' looks up the `systemverilog' symbol. The mismatch makes
  ;; treesit-auto think the grammar is missing on every .sv open and re-prompt
  ;; to install. verilog-ts-mode ships its own `verilog-ts-install-grammar'
  ;; which installs under the correct symbol.
  (setq treesit-auto-langs
        (seq-remove (lambda (r) (memq (treesit-auto-recipe-lang r) '(verilog systemverilog)))
                    treesit-auto-langs))
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode))

(use-package session-async
  :if macos-p)

;;; YAML
;; (use-package yaml-mode
;;   :if macos-p
;;   :mode "\\.yml\\'")

;;; ACL2

;; (use-package init-acl2
;;   :if macos-p
;;   :ensure nil
;;   :hook ((lisp-mode . acl2-lisp-mode))
;;   :config
;;   (message "init.el: loaded acl2")
;;   ;; :mode ("\\.lisp\\'" . lisp-mode)
;;   )

;;; HOL4
;; Deliberately not loaded.  HOL4's two editor-mode files bind their keys in the
;; *global* map at load time -- unconditionally, with no minor mode to turn off:
;;  - hol-unicode.el inserts characters from C-S-a (α), C-S-c, C-S-i, C-S-q,
;;    C-S-u and ~40 more, and claims C-S-f, C-S-p, C-<, C->, C-" and a dozen
;;    other keys as prefix maps.  C-S-a is the one that hurt: it shadowed
;;    shift-selection to the start of the line.
;;  - hol-mode.el takes M-h (`mark-paragraph') and C-M-h (`mark-defun'), and
;;    adds a menu-bar entry that is always present.
;; HOL Light (elisp/hol-light.el, below) is an unrelated package and does none
;; of this.  If HOL4 is wanted again, load these from a mode hook and put their
;; commands in a mode-local map rather than at top level.
;; (load "~/Code/HOL/tools/editor-modes/emacs/hol-mode")
;; (load "~/Code/HOL/tools/editor-modes/emacs/hol-unicode")

;;; OCaml

;; No opam switch is on `exec-path' -- the login shell does not run `opam env'
;; -- and putting one there would be wrong anyway, because the two switches in
;; use are not interchangeable: `default' (OCaml 5.4.1) holds ocaml-lsp-server,
;; ocamlformat and utop, while ~/Code/hol-light carries a local switch (5.4.0 +
;; camlp5) that HOL Light is built against and has to run in.  So every OCaml
;; program below is launched through `opam exec --', which resolves the switch
;; from the process's working directory and therefore picks the right one per
;; tree, with no switching by hand.  `opam-switch-mode' covers the rest.

(use-package tuareg
  :mode (("\\.ml\\'" . tuareg-mode)
         ("\\.mli\\'" . tuareg-interface-mode))
  :preface
  (defun my-ocaml-setup ()
    "Set up the OCaml tooling that HOL Light sources must not get.
`hol-light-tuareg-setup' claims those buffers instead: ocamllsp cannot parse
their camlp5 term quotations, and utop is a plain OCaml toplevel where HOL
Light needs the one its own `make' produces."
    (unless (hol-light-file-p)
      (utop-minor-mode)
      ;; ocamllsp resolves modules out of dune's build metadata, and is little
      ;; more than a syntax checker without it.
      (when (and buffer-file-name
                 (locate-dominating-file buffer-file-name "dune-project"))
        (eglot-ensure))))
  :hook (tuareg-mode . my-ocaml-setup)
  :config
  (message "init.el: loaded tuareg")
  (setq tuareg-interactive-program "opam exec -- ocaml -nopromptcont")

  ;; Restate eglot's OCaml entry rather than edit it, so the `:language-id'
  ;; properties ocamllsp expects survive; `add-to-list' puts this ahead of the
  ;; built-in one, which would look for a bare `ocamllsp' on `exec-path'.
  ;; Interface (.mli) buffers match through `tuareg-mode', which
  ;; `tuareg-interface-mode' derives from.
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(((caml-mode :language-id "ocaml")
                    (ocaml-ts-mode :language-id "ocaml")
                    (tuareg-mode :language-id "ocaml"))
                   "opam" "exec" "--" "ocamllsp")))
  ) ;; tuareg

(use-package utop
  :defer t
  :config
  (message "init.el: loaded utop")
  (setq utop-command "opam exec -- utop -emacs")
  ;; Skip the "utop command:" prompt on every start -- the wrapper above already
  ;; selects the switch belonging to the buffer's project.
  (setq utop-edit-command nil)
  ) ;; utop

(use-package dune
  :mode ("\\(?:\\`\\|/\\)dune\\(?:\\.inc\\|-project\\|-workspace\\)?\\'" . dune-mode)
  :config
  (message "init.el: loaded dune")
  (setq dune-command "opam exec -- dune")
  ) ;; dune

;; For the occasional buffer whose switch cannot be inferred from its directory:
;; `opam-switch-set-switch' fixes up `exec-path' and `process-environment'.
(use-package opam-switch-mode
  :commands (opam-switch-mode opam-switch-set-switch)
  :config
  (message "init.el: loaded opam-switch-mode"))

;;; HOL Light

;; HOL Light sources are OCaml, so `tuareg-mode' edits them; `hol-light-mode'
;; (elisp/hol-light.el) adds the toplevel, the statement/goal/tactic stepping,
;; HOL Light's own Help documentation through eldoc, and \\[xref-find-definitions]
;; over the tree, for files under ~/Code/hol-light.
(use-package hol-light
  :ensure nil
  :commands (hol-light-run hol-light-mode hol-light-file-p)
  :preface
  (defun my-hol-light-eldoc-box ()
    "Show HOL Light's documentation in a childframe, as for lean4 and Verilog.
A minor mode's hook runs when it is switched off as well as on, hence the
test rather than a bare `eldoc-box-hover-mode'."
    (eldoc-box-hover-mode (if hol-light-mode 1 -1)))
  :hook ((tuareg-mode . hol-light-tuareg-setup)
         (hol-light-mode . my-hol-light-eldoc-box))
  :config
  (message "init.el: loaded hol-light"))

;; Verilog
(use-package verilog-ts-mode
  :mode "\\.s?vh?\\'"
  :bind (:map verilog-ts-mode-map
              ;; Override electric-verilog-* fns inherited from verilog-mode-map
              ;; that reindent using `verilog-indent-level' instead of the
              ;; tree-sitter rules. Fall back to plain insertion + electric-indent-mode.
              ("RET" . newline)
              (";"   . self-insert-command)
              (":"   . self-insert-command)
              ("`"   . self-insert-command)))

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
          ;; eglot   ; disabled -- see the note below (svlangserver removed)
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
          ports))
  ;; Run the setup in a throwaway (non-Verilog) buffer.
  ;; `verilog-ext-mode-setup' calls `verilog-ext-flycheck-set-linter', which does
  ;; `flycheck-select-checker' whenever the current buffer is a Verilog buffer.
  ;; Under elpaca's deferred loading this :config runs the first time a Verilog
  ;; file is opened -- i.e. while that buffer is current -- so if the linter's
  ;; executable is missing (no `verilator' on PATH, or a remote TRAMP file where
  ;; flycheck cannot run command checkers) checker selection signals "Can't use
  ;; syntax checker ...", aborting mode setup as a "File mode specification error".
  ;; A `fundamental-mode' temp buffer makes that guard false, so setup completes
  ;; and `verilog-ext-mode' still enables normally when files are visited.
  (with-temp-buffer
    (verilog-ext-mode-setup))
  ;; --- No LSP for Verilog ---
  ;; svlangserver (via eglot) was removed deliberately.  It is a whole-tree
  ;; static indexer, and this FV flow defeats it: the design hierarchy is
  ;; elaborated by JasperGold, so cross-module references like
  ;;   l2c.pip2.pipinst.`EPRB_PATH.prbpickctl.wabPipReqVld
  ;; are unresolvable -- svlangserver's `getHierarchicalSymbol' only resolves a
  ;; dotted path whose first element is a symbol in the current file or a
  ;; module/interface name, and `l2c' is an elaboration-time instance declared
  ;; in another file.  Indexing the tree also cost hours and produced a
  ;; multi-hundred-MB index that wedged the server.  The `eglot' entry in
  ;; `verilog-ext-feature-list' above is disabled to match.
  ;;
  ;; Still available without LSP: verilog-ext's own `xref' backend and
  ;; `hierarchy'/`navigation' features, imenu, and plain grep/ripgrep.

  ;; Treat `soko/trunk' as the project root for HDL buffers.  Independent of
  ;; LSP -- this is what makes project.el, `consult-ripgrep', and verilog-ext
  ;; navigation search the whole design instead of a single leaf directory.
  ;; Workspace-prefix agnostic: any Perforce client (mm_aus_soko_pip.Wtmp,
  ;; pip2.Wtmp, ...) resolves by walking up to `soko/trunk'.
  (defun my-soko-trunk-root (dir)
    "Return the enclosing .../soko/trunk/ directory of DIR, or nil."
    (when (and dir (string-match "\\(.*/soko/trunk\\)/" dir))
      (file-name-as-directory (match-string 1 dir))))
  (defun my-soko-project-try (dir)
    "`project-find-functions' entry: treat soko/trunk as the root for HDL buffers."
    (when (and (derived-mode-p 'verilog-mode 'verilog-ts-mode)
               (my-soko-trunk-root dir))
      (cons 'transient (my-soko-trunk-root dir))))
  (add-hook 'project-find-functions #'my-soko-project-try 90)
  )

(use-package lean4-mode
  :ensure (:url "https://github.com/mayankmanj/lean4-mode.git"
           :branch "eglot-r"
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
  :ensure (:host github :repo "jdtsmith/indent-bars")
  :hook (lean4-mode . indent-bars-mode)
  :custom
  (indent-bars-treesit-support nil)   ; lean4 has no treesit grammar yet
  (indent-bars-prefer-character t)    ; NS backend doesn't support stipples
  (indent-bars-width-frac 0.2)
  (indent-bars-pad-frac 0.1)
  (indent-bars-color '(highlight :face-bg t :blend 0.4)))

(use-package eldoc-box
  :hook (((lean4-info-mode verilog-ts-mode verilog-mode) . eldoc-box-hover-mode)))

(defvar my-agent-shell-myvm-plugin-dirs
  '("/home/mayankm/.genie/default/plugins/fv-debug-agent/4.0"
    "/home/mayankm/.genie/default/plugins/sv-analyzer/3.7.0"
    "/org/seg/services/genie/all/components/appstore/disks/disk1/prod/FE/default/plugins/raven/v0.1.0")
  "Genie plugin directories to load in remote Claude shells on myvm.
These are what `genie-claude --plugin fv-debug-agent --plugin sv-analyzer
--plugin raven' passes to claude as `--plugin-dir'.  Refresh with
`genie-claude --plugin ... --show-path' when a plugin version changes.")

(defun my-agent-shell-add-genie-plugins (config)
  "Load `my-agent-shell-myvm-plugin-dirs' in CONFIG when starting on myvm.
Claude's `--plugin-dir' flag corresponds to the Claude Agent SDK's `plugins'
option, which the ACP adapter reads out of `_meta.claudeCode.options' -- so it
travels as agent-shell `:session-meta'.  The plugin list must be a vector: acp.el
serialises with `json-serialize', which renders a list of conses as a JSON
object, not an array."
  (if (equal "myvm" (file-remote-p default-directory 'host))
      (map-insert
       config :session-meta
       `((claudeCode
          . ((options
              . ,(cons `(plugins
                         . ,(vconcat (mapcar (lambda (dir)
                                               `((type . "local") (path . ,dir)))
                                             my-agent-shell-myvm-plugin-dirs)))
                       ;; Keep whatever options the package already set (the
                       ;; thinking-display workaround); we only add to them.
                       (map-nested-elt (map-elt config :session-meta)
                                       '(claudeCode options))))))))
    config))

(defun my-shell-maker-skip-curl-check (orig &rest args)
  "Return t in `agent-shell' buffers, otherwise call ORIG with ARGS.
`shell-maker' gates every submission on curl >= 7.76, because that is how its
HTTP-based shells (chatgpt-shell and friends) reach their backends.  agent-shell
does not use curl at all -- it speaks ACP over a pipe.  The check runs
`shell-command-to-string', which honours `default-directory', so in a TRAMP
agent-shell buffer it probes the *remote* curl; myvm ships 7.61.1, so every
prompt died with \"You need curl version 7.76 or newer.\" before being sent.
Skipping it also saves a remote round trip per prompt."
  (if (derived-mode-p 'agent-shell-mode)
      t
    (apply orig args)))

(defun my-agent-shell-local-fs-only (orig &rest args)
  "Withhold client-side file capabilities from *remote* agent shells.
`agent-shell-text-file-capabilities' makes agent-shell advertise ACP's
`fs/read_text_file' / `fs/write_text_file', which invites the agent to route its
Read/Edit tools back through Emacs instead of touching the filesystem itself.
Locally that is a win: the agent then sees unsaved buffer text.  Over TRAMP it
is the opposite -- `agent-shell--on-fs-read-text-file-request' answers with a
plain `insert-file-contents' on the remote name, and TRAMP is synchronous, so
any file the agent read that way would freeze the UI for a round trip (measured
at ~1.3s for a 5MB include on myvm).  The remote agent already runs on the
machine holding the files, so its own tools are both faster and non-blocking.
Cost: it reads what is on disk, so unsaved buffer changes are invisible to it.

This is a precaution, not a bug fix: an ACP traffic log of a full remote turn
showed the agent issuing no `fs/*' requests at all, so it may never have taken
that route here.  The freezing this was first written for turned out to be
remote transcript writes -- see `my-agent-shell-transcript-file-path'."
  (let* ((buf (plist-get args :shell-buffer))
         (dir (if (buffer-live-p buf)
                  (buffer-local-value 'default-directory buf)
                default-directory)))
    (if (file-remote-p dir)
        (let ((agent-shell-text-file-capabilities nil))
          (apply orig args))
      (apply orig args))))

(defun my-agent-shell-transcript-file-path ()
  "Return a transcript path, kept on local disk for remote shells.
agent-shell appends to the transcript after nearly every `session/update', with
`write-region ... APPEND', and `agent-shell--default-transcript-file-path' puts
it under the shell's cwd -- which for a TRAMP shell is remote.  Each append is
then a remote `write-region', and TRAMP surrounds every one of those with
attribute-preservation round trips (`file-acl', `set-file-acl', selinux get/set,
`file-modes', `tramp-set-file-uid-gid', `file-truename', `file-symlink-p',
`lock-file'/`unlock-file') regardless of how few bytes are being appended.

Measured on myvm with a counter on `tramp-file-name-handler': a single prompt
produced 373 appends costing 302s inside `write-region' and ~640s of remote
traffic overall, all of it blocking redisplay.  That is what froze the UI on
every tool call.  Local shells keep the default project-relative location.

The mirror path is <cache>/transcripts/<host>/<last-3-dirs>-<hash>/<stamp>.md.
The hash is over the whole remote directory so identically-named leaves in
different workspaces (pipN.Wtmp) do not collide."
  (if-let* ((host (file-remote-p default-directory 'host)))
      (let* ((localname (or (file-remote-p default-directory 'localname) "/"))
             (parts (seq-remove #'string-empty-p (split-string localname "/")))
             (tail (replace-regexp-in-string
                    "[^A-Za-z0-9]+" "-" (string-join (last parts 3) "-")))
             (dir (agent-shell-cache-dir
                   "transcripts" host
                   (concat tail "-" (substring (md5 localname) 0 8)))))
        (expand-file-name (format-time-string "%F-%H-%M-%S.md") dir))
    (agent-shell--default-transcript-file-path)))

(use-package agent-shell
  :if macos-p
  :ensure t
  :config
  ;; `claude-acp' is a per-host launcher script (~/.local/bin/claude-acp, both
  ;; here and on myvm).  acp.el spawns the ACP agent through TRAMP whenever
  ;; `default-directory' is remote, so one bare command name drives the local
  ;; agent and the one on myvm, each exporting its own CLAUDE_CODE_EXECUTABLE.
  ;; It must stay a bare name, not an absolute path: agent-shell pre-flights the
  ;; command with a *local* `executable-find' before acp.el's remote-aware one.
  (setq agent-shell-anthropic-claude-acp-command '("claude-acp"))
  ;; Start the agent in the directory of the buffer it was invoked from, rather
  ;; than `agent-shell-cwd''s default of the project root.  The root here is only
  ;; found as a project.el *transient* entry -- `vc-ignore-dir-regexp' above
  ;; swallows all TRAMP paths, so `project-try-vc' never resolves a remote root
  ;; -- which makes the default cwd depend on session state.  Trade-off: the
  ;; agent sees only this subtree unless given `--add-dir', and a CLAUDE.md at
  ;; the workspace root is no longer picked up as project memory.
  (setq agent-shell-cwd-function (lambda () default-directory))
  ;; Keep transcripts off the remote filesystem; see the function's docstring.
  (setq agent-shell-transcript-file-path-function
        #'my-agent-shell-transcript-file-path)
  ;; Translate between TRAMP file names and the plain paths the remote agent
  ;; speaks.  agent-shell runs this both on the cwd it sends out and on the
  ;; paths the agent sends back, so pick the direction by whether the path
  ;; already carries a TRAMP prefix.
  (setq agent-shell-path-resolver-function
        (lambda (path)
          (cond ((file-remote-p path) (file-remote-p path 'localname))
                ((file-remote-p default-directory)
                 (concat (file-remote-p default-directory) path))
                (t path))))
  (advice-add 'agent-shell-anthropic-make-claude-code-config
              :filter-return #'my-agent-shell-add-genie-plugins)
  (advice-add 'shell-maker--curl-version-supported
              :around #'my-shell-maker-skip-curl-check)
  (advice-add 'agent-shell--initiate-handshake
              :around #'my-agent-shell-local-fs-only))

;; (use-package neotree
;;   ;; :hook (neotree-mode . #'turn-off-evil-mode)
;;   :commands (neotree-toggle)
;;   :init
;;   (setq neo-theme (if (display-graphic-p) 'nerd-icons 'arrow))
;;   (add-hook 'neotree-mode-hook #'turn-off-evil-mode nil t)
;;   :config
;;   (message "init.el: loaded neotree")
;;
;;   (defun winum-assign-0-to-neotree ()
;;     (when (string-match-p ".*\\*NeoTree\\*.*" (buffer-name)) 0))
;;   (setq neo-window-fixed-size nil)
;;   (with-eval-after-load 'winum
;;     (add-to-list 'winum-assign-functions #'winum-assign-0-to-neotree))
;;     )

(use-package treemacs
  :config
  (defun my-winum-assign-0-to-treemacs ()
    (when (string-match-p "^ \\*Treemacs" (buffer-name)) 10))
  (with-eval-after-load 'winum
    (add-to-list 'winum-assign-functions #'my-winum-assign-0-to-treemacs))
  ;; Skip file-notify and git status on remote paths. Both spawn remote
  ;; processes (inotifywait/gio, git) per directory expansion and stall the
  ;; UI. Local trees keep both features.
  (advice-add 'treemacs--start-watching :before-while
              (lambda (path &rest _)
                (not (file-remote-p path))))
  (when (fboundp 'treemacs--git-status-process)
    (advice-add 'treemacs--git-status-process :before-while
                (lambda (path &rest _)
                  (not (file-remote-p path))))))
(use-package treemacs-evil
  :after treemacs)

(use-package org
  :ensure t
  :bind (("C-c a" . org-agenda)
         ("C-c c" . org-capture))
  :custom
  ;; Define your primary agenda and note files
  (org-directory "~/Documents/org/")
  (org-agenda-files (list "~/Documents/org/tasks.org" "~/Documents/org/projects.org"))
  (org-default-notes-file "~/Documents/org/notes.org")

  ;; Task Tracking & Workflow
  (org-todo-keywords '((sequence "TODO(t)" "WAIT(w)" "|" "DONE(d)" "CANCELLED(c)")))
  (org-log-done 'time)
  (org-log-into-drawer t)

  ;; Capture Templates for quick input
  (org-capture-templates
   '(("t" "Todo" entry (file+headline "~/Documents/org/tasks.org" "Inbox")
      "* TODO %?\n  %i\n  %U")
     ("n" "Note" entry (file+headline "~/Documents/org/notes.org" "Notes")
      "* %?\n  %i\n  %U")))

  ;; Agenda Customization
  (org-agenda-start-on-weekday 1)
  (org-agenda-span 'week)
  (org-agenda-window-setup 'current-window))

(use-package evil-org
  :after (evil org)
  :hook (org-mode . evil-org-mode)
  :config
  (evil-org-set-key-theme
   '(navigation insert textobjects additional todo heading return))
  ;; Reclaim M-<arrow> in org buffers; use M-hjkl (via evil-org) instead.
  (define-key org-mode-map (kbd "M-<left>")  nil)
  (define-key org-mode-map (kbd "M-<right>") nil)
  (define-key org-mode-map (kbd "M-<up>")    nil)
  (define-key org-mode-map (kbd "M-<down>")  nil))

(use-package org-mac-link
  :after org)

;; Modern UI upgrade (Requires installing org-modern)
(use-package org-modern
  :ensure t
  :hook (org-mode . org-modern-mode)
  :hook (org-agenda-finalize . org-modern-agenda))

;; (use-package vterm)
(use-package ghostel
  :ensure (:ref "v0.37.0")
  :hook (after-init . ghostel-comint-global-mode)
  :config
  ;; Default configuration
  ;; `rpc' isn't among ghostel's built-in methods, so without an entry here it
  ;; falls through to the connection-local `shell-file-name' -- which is
  ;; deliberately /bin/sh for myvm (see the `myvm-tcsh' profile above) -- and
  ;; remote terminals land in sh instead of tcsh.
  (setq ghostel-tramp-shells
        '(("ssh" login-shell)           ; auto-detect via getent
          ("scp" login-shell)
          ("rpc" login-shell))))


;; Global keybindings:
(use-package emacs
  :ensure nil
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
  (keymap-global-set "C-c w" #'visual-line-mode)
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

(when (not (display-graphic-p)) (xterm-mouse-mode 1))

(provide 'init)

;; Local variables:
;; byte-compile-warnings: (not obsolete free-vars)
;; End:

;;; init.el ends here
