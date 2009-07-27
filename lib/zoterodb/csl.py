#! /usr/bin/env python

import sys
reload(sys)
sys.setdefaultencoding("utf-8") # Needs Python Unicode build!
import os
try:
  import json
except:
  import simplejson as json
import traceback

mypath = os.path.split(sys.argv[0])[0]
if mypath == '': mypath = './'
os.chdir(mypath)

def log(*args):
  for i in args: print i

#
# Initialization
#

def load_spidermonkey():
  log("Loading spidermonkey ...")
  from spidermonkey import Runtime
  rt = Runtime()
  return rt.new_context()

def load_citeproc():
  log("Loading citeproj-js ...")
  cslcode = open("./src-js/citeproc-js.js").read()
  cx.eval_script(cslcode)

def path(*elements):
  return os.path.join( os.getcwd(), *elements )

def load_locals():
  log("Loading locales ...")
  cx.eval_script("locales = new Object();")
  for filename in os.listdir("locale"):
    p = path(".","locale", filename)
    if not os.path.stat.S_ISREG( os.stat(p).st_mode ):
        continue
    if p.endswith("~") or p.endswith(".orig"):
        continue
    lang = filename.split("-")[1]
    fh = open("./locale/%s" % (filename,))
    fh.readline()
    xml = fh.read()
    xml = json.dumps(xml)
    cx.eval_script("locales[\"%s\"] = %s" % (lang,xml,))

def load_sys():
  log("Loading sys ...")
  system = open("./src-js/sys.js").read()
  cx.eval_script(system)

#
# CSL interaction
#

def initialize():
  load_citeproc()
  load_locals()
  load_sys()

def loadData(input):
  log("ok loadData")
  for i in range(len(input)):
    for k in input[i].iterkeys():
      if type(input[i][k]) == int:
        input[i][k] = "%d" % input[i][k]
    input[i]['id'] = "ITEM-%s" % input[i]['id']
  data = json.dumps(input)
  cx.eval_script("sys.loadData(%s)" %(data,))
  return "Loaded data OK"

def makeStyle(csl):
  log("ok makeStyle")
  csl = json.dumps(open(csl).read().replace('\n', ''))
  cx.eval_script('var style = CSL.makeStyle(sys,%s)' %(csl,))
  return "Style init OK"

def insertItems(input):
  log("ok insertItems")
  for i in range(len(input)):
    if type(input[i]) == int:
      input[i] = "%d" % input[i]
  theinput = json.dumps(input)
  cx.eval_script("style.insertItems(%s)" %(theinput,))
  return "Insert items OK"

def makeCitationCluster(input):
  log("ok makeCitationCluster")
  theinput = json.dumps(input)
  result = cx.eval_script("style.makeCitationCluster(%s)" %(theinput,))
  return result

def registerFlipFlops(input):
  log("ok registerFlipFlops")
  theinput = json.dumps(input)
  result = cx.eval_script("style.registerFlipFlops(%s)" %(theinput,))
  return "Insert items OK"

def makeBibliography():
  log("ok makeBibliography")
  result = cx.eval_script("style.makeBibliography()")
  return result

if __name__ == '__main__':
  def log(*args): pass

cx = load_spidermonkey()
initialize()

if __name__ == '__main__':
  for i in range(4):
    if i > (len(sys.argv) - 1):
      sys.argv.append(None)
  if sys.argv[1] == None: sys.argv[1] = 'mla'
  if sys.argv[2] == None: sys.argv[2] = 'bibliography'
  if sys.argv[3] == None: sys.argv[3] = '[]'

  items = json.loads(sys.argv[3])
  loadData(items)

  makeStyle("style/%s.csl" % sys.argv[1])

  registerFlipFlops([
    {"start":"*", "end":"*", "func":["@font-style","italic"], "alt":["@font-style","normal"] },
    {"start":"<span class=\"subtitle\">", "end":"</span>", "func":["@font-weight","bold"], "alt":["@font-weight","normal"] },
    {"start":"\"", "end":"\"", "func":["@quotes","true"], "alt": ["@squotes","true"]  },
    {"start":"'", "end":"'", "func":["@quotes","true"], "alt": ["@squotes","true"] }
  ]),

  ids = [item['id'] for item in items]
  insertItems(ids)
  if sys.argv[2] == 'citation':
    print makeCitationCluster([[item['id'],{}] for item in items])
  else:
    print makeBibliography()[0]