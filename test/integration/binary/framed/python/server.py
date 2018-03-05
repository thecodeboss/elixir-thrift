#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#
# ==========================================================
#
# This file was simplified from thrift/test/py/TestServer.py
#
from __future__ import division
import logging
import time

from ThriftTest import ThriftTest
from ThriftTest.ttypes import Xtruct, Xception, Xception2, Insanity

from thrift.transport import TSocket
from thrift.transport import TTransport
from thrift.protocol import TBinaryProtocol
from thrift.server import TServer
from thrift.Thrift import TException


class TestHandler(object):
    def testVoid(self):
        print('testVoid()')

    def testString(self, str):
        print('testString(%s)' % str)
        return str

    def testBool(self, boolean):
        print('testBool(%s)' % str(boolean).lower())
        return boolean

    def testByte(self, byte):
        print('testByte(%d)' % byte)
        return byte

    def testI16(self, i16):
        print('testI16(%d)' % i16)
        return i16

    def testI32(self, i32):
        print('testI32(%d)' % i32)
        return i32

    def testI64(self, i64):
        print('testI64(%d)' % i64)
        return i64

    def testDouble(self, dub):
        print('testDouble(%f)' % dub)
        return dub

    def testBinary(self, thing):
        print('testBinary()')  # TODO: hex output
        return thing

    def testStruct(self, thing):
        print('testStruct({%s, %s, %s, %s})' % (thing.string_thing,
              thing.byte_thing, thing.i32_thing, thing.i64_thing))
        return thing

    def testException(self, arg):
        print('testException(%s)' % arg)
        if arg == 'Xception':
            raise Xception(errorCode=1001, message=arg)
        elif arg == 'TException':
            raise TException(message='This is a TException')

    def testMultiException(self, arg0, arg1):
        print('testMultiException(%s, %s)' % (arg0, arg1))
        if arg0 == 'Xception':
            raise Xception(errorCode=1001, message='This is an Xception')
        elif arg0 == 'Xception2':
            raise Xception2(
                errorCode=2002,
                struct_thing=Xtruct(string_thing='This is an Xception2'))
        return Xtruct(string_thing=arg1)

    def testOneway(self, seconds):
        print('testOneway(%d) => sleeping...' % seconds)
        time.sleep(seconds / 3)  # be quick
        print('done sleeping')

    def testNest(self, thing):
        print('testNest(%s)' % thing)
        return thing

    def testMap(self, thing):
        print('testMap(%s)' % thing)
        return thing

    def testStringMap(self, thing):
        print('testStringMap(%s)' % thing)
        return thing

    def testSet(self, thing):
        print('testSet(%s)' % thing)
        return thing

    def testList(self, thing):
        print('testList(%s)' % thing)
        return thing

    def testEnum(self, thing):
        print('testEnum(%s)' % thing)
        return thing

    def testTypedef(self, thing):
        print('testTypedef(%s)' % thing)
        return thing

    def testMapMap(self, thing):
        print('testMapMap(%s)' % thing)
        return {
            -4: {
                -4: -4,
                -3: -3,
                -2: -2,
                -1: -1,
            },
            4: {
                4: 4,
                3: 3,
                2: 2,
                1: 1,
            },
        }

    def testInsanity(self, argument):
        print('testInsanity(%s)' % argument)
        return {
            1: {
                2: argument,
                3: argument,
            },
            2: {6: Insanity()},
        }

    def testMulti(self, arg0, arg1, arg2, arg3, arg4, arg5):
        print('testMulti(%s)' % [arg0, arg1, arg2, arg3, arg4, arg5])
        return Xtruct(string_thing='Hello2',
                      byte_thing=arg0, i32_thing=arg1, i64_thing=arg2)


if __name__ == '__main__':
    handler = TestHandler()
    processor = ThriftTest.Processor(handler)
    transport = TSocket.TServerSocket(host='localhost', port=2345)
    tfactory = TTransport.TFramedTransportFactory()
    pfactory = TBinaryProtocol.TBinaryProtocolFactory()

    server = TServer.TSimpleServer(processor, transport, tfactory, pfactory)
    logging.basicConfig(level=logging.CRITICAL)
    server.serve()
