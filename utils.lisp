;;; somt utilities
(in-package #:cl-atproto-drisl)

(defun hash-table-keys (table)
  (let ((keys '()))
    (maphash (lambda (k v)
               (declare (ignore v))
               (push k keys))
             table)
    keys))

(defun integer-to-octets (n)
  (let* ((n-bytes (cbor-uint-bytes n))
         (out (make-array n-bytes :element-type '(unsigned-byte 8))))
    (loop for i from (1- n-bytes) downto 0
          for shift from 0 by 8
          do (setf (aref out i) (logand (ash n (- shift)) #xff)))
    out))

(defun base64-encode (octets)
  (let* ((table "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
         (len (length octets))
         (out (make-string (* 4 (ceiling len 3)))))
    (loop for i from 0 below len by 3
          for j from 0 by 4
          for b0 = (aref octets i)
          for b1 = (if (< (1+ i) len) (aref octets (1+ i)) 0)
          for b2 = (if (< (+ i 2) len) (aref octets (+ i 2)) 0)
          do (setf (aref out j)       (aref table (ash b0 -2))
                   (aref out (+ j 1)) (aref table (logior (ash (logand b0 3) 4) (ash b1 -4)))
                   (aref out (+ j 2)) (if (< (1+ i) len)
                                          (aref table (logior (ash (logand b1 15) 2) (ash b2 -6)))
                                          #\=)
                   (aref out (+ j 3)) (if (< (+ i 2) len)
                                          (aref table (logand b2 63))
                                          #\=)))
    out))


(defun base64-decode (string)
  (let* ((table "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
         (len (length string))
         (full-groups (floor len 4))
         (remainder (mod len 4))
         (out-len (+ (* full-groups 3)
                     (case remainder
                       (0 0)
                       (2 1)
                       (3 2)
                       (otherwise
                        (error "Invalid base64 length: ~D" len)))))
         (out (make-array out-len
                          :element-type '(unsigned-byte 8))))
    (labels ((value (c)
               (let ((pos (position c table)))
                 (or pos
                     (error "Invalid base64 character: ~C" c)))))
      (loop for i from 0 below len by 4
            for j from 0 by 3
            for remaining = (- len i)
            for c0 = (aref string i)
            for c1 = (aref string (+ i 1))
            for c2 = (if (> remaining 2)
                         (aref string (+ i 2))
                         #\=)
            for c3 = (if (> remaining 3)
                         (aref string (+ i 3))
                         #\=)
            for v0 = (value c0)
            for v1 = (value c1)
            for v2 = (if (char= c2 #\=) 0 (value c2))
            for v3 = (if (char= c3 #\=) 0 (value c3))
            for b0 = (logior (ash v0 2)
                             (ash v1 -4))
            for b1 = (logior (ash (logand v1 15) 4)
                             (ash v2 -2))
            for b2 = (logior (ash (logand v2 3) 6)
                             v3)
            do (when (< j out-len)
                 (setf (aref out j) b0))
               (when (< (+ j 1) out-len)
                 (setf (aref out (+ j 1)) b1))
               (when (< (+ j 2) out-len)
                 (setf (aref out (+ j 2)) b2))))
    out))

(defun base32-encode (octets)
  "Encode OCTETS using the Base32 encoding used by CIDv1. Uses RFC 4648 Base32, lowercase, without padding. *it does NOT append the 'b'*"
  (let* ((table "abcdefghijklmnopqrstuvwxyz234567")
         (len (length octets))
         ;; ceil(len * 8 / 5)
         (out-len (ceiling (* len 8) 5))
         (out (make-string out-len))
         (buffer 0)
         (bits 0)
         (pos 0))

    (loop for byte across octets
          do
             (setf buffer (logior (ash buffer 8) byte))
             (incf bits 8)

             (loop while (>= bits 5)
                   do
                      (decf bits 5)
                      (setf (aref out pos)
                            (aref table
                                  (logand (ash buffer (- bits)) 31)))
                      (incf pos)))

    ;; Emit remaining bits, padded with zeroes on the right.
    (when (> bits 0)
      (setf (aref out pos)
            (aref table
                  (logand (ash buffer (- 5 bits)) 31))))

    out))

(defun base32-decode (string)
  "Decode a CIDv1 Base32 string. Accepts RFC 4648 Base32 using either upper- or
lowercase letters. CIDv1 strings normally use lowercase and omit padding. it does NOT strip the initial 'b'!"
  (let* ((len (length string))
         ;; floor(len * 5 / 8), since incomplete trailing bits
         ;; do not form a byte.
         (out-len (floor (* len 5) 8))
         (out (make-array out-len
                          :element-type '(unsigned-byte 8)))
         (buffer 0)
         (bits 0)
         (pos 0))

    (labels ((value (c)
               (let ((c (char-downcase c)))
                 (cond
                   ((and (char>= c #\a)
                         (char<= c #\z))
                    (- (char-code c) (char-code #\a)))

                   ((and (char>= c #\2)
                         (char<= c #\7))
                    (+ 26 (- (char-code c) (char-code #\2))))

                   (t
                    (error "Invalid CID Base32 character: ~C" c))))))

      (loop for c across string
            do
               (setf buffer
                     (logior (ash buffer 5)
                             (value c)))
               (incf bits 5)

               (loop while (>= bits 8)
                     do
                        (decf bits 8)
                        (setf (aref out pos)
                              (logand (ash buffer (- bits)) 255))
                        (incf pos))))

    out))
