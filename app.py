#! /usr/bin/python
from TOSSIM import *
from sets import Set
from time import sleep
import sys
import threading


class Server():

    def runServer(self):
        self.tossim = Tossim([])
        self.radio = self.tossim.radio()
        self.topo = "topo.txt"
        self.noise = "meyer-heavy.txt"
        self.sensors = Set()
        self.routers = Set()
        self.tossim.addChannel("BlinkToRadio", sys.stdout)
        self.loadTopology(self.topo, self.radio, self.routers, self.sensors)
        self.loadNoiseModel(
            self.noise, self.tossim, self.routers, self.sensors)
        self.bootNodes(self.tossim, self.routers, self.sensors)

        self.thread = ThreadedEvents(self.tossim)
        self.thread.start()

        while(1):
            self.printMenu()
            self.readInput()

    def loadTopology(self, topo, radio, routers, sensors):
        f = open(topo, "r")
        for line in f:
            s = line.split()
            if s:
                print " ", s[0], " ", s[1], " ", s[2]
                radio.add(int(s[0]), int(s[1]), float(s[2]))
                # Verify node type and add to respective set
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

    def loadNoiseModel(self, noise, tossim, routers, sensors):

        n = open(noise, "r")
        for line in n:
            str1 = line.strip()
            if str1:
                val = int(str1)
                tossim.getNode(0).addNoiseTraceReading(val)
                for nid in set(routers):
                    tossim.getNode(nid).addNoiseTraceReading(val)
                for nid in set(sensors):
                    tossim.getNode(nid).addNoiseTraceReading(val)

        print "Creating noise model for server"
        tossim.getNode(0).createNoiseModel()
        for nid in set(routers):
            print "Creating noise model for router", nid
            tossim.getNode(nid).createNoiseModel()
        for nid in set(sensors):
            print "Creating noise model for sensor", nid
            tossim.getNode(nid).createNoiseModel()

    def bootNodes(self, tossim, routers, sensors):

        print "Booting server"
        tossim.getNode(0).bootAtTime(12234)

        counter = 1
        for nid in set(routers):
            print "Booting routing node ", nid
            tossim.getNode(nid).bootAtTime(
                (4 + tossim.ticksPerSecond() / 10) * counter + 122342)
            counter += 1

        for nid in set(sensors):
            print "Booting sensor node ", nid
            tossim.getNode(nid).bootAtTime(
                (4 + tossim.ticksPerSecond() / 10) * counter + 122342)
            counter += 1

    def printMenu(self):
        print "[1] "
        print "[2] "
        print "[3] "
        print "[4] "
        print ""
        print "[0] Exit"

    # for nid in range(1,2):
    #   print "Booting routing node ",nid;
    #   t.getNode(nid).bootAtTime((4 + t.ticksPerSecond() / 10) * nid + 122342)

    # for nid in range(100,101):
    #   print "Booting sensor node ",nid;
    #   t.getNode(nid).bootAtTime((4 + t.ticksPerSecond() / 10) * nid + 122342)


class ThreadedEvents(threading.Thread):

    def __init__(self, tossim):
        threading.Thread.__init__(self)
        self.running = True
        self.tossim = tossim

    def run(self):
        while(self.running):
            for i in range(200):
                self.tossim.runNextEvent()
            sleep(0.5)

if __name__ == "__main__":
    server = Server()
    server.runServer()
