package com.smartvisionband.camera

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test

class MjpegJpegFrameExtractorTest {
    @Test
    fun extractsFramesWhenMarkersSpanInputChunks() {
        val extractor = MjpegJpegFrameExtractor(32)
        val frames = mutableListOf<ByteArray>()

        extractor.feed(byteArrayOf(0x55, 0xff.toByte()), 2) { frames.add(it) }
        extractor.feed(byteArrayOf(0xd8.toByte(), 0x01, 0xff.toByte()), 3) { frames.add(it) }
        extractor.feed(byteArrayOf(0xd9.toByte(), 0x00, 0xff.toByte(), 0xd8.toByte(), 0x02, 0xff.toByte(), 0xd9.toByte()), 7) { frames.add(it) }

        assertEquals(2, frames.size)
        assertArrayEquals(byteArrayOf(0xff.toByte(), 0xd8.toByte(), 0x01, 0xff.toByte(), 0xd9.toByte()), frames[0])
        assertArrayEquals(byteArrayOf(0xff.toByte(), 0xd8.toByte(), 0x02, 0xff.toByte(), 0xd9.toByte()), frames[1])
    }
}