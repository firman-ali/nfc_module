package com.avatarsolution.nfc_module

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.MifareClassic
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.Toast

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.IOException
import kotlin.concurrent.thread

/** NfcModulePlugin */
class NfcModulePlugin: FlutterPlugin, ActivityAware, MethodCallHandler, NfcAdapter.ReaderCallback {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  private var currentActivity: Activity? = null

  private var nfcAdapter: NfcAdapter? = null
  private var successCount: Int = 0

  private val uiThreadHandler = Handler(Looper.getMainLooper())

  private var pendingOperation: PendingOperation = PendingOperation.None

  sealed class PendingOperation {
    object None : PendingOperation()
    data class Read(val sectorIndex: Int, val blockIndex: Int, val key: ByteArray) : PendingOperation()
    data class Write(val sectorIndex: Int, val blockIndex: Int, val data: ByteArray, val key: ByteArray) : PendingOperation()
    data class Reset(val key: ByteArray) : PendingOperation()
    data class ReadMultiple(val targets: List<Map<String, Int>>, val key: ByteArray) : PendingOperation()
    data class WriteMultiple(val targets: List<Map<String, Any>>, val key: ByteArray) : PendingOperation()
  }

  companion object {
    private const val TAG = "NfcModulePlugin"
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "nfc_module")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    tearDownNfc()
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "prepareReadBlock" -> {
        try {
          val sector = call.argument<Int>("sectorIndex")!!
          val block = call.argument<Int>("blockIndex")!!
          val keyHex = call.argument<String>("keyHex")!!
          pendingOperation = PendingOperation.Read(sector, block, hexStringToByteArray(keyHex))
          result.success("Siap membaca blok $block di sektor $sector. Tempelkan tag.")
        } catch (e: Exception) {
          result.error("ARGUMENT_ERROR", "Argumen tidak valid: ${e.message}", null)
        }
      }
      "prepareWriteBlock" -> {
        try {
          val sector = call.argument<Int>("sectorIndex")!!
          val block = call.argument<Int>("blockIndex")!!
          val keyHex = call.argument<String>("keyHex")!!
          val dataHex = call.argument<String>("dataHex")!!

          val data = hexStringToByteArray(dataHex)
          if (data.size != 16) {
            result.error("DATA_LENGTH_ERROR", "Data harus tepat 16 byte.", null)
            return
          }

          pendingOperation = PendingOperation.Write(sector, block, data, hexStringToByteArray(keyHex))
          result.success("Siap menulis ke blok $block di sektor $sector. Tempelkan tag.")
        } catch (e: Exception) {
          result.error("ARGUMENT_ERROR", "Argumen tidak valid: ${e.message}", null)
        }
      }
      "prepareResetCard" -> {
        try {
          val keyHex = call.argument<String>("keyHex")!!
          pendingOperation = PendingOperation.Reset(hexStringToByteArray(keyHex))
          result.success("Siap mereset kartu. Tempelkan tag.")
        } catch (e: Exception) {
          result.error("ARGUMENT_ERROR", "Argumen tidak valid: ${e.message}", null)
        }
      }
      "prepareReadMultipleBlocks" -> {
        try {
          @Suppress("UNCHECKED_CAST")
          val targets = call.argument<List<Map<String, Int>>>("targets")!!
          val keyHex = call.argument<String>("keyHex")!!
          pendingOperation = PendingOperation.ReadMultiple(targets, hexStringToByteArray(keyHex))
          result.success("Siap membaca ${targets.size} target. Tempelkan tag.")
        } catch (e: Exception) {
          result.error("ARGUMENT_ERROR", "Argumen tidak valid: ${e.message}", null)
        }
      }
      "prepareWriteMultipleBlocks" -> {
        try {
          val targets = call.argument<List<Map<String, Any>>>("targets")!!
          val keyHex = call.argument<String>("keyHex")!!
          pendingOperation = PendingOperation.WriteMultiple(targets, hexStringToByteArray(keyHex))
          result.success("Siap menulis ke ${targets.size} target. Tempelkan tag.")
        } catch (e: Exception) {
          result.error("ARGUMENT_ERROR", "Argumen tidak valid: ${e.message}", null)
        }
      }
      "cancelOperation" -> {
        pendingOperation = PendingOperation.None
        result.success("Operasi dibatalkan.")
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    currentActivity = binding.activity
    setupNfc()
  }

