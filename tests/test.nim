import balls

import semaphores

suite "semaphores":

  block:
    ## semaphores
    var sem: Semaphore

    sem.init 42

    check not sem.isReady, "semaphore should init in unready state"
    signal sem
    check sem.isReady, "signalling a semaphore should make it ready"
    block:
      withReady sem:
        break
      fail"sem unready"
