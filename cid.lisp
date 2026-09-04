(in-package #:cl-atproto-drisl)
;; See https://specs.ipfs.tech/cid/
;;


(defconstant +cid-size+ 37)
(defparameter *cid-prefix* #(#xD8 #x2A))
(defparameter *strict-cid-size* t)


;; (make-cid :bytes
;;            #(#x00 #x01 #x71 #x12 #x20 #x9F #xE4 #xCC #xC6 #xDE #x16 #x72 #x4F #x3A #x30
;;            #xC7 #xE8 #xF2 #x54 #xF3 #xC6 #x47 #x19 #x86 #xAC #xB1 #xF8 #xD8 #xCF #x8E
;;            #x96 #xCE #x2A #xD7 #xDB #xE7 #xFB)
;; )

(defstruct cid
  ;; a simple array of unsigned bytes representing the CID. It *must*
  ;; already contain the multibase prefix (a null byte)
  bytes)


;; computes the cid object (using cidv1) for an array of bytes
;; `type` must be :raw, :dag-cbor or :other
(defun cidv1 (bytes type)
  (let* ((typebyte (case type (:raw #x55) (:dag-cbor #x71) (:other #x51)))
         (digest (ironclad:digest-sequence :sha256 bytes)))
    (make-cid :bytes (concatenate '(vector (unsigned-byte 8))
                                  (list #x0 #x1 typebyte #x12 #x20)
                                  digest))))
