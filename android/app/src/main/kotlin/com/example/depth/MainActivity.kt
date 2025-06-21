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

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.depth"
    private var arSession: Session? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initSession" -> initSession(result)
                    "captureImage" -> captureImage(result)
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
}