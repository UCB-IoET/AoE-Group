"""
pysvcd demo: Subscribes to anything and everything it finds
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
        print "Waiting for all devices to connect..."
        self.attrs = list(sorted(self.attrs))
        for a, b, c in self.attrs:
            print "    {}:{}:{}".format(a, b, c)

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
                pprint(table)
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
        print "All devices connected"
        print ""
        print ""
        print ""

class RunInterface(object):
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


def run_recipe(svcd, recipe):
    prep = PrepInterface(svcd)
    recipe(prep)
    prep.connect_everything()

    run = RunInterface(svcd)
    recipe(run)

    if run.queries:
        print "[WARNING]: forgot to run wait_achieved()"
        run.wait_achieved()
    if run.commands:
        print "[WARNING]: forgot to run wait_completed()"
        run.wait_completed()
    print "SHUTTING DOWN"

# This is the main recipe!!!
def the_recipe(x):
    print "Setting setpoint on toaster"
    x.set("toaster", "pm.storm.toaster", "pm.storm.attr.toaster.setpoint", 300)
    x.wait_completed()
    print "Turning on toaster"
    x.set("toaster", "pm.storm.toaster", "pm.storm.attr.toaster.on", 1)
    x.wait_completed()
    print "Waiting for toaster to warm up"
    x.cond("toaster", "pm.storm.toaster", "pm.storm.attr.toaster.temp",
                operator.gt, 200)
    x.wait_achieved()
    print "Making coffee..."
    x.set("coffee", "pm.storm.svc.nespresso", "pm.storm.attr.nespresso.mkcoffee", 25)
    x.wait_completed()
    print "Waiting for coffee to finish..."
    x.cond("coffee", "pm.storm.svc.nespresso", "pm.storm.attr.nespresso.mkcoffee", operator.le, 0)
    x.wait_achieved()
    print "Turning off toaster"
    x.set("toaster", "pm.storm.toaster", "pm.storm.attr.toaster.setpoint", 0)
    x.set("toaster", "pm.storm.toaster", "pm.storm.attr.toaster.on", 0)
    x.wait_completed()
    print "RECIPE DONE"

if __name__ == "__main__":
    svcd = SerialSVCD()
    time.sleep(5.0)
    run_recipe(svcd, the_recipe)
