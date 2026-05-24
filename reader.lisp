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
          ;; Character literal #\x — don't interpret next char
          ;; Handled by checking if previous was #\ — actually we need
          ;; to handle the #-dispatch case
          ;; Block comment #| ... |#
          ((char= ch #\|)
           ;; Check if preceded by #
           (when (and (> (length result) 1)
                      (char= (aref result (- (length result) 2)) #\#))
             (let ((nesting 1))
               (loop
                 (let ((c (read-char stream nil nil)))
                   (unless c (return-from read-balanced-form
                               (coerce result 'simple-string)))
                   (vector-push-extend c result)
                   (cond
                     ((and (char= c #\|)
                           (let ((next (peek-char nil stream nil nil)))
                             (when (and next (char= next #\#))
                               (vector-push-extend (read-char stream) result)
                               t)))
                      (decf nesting)
                      (when (zerop nesting) (return)))
                     ((and (char= c #\#)
                           (let ((next (peek-char nil stream nil nil)))
                             (when (and next (char= next #\|))
                               (vector-push-extend (read-char stream) result)
                               t)))
                      (incf nesting))))))))
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
