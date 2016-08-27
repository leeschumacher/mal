(defpackage :mal
  (:use :common-lisp
        :types
        :env
        :reader
        :printer
        :genhash)
  (:export :main))

(in-package :mal)

(defvar *repl-env* (types:make-mal-value-hash-table))

(setf (genhash:hashref (types:make-mal-symbol "+") *repl-env*)
      (types:make-mal-builtin-fn (lambda (value1 value2)
                                   (types:apply-unwrapped-values '+
                                                                 value1
                                                                 value2))))

(setf (genhash:hashref (types:make-mal-symbol "-") *repl-env*)
      (types:make-mal-builtin-fn (lambda (value1 value2)
                                   (types:apply-unwrapped-values '-
                                                                 value1
                                                                 value2))))

(setf (genhash:hashref (types:make-mal-symbol "*") *repl-env*)
      (types:make-mal-builtin-fn (lambda (value1 value2)
                                   (types:apply-unwrapped-values '*
                                                                 value1
                                                                 value2))))

(setf (genhash:hashref (types:make-mal-symbol "/") *repl-env*)
      (types:make-mal-builtin-fn (lambda (value1 value2)
                                   (types:apply-unwrapped-values '/
                                                                 value1
                                                                 value2))))

(defun lookup-env (symbol env)
  (let ((value (genhash:hashref symbol env)))
    (if value
        value
        (error 'env:undefined-symbol
               :symbol (format nil "~a" (types:mal-data-value symbol))))))

(defun eval-sequence (sequence env)
  (map 'list
       (lambda (ast) (mal-eval ast env))
       (types:mal-data-value sequence)))

(defun eval-hash-map (hash-map env)
  (let ((hash-map-value (types:mal-data-value hash-map))
        (new-hash-table (types:make-mal-value-hash-table)))
    (genhash:hashmap (lambda (key value)
                       (setf (genhash:hashref (mal-eval key env) new-hash-table)
                             (mal-eval value env)))
                     hash-map-value)
    (types:make-mal-hash-map new-hash-table)))

(defun eval-ast (ast env)
  (switch-mal-type ast
    (types:symbol (lookup-env ast env))
    (types:list (eval-sequence ast env))
    (types:vector (make-mal-vector (apply 'vector (eval-sequence ast env))))
    (types:hash-map (eval-hash-map ast env ))
    (types:any ast)))

(defun mal-read (string)
  (reader:read-str string))

(defun mal-eval (ast env)
  (cond
    ((not (types:mal-list-p ast)) (eval-ast ast env))
    ((zerop (length (types:mal-data-value ast))) ast)
    (t (progn
         (let ((evaluated-list (eval-ast ast env)))
           (apply (types:mal-data-value (car evaluated-list))
                  (cdr evaluated-list)))))))

(defun mal-print (expression)
  (printer:pr-str expression))

(defun rep (string)
  (handler-case
      (mal-print (mal-eval (mal-read string)
                           *repl-env*))
    (error (condition)
      (format nil
              "~a"
              condition))))

(defvar *use-readline-p* nil)

(defun raw-input (prompt)
  (format *standard-output* prompt)
  (force-output *standard-output*)
  (read-line *standard-input* nil))

(defun mal-readline (prompt)
  (if *use-readline-p*
      (cl-readline:readline :prompt prompt
                            :add-history t
                            :novelty-check (lambda (old new)
                                             (not (string= old new))))
      (raw-input prompt)))

(defun mal-writeline (string)
  (when string
    (write-line string)
    (force-output *standard-output*)))

(defun main (&optional (argv nil argv-provided-p))
  (declare (ignorable argv argv-provided-p))
  (setf *use-readline-p* (not (or (string= (uiop:getenv "PERL_RL") "false")
                                  (string= (uiop:getenv "TERM") "dumb"))))
  (loop do (let ((line (mal-readline "user> ")))
             (if line (mal-writeline (rep line)) (return)))))
