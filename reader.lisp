(in-package #:cl-sourcery)

;;; --- Source-preserving reader ---
;;;
;;; A custom readtable that captures the raw text of list forms
;;; before the standard reader processes them. This preserves
;;; whitespace, comments, and formatting.

(defvar *last-source-text* nil
  "The raw text of the most recently read list form. Thread-local via dynamic binding.")

(defvar *sourcery-readtable* (copy-readtable nil)
  "Readtable with source-capturing ( reader macro.")

(defun read-balanced-form (stream)
  "Read characters from STREAM starting after the opening paren,
   tracking balanced parens, strings, comments, and escapes.
   Returns the full text including the opening paren."
  (let ((result (make-array 64 :element-type 'character
                               :adjustable t :fill-pointer 0))
        (depth 1))
    (vector-push-extend #\( result)
    (loop
      (let ((ch (read-char stream nil nil)))
        (unless ch
          (return (coerce result 'simple-string)))
        (vector-push-extend ch result)
        (cond
          ;; String literal — read until unescaped closing quote
          ((char= ch #\")
           (loop
             (let ((c (read-char stream nil nil)))
               (unless c (return-from read-balanced-form
                           (coerce result 'simple-string)))
               (vector-push-extend c result)
               (cond
                 ((char= c #\\)
                  (let ((next (read-char stream nil nil)))
                    (when next (vector-push-extend next result))))
                 ((char= c #\")
                  (return))))))
          ;; Line comment — read until newline
          ((char= ch #\;)
           (loop
             (let ((c (read-char stream nil nil)))
               (unless c (return-from read-balanced-form
                           (coerce result 'simple-string)))
               (vector-push-extend c result)
               (when (char= c #\Newline) (return)))))
          ;; # dispatch — handle reader macros that affect paren/quote tracking
          ((char= ch #\#)
           (let ((next (peek-char nil stream nil nil)))
             (cond
               ;; #\ character literal — consume the character name
               ((and next (char= next #\\))
                (vector-push-extend (read-char stream) result) ; consume backslash
                (let ((c (read-char stream nil nil)))
                  (when c
                    (vector-push-extend c result)
                    ;; If alphabetic, might be a named char like #\Newline
                    (when (alpha-char-p c)
                      (loop for nc = (peek-char nil stream nil nil)
                            while (and nc (alphanumericp nc))
                            do (vector-push-extend (read-char stream) result))))))
               ;; #| block comment — nested, consume until matching |#
               ((and next (char= next #\|))
                (vector-push-extend (read-char stream) result)
                (let ((nesting 1))
                  (loop
                    (let ((c (read-char stream nil nil)))
                      (unless c (return-from read-balanced-form
                                  (coerce result 'simple-string)))
                      (vector-push-extend c result)
                      (cond
                        ((and (char= c #\|)
                              (let ((nc (peek-char nil stream nil nil)))
                                (when (and nc (char= nc #\#))
                                  (vector-push-extend (read-char stream) result)
                                  t)))
                         (decf nesting)
                         (when (zerop nesting) (return)))
                        ((and (char= c #\#)
                              (let ((nc (peek-char nil stream nil nil)))
                                (when (and nc (char= nc #\|))
                                  (vector-push-extend (read-char stream) result)
                                  t)))
                         (incf nesting)))))))
               ;; #( vector literal — opens a paren
               ((and next (char= next #\())
                (vector-push-extend (read-char stream) result)
                (incf depth))
               ;; #" — namestring syntax in some implementations, treat " as string
               ((and next (char= next #\"))
                ;; Don't consume — let the main loop handle " on next iteration
                nil)
               ;; All other # dispatches (#., #', #+, #-, #:, #x, #o, #b, #S, #A, #P, #n=, #n#)
               ;; don't affect paren depth or quote state — just continue
               (t nil))))
          ;; Escaped symbol |...|
          ((char= ch #\|)
           (loop
             (let ((c (read-char stream nil nil)))
               (unless c (return-from read-balanced-form
                           (coerce result 'simple-string)))
               (vector-push-extend c result)
               (when (char= c #\|) (return)))))
          ;; Open paren — increase depth
          ((char= ch #\()
           (incf depth))
          ;; Close paren — decrease depth
          ((char= ch #\))
           (decf depth)
           (when (zerop depth)
             ;; Capture trailing comment on same line (e.g. ") ; comment")
             (loop for c = (peek-char nil stream nil nil)
                   while (and c (member c '(#\Space #\Tab)))
                   do (vector-push-extend (read-char stream) result))
             (when (and (peek-char nil stream nil nil)
                        (char= (peek-char nil stream nil nil) #\;))
               (loop for c = (read-char stream nil nil)
                     while (and c (not (char= c #\Newline)))
                     do (vector-push-extend c result)))
             (return (coerce result 'simple-string)))))))))

(defun sourcery-paren-reader (stream char)
  "Reader macro for ( that captures raw text then delegates to standard reader."
  (declare (ignore char))
  (let ((text (read-balanced-form stream)))
    (setf *last-source-text* text)
    ;; Now parse the captured text with the standard readtable
    (let ((*readtable* (copy-readtable nil)))
      (read-from-string text))))

;; Install on our custom readtable
(set-macro-character #\( #'sourcery-paren-reader nil *sourcery-readtable*)
