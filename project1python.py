import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import sys, time, math, serial, re

xsize=20
fahrenheit=["Part 1. It was a pleasure to burn.","It was a special pleasure to see things eaten","to see things blackened and changed.","With the brass nozzles in his fists,","with this great python spitting it's venomous kerosene upon the world,","the blood pounded in his head,","and his hands were the hands of some amazing conductor"," playing all the symphonies of blazing and burning"," to bring down the tatters and charcoal ruins of history.","With his symbolic helmet","numbered 451 on his stolid head","and his eyes all orange flame","with the thought of what came next","he flicked the igniter","and the house jumped up","in a gorging fire that burned the evening sky","red and black.","He strode in a swarm of fireflies.","He wanted above all,","like the old joke,","to shove a marshmallow on a stick in the furance","while the flapping pigeon-winged books died on the porch","and lawn of the house."]


ser = serial.Serial(
    #Remember to change this port to match
    port='COM4',
    baudrate=115200,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_TWO,
    bytesize=serial.EIGHTBITS
)
ser.isOpen()

def data_gen():
	line = 0
	t = data_gen.t
	while True:
		t+=1
		strin=ser.readline()
		temp=strin.decode('ASCII')
		val = re.findall("\d+\.\d+", temp)
		if val > 150:
			if line < 23:
				print(fahrenheit[line])
				line+=1
		yield t, val

def run(data):
    # update the data
    t,y = data
    if t>-1:
        xdata.append(t)
        ydata.append(y)
        if t>xsize: # Scroll to the left.
            ax.set_xlim(t-xsize, t)
        line.set_data(xdata, ydata)

    return line,

def on_close_figure(event):
    sys.exit(0)

data_gen.t = -1
fig = plt.figure()
fig.canvas.mpl_connect('close_event', on_close_figure)
ax = fig.add_subplot(111)
line, = ax.plot([], [], lw=2)
ax.set_ylim(0, 40)
ax.set_xlim(0, xsize)
ax.grid()
xdata, ydata = [], []

# Important: Although blit=True makes graphing faster, we need blit=False to prevent
# spurious lines to appear when resizing the stripchart.
ani = animation.FuncAnimation(fig, run, data_gen, blit=False, interval=100, repeat=False)
plt.show()