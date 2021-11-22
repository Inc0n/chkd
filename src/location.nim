
import strutils

type
  Location* = ref object
    line*: int
    col*: int
    path*: string

func makeLocation*(line: int = 0, col: int = 0, path: string = ""): Location =
  Location(line: line, col: col, path: path)

func copy*(self: Location): Location =
  makeLocation(self.line, self.col, self.path)
  # return
  #   "(line: " & $this.line & ", col " & $this.col & ", path: " & $this.path & ")"
  # let lineColStr =
  # let res = "at " & lineColStr & " in " & "'" & $this.path & "'\n"
  # # res &= $this.line & "\n" & " ".repeat(this.colNum - 1) & "^"
  # return res

func `$`*(this: Location): string =
  # return "\"$1\"($2, $3)" % [ $this.path, $this.line, $this.col]
  return $this.col