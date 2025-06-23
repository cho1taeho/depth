// android/app/src/main/kotlin/com/example/depth/MainActivity.kt

package com.example.depth

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.ar.core.Config
import com.google.ar.core.Session
import com.google.ar.core.exceptions.NotYetAvailableException
import com.google.ar.core.exceptions.UnavailableException
import java.io.File
import android.content.ContentValues
import android.provider.MediaStore
import android.os.Environment
import java.util.concurrent.ConcurrentLinkedQueue
import kotlinx.coroutines.*
import java.io.FileOutputStream
import java.io.DataOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.depth"
    private var arSession: Session? = null
    
    // 동영상 촬영 관련 변수들
    private var isRecording = AtomicBoolean(false)
    private var recordingJob: Job? = null
    private val depthFrames = ConcurrentLinkedQueue<DepthFrame>()
    
    // 깊이 프레임 데이터 클래스
    data class DepthFrame(
        val timestamp: Long,
        val depthData: ByteArray,
        val width: Int,
        val height: Int
    ) {
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (javaClass != other?.javaClass) return false
            other as DepthFrame
            return timestamp == other.timestamp
        }
        
        override fun hashCode(): Int {
            return timestamp.hashCode()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initSession" -> initSession(result)
                    "captureImage" -> captureImage(result)
                    "startVideoRecording" -> startVideoRecording(result)
                    "stopVideoRecording" -> stopVideoRecording(result)
                    "saveToGallery" -> {
                        val imagePath = call.argument<String>("imagePath")!!
                        saveImageToGallery(imagePath, result)
                    }
                    "measurePhoto" -> {
                        val depthPath = call.argument<String>("depthPath")!!
                        val x1 = call.argument<Int>("x1")!!
                        val y1 = call.argument<Int>("y1")!!
                        val x2 = call.argument<Int>("x2")!!
                        val y2 = call.argument<Int>("y2")!!
                        measureDistanceInDepthFile(depthPath, x1, y1, x2, y2, result)
                    }
                    "measureVideoFrame" -> {
                        val videoPath = call.argument<String>("videoPath")!!
                        val frameTimestamp = call.argument<Long>("frameTimestamp")!!
                        val x1 = call.argument<Int>("x1")!!
                        val y1 = call.argument<Int>("y1")!!
                        val x2 = call.argument<Int>("x2")!!
                        val y2 = call.argument<Int>("y2")!!
                        measureDistanceInVideoFrame(videoPath, frameTimestamp, x1, y1, x2, y2, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun initSession(result: MethodChannel.Result) {
        try {
            val session = Session(this)
            // Depth API 설정
            val config = session.config
            if (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                config.depthMode = Config.DepthMode.AUTOMATIC
            }
            session.configure(config)
            arSession = session
            result.success(null)
        } catch (e: UnavailableException) {
            result.error("UNAVAILABLE", e.message, null)
        }
    }

    private fun captureImage(result: MethodChannel.Result) {
        try {
            val session = arSession ?: throw IllegalStateException("Session not initialized")
            session.resume()
            val frame = session.update()

            // 컬러 이미지 데이터 복사
            val cameraImage = frame.acquireCameraImage()
            val colorBuffer = cameraImage.planes[0].buffer
            val colorBytes = ByteArray(colorBuffer.remaining()).also { colorBuffer.get(it) }
            cameraImage.close()

            // Depth 이미지 (16-bit) 복사
            val depthPath: String? = try {
                frame.acquireDepthImage16Bits().use { depthImage ->
                    val depthBuffer = depthImage.planes[0].buffer
                    val depthBytes = ByteArray(depthBuffer.remaining()).also { depthBuffer.get(it) }
                    val dir = File(filesDir, "depth").apply { if (!exists()) mkdirs() }
                    val ts = System.currentTimeMillis()
                    val file = File(dir, "depth_${ts}.raw").apply { writeBytes(depthBytes) }
                    file.absolutePath
                }
            } catch (_: NotYetAvailableException) {
                null
            }

            session.pause()

            // 컬러 파일 저장
            val dir = File(filesDir, "depth").apply { if (!exists()) mkdirs() }
            val ts = System.currentTimeMillis()
            val colorFile = File(dir, "color_${ts}.raw").apply { writeBytes(colorBytes) }

            result.success(
                mapOf(
                    "colorPath" to colorFile.absolutePath,
                    "depthPath" to (depthPath ?: "unavailable")
                )
            )
        } catch (e: Exception) {
            result.error("CAPTURE_ERROR", e.localizedMessage, null)
        }
    }

    // 갤러리에 이미지 저장하는 함수
    private fun saveImageToGallery(imagePath: String, result: MethodChannel.Result) {
        try {
            val file = File(imagePath)
            val contentValues = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, file.name)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES)
            }

            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)

            uri?.let { imageUri ->
                resolver.openOutputStream(imageUri)?.use { outputStream ->
                    file.inputStream().use { inputStream ->
                        inputStream.copyTo(outputStream)
                    }
                }
                result.success("Image saved to gallery")
            } ?: result.error("SAVE_ERROR", "Failed to save image", null)
        } catch (e: Exception) {
            result.error("SAVE_ERROR", e.localizedMessage, null)
        }
    }

    // 사진(Depth Map)에서 두 점의 거리 측정 함수
    private fun measureDistanceInDepthFile(depthPath: String, x1: Int, y1: Int, x2: Int, y2: Int, result: MethodChannel.Result) {
        try {
            val file = File(depthPath)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "Depth file not found", null)
                return
            }

            val bytes = file.readBytes()

            // Depth Map의 width, height (예시값 - 실제로는 저장 시 기록 필요)
            // 실제 구현에서는 width, height를 별도로 저장하거나 메타데이터로 관리해야 함
            val width = 640  // 예시값 - 실제 카메라 해상도에 맞게 조정
            val height = 480 // 예시값 - 실제 카메라 해상도에 맞게 조정

            // 픽셀 좌표가 이미지 범위를 벗어나지 않도록 체크
            if (x1 < 0 || x1 >= width || y1 < 0 || y1 >= height ||
                x2 < 0 || x2 >= width || y2 < 0 || y2 >= height) {
                result.error("INVALID_COORDINATES", "Coordinates out of bounds", null)
                return
            }

            // Depth Map에서 특정 픽셀의 깊이값 추출 (16-bit)
            fun getDepth(x: Int, y: Int): Int {
                val index = (y * width + x) * 2
                if (index + 1 >= bytes.size) return 0
                return ((bytes[index + 1].toInt() and 0xFF) shl 8) or (bytes[index].toInt() and 0xFF)
            }

            val d1 = getDepth(x1, y1)
            val d2 = getDepth(x2, y2)

            // 두 점 사이의 거리 계산 (단순한 깊이 차이)
            val distance = Math.abs(d1 - d2)

            result.success(distance)
        } catch (e: Exception) {
            result.error("MEASURE_ERROR", e.localizedMessage, null)
        }
    }

    // 동영상 촬영 시작
    private fun startVideoRecording(result: MethodChannel.Result) {
        if (isRecording.get()) {
            result.error("ALREADY_RECORDING", "Already recording video", null)
            return
        }

        try {
            val session = arSession ?: throw IllegalStateException("Session not initialized")
            
            // 깊이 데이터 파일 경로 설정
            val dir = File(filesDir, "videos").apply { if (!exists()) mkdirs() }
            val timestamp = System.currentTimeMillis()
            val depthDataFile = File(dir, "depth_${timestamp}.dat")
            
            // 깊이 데이터 수집 시작
            isRecording.set(true)
            depthFrames.clear()
            
            recordingJob = CoroutineScope(Dispatchers.IO).launch {
                var frameCount = 0
                while (isRecording.get()) {
                    try {
                        session.resume()
                        val frame = session.update()
                        
                        // 깊이 데이터 수집
                        try {
                            frame.acquireDepthImage16Bits().use { depthImage ->
                                val depthBuffer = depthImage.planes[0].buffer
                                val depthBytes = ByteArray(depthBuffer.remaining()).also { depthBuffer.get(it) }
                                
                                depthFrames.offer(DepthFrame(
                                    timestamp = System.currentTimeMillis(),
                                    depthData = depthBytes,
                                    width = depthImage.width,
                                    height = depthImage.height
                                ))
                                
                                // 깊이 데이터를 파일에 저장
                                DataOutputStream(FileOutputStream(depthDataFile, true)).use { dos ->
                                    dos.writeLong(System.currentTimeMillis())
                                    dos.writeInt(depthImage.width)
                                    dos.writeInt(depthImage.height)
                                    dos.writeInt(depthBytes.size)
                                    dos.write(depthBytes)
                                }
                            }
                        } catch (_: NotYetAvailableException) {
                            // 깊이 데이터가 아직 사용 불가능
                        }
                        
                        session.pause()
                        frameCount++
                        delay(33) // 약 30fps
                    } catch (e: Exception) {
                        e.printStackTrace()
                        break
                    }
                }
            }
            
            result.success(mapOf(
                "depthDataPath" to depthDataFile.absolutePath,
                "timestamp" to timestamp
            ))
            
        } catch (e: Exception) {
            result.error("RECORDING_ERROR", e.localizedMessage, null)
        }
    }
    
    // 동영상 촬영 중지
    private fun stopVideoRecording(result: MethodChannel.Result) {
        if (!isRecording.get()) {
            result.error("NOT_RECORDING", "Not currently recording", null)
            return
        }
        
        try {
            isRecording.set(false)
            recordingJob?.cancel()
            
            result.success("Video recording stopped")
            
        } catch (e: Exception) {
            result.error("STOP_RECORDING_ERROR", e.localizedMessage, null)
        }
    }
    
    // 동영상 프레임에서 거리 측정
    private fun measureDistanceInVideoFrame(
        videoPath: String, 
        frameTimestamp: Long, 
        x1: Int, y1: Int, x2: Int, y2: Int, 
        result: MethodChannel.Result
    ) {
        try {
            // 동영상 파일명에서 depth 데이터 파일 경로 추출
            val videoFile = File(videoPath)
            val depthDataFile = File(videoFile.parent, "depth_${videoFile.nameWithoutExtension.split("_").last()}.dat")
            
            if (!depthDataFile.exists()) {
                result.error("DEPTH_DATA_NOT_FOUND", "Depth data file not found", null)
                return
            }
            
            // 해당 타임스탬프에 가장 가까운 깊이 프레임 찾기
            val targetFrame = findClosestDepthFrame(depthDataFile, frameTimestamp)
            
            if (targetFrame == null) {
                result.error("FRAME_NOT_FOUND", "Depth frame not found for timestamp", null)
                return
            }
            
            // 깊이 데이터에서 거리 측정
            val distance = calculateDistanceFromDepthData(
                targetFrame.depthData, 
                targetFrame.width, 
                targetFrame.height, 
                x1, y1, x2, y2
            )
            
            result.success(distance)
            
        } catch (e: Exception) {
            result.error("MEASURE_VIDEO_ERROR", e.localizedMessage, null)
        }
    }
    
    // 가장 가까운 깊이 프레임 찾기
    private fun findClosestDepthFrame(depthDataFile: File, targetTimestamp: Long): DepthFrame? {
        try {
            var closestFrame: DepthFrame? = null
            var minDifference = Long.MAX_VALUE
            
            depthDataFile.inputStream().use { input ->
                while (input.available() > 0) {
                    val timestamp = input.readLong()
                    val width = input.readInt()
                    val height = input.readInt()
                    val dataSize = input.readInt()
                    val depthData = ByteArray(dataSize)
                    input.read(depthData)
                    
                    val difference = Math.abs(timestamp - targetTimestamp)
                    if (difference < minDifference) {
                        minDifference = difference
                        closestFrame = DepthFrame(timestamp, depthData, width, height)
                    }
                }
            }
            
            return closestFrame
            
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }
    
    // 깊이 데이터에서 거리 계산 (기존 함수와 동일)
    private fun calculateDistanceFromDepthData(
        depthData: ByteArray, 
        width: Int, 
        height: Int, 
        x1: Int, y1: Int, x2: Int, y2: Int
    ): Int {
        // 픽셀 좌표가 이미지 범위를 벗어나지 않도록 체크
        if (x1 < 0 || x1 >= width || y1 < 0 || y1 >= height ||
            x2 < 0 || x2 >= width || y2 < 0 || y2 >= height) {
            return 0
        }

        // Depth Map에서 특정 픽셀의 깊이값 추출 (16-bit)
        fun getDepth(x: Int, y: Int): Int {
            val index = (y * width + x) * 2
            if (index + 1 >= depthData.size) return 0
            return ((depthData[index + 1].toInt() and 0xFF) shl 8) or (depthData[index].toInt() and 0xFF)
        }

        val d1 = getDepth(x1, y1)
        val d2 = getDepth(x2, y2)

        // 두 점 사이의 거리 계산 (단순한 깊이 차이)
        return Math.abs(d1 - d2)
    }
}