;;; pueue-command.el --- Pueue interactive commands  -*- lexical-binding: t; -*-

;; Copyright (C) 2021  Valeriy Litkovskyy

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Interactive pueue commands

;;; Code:

;;;; REQUIRES

(require 'seq)
(require 'transient)

(declare-function pueue--marked-ids "pueue")

;;;; COMMANDS

(defun pueue-command--call (command &optional args)
  "Call pueue COMMAND with ARGS.
Show success or error message."
  (with-temp-buffer
    (apply #'call-process "pueue" nil t nil command args)
    (message "%s" (string-trim-right (buffer-string)))))

;;;;; ADD

(defun pueue-command-add--transient (command &optional args)
  "Transient helper.
Run pueue add command.  COMMAND is a string and ARGS are command
line arguments."
  (interactive
   (list (read-shell-command "Command: ")
         (mapcan
          (lambda (arg)
            (if (string-match-p (rx bos "--after=") arg)
                (mapcar
                 (apply-partially #'concat "--after=")
                 (split-string (substring arg 8) ","))
              (list arg)))
          (transient-args 'pueue-command-add))))
  (pueue-command--call "add" (append args (list command)))
  (revert-buffer nil t))

(transient-define-prefix pueue-command-add ()
  "Run pueue add command."
  ["Flags"
   ("-e" "Escape any special shell characters" "--escape")
   ("-i" "Immediately start the task" "--immediate")
   ("-s" "Create the task in Stashed state" "--stashed")]
  ["Options"
   ("-a" "Start the task after other tasks (N1,N2,N3..)" "--after=")
   ("-d" "Prevents the task from being enqueued until <delay> elapses" "--delay=")
   ("-g" "Assign the task to a group" "--group=")
   ("-l" "Add some information for yourself" "--label=")]
  ["Actions"
   ("a" "Add" pueue-command-add--transient)])

;;;;; CLEAN

(defun pueue-command-clean--transient (&optional args)
  "Transient helper.
Run pueue clean command.  ARGS are command line arguments."
  (interactive (list (transient-args 'pueue-command-clean)))
  (pueue-command--call "clean" args)
  (revert-buffer nil t))

(transient-define-prefix pueue-command-clean ()
  "Run pueue clean command."
  ["Flags"
   ("-s" "Only clean tasks that finished successfully" "--successful-only")]
  ["Actions"
   ("c" "Clean" pueue-command-clean--transient)])

;;;;; EDIT

(defun pueue-command-edit--transient (task-id &optional args)
  "Transient helper.
Run pueue edit command.  TASK-ID is a numeric id of a task.  ARGS
are command line arguments."
  (interactive
   (let ((marked-ids (pueue--marked-ids)))
     (if (or (not marked-ids) (/= 1 (seq-length marked-ids)))
         (user-error "No task id or more than one task id specified")
       (list (seq-first marked-ids) (transient-args 'pueue-command-edit)))))
  (pueue-command--call "edit" (append (list (number-to-string task-id)) args))
  (revert-buffer nil t))

(transient-define-prefix pueue-command-edit ()
  "Run pueue edit command."
  ["Flags"
   ("-p" "Edit the path of the task" "--path")]
  ["Actions"
   ("e" "Edit" pueue-command-edit--transient)])

;;;;; ENQUEUE

(defun pueue-command-enqueue--transient (task-ids &optional args)
  "Transient helper.
Run pueue enqueue command.  TASK-IDS are numeric task ids.  ARGS
are command line arguments."
  (interactive (list (pueue--marked-ids) (transient-args 'pueue-command-enqueue)))
  (let ((ids (seq-map #'number-to-string task-ids)))
    (pueue-command--call "enqueue" (append args ids))
    (revert-buffer nil t)))

(transient-define-prefix pueue-command-enqueue ()
  "Run pueue enqueue command."
  ["Options"
   ("-d" "Delay enqueuing these tasks until <delay> elapses" "--delay=")]
  ["Actions"
   ("Q" "Enqueue" pueue-command-enqueue--transient)])

;;;;; FOLLOW

(defun pueue-command-follow--transient (task-id &optional args)
  "Transient helper.
Run pueue follow command.  TASK-ID is a numeric id of a task.
ARGS are command line arguments."
  (interactive
   (let ((marked-ids (pueue--marked-ids)))
     (if (or (not marked-ids) (/= 1 (seq-length marked-ids)))
         (user-error "No task id or more than one task id specified")
       (list (seq-first marked-ids) (transient-args 'pueue-command-follow)))))

  (let* ((buffer-name "*Pueue Follow*")
         (id (number-to-string task-id))
         (command (append (list "pueue" "follow") args (list id))))
    (when-let ((buffer (get-buffer buffer-name)))
      (kill-buffer buffer))
    (async-shell-command (string-join command " ") buffer-name)))

(transient-define-prefix pueue-command-follow ()
  "Run pueue follow command."
  ["Flags"
   ("-e" "Show stderr instead of stdout" "--err")]
  ["Actions"
   ("f" "Follow" pueue-command-follow--transient)])

;;;;; GROUP

(defun pueue-command-group--transient (&optional args)
  "Transient helper.
Run pueue group command.  ARGS are command line arguments."
  (interactive (list (transient-args 'pueue-command-group)))
  (pueue-command--call "group" args)
  (revert-buffer nil t))

(transient-define-prefix pueue-command-group ()
  "Run pueue group command."
  ["Options"
   ("-a" "Add a group by name" "--add=")
   ("-r" "Remove a group by name" "--remove=")]
  ["Actions"
   ("G" "Group" pueue-command-group--transient)])

;;;;; KILL

(defun pueue-command-kill--transient (task-ids &optional args)
  "Transient helper.
Run pueue kill command.  TASK-IDS are numeric ids of tasks.  ARGS
are command line arguments."
  (interactive (list (pueue--marked-ids) (transient-args 'pueue-command-kill)))
  (let ((ids (seq-map #'number-to-string task-ids)))
    (pueue-command--call "kill" (append args ids))
    (revert-buffer nil t)))

(transient-define-prefix pueue-command-kill ()
  "Run pueue kill command."
  ["Flags"
   ("-a" "Kill all running tasks across ALL groups. This also pauses all groups" "--all")
   ("-c" "Send the SIGTERM signal to all children as well" "--children")]
  ["Options"
   ("-g" "Kill all running tasks in a group. This also pauses the group" "--group=")]
  ["Actions"
   ("k" "Kill" pueue-command-kill--transient)])

;;;;; LOG

(defun pueue-command-log--transient (task-ids &optional args)
  "Transient helper.
Run pueue log command.  TASK-IDS are numeric ids of tasks.  ARGS
are command line arguments."
  (interactive (list (pueue--marked-ids) (transient-args 'pueue-command-log)))
  (let* ((ids (seq-map #'number-to-string task-ids))
         (command (append (list "pueue" "log") args ids))
         (buffer-name "*Pueue Log*"))
    (async-shell-command (string-join command " ") buffer-name)))

(transient-define-prefix pueue-command-log ()
  "Run pueue log command."
  ["Flags"
   ("-f" "Show the whole stdout and stderr output" "--full")]
  ["Options"
   ("-l" "Only print the last X lines of each task's output" "--lines=")]
  ["Actions"
   ("l" "Log" pueue-command-log--transient)])

;;;;; PARALLEL

(defun pueue-command-parallel--transient (parallel-tasks &optional args)
  "Transient helper.
Run pueue parallel command.  PARALLEL-TASKS is a number.  ARGS
are command line arguments."
  (interactive (list (read-number "Parallel tasks: ")
                     (transient-args 'pueue-command-parallel)))
  (let ((parallel-tasks (number-to-string parallel-tasks)))
    (pueue-command--call "parallel" (append args (list parallel-tasks)))
    (revert-buffer nil t)))

(transient-define-prefix pueue-command-parallel ()
  "Run pueue parallel command."
  ["Options"
   ("-g" "Set the amount for the specific group" "--group=")]
  ["Actions"
   ("L" "Parallel" pueue-command-parallel--transient)])

;;;;; PAUSE

(defun pueue-command-pause--transient (task-ids &optional args)
  "Transient helper.
Run pueue pause command.  TASK-IDS are numeric ids of tasks.
ARGS are command line arguments."
  (interactive (list (pueue--marked-ids) (transient-args 'pueue-command-pause)))
  (let ((ids (seq-map #'number-to-string task-ids)))
    (pueue-command--call "pause" (append args ids))
    (revert-buffer nil t)))

(transient-define-prefix pueue-command-pause ()
  "Run pueue pause command."
  ["Flags"
   ("-a" "Pause all groups!" "--all")
   ("-c" "Also pause direct child processes of a task's main proces." "--children")]
  ["Options"
   ("-g" "Pause a specific group" "--group=")]
  ["Actions"
   ("P" "Pause" pueue-command-pause--transient)])

;;;;; REMOVE

(defun pueue-command-remove (task-ids)
  "Run pueue remove command.
TASK-IDS are numeric ids of tasks."
  (interactive (list (pueue--marked-ids)))
  (let ((ids (seq-map #'number-to-string task-ids)))
    (pueue-command--call "remove" ids)
    (revert-buffer nil t)))

;;;;; RESET

(defun pueue-command-reset--transient (&optional args)
  "Transient helper.
Run pueue reset command.  ARGS are command line arguments."
  (interactive (list (transient-args 'pueue-command-reset)))
  (pueue-command--call "reset" args)
  (revert-buffer nil t))

(transient-define-prefix pueue-command-reset ()
  "Run pueue reset command."
  ["Flags"
   ("-c" "Send the SIGTERM signal to all children as well" "--children")
   ("-f" "Don't ask for any confirmation" "--force")]
  ["Actions"
   ("t" "Reset" pueue-command-reset--transient)])

;;;;; RESTART

(defun pueue-command-restart--transient (task-ids &optional args)
  "Run pueue restart command.
TASK-IDS are numeric ids of tasks.  ARGS are command line
arguments."
  (interactive (list (pueue--marked-ids) (transient-args 'pueue-command-restart)))
  (let ((ids (seq-map #'number-to-string task-ids)))
    (pueue-command--call "restart" (append args ids))
    (revert-buffer nil t)))

(transient-define-prefix pueue-command-restart ()
  "Run pueue restart command."
  ["Flags"
   ("-a" "Restart all failed tasks" "--all-failed")
   ("-e" "Edit the tasks' command before restarting" "--edit")
   ("-p" "Edit the tasks' path before restarting" "--edit-path")
   ("-i" "Restart the task by reusing the already existing tasks" "--in-place")
   ("-k" "Immediately start the tasks" "--start-immediately")
   ("-s" "Set the restarted task to a \"Stashed\" state" "--stashed")]
  ["Actions"
   ("r" "Restart" pueue-command-restart--transient)])

;;;;; SEND

(defun pueue-command-send (task-id input)
  "Run pueue send command.
TASK-ID is a numeric id of task.  INPUT is a string."
  (interactive
   (let ((marked-ids (pueue--marked-ids)))
     (if (or (not marked-ids) (/= 1 (seq-length marked-ids)))
         (user-error "No task id or more than one task id specified")
       (list (seq-first marked-ids) (read-string "Input: ")))))
  (let ((id (number-to-string task-id)))
    (pueue-command--call "send" (list id input))
    (revert-buffer nil t)))

;;;;; START

(defun pueue-command-start--transient (task-ids &optional args)
  "Transient helper.
Run pueue start command.  TASK-IDS are numeric ids of tasks.
ARGS are command line arguments."
  (interactive (list (pueue--marked-ids) (transient-args 'pueue-command-start)))
  (let ((ids (seq-map #'number-to-string task-ids)))
    (pueue-command--call "start" (append args ids))
    (revert-buffer nil t)))

(transient-define-prefix pueue-command-start ()
  "Run pueue start command."
  ["Flags"
   ("-a" "Resume all groups" "--all")
   ("-c" "Also resume direct child processes of your paused tasks" "--children")]
  ["Options"
   ("-g" "Resume a specific group and all paused tasks in it" "--group=")]
  ["Actions"
   ("s" "Start" pueue-command-start--transient)])

;;;;; STASH

(defun pueue-command-stash (task-ids)
  "Run pueue stash command.
TASK-IDS are numeric ids of tasks."
  (interactive (list (pueue--marked-ids)))
  (let ((ids (seq-map #'number-to-string task-ids)))
    (pueue-command--call "stash" ids)
    (revert-buffer nil t)))

;;;;; SWITCH

(defun pueue-command-switch (task-id-1 task-id-2)
  "Run pueue switch command.
TASK-ID-1 and TASK-ID-2 are numeric ids of tasks."
  (interactive
   (let ((marked-ids (pueue--marked-ids)))
     (if (or (not marked-ids) (/= 2 (seq-length marked-ids)))
         (user-error "No task id or not two task ids specified")
       marked-ids)))
  (let ((ids (mapcar #'number-to-string (list task-id-1 task-id-2))))
    (pueue-command--call "switch" ids))
  (revert-buffer nil t))

;;;; PROVIDE

(provide 'pueue-command)
;;; pueue-command.el ends here
