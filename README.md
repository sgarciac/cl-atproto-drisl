# cl-atproto-drisl

A minimal Common Lisp implementation of DRISL serialization and deserialization for AT Protocol.

DRISL is a CBOR-based serialization format used by the Bluesky AT Protocol. This library provides functions to serialize and deserialize DRISL-encoded data.

## Installation

This library is available via Quicklisp:

```lisp
(ql:quickload :cl-atproto-drisl)
```

## Dependencies

- `flexi-streams` - for handling UTF-8 encoding and binary streams

## Quick Start

```lisp
(use-package :cl-atproto-drisl)

;; Serialize a string
(drlis-serialize-to-sequence "hello")

;; Deserialize bytes back to a Lisp object
(drlis-deserialize-from-sequence bytes)
```

## API Reference

### Serialization

#### `DRISL-SERIALIZE stream data-item`
Writes a data item to a binary stream following DRISL encoding rules.

#### `DRISL-SERIALIZE-TO-SEQUENCE data-item`
Convenience function that returns the serialized data as an octet vector.

### Deserialization

#### `DRISL-DESERIALIZE stream`
Reads one DRISL-encoded data item from a binary stream and returns it.

#### `DRISL-DESERIALIZE-FROM-SEQUENCE bytes`
Convenience function that deserializes from an octet vector.

### CID Support

#### `MAKE-CID :bytes bytes`
Creates a CID struct for representing Content Identifiers (required to be 37 bytes including the multibase prefix).

### Stream-Based Operations

For more control, you can work directly with streams:

```lisp
;; Writing
(flexi-streams:with-output-to-sequence (stream)
  (drisl-serialize stream "hello"))

;; Reading
(flexi-streams:with-input-from-sequence (stream bytes)
  (drisl-deserialize stream))
```

## Supported Data Types

The library supports the following data types, following the conventions of [jzon](https://github.com/Zulu-Inuoe/jzon):

| Lisp Type | DRISL Type |
|-----------|------------|
| `INTEGER` | Unsigned/Negative Integer |
| `STRING` | Text String |
| `(SIMPLE-ARRAY (UNSIGNED-BYTE 8))` | Byte String |
| `HASH-TABLE` | Map (keys serialized and sorted lexicographically) |
| `SIMPLE-ARRAY` | Array |
| `CID` struct | CID (CBOR tag 42) |
| `NIL` | Null |
| `T` / `NIL` | Boolean |

## Examples

### Encoding a CID

```lisp
(base64-encode
  (flexi-streams:with-output-to-sequence (stream)
    (drisl-serialize stream (make-cid :bytes
                                      #(#x00 #x01 #x71 #x12 #x20 #x9F #xE4 #xCC #xC6 #xDE #x16 #x72 #x4F #x3A #x30 #xC7 #xE8 #xF2 #x54 #xF3 #xC6 #x47 #x19 #x86 #xAC #xB1 #xF8 #xD8 #xCF #x8E #x96 #xCE #x2A #xD7 #xDB #xE7 #xFB)))))
```

### Encoding an Object (Hash Table)

```lisp
(let ((m (make-hash-table :test 'equal)))
  (setf (gethash 5 m) "sergio")
  (setf (gethash 4 m) 30)
  (setf (gethash 3 m) nil)
  (base64-encode
    (flexi-streams:with-output-to-sequence (stream)
      (drisl-serialize stream m))))
```

### Encoding a String

```lisp
(flexi-streams:with-output-to-sequence (stream)
  (drisl-serialize stream "hello"))
```

### Decoding

```lisp
;; From bytes
(drisl-deserialize-from-sequence
  (drisl-serialize-to-sequence "hello"))

;; From stream
(flexi-streams:with-input-from-sequence (stream bytes)
  (drisl-deserialize stream))
```

## License

GPL 3.0

## Author

Sergio Garcia <sergio.garcia@gmail.com>