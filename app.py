#! /usr/bin/python
from TOSSIM import *
from sets import Set
import sys

t = Tossim([])
r = t.radio()
f = open("topo.txt", "r")

sensors = Set()
routers = Set()

for line in f:
  s = line.split()
  if s:
    print " ", s[0], " ", s[1], " ", s[2];
    r.add(int(s[0]), int(s[1]), float(s[2]))
    # Verify node type and add to respective set
    n1 = s[0];
    if 0 != int(s[0]):
      if int(s[0]) < 100:
        routers.add(int(s[0]))
      else:
        sensors.add(int(s[0]))
    # Verify node type and add to respective set
    if 0 != int(s[1]):
      if int(s[1]) < 100:
        routers.add(int(s[1]))
      else:
        sensors.add(int(s[1]))

print "routers ",routers;
print "sensors", sensors;




t.addChannel("BlinkToRadio", sys.stdout)

noise = open("meyer-heavy.txt", "r")
for line in noise:
  str1 = line.strip()
  if str1:
    val = int(str1)
    t.getNode(0).addNoiseTraceReading(val)
    for nid in set(routers):
      t.getNode(nid).addNoiseTraceReading(val)
    for nid in set(sensors):
      t.getNode(nid).addNoiseTraceReading(val)

print "Creating noise model for server"
t.getNode(0).createNoiseModel()

for nid in set(routers):
  print "Creating noise model for router", nid;
  t.getNode(nid).createNoiseModel()

for nid in set(sensors):
  print "Creating noise model for sensor", nid;
  t.getNode(nid).createNoiseModel()


print "Booting server"
t.getNode(0).bootAtTime(12234)

counter = 1
for nid in set(routers):
  print "Booting routing node ",nid;
  t.getNode(nid).bootAtTime((4 + t.ticksPerSecond() / 10) * counter + 122342)
  counter += 1

for nid in set(sensors):
  print "Booting sensor node ", nid;
  t.getNode(nid).bootAtTime((4 + t.ticksPerSecond() / 10) * counter + 122342)
  counter += 1

# for nid in range(1,2):
#   print "Booting routing node ",nid;
#   t.getNode(nid).bootAtTime((4 + t.ticksPerSecond() / 10) * nid + 122342)

# for nid in range(100,101):
#   print "Booting sensor node ",nid;
#   t.getNode(nid).bootAtTime((4 + t.ticksPerSecond() / 10) * nid + 122342)

for i in range(200):
  t.runNextEvent()
