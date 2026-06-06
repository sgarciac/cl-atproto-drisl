;;; A minimal implementation of a drisl serializer and deserializer
;;; minus floats, because atproto does not support them.
;;;
;;; Entry points:
;;;   - DRISL-SERIALIZE   stream data-item  -> writes one item to a binary stream
;;;   - DRISL-DESERIALIZE stream            -> reads one item from a binary stream
;;; Convenience wrappers operating on octet vectors:
;;;   - DRISL-SERIALIZE-TO-SEQUENCE     data-item -> octet vector
;;;   - DRISL-DESERIALIZE-FROM-SEQUENCE bytes     -> data item
;;;
;;; CIDs (CBOR tag 42) are represented by the CID struct defined below.

;; examples:
;;
;; encode a CID
;; (base64-encode
;;  (flexi-streams:with-output-to-sequence (stream)
;;    (drisl-serialize stream (make-cid :bytes
;;                                      #(#x00 #x01 #x71 #x12 #x20 #x9F #xE4 #xCC #xC6 #xDE #x16 #x72 #x4F #x3A #x30 #xC7 #xE8 #xF2 #x54 #xF3 #xC6 #x47 #x19 #x86 #xAC #xB1 #xF8 #xD8 #xCF #x8E #x96 #xCE #x2A #xD7 #xDB #xE7 #xFB)
;;                                      ))))