  override fun onDetachedFromActivity() {
    tearDownNfc()
    currentActivity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  private fun setupNfc() {
    val activity = currentActivity ?: return
    nfcAdapter = NfcAdapter.getDefaultAdapter(activity)

    if (nfcAdapter == null) {
      Toast.makeText(activity, "Perangkat ini tidak mendukung NFC", Toast.LENGTH_LONG).show()
      return
    }

    nfcAdapter?.enableReaderMode(
      activity,
      this,
      NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
      null
    )
  }

  private fun tearDownNfc() {
    if (currentActivity == null) {
      return
    }

    try {
      nfcAdapter?.disableReaderMode(currentActivity!!)
    } catch (e: IllegalArgumentException) {
      Log.i(TAG, "Receiver tidak terdaftar atau sudah dilepas: ${e.message}")
    } catch (e: Exception) {
      Log.e(TAG, "Error saat teardown NFC: ${e.message}")
    }
  }

  override fun onTagDiscovered(tag: Tag?) {
    Log.d(TAG, "NFC Tag Ditemukan!")
    tag ?: return

    val currentOperation = pendingOperation
    if (currentOperation is PendingOperation.None) return
    thread { handleMifareClassic(tag, currentOperation) }
    pendingOperation = PendingOperation.None
  }

  private fun handleMifareClassic(tag: Tag, operation: PendingOperation) {
    val mifare = MifareClassic.get(tag)
    if (mifare == null) {
      sendErrorToFlutter("TAG_NOT_SUPPORTED", "Tag ini bukan MIFARE Classic.")
      return
    }

    try {
      mifare.connect()
      when (operation) {
        is PendingOperation.Read -> {
          val (sectorIndex, relativeBlockIndex, key) = operation
          if (mifare.authenticateSectorWithKeyA(sectorIndex, key)) {
            val absoluteBlockIndex = mifare.sectorToBlock(sectorIndex) + relativeBlockIndex
            val blockData = mifare.readBlock(absoluteBlockIndex)
            sendSuccessToFlutter("onReadResult", mapOf(
              "sector" to sectorIndex,
              "block" to relativeBlockIndex,
              "dataHex" to byteArrayToHexString(blockData)
            ))
          } else {
            sendErrorToFlutter("AUTH_ERROR", "Gagal autentikasi sektor $sectorIndex.")
          }
        }
        is PendingOperation.Write -> {
          val (sectorIndex, relativeBlockIndex, data, key) = operation
          if (mifare.authenticateSectorWithKeyA(sectorIndex, key)) {
            val absoluteBlockIndex = mifare.sectorToBlock(sectorIndex) + relativeBlockIndex
            mifare.writeBlock(absoluteBlockIndex, data)
            sendSuccessToFlutter("onWriteResult", mapOf(
              "sector" to sectorIndex,
              "block" to relativeBlockIndex,
              "success" to true
            ))
          } else {
            sendErrorToFlutter("AUTH_ERROR", "Gagal autentikasi sektor $sectorIndex.")
          }
        }
        is PendingOperation.Reset -> {
          val key = operation.key
          val zeroData = ByteArray(16) // Array 16 byte berisi nol
          var sectorsReset = 0

          for (i in 0 until mifare.sectorCount) {
            if (mifare.authenticateSectorWithKeyA(i, key)) {
              val blockCount = mifare.getBlockCountInSector(i)
              for (j in 0 until blockCount) {
                val trailerBlockIndex = blockCount - 1
                if (j == trailerBlockIndex) continue

                if (i == 0 && j == 0) continue

                val blockIndex = mifare.sectorToBlock(i) + j
                mifare.writeBlock(blockIndex, zeroData)
              }
              sectorsReset++
            } else {
              sendErrorToFlutter("AUTH_ERROR", "Gagal autentikasi Sektor $i. Reset dihentikan.")
              return
            }
          }
          sendSuccessToFlutter("onResetResult", mapOf("sectorsReset" to sectorsReset))
        }
        is PendingOperation.ReadMultiple -> {
          val (targets, key) = operation
          val results = mutableListOf<Map<String, Any>>()
          val authenticatedSectors = mutableSetOf<Int>()

          for (target in targets) {
            val sectorIndex = target["sectorIndex"] ?: -1
            val blockIndex = target["blockIndex"] ?: -1

            if (sectorIndex == -1 || blockIndex == -1) continue

            var authSuccess = authenticatedSectors.contains(sectorIndex)
            if (!authSuccess) {
              if (mifare.authenticateSectorWithKeyA(sectorIndex, key)) {
                authenticatedSectors.add(sectorIndex)
                authSuccess = true
              }
            }

            if (authSuccess) {
              try {
                val absoluteBlockIndex = mifare.sectorToBlock(sectorIndex) + blockIndex
                val blockData = mifare.readBlock(absoluteBlockIndex)
                results.add(mapOf(
                  "sector" to sectorIndex,
                  "block" to blockIndex,
                  "dataHex" to byteArrayToHexString(blockData),
                  "success" to true
                ))
              } catch (e: IOException) {
                results.add(mapOf(
                  "sector" to sectorIndex,
                  "block" to blockIndex,
                  "error" to "Gagal baca blok: ${e.message}",
                  "success" to false
                ))
              }
            } else {
              results.add(mapOf(
                "sector" to sectorIndex,
                "block" to blockIndex,
                "error" to "Gagal autentikasi sektor",
                "success" to false
              ))
            }
          }
          sendSuccessToFlutter("onMultiReadResult", mapOf("results" to results))
        }
        is PendingOperation.WriteMultiple -> {
          val (targets, key) = operation
          val results = mutableListOf<Map<String, Any>>()
          val authenticatedSectors = mutableSetOf<Int>()

          for (target in targets) {
            val sectorIndex = target["sectorIndex"] as? Int ?: -1
            val blockIndex = target["blockIndex"] as? Int ?: -1
            val dataHex = target["dataHex"] as? String ?: ""

            if (sectorIndex == -1 || blockIndex == -1 || dataHex.isEmpty()) continue

            // Validasi keamanan di sisi native
            val sectorTrailer = mifare.getBlockCountInSector(sectorIndex) - 1
            if (blockIndex == sectorTrailer || (sectorIndex == 0 && blockIndex == 0)) {
              results.add(mapOf(
                "sector" to sectorIndex, "block" to blockIndex,
                "error" to "Penulisan ke blok sistem dilarang", "success" to false
              ))
              continue
            }

            var authSuccess = authenticatedSectors.contains(sectorIndex)
            if (!authSuccess) {
              if (mifare.authenticateSectorWithKeyA(sectorIndex, key)) {
                authenticatedSectors.add(sectorIndex)
                authSuccess = true
              }
            }

            if (authSuccess) {
              try {
                val absoluteBlockIndex = mifare.sectorToBlock(sectorIndex) + blockIndex
                mifare.writeBlock(absoluteBlockIndex, hexStringToByteArray(dataHex))
                results.add(mapOf(
                  "sector" to sectorIndex, "block" to blockIndex, "success" to true
                ))
              } catch (e: IOException) {
                results.add(mapOf(
                  "sector" to sectorIndex, "block" to blockIndex,
                  "error" to "Gagal tulis blok: ${e.message}", "success" to false
                ))
              }
            } else {
              results.add(mapOf(
                "sector" to sectorIndex, "block" to blockIndex,
                "error" to "Gagal autentikasi sektor", "success" to false
              ))
            }
          }
          sendSuccessToFlutter("onMultiWriteResult", mapOf("results" to results))
        }
        is PendingOperation.None -> { /* Do nothing */ }
      }
    } catch (e: IOException) {
      Log.e(TAG, "IOException saat operasi MIFARE: ${e.message}")
      sendErrorToFlutter("IO_ERROR", "Kesalahan komunikasi dengan tag: ${e.message}")
    } catch (e: Exception) {
      Log.e(TAG, "Exception saat operasi MIFARE: ${e.message}")
      sendErrorToFlutter("UNKNOWN_ERROR", "Terjadi kesalahan: ${e.message}")
    } finally {
      try {
        mifare.close()
      } catch (e: IOException) {
        Log.e(TAG, "Error saat menutup koneksi MIFARE: ${e.message}")
      }
    }
  }

  private fun sendSuccessToFlutter(method: String, data: Map<String, Any>) {
    uiThreadHandler.post {
      channel?.invokeMethod(method, data)
    }
  }

  private fun sendErrorToFlutter(errorCode: String, errorMessage: String) {
    uiThreadHandler.post {
      channel?.invokeMethod("onError", mapOf(
        "errorCode" to errorCode,
        "errorMessage" to errorMessage
      ))
    }
  }

  private fun hexStringToByteArray(hex: String): ByteArray {
    val len = hex.length
    val data = ByteArray(len / 2)
    var i = 0
    while (i < len) {
      data[i / 2] = ((Character.digit(hex[i], 16) shl 4) + Character.digit(hex[i + 1], 16)).toByte()
      i += 2
    }
    return data
  }

  private fun byteArrayToHexString(bytes: ByteArray): String {
    val hexChars = CharArray(bytes.size * 2)
    for (j in bytes.indices) {
      val v = bytes[j].toInt() and 0xFF
      hexChars[j * 2] = "0123456789ABCDEF"[v ushr 4]
      hexChars[j * 2 + 1] = "0123456789ABCDEF"[v and 0x0F]
    }
    return String(hexChars)
  }
}
