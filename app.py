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
        self.noise = "meyer-heavy-trimmed.txt"
        self.debug = open("debug.txt", "w")
        self.log = open("log.txt", "w")
        self.log.close()
        self.sensors = Set()
        self.routers = Set()
        self.tossim.addChannel("debug", self.debug)
        self.loadTopology(self.topo, self.radio, self.routers, self.sensors)
        self.loadNoiseModel(
            self.noise, self.tossim, self.routers, self.sensors)
        self.bootNodes(self.tossim, self.routers, self.sensors)

        self.thread = ThreadedEvents(self.tossim)
        self.thread.start()

        while(1):
            #self.printMenu()
            self.readInput()

    def loadTopology(self, topo, radio, routers, sensors):
        f = open(topo, "r")
        for line in f:
            s = line.split()
            if s:
                # print " ", s[0], " ", s[1], " ", s[2]
                self.debug.write(s[0] + " " + s[1] + " " + s[2] + "\n")
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

        # print "Creating noise model for server"
        self.debug.write("Creating noise model for server" + "\n")
        tossim.getNode(0).createNoiseModel()
        for nid in set(routers):
            # print "Creating noise model for router", nid
            self.debug.write(
                "Creating noise model for router " + str(nid) + "\n")
            tossim.getNode(nid).createNoiseModel()
        for nid in set(sensors):
            # print "Creating noise model for sensor", nid
            self.debug.write(
                "Creating noise model for sensor " + str(nid) + "\n")
            tossim.getNode(nid).createNoiseModel()

    def bootNodes(self, tossim, routers, sensors):

        self.debug.write("Booting server" + "\n")
        tossim.getNode(0).bootAtTime(12234)

        counter = 1
        for nid in set(routers):
            self.debug.write("Booting routing node " + str(nid) + "\n")
            tossim.getNode(nid).bootAtTime(
                (4 + tossim.ticksPerSecond() / 10) * counter + 1232)
            counter += 1

        for nid in set(sensors):
            self.debug.write("Booting sensor node " + str(nid) + "\n")
            tossim.getNode(nid).bootAtTime(
                (4 + tossim.ticksPerSecond() / 10) * counter + 1232)
            counter += 1

    def printMenu(self):
        print "[1] Simulate fire"
        print "[2] Simulate Routing Node malfuntion"
        print "[3] Simulate malfuntion of module in Sensor Node"
        print "[4] Check log file content"
        print ""
        print "[5] Check debug file content"
        print ""
        print "[0] Exit"

    def readInput(self):
        while(1):
            self.printMenu()
            iTemp = raw_input("Select an option [0-5]: ")
            print ""
            try:
                i = int(iTemp)
            except ValueError:
                print "ERROR: Invalid input type."
                print ""
                continue
            if(i < 0 or i > 5):
                print "ERROR: Invalid option selected"
                print ""
                continue
            break

        if(i == 0):
            self.thread.running = False
            self.thread.join()
            self.debug.close()
            exit()

        options = {
            1: self.simulateFire,
            2: self.simulateRoutingNodeMalfunction,
            3: self.simulateSensorNodeComponentMalfunction,
            4: self.checkLogFile,
            5: self.checkDebugFile
        }
        options[i]()

    def simulateFire(self):
        print "Simulating fire"

    def simulateRoutingNodeMalfunction(self):
        print "Simulating Routing Node malfuntion"

    def simulateSensorNodeComponentMalfunction(self):
        print "Simulating malfuntion of module in Sensor Node"

    def checkLogFile(self):
        d = open("log.txt", "r")
        # d = self.debug
        for line in d:
            print line
        d.close()

    def checkDebugFile(self):
        d = open("debug.txt", "r")
        # d = self.debug
        for line in d:
            print line
        d.close()


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
