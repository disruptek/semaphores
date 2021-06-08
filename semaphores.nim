import std/hashes
import std/locks

type
  Semaphore* = object
    id: int
    lock: Lock
    count: int
    cond: Cond

when (NimMajor, NimMinor) == (1, 0):
  proc `=sink`(a: var Semaphore; b: Semaphore) =
    {.warning: "nim-1.0 bug; see https://github.com/nim-lang/Nim/issues/14873".}
    if a.id != 0:
      deinitLock a.lock
      deinitCond a.cond
    a.id = b.id
    a.count = b.count
    initLock a.lock
    initCond a.cond

proc id*(s: Semaphore): int = s.id

proc hash*(s: Semaphore): Hash =
  ## helper for use in containers
  result = s.id.Hash

proc `==`*(a, b: Semaphore): bool =
  ## helper for use in containers
  result = a.id == b.id

proc `<`*(a, b: Semaphore): bool =
  ## helper for use in containers
  result = a.id < b.id

proc init*(s: var Semaphore; id: int) =
  ## initialize a semaphore
  assert id != 0
  initLock s.lock
  initCond s.cond
  s.count = 0
  s.id = id

proc `=destroy`*(s: var Semaphore) =
  ## destroy a semaphore
  deinitCond s.cond
  deinitLock s.lock
  s.count = 0
  s.id = 0

proc signal*(s: var Semaphore) =
  ## blocking signal of `s`
  assert s.id != 0
  withLock s.lock:
    inc s.count
    signal s.cond

proc wait*(s: var Semaphore) =
  ## blocking wait on `s`
  assert s.id != 0
  template consume(s: Semaphore) =
    try:
      if s.count > 0:
        dec s.count
        break
    finally:
      release s.lock

  while true:
    acquire s.lock
    consume s
    # race
    wait(s.cond, s.lock)
    consume s

proc isReady*(s: var Semaphore): bool =
  ## `true` if `s` is ready
  assert s.id != 0
  withLock s.lock:
    result = s.count > 0

template withReady*(s: var Semaphore; body: untyped): untyped =
  ## run the body with a ready `s`
  assert s.id != 0
  withLock s.lock:
    if s.count > 0:
      try:
        body
      finally:
        dec s.count
    else:
      raise Defect.newException: "semaphore " & $s.id & " unready"
