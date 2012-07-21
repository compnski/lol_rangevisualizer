from collections import defaultdict
import BaseHTTPServer
import Queue
import SocketServer
import base64
import code
import hashlib
import json
import json
import os
import random
import socket
import stat
import threading
import time
import time
import urlparse

TIMEOUT = 180
PORT = 8000

class Error(BaseException): pass
class SessionDataTimeout(Error): pass

class GameSession:
    def __init__(self, sessionKey, data={}):
        self.sessionKey = sessionKey
        this.data =data

    def toJson(self):
        return json.dumps(data)

class SessionManager(object):
    def create(self, sessionKey):
        data = GameSession(sessionKey, [])
        return self.setSessionData(sessionKey, data)

    def setSessionData(self, sessionKey, session):
        print "setSessionData", session
        data = (time.time(), session)
        self._sessionMap[sessionKey] = data
        self.publishSessionData(sessionKey, data)
        return data

    def getSessionData(self, sessionKey, lastUpdate=0, block=False, timeout=0):
        """Returns (lastUpdateMs, sessionData).
        If there is no data and block is false, returns None, None.
        If the data is older than lastUpdateMs and block is false, returns the data.
        If block is true then wait to see if someone pushes session data
        for timeout seconds.
        """
        sessionData = self._sessionMap.get(sessionKey, (None, None))
        if not block:
            return sessionData
        print "getData", sessionData[0], lastUpdate, sessionData[0] >= lastUpdate
        if sessionData[0] is None or sessionData[0] < lastUpdate:
            try:
                sessionData = self.waitForSessionData(sessionKey, timeout)
            except SessionDataTimeout:
                pass
        return sessionData

    def __init__(self):
        self._waitQueueMap = defaultdict(list)
        self._sessionMap = {}

    def waitForSessionData(self, sessionKey, timeout=TIMEOUT):
        q = Queue.Queue()
        self._waitQueueMap[sessionKey].append(q)
        try:
            return q.get(timeout=timeout)
        except Queue.Empty:
            raise SessionDataTimeout()
        finally:
            self._waitQueueMap[sessionKey].remove(q)

    def publishSessionData(self, sessionKey, data):
        if sessionKey not in self._waitQueueMap:
            return 0
        for q in self._waitQueueMap[sessionKey]:
            q.put(data)
        return len(self._waitQueueMap[sessionKey])


sessionManager = SessionManager()

class ThreadedTCPRequestHandler(SocketServer.BaseRequestHandler):
    def handle(self):
        data = self.request.recv(1024)
        cur_thread = threading.current_thread()
        response = "{}: {}".format(cur_thread.name, data)
        self.request.send(response)
class ThreadedTCPServer(SocketServer.ThreadingMixIn, SocketServer.TCPServer): pass

def guessContentType(filename):
    ext = os.path.splitext(filename)[1]
    print ext
    if ext == ".html":
        return 'text/html'
    if ext == ".js":
        return 'application/x-javascript'
    if ext == ".css":
        return 'text/css'
    if ext == ".coffee":
        return 'text/coffeescript'
    else:
        return "application/xml"

class CustomHTTP(BaseHTTPServer.BaseHTTPRequestHandler):
    _staticFileMap = {}
    def do_GET(self):
        filename = os.path.basename(self.path)
        filename = filename.split("?")[0]
        print self.path, filename

        if filename in CustomHTTP._staticFileMap:
            return self.handleStaticFile(filename)
        self.do_POST()

    def getCoffeeScripts(self):
        import os
        coffeeScripts = os.listdir("coffee/")
        coffeeScripts.sort()
        scripts = [open("coffee/" + script, "r").read() for script in coffeeScripts if os.path.exists("coffee/" + script) and script.endswith(".coffee")]
        return scripts

    def handle_coffeeMain(self):
        scripts = self.getCoffeeScripts()
        scripts.append("main()")
        return "\n".join(scripts)

    @classmethod
    def reloadFile(cls, filename, path, lastMod):
        print "Loading %s" % filename
        cls._staticFileMap[filename] = (path, lastMod, open(path, "rb").read())

    def handleStaticFile(self, filename):
        (path, cacheLastMod, _) = CustomHTTP._staticFileMap[filename]
        try:
            lastMod = os.stat(filename)[stat.ST_MTIME]
            if lastMod > cacheLastMod:
                self.reloadFile(filename, path, lastMod)
            self.send_response(200)
            self.send_header('Content-Type', guessContentType(filename))
            self.end_headers()
            self.wfile.write(CustomHTTP._staticFileMap[filename][2])
        except OSError:
            pass

    def handle_getSessionKey():
        return hashlib.md5("%s:%s" % (time.time(), os.getpid())).hexdigest()

    def do_POST(self):
        filename = os.path.basename(self.path)
        filename = filename.split("?")[0]
        print self.path, filename

        if getattr(self, "handle_%s" % filename, False):
            response = getattr(self, "handle_%s" % filename)()
            if response is None:
                return
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response))
            self.end_headers()
            self.wfile.write(response)
            return
        self.send_error(404)

    def make_file(self, filename):
        if os.path.exists(filename):
            basename = os.path.basename(filename)
            (base,ext) = os.path.splitext(basename)
            base = base + time.time()
            basename = base + "." + ext
            filename = os.path.join(os.path.dirname(filename), basename)

        tmpdir = tempfile.gettempdir()
        tmpdir = "images/"
        return open(os.path.join(tmpdir, filename), "wb")

    def read_image_helper(self, fp, length):
        """Internal: read binary data."""
        imageParts = []
        todo = length
        if todo >= 0:
            while todo > 0:
                data = fp.read(min(todo, fp.bufsize))
                if not data:
                    self.done = -1
                    break
                todo = todo - len(data)
                data = data.split(",")[-1] #Take the second if there is
                imageParts.append(data)
        return "".join(imageParts)

    @property
    def cgiParams(self):
        return urlparse.parse_qs(urlparse.urlparse(self.path).query)

    def handle_waitForData(self):
        sessionKey = self.headers.get('X-Session-Key', None)
        if not sessionKey:
            self.send_error(400)
            return None
        lastUpdateTs = self.cgiParams.get("lastUpdate", 0)
        (lastUpdateTs, session) = sessionManager.getSessionData(sessionKey, lastUpdateTs, True, 100)
        if session is None:
            print "204 "*10
            self.send_response(204)
            return None
        print lastUpdateTs, session
        ret = dict(round=session.toDict(),
                   lastUpdateTs=lastUpdateTs)
        return json.dumps(ret)


def loadFiles():
    #preload
    files = ['range.html', 'range.coffee',
             'coffee-script.js']
    for filename in files:
        try:
            lastMod = os.stat(filename)[stat.ST_MTIME]
            CustomHTTP.reloadFile(filename, filename, lastMod)
        except (IOError, OSError):
            print "File %s not found, cannot serve it." % filename

import tempfile

Handler = CustomHTTP

ThreadedTCPServer.allow_reuse_address = True

httpd = ThreadedTCPServer(("", PORT), Handler)
httpd.allow_reuse_address = True
print "serving at port", PORT

try:
    loadFiles()
    httpd.serve_forever()
except KeyboardInterrupt:
    pass
