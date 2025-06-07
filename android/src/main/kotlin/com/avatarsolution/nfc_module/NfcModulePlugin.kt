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
import java.nio.charset.Charset
import java.util.Arrays
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

  private val uiThreadHandler = Handler(Looper.getMainLooper())

  private var sessionTagId: ByteArray? = null
  private var pendingOperation: PendingOperation = PendingOperation.None

  private val nfcStateReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
      if (intent.action == NfcAdapter.ACTION_ADAPTER_STATE_CHANGED) {
        val state = intent.getIntExtra(NfcAdapter.EXTRA_ADAPTER_STATE, NfcAdapter.STATE_OFF)
        when (state) {
          NfcAdapter.STATE_ON -> {
            Log.d(TAG, "NFC diaktifkan oleh pengguna. Mencoba setup ulang.")
            setupNfc()
          }
          NfcAdapter.STATE_OFF -> {
            Log.d(TAG, "NFC dinonaktifkan oleh pengguna. Membersihkan resource.")
            tearDownNfc()
          }
        }
      }
    }
  }

  sealed class PendingOperation {
    object None : PendingOperation()
    data class ReadMultiple(
      val originalTargets: List<Map<String, Int>>,
      var pendingTargets: MutableList<Map<String, Int>>,
      val accumulatedResults: MutableList<Map<String, Any>>,
      val key: ByteArray
    ) : PendingOperation()
    data class WriteMultiple(
      val originalTargets: List<Map<String, Any>>,
      var pendingTargets: MutableList<Map<String, Any>>,
      val accumulatedResults: MutableList<Map<String, Any>>,
      val key: ByteArray
    ) : PendingOperation()
    data class Reset(
      var totalSectors: Int?,
      var pendingSectors: MutableList<Int>,
      val completedSectors: MutableList<Int>,
      val key: ByteArray
    ) : PendingOperation()
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
    sessionTagId = null
    pendingOperation = PendingOperation.None

    try {
      when (call.method) {
        "getPlatformVersion" -> {
          result.success("Android ${android.os.Build.VERSION.RELEASE}")
        }
        "prepareReadMultipleBlocks" -> {
          val targets = call.argument<List<Map<String, Int>>>("targets")!!
          val keyHex = call.argument<String>("keyHex")!!
          pendingOperation = PendingOperation.ReadMultiple(
            originalTargets = targets, pendingTargets = targets.toMutableList(),
            accumulatedResults = mutableListOf(), key = hexStringToByteArray(keyHex)
          )
          result.success("Sesi baca ganda dimulai. Tempelkan tag.")
        }
        "prepareWriteMultipleBlocks" -> {
          val targets = call.argument<List<Map<String, Any>>>("targets")!!
          val keyHex = call.argument<String>("keyHex")!!
          pendingOperation = PendingOperation.WriteMultiple(
            originalTargets = targets, pendingTargets = targets.toMutableList(),
            accumulatedResults = mutableListOf(), key = hexStringToByteArray(keyHex)
          )
          result.success("Sesi tulis ganda dimulai. Tempelkan tag.")
        }
        "prepareResetCard" -> {
          val keyHex = call.argument<String>("keyHex")!!
          pendingOperation = PendingOperation.Reset(
            totalSectors = null, // Akan diisi saat tag pertama kali terdeteksi
            pendingSectors = mutableListOf(), completedSectors = mutableListOf(),
            key = hexStringToByteArray(keyHex)
          )
          result.success("Sesi reset dimulai. Tempelkan tag.")
        }
        "cancelOperation" -> {
          result.success("Operasi dibatalkan.")
        }
        else -> result.notImplemented()
      }
    } catch (e: Exception) {
      result.error("ARGUMENT_ERROR", "Argumen tidak valid: ${e.message}", null)
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    currentActivity = binding.activity
    val filter = IntentFilter(NfcAdapter.ACTION_ADAPTER_STATE_CHANGED)
    currentActivity?.registerReceiver(nfcStateReceiver, filter)
    setupNfc()
  }

  override fun onDetachedFromActivity() {
    try {
      currentActivity?.unregisterReceiver(nfcStateReceiver)
    } catch (e: IllegalArgumentException) {
      Log.w(TAG, "NFC state receiver tidak terdaftar atau sudah dilepas.")
    }
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
    if (nfcAdapter == null) nfcAdapter = NfcAdapter.getDefaultAdapter(activity)

    if (nfcAdapter == null) {
      sendErrorToFlutter("NO_NFC_SUPPORT", "Perangkat tidak memiliki hardware NFC.")
      return
    }

    if (nfcAdapter?.isEnabled == false) {
      sendErrorToFlutter("NFC_DISABLED", "NFC tidak aktif. Mohon aktifkan di pengaturan.")
      return
    }

    nfcAdapter?.enableReaderMode(activity, this, NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK, null)
    Log.d(TAG, "NFC Reader Mode diaktifkan.")
  }

  private fun tearDownNfc() {
    currentActivity?.let {
      try {
        nfcAdapter?.disableReaderMode(currentActivity!!)
        Log.d(TAG, "NFC Reader Mode dinonaktifkan.")
      } catch (e: IllegalArgumentException) {
        Log.i(TAG, "Receiver tidak terdaftar atau sudah dilepas: ${e.message}")
      } catch (e: Exception) {
        Log.e(TAG, "Error saat teardown NFC: ${e.message}")
      }
    }
  }

  override fun onTagDiscovered(tag: Tag?) {
    Log.d(TAG, "NFC Tag Ditemukan!")
    tag ?: return
    val currentOperation = pendingOperation
    if (currentOperation is PendingOperation.None) return
    thread { handleMifareSession(tag, currentOperation) }
  }


  private fun handleMifareSession(tag: Tag, operation: PendingOperation) {
    if (sessionTagId == null) {
      sessionTagId = tag.id
    } else if (!Arrays.equals(sessionTagId, tag.id)) {
      sendErrorToFlutter("WRONG_TAG", "Tag yang berbeda terdeteksi. Sesi dibatalkan.")
      pendingOperation = PendingOperation.None; sessionTagId = null
      return
    }

    val mifare = MifareClassic.get(tag)
    if (mifare == null) {
      sendErrorToFlutter("TAG_NOT_SUPPORTED", "Tag ini bukan MIFARE Classic.")
      return
    }

    try {
      mifare.connect()
      when (operation) {
        is PendingOperation.ReadMultiple -> processReadMultiple(mifare, operation)
        is PendingOperation.WriteMultiple -> processWriteMultiple(mifare, operation)
        is PendingOperation.Reset -> processReset(mifare, operation)
        is PendingOperation.None -> {}
      }
    } catch (e: Exception) {
      Log.e(TAG, "Koneksi ke tag terputus atau error lain: ${e.message}")
    } finally {
      try { mifare.close() } catch (e: IOException) { /* Abaikan error saat menutup */ }
    }
  }

  private fun processReadMultiple(mifare: MifareClassic, session: PendingOperation.ReadMultiple) {
    val authenticatedSectors = mutableSetOf<Int>()
    val targetsToProcess = ArrayList(session.pendingTargets)

    for (target in targetsToProcess) {
      val sectorIndex = target["sectorIndex"]!!
      val blockIndex = target["blockIndex"]!!

      var authSuccess = authenticatedSectors.contains(sectorIndex)
      if (!authSuccess) {
        if (mifare.authenticateSectorWithKeyA(sectorIndex, session.key)) {
          authenticatedSectors.add(sectorIndex)
          authSuccess = true
        }
      }
      if (authSuccess) {
        try {
          val absoluteBlockIndex = mifare.sectorToBlock(sectorIndex) + blockIndex
          val blockData = mifare.readBlock(absoluteBlockIndex)
          session.accumulatedResults.add(mapOf("sector" to sectorIndex, "block" to blockIndex, "dataHex" to byteArrayToString(blockData), "success" to true))
          session.pendingTargets.remove(target)
        } catch (e: IOException) { /* Gagal baca, jangan hapus. Coba lagi nanti. */ }
      }
    }

    if (session.pendingTargets.isEmpty()) {
      sendSuccessToFlutter("onMultiReadResult", mapOf("results" to session.accumulatedResults))
      pendingOperation = PendingOperation.None; sessionTagId = null
    } else {
      sendProgressUpdate("onReadProgressUpdate", session.originalTargets.size, session.accumulatedResults.size)
    }
  }

  private fun processWriteMultiple(mifare: MifareClassic, session: PendingOperation.WriteMultiple) {
    val authenticatedSectors = mutableSetOf<Int>()
    val targetsToProcess = ArrayList(session.pendingTargets)

    for (target in targetsToProcess) {
      val sector = target["sectorIndex"] as Int
      val block = target["blockIndex"] as Int
      val dataString = target["dataString"] as String

      val sectorTrailer = mifare.getBlockCountInSector(sector) - 1
      if (block == sectorTrailer || (sector == 0 && block == 0)) {
        session.accumulatedResults.add(mapOf("sector" to sector, "block" to block, "error" to "Penulisan ke blok sistem dilarang", "success" to false))
        session.pendingTargets.remove(target)
        continue
      }

      var authSuccess = authenticatedSectors.contains(sector)
      if (!authSuccess) {
        if (mifare.authenticateSectorWithKeyA(sector, session.key)) {
          authenticatedSectors.add(sector)
          authSuccess = true
        }
      }

      if (authSuccess) {
        try {
          val absoluteBlockIndex = mifare.sectorToBlock(sector) + block
          mifare.writeBlock(absoluteBlockIndex, plainStringToPaddedByteArray(dataString))
          session.accumulatedResults.add(mapOf("sector" to sector, "block" to block, "success" to true))
          session.pendingTargets.remove(target)
        } catch (e: IOException) { /* Gagal tulis, jangan hapus. Coba lagi nanti. */ }
      }
    }

    if (session.pendingTargets.isEmpty()) {
      sendSuccessToFlutter("onMultiWriteResult", mapOf("results" to session.accumulatedResults))
      pendingOperation = PendingOperation.None; sessionTagId = null
    } else {
      sendProgressUpdate("onWriteProgressUpdate", session.originalTargets.size, session.accumulatedResults.size)
    }
  }

  private fun processReset(mifare: MifareClassic, session: PendingOperation.Reset) {
    if (session.totalSectors == null) {
      session.totalSectors = mifare.sectorCount
      session.pendingSectors = (0 until mifare.sectorCount).toMutableList()
    }

    val sectorsToProcess = ArrayList(session.pendingSectors)
    val zeroData = ByteArray(16)

    for (sector in sectorsToProcess) {
      if (mifare.authenticateSectorWithKeyA(sector, session.key)) {
        val blockCount = mifare.getBlockCountInSector(sector)
        for (j in 0 until blockCount) {
          val trailerBlockIndex = blockCount - 1
          if (j == trailerBlockIndex || (sector == 0 && j == 0)) continue

          val blockIndex = mifare.sectorToBlock(sector) + j
          try {
            mifare.writeBlock(blockIndex, zeroData)
          } catch(e: IOException) {
            // Jika satu blok gagal ditulis, anggap seluruh sektor gagal untuk dicoba lagi
            // Keluar dari inner loop dan jangan hapus sektor dari pending list
            return
          }
        }
        session.pendingSectors.remove(sector)
        session.completedSectors.add(sector)
      }
    }

    if (session.pendingSectors.isEmpty()) {
      sendSuccessToFlutter("onResetResult", mapOf("sectorsReset" to session.completedSectors.size))
      pendingOperation = PendingOperation.None; sessionTagId = null
    } else {
      sendProgressUpdate("onResetProgressUpdate", session.totalSectors!!, session.completedSectors.size)
    }
  }

  private fun sendProgressUpdate(method: String, total: Int, completed: Int) {
    uiThreadHandler.post {
      channel?.invokeMethod(method, mapOf("total" to total, "completed" to completed))
    }
  }

  private fun sendSuccessToFlutter(method: String, data: Map<String, Any>) {
    uiThreadHandler.post { channel?.invokeMethod(method, data) }
  }
  private fun sendErrorToFlutter(errorCode: String, errorMessage: String) {
    uiThreadHandler.post { channel?.invokeMethod("onError", mapOf("errorCode" to errorCode, "errorMessage" to errorMessage)) }
  }
  private fun plainStringToPaddedByteArray(s: String): ByteArray {
    val sourceBytes = s.toByteArray(Charset.forName("UTF-8"))
    val resultBytes = ByteArray(16)
    Arrays.fill(resultBytes, 0x20.toByte())
    System.arraycopy(sourceBytes, 0, resultBytes, 0, minOf(sourceBytes.size, resultBytes.size))
    return resultBytes
  }
  private fun byteArrayToString(a: ByteArray): String {
    val sb = StringBuilder(a.size * 2)
    for (b in a) {
      sb.append(String.format("%02X", b))
    }
    return sb.toString()
  }
  private fun hexStringToByteArray(s: String): ByteArray {
    val len = s.length; val data = ByteArray(len / 2)
    var i = 0
    while (i < len) {
      data[i / 2] = ((Character.digit(s[i], 16) shl 4) + Character.digit(s[i + 1], 16)).toByte()
      i += 2
    }
    return data
  }
}
