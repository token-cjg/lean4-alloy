/-
Copyright (c) 2022 Mac Malone. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Mac Malone
-/
import Alloy.C.Shim
import Lean.Server.Requests

open Lean Server JsonRpc RequestM

namespace Alloy.C

def Shim.leanPosToCLsp? (self : Shim) (leanPos : String.Pos) : Option Lsp.Position := do
  self.text.utf8PosToLspPos (← self.leanPosToShim? leanPos)

def Shim.cLspPosToLean? (self : Shim) (cPos : Lsp.Position) : Option String.Pos := do
  self.shimPosToLean? (self.text.lspPosToUtf8Pos cPos)

def Shim.cPosToLeanLsp? (self : Shim) (cPos : String.Pos) (leanText : FileMap) : Option Lsp.Position := do
  leanText.utf8PosToLspPos (← self.shimPosToLean? cPos)

def Shim.cLspPosToLeanLsp? (self : Shim) (cPos : Lsp.Position) (leanText : FileMap) : Option Lsp.Position := do
  leanText.utf8PosToLspPos (← self.cLspPosToLean? cPos)

def Shim.cLspRangeToLeanLsp? (self : Shim) (cRange : Lsp.Range) (leanText : FileMap) : Option Lsp.Range := do
  let startPos ← self.cLspPosToLeanLsp? cRange.start leanText
  let beforeEndPos := self.text.source.prev (self.text.lspPosToUtf8Pos cRange.end)
  let beforeEndPos := self.text.source.next (← self.shimPosToLean? beforeEndPos)
  return ⟨startPos, leanText.utf8PosToLspPos beforeEndPos⟩

/-- Fallback to returning `resp` if `act` errors. Also, log the error message. -/
def withFallbackResponse (resp : RequestTask α) (act : RequestM (RequestTask α)) : RequestM (RequestTask α) :=
  try
    act
  catch e =>
    (←read).hLog.putStrLn s!"C language server request failed: {e.message}"
    return resp

def cRequestError [ToString α] : ResponseError α → RequestError
| {id, code, message, data?} =>
  let data := data?.map (s!"\n{·}") |>.getD ""
  .mk code s!"C language server request {id} failed: {message}{data}"

def mergeResponses (shimTask : Task (Except (ResponseError Json) α))
(leanTask : RequestTask α) (f : α → α → RequestM α) : RequestM (RequestTask α) := do
  bindTask shimTask fun
  | .ok shimResult => do
    bindTask leanTask fun
    | .ok leanResult =>
      return Task.pure <| .ok <| ← f shimResult leanResult
    | .error e => throw e
  | .error e => throw <| cRequestError e
