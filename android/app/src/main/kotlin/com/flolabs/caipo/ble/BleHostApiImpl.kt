package com.flolabs.caipo.ble

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.Intent
import android.provider.Settings
import com.flolabs.caipo.BleFlutterApi
import com.flolabs.caipo.BleHostApi
import com.flolabs.caipo.BlePeripheral
import com.flolabs.caipo.BleService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class BleHostApiImpl(
    private val manager: CaipoBleManager,
    private val flutterApi: BleFlutterApi,
    private val activity: () -> Activity?,
    private val context: Context,
) : BleHostApi, CaipoBleManager.Callbacks {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var enableContinuation: ((Boolean) -> Unit)? = null

    init {
        manager.setCallbacks(this)
    }

    override fun startScan(timeoutSeconds: Long, serviceUuids: List<String>) {
        manager.startScan(timeoutSeconds.toInt(), serviceUuids)
    }

    override fun stopScan() = manager.stopScan()

    override fun manageDevice(uuid: String, requiresBond: Boolean) {
        CaipoBleForegroundService.start(context, uuid)
    }

    override fun unmanageDevice(uuid: String) {
        manager.disconnect(uuid, "cancelled")
        CaipoBleForegroundService.stop(context)
    }

    override suspend fun requestBond(uuid: String): Boolean = suspendCancellableCoroutine { continuation ->
        manager.bond(uuid) { bonded ->
            if (continuation.isActive) continuation.resume(bonded)
        }
    }

    override suspend fun readCharacteristic(
        peripheralUuid: String,
        serviceUuid: String,
        characteristicUuid: String,
    ): ByteArray = suspendCancellableCoroutine { continuation ->
        manager.read(peripheralUuid, serviceUuid, characteristicUuid) { result ->
            result.fold(
                onSuccess = { if (continuation.isActive) continuation.resume(it) },
                onFailure = { if (continuation.isActive) continuation.resumeWithException(it) },
            )
        }
    }

    override suspend fun writeCharacteristic(
        peripheralUuid: String,
        serviceUuid: String,
        characteristicUuid: String,
        data: ByteArray,
    ) {
        suspendCancellableCoroutine { continuation ->
            manager.write(peripheralUuid, serviceUuid, characteristicUuid, data) { result ->
                result.fold(
                    onSuccess = { if (continuation.isActive) continuation.resume(Unit) },
                    onFailure = { if (continuation.isActive) continuation.resumeWithException(it) },
                )
            }
        }
    }

    override suspend fun subscribeCharacteristic(
        peripheralUuid: String,
        serviceUuid: String,
        characteristicUuid: String,
    ) {
        suspendCancellableCoroutine { continuation ->
            manager.subscribe(peripheralUuid, serviceUuid, characteristicUuid) { result ->
                result.fold(
                    onSuccess = { if (continuation.isActive) continuation.resume(Unit) },
                    onFailure = { if (continuation.isActive) continuation.resumeWithException(it) },
                )
            }
        }
    }

    override fun unsubscribeCharacteristic(peripheralUuid: String, serviceUuid: String, characteristicUuid: String) {
        manager.unsubscribe(peripheralUuid, serviceUuid, characteristicUuid)
    }

    override fun getBluetoothState(): String = manager.bluetoothState()

    override suspend fun enableBluetooth(): Boolean = suspendCancellableCoroutine { continuation ->
        if (manager.bluetoothState() == "on") {
            continuation.resume(true)
            return@suspendCancellableCoroutine
        }
        val host = activity()
        if (host == null) {
            continuation.resume(false)
            return@suspendCancellableCoroutine
        }
        enableContinuation = { enabled ->
            if (continuation.isActive) continuation.resume(enabled)
        }
        try {
            host.startActivityForResult(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE), REQUEST_ENABLE_BT)
        } catch (_: Exception) {
            enableContinuation = null
            if (continuation.isActive) continuation.resume(false)
        }
    }

    override fun isPeripheralConnected(uuid: String): Boolean = manager.isConnected(uuid)

    override suspend fun maximumWriteLength(peripheralUuid: String): Long {
        return manager.maximumWriteLength(peripheralUuid).toLong()
    }

    override fun startRssiStreaming(uuid: String) = manager.startRssi(uuid)

    override fun stopRssiStreaming(uuid: String) = manager.stopRssi()

    override fun openBluetoothSettings() {
        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int) {
        if (requestCode != REQUEST_ENABLE_BT) return
        val callback = enableContinuation
        enableContinuation = null
        callback?.invoke(resultCode == Activity.RESULT_OK)
    }

    override fun onBluetoothState(state: String) = emit { flutterApi.onBluetoothStateChanged(state) }

    override fun onDiscovered(uuid: String, name: String, rssi: Int, serviceUuids: List<String>) = emit {
        flutterApi.onPeripheralDiscovered(BlePeripheral(uuid, name, rssi.toLong(), serviceUuids))
    }

    override fun onReady(uuid: String, services: List<CaipoBleManager.DiscoveredService>) = emit {
        flutterApi.onDeviceReady(
            uuid,
            services.map { BleService(it.uuid, it.characteristics) },
        )
    }

    override fun onDisconnected(uuid: String, error: String?) = emit {
        flutterApi.onPeripheralDisconnected(uuid, error)
    }

    override fun onValue(uuid: String, serviceUuid: String, characteristicUuid: String, value: ByteArray) = emit {
        flutterApi.onCharacteristicValueUpdated(uuid, serviceUuid, characteristicUuid, value)
    }

    override fun onRssi(uuid: String, rssi: Int) = emit { flutterApi.onRssiUpdate(uuid, rssi.toLong()) }

    private fun emit(block: suspend () -> Unit) {
        scope.launch {
            try {
                block()
            } catch (_: Exception) {
            }
        }
    }

    companion object {
        private const val REQUEST_ENABLE_BT = 43
    }
}
