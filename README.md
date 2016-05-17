# DotOverload

This julia package provides interception methods for expressions like 
```julia

mydict.mykey = 42

```
(see https://github.com/JuliaLang/julia/issues/1974)

It is implemented as a macro which modifies the ast of a given expression (see https://github.com/sneusse/DotOverload.jl/blob/master/src/DotOverload.jl )

## Why?

So I can copy/paste matplotlib examples, as I have no clue how that works and I'm tired of writing brackets.

## Example

*Basics*

```julia

using DotOverload

DotOverload.getMember(t::Dict, k) = t[k]
DotOverload.setMember!(t::Dict, k, v) = t[k] = v

mydict = Dict()
@dotted mydict.mykey = 42
@dotted println(mydict.mykey) # prints 42

```

For bigger chunks of code I would recommend something like this:

```julia

using DotOverload

DotOverload.getMember(t::Dict, k) = t[k]
DotOverload.setMember!(t::Dict, k, v) = t[k] = v

mydict = Dict()

@dotted function doStuffWithDict(stuff)
  mydict.mykey = stuff * 2
  mydict.mykey += mydict.mykey
  return mydict.mykey /= 5
end

println(Int(round(doStuffWithDict(53)))) # prints 42

```

If you want to go cracy all the way (like I prefer to do) you might want to try this:

```julia

# we also need this before defining a module
using DotOverload

@dotted module PlotTest

using DotOverload
using PyCall
using PyPlot

DotOverload.getMember(t::PyObject, k) = t[k]
DotOverload.setMember!(t::PyObject, k, v) = t[k] = v
DotOverload.getMember(t::Figure, k) = t[k]
DotOverload.setMember!(t::Figure, k, v) = t[k] = v

plt.ioff()

fig, ax = plt.subplots()
line, = ax.plot([],[])

plt.ion()

function init()
  fig.show()
  fig.canvas.draw()
  plt.axis([0, 2*π, -2, 2])
end

function doStuff()
  x = linspace(0,2*pi,1000);
  y = sin(3*x + 4*cos(2*x))

  line.set_xdata(x)
  line.set_ydata(y)

  ax.draw_artist(line)
  fig.canvas.update()
end

end #module

# usage:
# using PlotTest
# PlotTest.init()
# PlotTest.doStuff()


```

*Advanced*

What if we want "dispatch on values" ?

```julia

using DotOverload

type Field{TName}
end

DotOverload.getMember(t::Dict, ::Type{Field{:a}}) = "a is always 42"
DotOverload.getMember{T}(t::Dict, f::Type{Field{T}}) = t[T]
DotOverload.getMember(t::Dict, f::Symbol) = DotOverload.getMember(t::Dict, Field{f})
DotOverload.setMember!(t::Dict, f::Symbol, v) = t[f] = v

@dotted begin
  d = Dict()

  d.b = 42
  println(d.a) # note that d.a is not defined yet!
  # prints "a is always 42"
  
  println("b is: $(d.b) - this time")
  # prints "b is: 42 - this time"

  d.a = 43
  d.b = 43
  println(d.a)
  # prints "a is always 42"
  
  println("b is: $(d.b) - this time")
  # prints "b is: 43 - this time"
  
end
```

*More crazyness*

Providing setters, getters and attached methods for your custom types
(not properly implemented!)

```julia
using DotOverload

type Field{TName}
end

macro getter(ex::Expr)

  # we need more sanity checks!
  if (ex.head != :(=))
    error("Nope")
  end

  # T is our type
  T = ex.args[1].args[1]

  # F is our property
  F = ex.args[1].args[2]

  # B is the block of code
  B = ex.args[2]

  # create method for field access
  @eval DotOverload.getMember(t::$T, f::Symbol) = DotOverload.getMember(t::$T, Field{f})

  # create method for the _specific_ field access
  mygetter = @eval DotOverload.getMember(self::$T, ::Type{Field{$F}}) = $B

  # create catch-all method to support access without a property
  @eval DotOverload.getMember{Q}(t::$T, ::Type{Field{Q}}) = Base.getfield(t, Q)

  return mygetter
end

macro setter(ex::Expr)

    # we need more sanity checks!
    if (ex.head != :(=))
      error("Nope")
    end

    # T is our type
    T = ex.args[1].args[1]

    # F is our property
    F = ex.args[1].args[2]

    # B is the block of code
    B = ex.args[2]

    # create method for field access
    @eval DotOverload.setMember!(t::$T, f::Symbol, value) = DotOverload.setMember!(t::$T, Field{f}, value)

    # create method for the _specific_ field access
    mysetter = @eval DotOverload.setMember!(self::$T, ::Type{Field{$F}}, value) = $B

    # create catch-all method to support access without a property
    @eval DotOverload.setMember!{Q}(t::$T, ::Type{Field{Q}}, value) = Base.setfield!(t, Q, value)

    return mysetter
end

macro method(ex::Expr)

  # we need more sanity checks!
  if (ex.head != :(=))
    error("Nope")
  end

  # T is our type
  T = ex.args[1].args[1]

  # F is our property
  # FN is the name of our property
  F = ex.args[1].args[2]
  FN = F.args[1]

  # P is our parameter or tuple of parameters
  # B is the block of code
  P = ex.args[2].args[1]
  B = ex.args[2].args[2]

  if (isa(P, Expr))
    P = P.args
  else
    P = [P]
  end

  # create method for field access
  @eval DotOverload.getMember(t::$T, f::Symbol) = DotOverload.getMember(t::$T, Field{f})

  # create name for dispatchable function
  funname = Symbol("_method_"*string(T)*"_"*string(FN))

  # bind the function to the property
  mymethod = eval( Expr(:function, Expr(:call, funname, P...), B) )
  mymethod = @eval DotOverload.getMember(self::$T, ::Type{Field{$F}}) = $mymethod

  # create catch-all method to support access without a property
  @eval DotOverload.getMember{Q}(t::$T, ::Type{Field{Q}}) = Base.getfield(t, Q)

  return mymethod
end

type MyType
  _val::Int64
end

@getter MyType.Value = Int64(self._val / 2)
@setter MyType.Value = self._val = Int64(value * 2)
@method MyType.multi = function()
  println("NOSTUFF!")
end
@method MyType.multi = function(stuff)
  println("some stuff: $stuff")
end
@method MyType.multi = function(stuff, more)
  println("first stuff: $stuff and more stuff: $more")
end

o = MyType(3)

@dotted begin
  o = MyType(0)
  o.Value = 42
  println("o._val is $(o._val)")
  println("o.Value is $(o.Value)")
  o.multi()
  o.multi(1)
  o.multi(1,2)
end

```


## More examples

See tests.

## Issues

I'm not sure if I caught all the special cases (well, I only caught one so far):
```julia
# left side of '=' expression will be ignored -> something.somefunc(args)
# right side will become -> 'getMember(args, :field) * 2'

something.somefunc(args) = args.field * 2
```

### Differences between v0.4 and v0.5

In Julia v0.4 it is possible to define the ```getMember``` overload *after* the block using the method. In v0.5 this does not seem to work and I'm not sure why (only tested the REPL)

