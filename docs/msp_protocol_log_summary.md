# MSP Protocol Logger – Field & Value Summary (S.Port)

This document explains **what each value in `msp_proto.log` means**, with a focus on **FrSky S.Port MSP traffic** and why corruption is observed (notably for CMD=217).

---

## 1. Log Line Structure

A typical log line:

```
210.720 RX sport CMD=217 SID=0x1B FID=0x32 SEQ=6 DATA=D6 00 D9 00 01 00
```

### Fields

| Field | Description |
|------|------------|
| `210.720` | Timestamp (seconds since script start / boot) |
| `RX` / `TX` | Direction (received from FC / transmitted by radio) |
| `sport` | Transport protocol (FrSky S.Port) |
| `CMD=217` | MSP command ID (decimal). `217 = 0xD9` |
| `SID=0x1B` | S.Port **sensor / physical ID** (remote / FBL side) |
| `FID=0x32` | S.Port **frame / prim ID** used for MSP replies |
| `SEQ=6` | MSP **sequence number** (4-bit, wraps 0–15) |
| `DATA=...` | Raw 6-byte S.Port payload |

All MSP semantics are encoded inside `DATA`.

---

## 2. S.Port MSP Frame Payload Layout

Each S.Port MSP frame carries **6 bytes**:

```
[0] STATUS
[1] FLAGS        (MSPv2 only)
[2] CMD_L
[3] CMD_H
[4] LEN_L        (MSPv2 start frame only)
[5] LEN_H        (MSPv2 start frame only)
```

For **continuation frames**, bytes `[2..5]` are reused as **payload data bytes**.

---

## 3. STATUS Byte (Byte 0)

### Bit layout

| Bits | Meaning |
|-----|--------|
| bit 7 (0x80) | **START** frame (first frame of a reply) |
| bit 6 (0x40) | **ERROR** flag |
| bits 5–4 | MSP protocol version (`01 = v1`, `10 = v2`) |
| bits 3–0 | Sequence number (0–15) |

### Example

`D6` (binary `1101 0110`):

| Component | Value |
|---------|------|
| START | Yes |
| ERROR | Yes |
| Version | `10` → **MSPv2** |
| Sequence | `6` |

---

## 4. FLAGS Byte (Byte 1)

- Used only in **MSPv2**
- Usually `00`
- Reserved / future use

---

## 5. CMD Bytes (Bytes 2–3)

Little-endian MSP command ID.

Example:
```
D9 00 → 0x00D9 → CMD 217
```

---

## 6. LEN Bytes (Bytes 4–5)

Only valid for **START frames**.

Example:
```
01 00 → payload length = 1 byte
```

---

## 7. Continuation Frames

Example:
```
47 02 20 B0 A2 01
```

- Byte 0: STATUS (continuation)
- Bytes 1–5: payload bytes

---

## 8. RXDONE Entries

Example:

```
RXDONE sport CMD=217 ERR=true SIZE=1
02
```

| Field | Meaning |
|------|--------|
| `RXDONE` | Reply assembly complete |
| `ERR=true` | ERROR flag was set |
| `SIZE=1` | Declared payload size |
| `02` | Final payload |

---

## 9. Why CMD=217 Corrupts on S.Port

- MSP replies and normal telemetry **share the same S.Port channel**
- Frames can **interleave**
- Non-MSP telemetry frames may be misinterpreted as MSP continuation frames
- This results in corrupted payloads

This does **not** occur on CRSF / ELRS due to stricter framing.

---

## 10. One-Sentence Summary

Each log entry represents a 6-byte S.Port frame where the STATUS byte encodes start/version/sequence, CMD bytes identify the MSP command, and LEN or payload bytes follow — CMD=217 corruption occurs because non-MSP telemetry frames are mistakenly consumed as MSP continuation frames.
