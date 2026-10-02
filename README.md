# FAKEIT.SYS

> Fakes the amount of physical RAM seen by DOS (and Windows)

## Purpose

`FAKEIT.SYS` lets an old DOS/Windows environment appear as though the machine has
**less** physical RAM than is actually installed.

It is intended for old memory managers and Windows 3.x systems which can be
unreliable on DOS machines with unusually large amounts of RAM:
- Windows 3.0 > 16MB
- Windows 3.1 > 256MB

## Requirements

* 80386 or later processor.
* DOS 3.x or later 
* `FAKEIT.SYS` must load BEFORE `HIMEM.SYS`, `HIMEMX`, `QEMM386`, `386MAX`, `EMM386`, `JEMM386` or any another
  extended-memory manager you're banging

## Syntax

In `CONFIG.SYS`:

```
  DEVICE=C:\UTILS\FAKEIT.SYS /MAX=16384
```

`/MAX` is TOTAL visible RAM in kilobytes, not only memory above 1 MB.
Examples:
```
  /MAX=8192     8 MB total
  /MAX=16384   16 MB total
  /MAX=32768   32 MB total
  /MAX=65536   64 MB total
```
If /MAX is omitted the default is 16384 KB. Accepted range is 1024 through 4194303 KB.



### Typical HIMEM/EMM386 setup

`CONFIG.SYS`:

```
  DEVICE=C:\UTILS\FAKEIT.SYS /MAX=8192
  DEVICE=C:\DOS\HIMEM.SYS
  DEVICE=C:\DOS\EMM386.EXE
```

