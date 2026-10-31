package com.smartvisionband.bluetooth
object Protocol {
 private val hapticCommands=setOf("S","W","C")
 val outgoing=Regex("^(VIBRATE_ON|VIBRATE_OFF|VIBRATE_PATTERN:[123]|PING)$")
 fun hapticByte(command:String):ByteArray {
  require(command in hapticCommands){"Unsupported haptic command"}
  return byteArrayOf(command[0].code.toByte())
 }
 fun distance(line:String):Double? {
  if(!line.startsWith("DIST:"))return null
  val n=line.substring(5).toDoubleOrNull()?:return null
  return n.takeIf{it.isFinite() && it>0 && it<=600}
 }
}
