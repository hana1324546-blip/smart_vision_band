package com.smartvisionband
import org.junit.Test
import org.junit.Assert.*
import com.smartvisionband.bluetooth.Protocol
class ProtocolTest {
 @Test fun parsesDistance(){assertEquals(35.0,Protocol.distance("DIST:35")!!,0.001)}
 @Test fun rejectsNonFinite(){assertNull(Protocol.distance("DIST:NaN"))}
 @Test fun encodesRawHapticCommands(){
  assertArrayEquals(byteArrayOf('S'.code.toByte()),Protocol.hapticByte("S"))
  assertArrayEquals(byteArrayOf('W'.code.toByte()),Protocol.hapticByte("W"))
  assertArrayEquals(byteArrayOf('C'.code.toByte()),Protocol.hapticByte("C"))
 }
 @Test(expected=IllegalArgumentException::class) fun rejectsUnknownHapticCommand(){Protocol.hapticByte("X")}
}
