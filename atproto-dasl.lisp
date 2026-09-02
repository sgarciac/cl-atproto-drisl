;;; Functions to transform a https://github.com/Zulu-Inuoe/jzon data structure
;;; into one using the atproto json encoding rules
;;; Bytes become:
;;; {\"$bytes\": \"...base64...\"}
;;;
;;; CID links become:
;;; {\"$link\": \"bafy...\"}
;;;
;;; the reverse method is also provided
(in-package #:cl-atproto-drisl)

(defun cidv1-to-string (cid-bytes)
  (concatenate 'string
               "b"
               (base32-encode cid-bytes)))

(defun cidv1-from-string (string)
  (unless (and (> (length string) 0)
               (char= (char-downcase (char string 0)) #\b))
    (error "Not a CIDv1 Base32 string: ~A" string))
  (base32-decode (subseq string 1)))

(defun atproto-dasl-encode (data-item)
  "Recursively transform a 'native' lisp/jzon object into DASL/ATProto lisp/jzon."
  (etypecase data-item
    ((SIMPLE-ARRAY (UNSIGNED-BYTE 8))
     (let ((ht (make-hash-table :test 'equal)))
       (setf (gethash "$bytes" ht) (base64-encode data-item))
       ht))
    (HASH-TABLE
     (let ((result (make-hash-table :test 'equal)))
       (maphash
        (lambda (key value)
          (setf (gethash key result)
                (atproto-dasl-encode value)))
        data-item)
       result))
    (STRING data-item)
    ((SIMPLE-ARRAY (UNSIGNED-BYTE 8))
     data-item)
    (SIMPLE-ARRAY
     (map 'vector
          (lambda (x)
            (atproto-dasl-encode x))
          data-item))
    (CID
     (let ((ht (make-hash-table :test 'equal)))
       (setf (gethash "$link" ht) (cidv1-to-string data-item))
       ht)
     )
    (T data-item)))

(defun atproto-dasl-decode (data-item)
  "Recurseively transform a DASL/ATproto lisp/jzon object into a 'native' lisp/jzon object"
  (etypecase data-item
    (HASH-TABLE
     (cond ((gethash "$bytes" data-item)
            (base64-decode (gethash "$bytes" data-item)))
           ((gethash "$link" data-item)
            (make-cid :bytes (cidv1-from-string (gethash "$link" data-item))))
           (t
            (let ((result (make-hash-table :test 'equal)))
              (maphash
               (lambda (key value)
                 (setf (gethash key result)
                       (atproto-dasl-decode value)))
               data-item)
              result))))
    (STRING data-item)
    ((SIMPLE-ARRAY (UNSIGNED-BYTE 8))
     data-item)

    (SIMPLE-ARRAY
     (map 'vector
          (lambda (x)
            (atproto-dasl-decode x))
          data-item))
    (T data-item)))
