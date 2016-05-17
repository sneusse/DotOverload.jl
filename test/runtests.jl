using DotOverload
using Base.Test

type TT
  F::Int64
end

# basic assertions

@test macroexpand( :( @dotted a.f )) == :(getMember(a,:f))
@test macroexpand( :( @dotted a.b.c = b.g += e.f )) == :(setMember!(getMember(a,:b),:c,setMember!(b,:g,getMember(b,:g) + getMember(e,:f))))
@test macroexpand( :( @dotted (a).b )) == :(getMember(a,:b))

# there are some parsing changes between 0.4 - 0.5?
if (VERSION >= v"0.5.0-dev")
  @test macroexpand( :( @dotted a.(b) )) == :(getMember(a,(b,)))
  @test macroexpand( :( @dotted anything.(10) )) == :(getMember(anything,(10,)))
else
  @test macroexpand( :( @dotted a.(b) )) == :(getMember(a,b))
  @test macroexpand( :( @dotted anything.(10) )) == :(getMember(anything,10))
end


@test macroexpand( :( @dotted "weird".stuff )) == :(getMember("weird",:stuff))
@test macroexpand( :( @dotted "weird"."stuff" )) == :(getMember("weird","stuff"))

# basic usage

DotOverload.getMember(t, m::Symbol) = begin
  println("intercepted!")
  return getfield(t, m)
end

@dotted function dontDoThatAtHome()
  a = TT(42)
  return a.F
end

@test 42 == dontDoThatAtHome() #result: 42, prints: "intercepted"

# code equality

DotOverload.getMember(t, m::Symbol) = Base.getfield(t, m)
DotOverload.setMember!(t, m::Symbol, v) = Base.setfield!(t,m,v)

function test1()
  a = TT(3)
  return a.F
end

@dotted function test2()
  a = TT(3)
  return a.F
end

@test @code_lowered(test1()) != @code_lowered(test2())
@test @code_llvm(test1()) == @code_llvm(test2())

# lua table like Dict

@dotted function test3()
  getMember(t::Dict, k) = t[k]
  setMember!(t::Dict, k::Symbol, v) = t[k] = v

  d = Dict()
  d.key1 = 1
  d.key2 = 2

  return d.key1 + d.key2
end

@test test3() == 3


# more examples

@dotted function test4()
  function getMember(t, k)
    return getfield(t, k)
  end
  function setMember!(t, m, v)
    return Base.setfield!(t,m,v)
  end
  function getMember(t::Dict, k)
    v = nothing
    try
      v = t[k]
      try
        v = round(v*2)
      catch
      end
    catch
      t[k] = Dict()
      v = t[k]
    end
    return v
  end
  function setMember!(t::Dict, k::Symbol, v)
    t[k] = v*2
  end

  a = 10.5
  b = Dict()

  b.this.is.kinda.kool = a

  return b.this.is.kinda.kool
end

@test test4() == 42

# a module!

@dotted module m

using DotOverload
DotOverload.getMember(t::Dict, k::Symbol) = t[k]
DotOverload.setMember!(t::Dict, k::Symbol, v) = t[k] = v

a = Dict()
a[:stuff] = 25
a.stuff *= 2

foo() = a.stuff * 2

end

@test m.foo() == 100

# REPL example (0.4):
#
# julia> using DotOverload
#
# julia> v = @dotted function() a.b = 32; a.b end
# (anonymous function)
#
# julia> a = Dict()
# Dict{Any,Any} with 0 entries
#
# julia> v()
# ERROR: type Dict has no field b
#  in setMember! at C:\SN\prj\julia\DotOverload\src\DotOverload.jl:128
#  in anonymous at none:1
#
# julia> DotOverload.getMember(t::Dict, k) = t[k]
# getMember (generic function with 2 methods)
#
# julia> DotOverload.setMember!(t::Dict, k, v) = t[k] = v
# setMember! (generic function with 2 methods)
#
# julia> v()
# 32
#
# julia>