;; encode an object:
;;
;; (let ((m (make-hash-table :test 'equal)))
;;   (setf (gethash 5 m) "sergio")
;;   (setf (gethash 4 m) 30)
;;   (setf (gethash 3 m) nil)
;;   (base64-encode
;;    (flexi-streams:with-output-to-sequence (stream)
;;      (drisl-serialize stream m))))

;; encode a test string
;; (flexi-streams:with-output-to-sequence (stream)
;;   (drisl-serialize stream "hello"))

;; decode bytes back into a Lisp object
;; (drisl-deserialize-from-sequence
;;  (drisl-serialize-to-sequence "hello"))
;;
;; or, reading from a stream directly:
;; (flexi-streams:with-input-from-sequence (stream bytes)
;;   (drisl-deserialize stream))

(in-package #:cl-atproto-drisl)

(defconstant +special-false+ #xf4)
(defconstant +special-true+  #xf5)
(defconstant +special-nil+   #xf6)
(defconstant +cid-prefix+ #(#xD8 #x2A #x58 #x25))

(defstruct cid
  ;; a simple array of unsigned bytes representing the CID. It *must*
  ;;already contain the multibase prefix (a null byte)
  bytes)

;; helper to compare sequences of bytes in a bytewise lexicographic order
(defun bytewise-lex< (a b)
  (let ((len-a (length a))
        (len-b (length b)))
    (loop for i from 0 below (min len-a len-b)
          do (let ((byte-a (aref a i))
                   (byte-b (aref b i)))
               (cond ((< byte-a byte-b) (return t))
                     ((> byte-a byte-b) (return nil))))
          finally (return (< len-a len-b)))))

(defun cbor-uint-bytes (n)
  (cond ((< n #x100) 1)
        ((< n #x10000) 2)
        ((< n #x100000000) 4)
        (t 8)))

(defun drisl-unsigned-integer (stream i)
  (if (< i 24)
      (write-byte i stream)
      (let* ((bytes (integer-to-octets i))
             (size-case (+ 24 (floor (log (length bytes) 2)))))
        (write-byte size-case stream)
        (loop for b across bytes
              do (write-byte b stream)))))

(defun drisl-negative-integer (stream i)
  (let ((i (- -1 i)))
    (if (< i 24)
        (write-byte (logior #b00100000 i) stream)
        (let* ((bytes (integer-to-octets i))
               (size-case (+ 24 (floor (log (length bytes) 2)))))
          (write-byte (logior #b00100000 size-case) stream)
          (loop for b across bytes
                do (write-byte b stream))))))

(defun drisl-integer (stream i)
  (if (minusp i)
      (drisl-negative-integer stream i)
      (drisl-unsigned-integer stream i)))

(defun drisl-bytes (stream bytes)
  (let* ((i (length bytes)))
    (if (< i 24)
        (write-byte (logior #b01000000 i) stream)
        (let* ((size-bytes (integer-to-octets i))
               (size-case (+ 24 (floor (log (length size-bytes) 2)))))
          (write-byte (logior #b01000000 size-case) stream)
          (loop for b across size-bytes
                do (write-byte b stream))))
    (loop for b across bytes
          do (write-byte b stream))))

(defun drisl-string (stream str)
  (let* ((bytes (flexi-streams:string-to-octets str :external-format :utf-8))
         (i (length bytes)))
    (if (< i 24)
        (write-byte (logior #b01100000 i) stream)
        (let* ((size-bytes (integer-to-octets i))
               (size-case (+ 24 (floor (log (length size-bytes) 2)))))
          (write-byte (logior #b01100000 size-case) stream)
          (loop for b across size-bytes
                do (write-byte b stream))))
    (loop for b across bytes
          do (write-byte b stream))))

(defun drisl-array (stream arr)
  (let ((i (length arr)))
    ;; write size of the array
    (if (< i 24)
        (write-byte (logior #b10000000 i) stream)
        (let* ((bytes (integer-to-octets i))
               (size-case (+ 24 (floor (log (length bytes) 2)))))
          (write-byte (logior #b10000000 size-case) stream)
          (loop for b across bytes
                do (write-byte b stream))))
    ;; write array elements
    (loop for element across arr
          do (drisl-serialize stream element))))

(defun drisl-map (stream m)
  (let* ((i (hash-table-count m))
         (keys (hash-table-keys m))
         (serialized-keys (mapcar (lambda (k)
                                    (flexi-streams:with-output-to-sequence (stream)
                                      (drisl-serialize stream k)))
                                  keys))
         (skey-to-key (make-hash-table :test 'equal)))
    ;; serialized-key to key
    (loop for k in keys
          for skey in serialized-keys
          do (setf (gethash skey skey-to-key) k))
    ;; write size of the map
    (if (< i 24)
        (write-byte (logior #b10100000 i) stream)
        (let* ((bytes (integer-to-octets i))
               (size-case (+ 24 (floor (log (length bytes) 2)))))
          (write-byte (logior #b10100000 size-case) stream)
          (loop for b across bytes
                do (write-byte b stream))))
    ;; write key-value pairs
    (dolist (sk (sort serialized-keys #'bytewise-lex<))
      (write-sequence sk stream)
      (drisl-serialize stream (gethash (gethash sk skey-to-key) m))
      )))

(defun drisl-cid (stream cid)
  (when (not (=(length (cid-bytes cid)) 37))
    (error "CID bytes must be exactly 37 bytes long, including the multibase prefix"))
  (write-sequence +cid-prefix+ stream)
  (loop for byte across (cid-bytes cid)
        do (write-byte byte stream)))

(defun read-uint-bytes (stream n)
  "Read N big-endian bytes from STREAM and return the resulting unsigned integer."
  (let ((value 0))
    (dotimes (i n value)
      (setf value (logior (ash value 8) (read-byte stream))))))

(defun read-cbor-argument (stream info)
  "Given the low 5 bits (INFO) of a CBOR initial byte, read and return
   the argument value from STREAM. Signals an error for indefinite
   lengths (info = 31), which are not allowed in DRISL."
  (cond ((< info 24) info)
        ((= info 24) (read-uint-bytes stream 1))
        ((= info 25) (read-uint-bytes stream 2))
        ((= info 26) (read-uint-bytes stream 4))
        ((= info 27) (read-uint-bytes stream 8))
        (t (error "Invalid/unsupported CBOR additional-info value: ~A" info))))

(defun drisl-deserialize (stream)
  "Read one DRISL-encoded data item from a binary STREAM and return it.
   Inverse of DRISL-SERIALIZE. Maps the CBOR tag 42 (CID) to a CID struct,
   true/false/null to T/NIL/NIL, byte strings to (SIMPLE-ARRAY (UNSIGNED-BYTE 8)),
   text strings to Lisp strings, arrays to simple vectors, and maps to
   EQUAL hash-tables."
  (let* ((initial (read-byte stream))
         (major (ash initial -5))
         (info  (logand initial #b00011111)))
    (ecase major
      (0 ;; unsigned integer
       (read-cbor-argument stream info))
      (1 ;; negative integer
       (- -1 (read-cbor-argument stream info)))
      (2 ;; byte string
       (let* ((len (read-cbor-argument stream info))
              (buf (make-array len :element-type '(unsigned-byte 8))))
         (read-sequence buf stream)
         buf))
      (3 ;; text string
       (let* ((len (read-cbor-argument stream info))
              (buf (make-array len :element-type '(unsigned-byte 8))))
         (read-sequence buf stream)
         (flexi-streams:octets-to-string buf :external-format :utf-8)))
      (4 ;; array
       (let* ((len (read-cbor-argument stream info))
              (arr (make-array len)))
         (dotimes (i len)
           (setf (aref arr i) (drisl-deserialize stream)))
         arr))
      (5 ;; map
       (let* ((len (read-cbor-argument stream info))
              (m (make-hash-table :test 'equal)))
         (dotimes (i len)
           (let ((k (drisl-deserialize stream))
                 (v (drisl-deserialize stream)))
             (setf (gethash k m) v)))
         m))
      (6 ;; tag
       (let ((tag (read-cbor-argument stream info)))
         (unless (= tag 42)
           (error "Unsupported CBOR tag: ~A" tag))
         (let ((bytes (drisl-deserialize stream)))
           (unless (and (typep bytes '(simple-array (unsigned-byte 8) (*)))
                        (= (length bytes) 37))
             (error "Tag 42 (CID) payload must be a 37-byte byte string"))
           (make-cid :bytes bytes))))
      (7 ;; simple values
       (cond ((= info 20) nil)        ;; false
             ((= info 21) t)          ;; true
             ((= info 22) nil)        ;; null
             (t (error "Unsupported CBOR simple value: ~A" info)))))))

(defun drisl-serialize (stream data-item)
  "Write a data item to a binary stream following the drisl encoding
   rules. Data items must follow the conventions of jzon
   https://github.com/Zulu-Inuoe/jzon.

   CIDs (tag 42) can be represented using the struct \"cid\"
   defined in this file.
  "
  (etypecase data-item
    (NULL
     (write-byte +special-nil+ stream))
    (BOOLEAN
     (write-byte +special-true+ stream))
    (SYMBOL
     (case data-item
       (NULL
        (write-byte +special-false+ stream))))
    (INTEGER
     (drisl-integer stream data-item))
    ((SIMPLE-ARRAY (UNSIGNED-BYTE 8))
     (drisl-bytes stream data-item))
    ((SIMPLE-ARRAY CHARACTER)
     (drisl-string stream data-item))
    (HASH-TABLE
     (drisl-map stream data-item))
    (SIMPLE-ARRAY
     (drisl-array stream data-item))
    (CID
     (drisl-cid stream data-item))
    ))

;; symetric
;;(drisl-deserialize-from-sequence (drisl-serialize-to-sequence (make-array 10 :element-type '(unsigned-byte 8) :initial-contents '(1 2 3 4 5 6 7 8 9 10))))

(defun drisl-serialize-to-sequence (data-item)
  (flexi-streams:with-output-to-sequence (stream)
    (drisl-serialize stream data-item)))

(defun drisl-deserialize-from-sequence (bytes)
  (flexi-streams:with-input-from-sequence (stream bytes)
    (drisl-deserialize stream)))
