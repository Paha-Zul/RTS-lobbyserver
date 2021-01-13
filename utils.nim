import tables, options

proc first*[T](s: openArray[T]; pred: proc (x: T): bool {.closure.}): Option[T] {.inline.} =
    for item in s:
        if pred(item):
            return some(item)

    return none(T)
        
proc firstIndex*[T](s: openArray[T]; pred: proc (x: T): bool {.closure.}): int {.inline.} =
    var counter = 0
    for item in s:
        if pred(item):
            return counter
        counter += 1

    return -1