# cl-atproto-drisl

This library provides functions to serialize and deserialize AT Protocol records to and from their CBOR representation.

## Dependencies

- `flexi-streams` - for handling UTF-8 encoding and binary streams
- `ironclad` - for computing CIDs

## Quick Start

Data is represented using the same objects as https://github.com/Zulu-Inuoe/jzon

```lisp
(use-package :cl-atproto-drisl)

;; Serialize a string
(drisl-serialize-to-sequence "hello")

;; Deserialize bytes back to a Lisp object
(drisl-deserialize-from-sequence bytes)
```

CIDs are represented using the `cid` structure, where the `bytes` field contains the binary encoding of the CID, including the null multibase prefix (0).

Byte strings are represented using `(SIMPLE-ARRAY (UNSIGNED-BYTE 8))`.


## API Reference

### JSON Encoding

The following functions are provided to facilitate encoding and decoding from atproto-flavoured JSON.

#### `ATPROTO-DASL-ENCODE data-item`
Recursively transforms a native Lisp/JZON object into DASL/ATProto format:
- Byte arrays become `{"$bytes": "<base64-encoded>"}`
- CID structs become `{"$link": "<base64-encoded>"}`
- Hash-tables and arrays are recursively processed

#### `ATPROTO-DASL-DECODE data-item`
Recursively transforms a DASL/ATProto object back to native Lisp/JZON format:
- `{"$bytes": "<base64>"}` becomes a byte array
- `{"$link": "<bafy...>"}` becomes a CID struct
- Hash-tables and arrays are recursively processed

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

#### `CIDV1 bytes type`
Computes a CIDv1 from raw bytes. The `type` argument specifies the multicodec:
- `:raw` - Raw data (#x55)
- `:dag-cbor` - DAG-CBOR encoded data (#x71)
- `:other` - Other codec (#x51)

Returns a CID struct with the SHA-256 digest of the input prefixed with the CIDv1 version bytes.

#### `DRISL-CIDV1 data-item &key (type :dag-cbor)`
Convenience function that computes the CIDv1 for a serialized data item. The data item is first serialized using `drisl-serialize-to-sequence`, then its CIDv1 is computed. Defaults to `:dag-cbor` type.

#### `MAKE-CID :bytes bytes`
Creates a CID struct for representing Content Identifiers (required to be 37 bytes including the multibase prefix).

#### `*STRICT-CID-SIZE*`
Special variable that controls whether CIDs must be exactly 37 bytes (including the multibase prefix). Defaults to `T`.

- When `T` (default): CIDs are validated to be exactly 37 bytes; an error is raised otherwise.
- When `NIL`: CIDs of any length are accepted during deserialization.

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
| `NIL` (null) | Null |
| `T` / the symbol `NIL` | Boolean |

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
