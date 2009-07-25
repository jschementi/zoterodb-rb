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
  log "Loading spidermonkey ..."
  from spidermonkey import Runtime
  rt = Runtime()
  return rt.new_context()

def load_citeproc():
  log "Loading citeproj-js ..."
  cslcode = open("./src-js/citeproc-js.js").read()
  cx.eval_script(cslcode)

def path(*elements):
  return os.path.join( os.getcwd(), *elements )

def load_locals():
  log "Loading locales ..."
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
  log "Loading sys ..."
  system = open("./src-js/sys.js").read()
  cx.eval_script(system)

#
# CSL interaction
#

cx = load_spidermonkey()

def initialize():
  load_citeproc()
  load_locals()
  load_sys()

def loadData(input):
  log "ok loadData"
  data = json.dumps(input)
  cx.eval_script("sys.loadData(%s)" %(data,))
  return "Loaded data OK"

def makeStyle(csl):
  log "ok makeStyle"
  csl = json.dumps(open(csl).read().replace('\n', ''))
  cx.eval_script('var style = CSL.makeStyle(sys,%s)' %(csl,))
  return "Style init OK"

def insertItems(input):
  log "ok insertItems"
  theinput = json.dumps(input)
  cx.eval_script("style.insertItems(%s)" %(theinput,))
  return "Insert items OK"

def makeCitationCluster(input):
  log "ok makeCitationCluster"
  theinput = json.dumps(input)
  result = cx.eval_script("style.makeCitationCluster(%s)" %(theinput,))
  return result

def registerFlipFlops(input):
  log "ok registerFlipFlops"
  theinput = json.dumps(input)
  result = cx.eval_script("style.registerFlipFlops(%s)" %(theinput,))
  return "Insert items OK"

def makeBibliography():
  log "ok makeBibliography"
  result = cx.eval_script("style.makeBibliography()")
  return result


cx = load_spidermonkey()
initialize()

if __name__ == '__main__':
  items = [
    {
      "id": "ITEM-1",
      "type": "book",
      "author": [
        { "name":"Doe, John", "primary-key":"Doe", "secondary-key":"John" }
      ],
      "title": "Book A: insert interesting title phrase here",
      "issued": { "year": "2006" }
    },
    {
      "id": "ITEM-2",
      "type": "book",
      "author": [
        { "name":" Roe, Jane", "primary-key":"Roe", "secondary-key":"Jane" }
      ],
      "title": "Book B: <span class=\"subtitle\">quiet</span> reflections on anonymity",
      "issued": { "year": "2007" }
    },
    {
      "id": "ITEM-3",
      "type": "book",
      "author": [
        { "primary-key":"Anderson", "secondary-key":"Margaret" }
      ],
      "title": "The '\"Amazing\" <i>Life</i> of the *Grand Petunia Royale*' by Karl Truckload",
      "issued": { "year": "1950" }
    },
    {
      "id": "ITEM-4",
      "type": "book",
      "author": [
        { "primary-key":"Zinfandel", "secondary-key":"William" }
      ],
      "title": "<i>Peri Bathos</i>: on the art of sinking in poetry (an exercise in flagrant plagiarism)",
      "issued": { "year": "1945" }
    }
  ]

  log(
    loadData(items),
    makeStyle("style/ieee.csl"),
    insertItems(["ITEM-1","ITEM-2"]),
    makeBibliography(),
    makeCitationCluster([["ITEM-3",{}], ["ITEM-4",{}]]),
    makeBibliography(),
    registerFlipFlops([
      {"start":"*", "end":"*", "func":["@font-style","italic"], "alt":["@font-style","normal"] },
      {"start":"<span class=\"subtitle\">", "end":"</span>", "func":["@font-weight","bold"], "alt":["@font-weight","normal"] },
      {"start":"\"", "end":"\"", "func":["@quotes","true"], "alt": ["@squotes","true"]  },
      {"start":"'", "end":"'", "func":["@quotes","true"], "alt": ["@squotes","true"] }
    ]),
    makeBibliography()
  )
else :
  if sys.argv[1] == None: sys.argv[1] = 'mla'
  if sys.argv[2] == None: sys.argv[2] = 'bibliography'
  if sys.argv[3] == None: sys.argv[3] = '[]'

  items = json.loads(sys.argv[3])
  loadData(items)
  
  makeStyle("style/%s.csl" % sys.argv[1])
  insertItems([item['id'] for item in items])
  if sys.argv[2] == 'citation':
    print makeCitationCluster([[item['id'],{}] for item in items])
  else:
    print makeBibliography()