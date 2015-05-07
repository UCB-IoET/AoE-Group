"""
Main kitchen controller (in python to allow faster prototyping)

To run:
* Flash a firestorm with pysvcd_bridge.lua
* Run this script while that firestorm is plugged in

Scroll down to "the_recipe" for instructions on how to create a recipe
"""

import time
from pysvcd import SerialSVCD, TimeoutException
from copy import deepcopy
import sys
import operator

def pprint(table):
    for k, v in table.items():
        print repr(k), ": {"
        for kk, vv in v.items():
            print "  ", repr(kk), ": {"
            for kkk, vvv in vv.items():
                print "  ", "  ", repr(kkk), ":", type(vvv)
            print "  ", "}"
        print "}"


class PrepInterface(object):
    """
    Runs the recipe once in prep mode
    (checks that all kitchen devices are online)
    """

    def __init__(self, svcd):
        self.svcd = svcd
        self.attrs = set()

    def set(self, a, b, c, v):
        self.attrs.add((a, b, c))

    def cond(self, a, b, c, op, v):
        self.attrs.add((a, b, c))

    def wait_completed(self):
        pass

    def wait_achieved(self):
        pass

    def connect_everything(self):
        print "\n\n\n\n"
        print "[MASTER] Waiting for the following devices to connect:"
        self.attrs = list(sorted(self.attrs))
        for a, b, c in self.attrs:
            print "    {}:{}:{}".format(a, b, c)
        print "\n\n"

        last_table = {}

        while self.attrs:
            table = self.svcd.get_table()
            do_print= False
            if table.keys() != last_table.keys():
                do_print = True
            else:
                for k,v in table.items():
                    if v.keys() != last_table[k].keys():
                        do_print = True
                        break
                    for kk, vv in v.items():
                        if vv.keys() != last_table[k][kk].keys():
                            do_print = True
                            break
            if do_print:
                # pprint(table)
                last_table = deepcopy(table)



            remove_idx = []
            for i, attr in enumerate(self.attrs):
                a, b, c = attr
                try:
                    table[a][b][c]
                    print "Detected {}:{}:{}".format(a, b, c)
                    remove_idx.append(i)
                except:
                    continue

            for i in sorted(remove_idx)[::-1]:
                del self.attrs[i]


            time.sleep(0.5)
        print "[MASTER] All devices connected"
        print ""
        print ""
        print ""

class RunInterface(object):
    """
    Runs the recipe with actual effects on hardware
    """

    def __init__(self, svcd):
        self.svcd = svcd
        self.table = svcd.get_table()
        self.commands = []
        self.queries = []

    def set(self, a, b, c, v):
        self.commands.append((a, b, c, v))

    def cond(self, a, b, c, op, v):
        self.queries.append((a, b, c, op, v))

    def wait_completed(self):
        while self.commands:
            remove_idx = []
            for i, command in enumerate(self.commands):
                if self.do_command(command):
                    print "ran command {}:{}:{}={}".format(*command)
                    remove_idx.append(i)

            for i in sorted(remove_idx)[::-1]:
                del self.commands[i]

    def wait_achieved(self):
        for query in self.queries:
            self.issue_query(query)

        while self.queries:
            time.sleep(0.2)

    def do_command(self, command):
        a, b, c, val = command
        res = self.table[a][b][c].write(val, timeout_ms=1500)
        return res == SerialSVCD.OK

    def issue_query(self, query):
        a, b, c, op, rhs = query

        def on_val(lhs):
            if op(lhs, rhs):
                try:
                    self.queries.remove(query)
                    print "query met {}:{}:{} OP {}".format(a, b, c, rhs)
                except ValueError: # Already removed
                    print "Query {}:{}:{} OP {} not found".format(a, b, c, rhs)
                    pass

                try:
                    unsubscribe_fn()
                except TimeoutException:
                    pass
            else:
                print "Query {}:{}:{} OP {} not met: {}".format(a, b, c, rhs, lhs)

        unsubscribe_fn = self.table[a][b][c].subscribe(on_val)


