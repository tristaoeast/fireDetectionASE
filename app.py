#! /usr/bin/python
from TOSSIM import *
from RadioMsg import *
from sets import Set
from time import sleep
from subprocess import call
from subprocess import Popen
from os import remove
import shutil
import sys
import threading


class Server():

    def runServer(self):
        self.tossim = Tossim([])
        self.radio = self.tossim.radio()
        self.topo = "topo3.txt"
        self.noise = "meyer-heavy-trimmed.txt"
        self.debug = open("debug.txt", "w")
        self.log = open("log.txt", "w")
        #self.log.close()
        self.sensors = Set()
        self.routers = Set()
        self.tossim.addChannel("debug", self.debug)
        self.tossim.addChannel("log", self.log)
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
                self.debug.write(s[1] + " " + s[0] + " " + s[2] + "\n")
                radio.add(int(s[1]), int(s[0]), float(s[2]))
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
                (4 + tossim.ticksPerSecond() / 10) * counter + 12332)
            counter += 1

        for nid in set(sensors):
            self.debug.write("Booting sensor node " + str(nid) + "\n")
            tossim.getNode(nid).bootAtTime(
                (4 + tossim.ticksPerSecond() / 10) * counter + 12332)
            counter += 1

    def printMenu(self):
        print "[1] Simulate fire"
        print "[2] Simulate Routing Node malfuntion"
        print "[3] Simulate malfuntion of module in Sensor Node"
        print "[4] Check log file content"
        print ""
        print "[5] Put out fire"
        print "[6] Check debug file content"
        print ""
        print "[0] Exit"

    def readInput(self):
        while(1):
            self.printMenu()
            iTemp = raw_input("Select an option [0-6]: ")
            print ""
            try:
                i = int(iTemp)
            except ValueError:
                print "ERROR: Invalid input type."
                print ""
                continue
            if(i < 0 or i > 6):
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
            3: self.simulateSensorNodeModuleMalfunction,
            4: self.checkLogFile,
            5: self.putOutFire,
            6: self.checkDebugFile
        }
        options[i]()

    def simulateFire(self):
        t = self.tossim

        while(1):
            self.printMenu()
            iTemp = raw_input("Select a Sensor Node to trigger the fire [look at topo]: ")
            print ""
            try:
                i = int(iTemp)
            except ValueError:
                print "ERROR: Invalid input type."
                print ""
                continue
            if not(i in self.sensors):
                print "ERROR: Invalid sensor node selected"
                print ""
                continue
            break

        #inject packet to simulate fire
        msg = RadioMsg()
        msg.set_msg_type(3)
        msg.set_dest(i)
        pkt = t.newPacket()
        pkt.setData(msg.data)
        pkt.setType(msg.get_amType())
        pkt.setDestination(i)
        pkt.setSource(0)
        pkt.deliverNow(i)


    def simulateRoutingNodeMalfunction(self):
        t = self.tossim

        while(1):
            iTemp = raw_input("Select a Routing Node simulate malfunction [look at topo]: ")
            print ""
            try:
                i = int(iTemp)
            except ValueError:
                print "ERROR: Invalid input type."
                print ""
                continue
            if not(i in self.routers or 0 == i):
                print "ERROR: Invalid sensor node selected"
                print ""
                continue
            break

        if not(0 == i):
            m = t.getNode(i)
            m.turnOff()

    def simulateSensorNodeModuleMalfunction(self):
        print "Simulating malfuntion of module in Sensor Node"
        t = self.tossim

        while(1):
            iTemp = raw_input("Select a Sensor Nodeto simulate module malfunction [look at topo]: ")
            print ""
            try:
                i = int(iTemp)
            except ValueError:
                print "ERROR: Invalid input type."
                print ""
                continue
            if not(i in self.sensors):
                print "ERROR: Invalid sensor node selected"
                print ""
                continue
            while(1):
                print "[1] Temperature Sensor"
                print "[2] Humidity Sensor"
                print "[3] Smoke Detector"
                print "[4] GPS"
                print ""
                print "[0] Cancel"
                iiTemp = raw_input("Select an option [0-4]: ")
                print ""
                try:
                    ii = int(iiTemp)
                except ValueError:
                    print "ERROR: Invalid input type."
                    print ""
                    continue
                if(ii < 0 or ii > 4):
                    print "ERROR: Invalid option selected"
                    print ""
                    continue
                break
            break

        if not (0 == ii):
            #inject packet to simulate fire
            msg = RadioMsg()
            if(1 == ii):
                msg.set_msg_type(9)
            elif(2 == ii):
                msg.set_msg_type(8)
            elif(3 == ii):
                msg.set_msg_type(6)
            elif(4 == ii):
                msg.set_msg_type(7)
            msg.set_dest(i)
            pkt = t.newPacket()
            pkt.setData(msg.data)
            pkt.setType(msg.get_amType())
            pkt.setDestination(i)
            pkt.setSource(0)
            pkt.deliverNow(i)

    def checkLogFile(self):
        shutil.copy2("log.txt", "logTemp.txt")
        self.sp = Popen('gedit logTemp.txt', shell=True)
        #d = open("log.txt", "r")
        #for line in d:
        #    print line
        #d.close()

    def checkDebugFile(self):
        shutil.copy2("debug.txt", "debugTemp.txt")
        self.sp = Popen('gedit debugTemp.txt', shell=True)
        #call(["gedit", "debugTemp.txt"])
        #d = open("debugTemp.txt")
        #for line in d:
        #    print line
        #d.close()

    def putOutFire(self):
        t = self.tossim

        while(1):
            self.printMenu()
            iTemp = raw_input("Select a Sensor Node to put out the fire: ")
            print ""
            try:
                i = int(iTemp)
            except ValueError:
                print "ERROR: Invalid input type."
                print ""
                continue
            if not(i in self.sensors):
                print "ERROR: Invalid sensor node selected"
                print ""
                continue
            break

        #inject packet to simulate fire
        msg = RadioMsg()
        msg.set_msg_type(4)
        pkt = t.newPacket()
        pkt.setData(msg.data)
        pkt.setType(msg.get_amType())
        pkt.setDestination(101)
        pkt.setSource(0)
        pkt.deliverNow(101)


class ThreadedEvents(threading.Thread):

    def __init__(self, tossim):
        threading.Thread.__init__(self)
        self.running = True
        self.tossim = tossim

    def run(self):
        while(self.running):
            for i in range(500):
                self.tossim.runNextEvent()
            sleep(0.5)
            

if __name__ == "__main__":
    server = Server()
    server.runServer()
