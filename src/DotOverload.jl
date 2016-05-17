module DotOverload


export getMember
export setMember!
export @dotted

macro dotted(ex::Expr)

  function getExpression(ex, mem)
    if (mem != nothing)
      return Expr(:call, :getMember, ex, mem)
    end
    return ex
  end

  function treewalk(stuff)
    # return whatever is not an expression
    if (!isa(stuff, Expr))
      return stuff, nothing
    end

    # care only about binary expressions ( dot, assignment )
    if (length(stuff.args) == 2)
      h = stuff.head

      left, leftmember = nothing, nothing

      # special case (should be ignored):
      # module.func(p) = 2*p
      if (isa(stuff.args[1], Expr)
        && isa(stuff.args[2], Expr)
        && h == :(=)
        && stuff.args[1].head == :call
        && stuff.args[2].head == :block)

        # ignore for now
        left, leftmember = stuff.args[1], nothing
      else
        left, leftmember = treewalk(stuff.args[1])
      end

      right, rightmember = treewalk(stuff.args[2])

      getleft = getExpression(left, leftmember)
      right = getExpression(right, rightmember)

      # that's what we're looking for
      if ( h == :(.) )
        return getleft, right
      end

      # look for assignment
      if (leftmember != nothing)
        setleft = nothing

        if ( h == :(=) )
          setleft = right
        elseif ( h == :(+=) )
          setleft = :($getleft + $right)
        elseif ( h == :(-=) )
          setleft = :($getleft - $right)
        elseif ( h == :(*=) )
          setleft = :($getleft * $right)
        elseif ( h == :(/=) )
          setleft = :($getleft / $right)
        elseif ( h == :(\=) )
          setleft = :($getleft \ $right)
        elseif ( h == :(÷=) )
          setleft = :($getleft ÷ $right)
        elseif ( h == :(%=) )
          setleft = :($getleft % $right)
        elseif ( h == :(^=) )
          setleft = :($getleft ^ $right)
        elseif ( h == :(&=) )
          setleft = :($getleft & $right)
        elseif ( h == :(|=) )
          setleft = :($getleft | $right)
        elseif ( h == :($=) )
          setleft = :($getleft $ $right)
        elseif ( h == :(>>>=) )
          setleft = :($getleft >>> $right)
        elseif ( h == :(>>=) )
          setleft = :($getleft >> $right)
        elseif ( h == :(<<=) )
          setleft = :($getleft << $right)
        end

        # If it is an assignment expression, return to parent expression
        # and discard the assignment. Instead generate a call expression.
        if (setleft != nothing)
          return Expr(:call, :setMember!, left, leftmember, setleft), nothing
        end
      end

      # if we did not have an assignment or a dot expression
      # we will end here.
      stuff.args[1] = getleft
      stuff.args[2] = right

      return stuff, nothing
    end

    # non binary expressions -> fix all args
    for i = 1:length(stuff.args)
      ex, mem = treewalk(stuff.args[i])
      stuff.args[i] = getExpression(ex, mem)
    end

    return stuff, nothing
  end

  ex, mem = treewalk(ex)
  ex = getExpression(ex, mem)

  if (ex.head == :module)
    return Expr(:escape, Expr(:toplevel, ex))
  end

  return Expr(:escape, ex)
end

function getMember(t, m)
  return Base.getfield(t, m)
end

function setMember!(t, m, v)
  return Base.setfield!(t,m,v)
end


end # module