def the_recipe(x):
    """
    This is the main recipe

    The names below are (device-id, service-name, attr-name) pairs, where the
    service and attribute names are looked up in manifest.json

    How to issue commands:
        x.set(id, svc, attr, new_value) -- queue setting the attribute to a value
        x.wait_completed() -- execute all queued actions
                              (allows executing actions in parallel)

    How to wait for something to change:
        x.cond(id, svc, attr, operator, lhs) -- queue a condition to wait for
            The condition is achieved if operator(value, lhs) evaluates to True
            Good operators are operator.gt, operator.ge, etc from the python libs

        x.wait_achieved() -- wait for all operations to be true
                             (allows determining in parallel if all conditions
                              are met)


    Other useful stuff: prints, sleeps


    The script that runs this recipe will first wait for all devices used to be
    advertising on svcd, and determine their IP addresses.

    Then it will execute the recipe, with retries in case commands fail
    """

    # This is a dummy recipe
    # (i.e. not tested to actually be the correct sequencing of events)

    # TODO: if there is a button service, use it to start everything

    # Set the hotplate and toaster to preheat mode
    print "Preheating toaster and hotplate..."
    x.set("toaster", "pm.storm.toaster", "pm.storm.attr.toaster.setpoint", 255)
    x.set("toaster", "pm.storm.toaster", "pm.storm.attr.toaster.on", 1)
    x.set("hotplate", "pm.storm.hotplate", "pm.storm.attr.hotplate.on", 1)
    x.wait_completed()

    # TODO: wait for human action to start main cycle (need button service)
    print "Waiting for toaster to warm up"
    x.cond("toaster", "pm.storm.toaster", "pm.storm.attr.toaster.temp",
                operator.gt, 200) # DEBUG: 200 is below room temperature!
    x.wait_achieved()

    # Start the coffee maker
    print "Starting coffee..."
    x.set("coffee", "pm.storm.svc.nespresso", "pm.storm.attr.nespresso.mkcoffee",
          25 # seconds to brew
    )
    x.wait_completed()

    # Once the coffee is partially done, start the toast (raise the temp)
    print "Coffee is brewing..."
    time.sleep(2.0)
    print "Increasing toast temperature"
    x.set("toaster", "pm.storm.toaster", "pm.storm.attr.toaster.setpoint", 300)
    x.wait_completed()


    # Everything should finish at the same time
    print "Waiting for coffee to finish..."
    x.cond("coffee", "pm.storm.svc.nespresso", "pm.storm.attr.nespresso.mkcoffee", operator.le, 0)
    x.wait_achieved()

    print "Turning off toaster and hotplate"
    x.set("toaster", "pm.storm.toaster", "pm.storm.attr.toaster.setpoint", 0)
    x.set("toaster", "pm.storm.toaster", "pm.storm.attr.toaster.on", 0)
    x.set("hotplate", "pm.storm.hotplate", "pm.storm.attr.hotplate.on", 0)
    x.wait_completed()


    print "RECIPE DONE"

def run_recipe(recipe):
    """
    Bootstrap script for running a recipe
    """
    svcd = SerialSVCD()
    time.sleep(5.0) # Wait for the svcd bridge to boot up

    # Wait for all devices in the kitchen to come online
    prep = PrepInterface(svcd)
    recipe(prep)
    prep.connect_everything()

    # Run the recipe
    run = RunInterface(svcd)
    print "\n\n\n\n"
    print "[MASTER] Running recipe"
    recipe(run)

    # Clean up
    if run.queries:
        print "[WARNING]: forgot to run wait_achieved()"
        run.wait_achieved()
    if run.commands:
        print "[WARNING]: forgot to run wait_completed()"
        run.wait_completed()
    print "SHUTTING DOWN"

if __name__ == "__main__":
    run_recipe(the_recipe)
