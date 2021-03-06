;; tab.jl - frame handling of tab
;;
;; Copyright (C) Yann Hodique <Yann.Hodique@lifl.fr>
;;
;; This file is an official accepted contribution into sawfish.
;;
;; This script is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; sawfish is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with sawfish; see the file COPYING.  If not, write to
;; the Free Software Foundation, 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301 USA.

(define-structure sawfish.wm.tabs.tab

    (export tab-pos 
            tabbar-left-margin
            tabbar-left-margin-transient
            tabbar-right-margin
            tabbar-right-margin-transient
            tab-window-add-to-tabgroup
            set-tab-adjustments)

    (open rep
	  rep.system
	  sawfish.wm.misc
	  sawfish.wm.custom
	  sawfish.wm.commands
	  sawfish.wm.frames
	  sawfish.wm.tabs.tabgroup
      sawfish.wm.cursors
	  sawfish.wm.windows
      sawfish.wm.gaol)

  (define-structure-alias tab sawfish.wm.tabs.tab)

  ;; TODO:
  ;; - make calculations work with tiny windows, should fixed
  ;; - hide some frame parts on leftmost and rightmost tabs, should fixed
  ;; - add a drag-n-drop way to group windows by tabs

  (define select-cursor (default-cursor))
  (define marked-window nil)

  (define tabbar-left-dec-width)
  (define tabbar-right-dec-width)
  (define tabbar-left-margin)
  (define tabbar-right-margin)
  (define tabbar-left-margin-transient)
  (define tabbar-right-margin-transient)

  (define (set-tab-adjustments #!key theme-left-dec-width theme-right-dec-width theme-left-margin
                               theme-right-margin theme-left-margin-transient theme-right-margin-transient)
    (setq tabbar-left-dec-width theme-left-dec-width)
    (setq tabbar-right-dec-width theme-right-dec-width)
    (setq tabbar-left-margin theme-left-margin)
    (setq tabbar-right-margin theme-right-margin)
    (setq tabbar-left-margin-transient theme-left-margin-transient)
    (setq tabbar-right-margin-transient theme-right-margin-transient))

  (gaol-add set-tab-adjustments)

  (define (get-tab-pos win)
    (let* ((group (tab-find-window win))
       	   (tabnum (tab-rank win (tab-group-window-list group))))
      (tab-pos group tabnum win)))

  (define (tab-pos group tabnum win)
    "Find the left and right pixel offsets of a tab"
    (let* ((dim-x (car (window-dimensions win)))
           (dim-y (cdr (window-dimensions win)))
           (margin-l
            (if (or (eq (window-get win 'type) 'transient)
                    (eq (window-get win 'type) 'shaped-transient))
                tabbar-left-margin-transient
              tabbar-left-margin))
           (margin-r
            (if (or (eq (window-get win 'type) 'transient)
                    (eq (window-get win 'type) 'shaped-transient))
                tabbar-right-margin-transient
              tabbar-right-margin))
           (tabarea-width (- dim-x margin-l margin-r))
           (tabarea-height (- dim-y margin-l margin-r))
           (numtabs (length (tab-group-window-list group)))
           (left (quotient (* tabnum tabarea-width) numtabs))
           (bottom (quotient (* tabnum tabarea-height) numtabs))
           ;; the right edge is not always "left + (window-width / numtabs)"
           ;; that would be inaccurate due to rounding errors
           ;;
           (right (quotient (* (+ tabnum 1) tabarea-width) numtabs))
           (top (quotient (* (+ tabnum 1) tabarea-height) numtabs))
           (width (- right left))
           (height (- top bottom)))
      (list dim-x dim-y margin-l margin-r left right width bottom top height)))

  (define (tab-title-text-width win)
    "Width of the title text area is the tabwidth minus decorations by horizontal titlebar themes"
    (let* ((tabwidth (nth 6 (get-tab-pos win))))
      (+ tabwidth
         (- tabbar-left-dec-width)
         (- tabbar-right-dec-width))))

  (define (tab-title-text-height win)
    "Height of the title text area is the tabheight minus decorations by vertical titlebar themes"
    (let* ((tabheight (nth 9 (get-tab-pos win))))
      (when (> tabheight 0)
        (+ tabheight
           (- tabbar-left-dec-width)
           (- tabbar-right-dec-width)))))

  (define (tab-left-edge win)
    "Compute left edge of tab by horizontal titlebar themes"
    (let* ((left (nth 4 (get-tab-pos win)))
           (margin-l (nth 2 (get-tab-pos win))))
      (+ left margin-l)))

  (define (tab-bottom-edge win)
    "Compute bottom edge of tab by vertical titlebar themes"
    (let* ((bottom (nth 7 (get-tab-pos win)))
           (margin-l (nth 2 (get-tab-pos win))))
      (+ bottom margin-l)))

  (define (tab-right-dec-pos win)
    "Compute position of tab's right-edge decoration by horizontal titlebar themes"
    (let* ((right (nth 5 (get-tab-pos win)))
           (margin-l (nth 2 (get-tab-pos win)))
           (dim-x (nth 0 (get-tab-pos win))))
      (when (> dim-x margin-l) ;; don't display outside from frame
        (+ right margin-l (- tabbar-right-dec-width)))))

  (define (tab-top-dec-pos win)
    "Compute position of tab's top-edge decoration by vertical titlebar themes"
    (let* ((top (nth 8 (get-tab-pos win)))
           (margin-l (nth 2 (get-tab-pos win)))
           (dim-y (nth 1 (get-tab-pos win))))
      (when (> dim-y margin-l) ;; don't display outside from frame
        (+ top margin-l (- tabbar-right-dec-width)))))

  (define (tab-title-left-edge win)
    "Compute left edge of tab by horizontal titlebar themes"
    (+ (tab-left-edge win) tabbar-left-dec-width))

  (define (tab-title-bottom-edge win)
    "Compute bottom edge of tab by vertical titlebar themes"
    (+ (tab-bottom-edge win) tabbar-left-dec-width))

  ;; new classes tabs : tabbar-horizontal-left-edge tabbar-horizontal tabbar-horizontal-right-edge
  ;;
  (define-frame-class 'tabbar-horizontal-left-edge
    `((left-edge . ,tab-left-edge)) t)

  (define-frame-class 'tabbar-horizontal
    `((left-edge . ,tab-title-left-edge)
      (width . ,tab-title-text-width)))

  (define-frame-class 'tabbar-horizontal-right-edge
    `((left-edge . ,tab-right-dec-pos)) t)

  ;; new classes tabs on side : tabbar-vertical-top-edge tabbar-vertical tabbar-vertical-bottom-edge
  ;;
  (define-frame-class 'tabbar-vertical-top-edge
    `((bottom-edge . ,tab-top-dec-pos)) t)

  (define-frame-class 'tabbar-vertical
    `((bottom-edge . ,tab-title-bottom-edge)
      (height . ,tab-title-text-height)))

  (define-frame-class 'tabbar-vertical-bottom-edge
    `((bottom-edge . ,tab-bottom-edge)) t)

  (define (emit-marked-hook w)
    (call-window-hook 'window-state-change-hook w (list '(marked))))

  ;; This function is for interactive use. Use tab-group-window for lisp.
  (define (tab-window-add-to-tabgroup win)
    "Add a window to a tabgroup. Apply this command on a window, then
on another. The first window will be added to the tabgroup containig
the second."
    (when (net-wm-window-type-normal-p win)
      (if marked-window
          (progn
            (mapcar (lambda (w) 
                      (window-put w 'marked nil)
                      (emit-marked-hook w)
                      (tab-group-window w win)) marked-window)
            (default-cursor select-cursor)
            (window-put win 'marked nil)
            (setq marked-window nil))
        (window-put win 'marked t)
        (default-cursor (get-cursor marked-cursor-shape))
        (setq marked-window (cons win)))
      (emit-marked-hook win)))

  (define-command 'tab-window-add-to-tabgroup tab-window-add-to-tabgroup #:spec "%W")

  (define (tab-tabgroup-add-to-tabgroup win)
    "Add a tabgroup to a tabgroup. Apply this command on a window
from the tabgroup, then on another. The tabgroup will be added to
the tabgroup containig the second."
    (when (net-wm-window-type-normal-p win)
      (if marked-window
          (progn
            (setq marked-window (tab-group-windows (car marked-window)))
            (tab-window-add-to-tabgroup win))
        (default-cursor (get-cursor marked-cursor-shape))
        (setq marked-window (tab-group-windows win))
        (mapcar (lambda (w) 
                  (window-put w 'marked t)
                  (emit-marked-hook w)) marked-window))))

  (define-command 'tab-tabgroup-add-to-tabgroup tab-tabgroup-add-to-tabgroup #:spec "%W")

  (define (check-win)
    "Check if a window that was marked as tab is destroy"
    (if (car marked-window)
        (let ((m-list marked-window))
          (setq marked-window nil)
          (mapcar (lambda (w)
                    (if (window-id w)
                        (setq marked-window (append marked-window (cons w nil))))) m-list)
          (when (not (car marked-window))
            (default-cursor select-cursor)
            (setq marked-window nil)))))

  (add-hook 'destroy-notify-hook check-win))

;;(require 'x-cycle)
;;(define-cycle-command-pair
;;  'cycle-tabgroup 'cycle-tabgroup-backwards
;;  (lambda (w)
;;    (delete-if-not window-in-cycle-p
;;                   (delete-if (lambda (win)
;;                                (and (not (eq win w))
;;                                     (tab-same-group-p win w)))
;;                              (workspace-windows current-workspace))
;;                   )
;;    )
;;  #:spec "%W")
