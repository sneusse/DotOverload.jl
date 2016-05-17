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
