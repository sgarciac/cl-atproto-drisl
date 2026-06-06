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
