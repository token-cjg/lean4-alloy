import Alloy.C

open Alloy.C

namespace Foo

extern c def my_add (x y : UInt32) : UInt32 := {
  return x + y;
}
