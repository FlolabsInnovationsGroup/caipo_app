package com.flolabs.caipo.ble

import android.annotation.SuppressLint
import android.app.Application
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import androidx.core.content.ContextCompat
import java.util.ArrayDeque
import java.util.UUID

/**
 * GATT client adapted from the shape of OMI's native BLE manager (MIT).
 * CAIPO does not impersonate OMI device identifiers. Service UUIDs are
 * supplied by Dart from constants.dart.
 */
class CaipoBleManager private constructor(private val app: Application) {
    interface Callbacks {
        fun onBluetoothState(state: String)
        fun onDiscovered(uuid: String, name: String, rssi: Int, serviceUuids: List<String>)
        fun onReady(uuid: String, services: List<DiscoveredService>)
        fun onDisconnected(uuid: String, error: String?)
        fun onValue(uuid: String, serviceUuid: String, characteristicUuid: String, value: ByteArray)
        fun onRssi(uuid: String, rssi: Int)
    }

    data class DiscoveredService(val uuid: String, val characteristics: List<String>)

    private val main = Handler(Looper.getMainLooper())
    private val bluetoothManager = app.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val adapter: BluetoothAdapter? get() = bluetoothManager.adapter
    private val gatts = HashMap<String, BluetoothGatt>()
    private val queue = ArrayDeque<Runnable>()
    private var busy = false
    private var scanning = false
    private var scanCallback: ScanCallback? = null
    private var scanTimeout: Runnable? = null
    private val reads = HashMap<String, (Result<ByteArray>) -> Unit>()
    private val writes = HashMap<String, (Result<Unit>) -> Unit>()
    private val subscribes = HashMap<String, (Result<Unit>) -> Unit>()
    private val readySent = HashSet<String>()
    private var rssiAddress: String? = null
    private var callbacks: Callbacks? = null
    var connectTimeoutMs: Long = 30_000

    private val stateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != BluetoothAdapter.ACTION_STATE_CHANGED) return
            val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
            callbacks?.onBluetoothState(stateName(state))
        }
    }

    init {
        ContextCompat.registerReceiver(
            app,
            stateReceiver,
            IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    fun setCallbacks(callbacks: Callbacks) {
        this.callbacks = callbacks
    }

    fun bluetoothState(): String {
        val radio = adapter ?: return "unsupported"
        return stateName(radio.state)
    }

    @SuppressLint("MissingPermission")
    fun startScan(timeoutSeconds: Int, serviceUuids: List<String>) {
        val radio = adapter ?: return
        if (!radio.isEnabled) {
            callbacks?.onBluetoothState("off")
            return
        }
        if (!hasScanPermission()) return
        stopScan()
        val scanner = radio.bluetoothLeScanner ?: return
        val filters = serviceUuids.mapNotNull { raw ->
            try {
                ScanFilter.Builder().setServiceUuid(ParcelUuid(UUID.fromString(raw))).build()
            } catch (_: IllegalArgumentException) {
                null
            }
        }
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val device = result.device ?: return
                val record = result.scanRecord
                callbacks?.onDiscovered(
                    device.address.uppercase(),
                    record?.deviceName ?: device.name ?: "",
                    result.rssi,
                    record?.serviceUuids?.map { it.uuid.toString() } ?: emptyList(),
                )
            }

            override fun onScanFailed(errorCode: Int) {
                Log.w(TAG, "scan failed: $errorCode")
            }
        }
        scanCallback = callback
        scanning = true
        if (filters.isEmpty()) scanner.startScan(null, settings, callback) else scanner.startScan(filters, settings, callback)
        if (timeoutSeconds > 0) {
            val timeout = Runnable { stopScan() }
            scanTimeout = timeout
            main.postDelayed(timeout, timeoutSeconds * 1000L)
        }
    }

    @SuppressLint("MissingPermission")
    fun stopScan() {
        if (!scanning) return
        scanning = false
        scanTimeout?.let { main.removeCallbacks(it) }
        scanTimeout = null
        scanCallback?.let { callback ->
            try {
                adapter?.bluetoothLeScanner?.stopScan(callback)
            } catch (error: Exception) {
                Log.w(TAG, "stopScan: ${error.message}")
            }
        }
        scanCallback = null
    }

    @SuppressLint("MissingPermission")
    fun connect(address: String) {
        val radio = adapter ?: return
        val normalized = address.uppercase()
        readySent.remove(normalized)
        val device = radio.getRemoteDevice(normalized)
        val gatt = device.connectGatt(app, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        if (gatt != null) gatts[normalized] = gatt
        main.postDelayed({
            if (!readySent.contains(normalized) && gatts.containsKey(normalized)) {
                disconnect(normalized, "timeout")
            }
        }, connectTimeoutMs)
    }

    @SuppressLint("MissingPermission")
    fun disconnect(address: String, error: String?) {
        val normalized = address.uppercase()
        val gatt = gatts.remove(normalized) ?: return
        readySent.remove(normalized)
        try {
            gatt.disconnect()
            gatt.close()
        } catch (_: Exception) {
        }
        callbacks?.onDisconnected(normalized, error)
    }

    fun isConnected(address: String): Boolean {
        val gatt = gatts[address.uppercase()] ?: return false
        return bluetoothManager.getConnectionState(gatt.device, BluetoothProfile.GATT) == BluetoothProfile.STATE_CONNECTED
    }

    @SuppressLint("MissingPermission")
    fun read(address: String, serviceUuid: String, characteristicUuid: String, done: (Result<ByteArray>) -> Unit) {
        val gatt = gatts[address.uppercase()]
        val characteristic = find(gatt, serviceUuid, characteristicUuid)
        if (gatt == null || characteristic == null) {
            done(Result.failure(IllegalStateException("Characteristic not found")))
            return
        }
        val key = key(address, serviceUuid, characteristicUuid)
        reads[key] = done
        enqueue {
            if (!gatt.readCharacteristic(characteristic)) {
                reads.remove(key)
                done(Result.failure(IllegalStateException("Read rejected")))
                completeQueue()
            }
        }
    }

    @SuppressLint("MissingPermission")
    fun write(
        address: String,
        serviceUuid: String,
        characteristicUuid: String,
        data: ByteArray,
        done: (Result<Unit>) -> Unit,
    ) {
        val gatt = gatts[address.uppercase()]
        val characteristic = find(gatt, serviceUuid, characteristicUuid)
        if (gatt == null || characteristic == null) {
            done(Result.failure(IllegalStateException("Characteristic not found")))
            return
        }
        val key = key(address, serviceUuid, characteristicUuid)
        writes[key] = done
        enqueue {
            characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            val started = if (Build.VERSION.SDK_INT >= 33) {
                gatt.writeCharacteristic(characteristic, data, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT) == BluetoothGatt.GATT_SUCCESS
            } else {
                @Suppress("DEPRECATION")
                characteristic.value = data
                @Suppress("DEPRECATION")
                gatt.writeCharacteristic(characteristic)
            }
            if (!started) {
                writes.remove(key)
                done(Result.failure(IllegalStateException("Write rejected")))
                completeQueue()
            }
        }
    }

    @SuppressLint("MissingPermission")
    fun subscribe(address: String, serviceUuid: String, characteristicUuid: String, done: (Result<Unit>) -> Unit) {
        val gatt = gatts[address.uppercase()]
        val characteristic = find(gatt, serviceUuid, characteristicUuid)
        if (gatt == null || characteristic == null) {
            done(Result.failure(IllegalStateException("Characteristic not found")))
            return
        }
        val key = key(address, serviceUuid, characteristicUuid)
        subscribes[key] = done
        enqueue {
            gatt.setCharacteristicNotification(characteristic, true)
            val cccd = characteristic.getDescriptor(CCCD)
            if (cccd == null) {
                subscribes.remove(key)
                done(Result.success(Unit))
                completeQueue()
                return@enqueue
            }
            val value = BluetoothGattCharacteristic.ENABLE_NOTIFICATION_VALUE
            val started = if (Build.VERSION.SDK_INT >= 33) {
                gatt.writeDescriptor(cccd, value) == BluetoothGatt.GATT_SUCCESS
            } else {
                @Suppress("DEPRECATION")
                cccd.value = value
                @Suppress("DEPRECATION")
                gatt.writeDescriptor(cccd)
            }
            if (!started) {
                subscribes.remove(key)
                done(Result.failure(IllegalStateException("Notify rejected")))
                completeQueue()
            }
        }
    }

    @SuppressLint("MissingPermission")
    fun unsubscribe(address: String, serviceUuid: String, characteristicUuid: String) {
        val gatt = gatts[address.uppercase()] ?: return
        val characteristic = find(gatt, serviceUuid, characteristicUuid) ?: return
        gatt.setCharacteristicNotification(characteristic, false)
    }

    fun startRssi(address: String) {
        rssiAddress = address.uppercase()
        sampleRssi()
    }

    fun stopRssi() {
        rssiAddress = null
    }

    @SuppressLint("MissingPermission")
    private fun sampleRssi() {
        val address = rssiAddress ?: return
        gatts[address]?.readRemoteRssi()
        main.postDelayed({ if (rssiAddress == address) sampleRssi() }, 1000)
    }

    private val gattCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            val address = gatt.device.address.uppercase()
            main.post {
                if (gatts[address] !== gatt && newState == BluetoothProfile.STATE_CONNECTED) return@post
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        gatts[address] = gatt
                        gatt.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH)
                        enqueue {
                            if (!gatt.discoverServices()) completeQueue()
                        }
                    }
                    BluetoothProfile.STATE_DISCONNECTED -> {
                        val error = if (readySent.contains(address) || status == 8 || status == 19 || status == 22) {
                            "link_lost"
                        } else if (status == BluetoothGatt.GATT_SUCCESS) {
                            "cancelled"
                        } else {
                            "gatt_discovery_failed"
                        }
                        disconnect(address, error)
                    }
                }
            }
        }

        @SuppressLint("MissingPermission")
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            val address = gatt.device.address.uppercase()
            main.post {
                completeQueue()
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    disconnect(address, "gatt_discovery_failed")
                    return@post
                }
                enqueue {
                    if (!gatt.requestMtu(512)) completeQueue()
                }
            }
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            val address = gatt.device.address.uppercase()
            main.post {
                completeQueue()
                if (readySent.contains(address)) return@post
                readySent.add(address)
                val services = gatt.services.orEmpty().map { service ->
                    DiscoveredService(
                        service.uuid.toString().lowercase(),
                        service.characteristics.map { it.uuid.toString().lowercase() },
                    )
                }
                callbacks?.onReady(address, services)
            }
        }

        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray, status: Int) {
            deliverRead(gatt, characteristic, value, status)
        }

        @Deprecated("Deprecated in API 33")
        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            @Suppress("DEPRECATION")
            deliverRead(gatt, characteristic, characteristic.value ?: ByteArray(0), status)
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            val key = key(gatt.device.address, characteristic.service.uuid.toString(), characteristic.uuid.toString())
            main.post {
                val done = writes.remove(key)
                if (status == BluetoothGatt.GATT_SUCCESS) done?.invoke(Result.success(Unit))
                else done?.invoke(Result.failure(IllegalStateException("Write failed: $status")))
                completeQueue()
            }
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: android.bluetooth.BluetoothGattDescriptor, status: Int) {
            val characteristic = descriptor.characteristic
            val key = key(gatt.device.address, characteristic.service.uuid.toString(), characteristic.uuid.toString())
            main.post {
                val done = subscribes.remove(key)
                if (status == BluetoothGatt.GATT_SUCCESS) done?.invoke(Result.success(Unit))
                else done?.invoke(Result.failure(IllegalStateException("Subscribe failed: $status")))
                completeQueue()
            }
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            emitValue(gatt, characteristic, value)
        }

        @Deprecated("Deprecated in API 33")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            @Suppress("DEPRECATION")
            emitValue(gatt, characteristic, characteristic.value ?: ByteArray(0))
        }

        override fun onReadRemoteRssi(gatt: BluetoothGatt, rssi: Int, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                callbacks?.onRssi(gatt.device.address.uppercase(), rssi)
            }
        }
    }

    private fun deliverRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray, status: Int) {
        val key = key(gatt.device.address, characteristic.service.uuid.toString(), characteristic.uuid.toString())
        main.post {
            val done = reads.remove(key)
            if (status == BluetoothGatt.GATT_SUCCESS) done?.invoke(Result.success(value))
            else done?.invoke(Result.failure(IllegalStateException("Read failed: $status")))
            completeQueue()
        }
    }

    private fun emitValue(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
        callbacks?.onValue(
            gatt.device.address.uppercase(),
            characteristic.service.uuid.toString().lowercase(),
            characteristic.uuid.toString().lowercase(),
            value.copyOf(),
        )
    }

    private fun enqueue(command: Runnable) {
        main.post {
            queue.add(command)
            drain()
        }
    }

    private fun drain() {
        if (busy) return
        val command = queue.poll() ?: return
        busy = true
        command.run()
    }

    private fun completeQueue() {
        busy = false
        drain()
    }

    private fun find(gatt: BluetoothGatt?, serviceUuid: String, characteristicUuid: String): BluetoothGattCharacteristic? {
        val service = gatt?.getService(UUID.fromString(serviceUuid)) ?: return null
        return service.getCharacteristic(UUID.fromString(characteristicUuid))
    }

    private fun key(address: String, serviceUuid: String, characteristicUuid: String) =
        "${address.uppercase()}:${serviceUuid.lowercase()}:${characteristicUuid.lowercase()}"

    private fun hasScanPermission(): Boolean {
        if (Build.VERSION.SDK_INT < 31) return true
        return ContextCompat.checkSelfPermission(app, android.Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
    }

    private fun stateName(state: Int): String = when (state) {
        BluetoothAdapter.STATE_ON -> "on"
        BluetoothAdapter.STATE_OFF -> "off"
        BluetoothAdapter.STATE_TURNING_ON -> "turning_on"
        BluetoothAdapter.STATE_TURNING_OFF -> "turning_off"
        else -> "unknown"
    }

    companion object {
        private const val TAG = "CaipoBle"
        private val CCCD: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        lateinit var instance: CaipoBleManager
            private set

        fun init(application: Application): CaipoBleManager {
            if (!::instance.isInitialized) instance = CaipoBleManager(application)
            return instance
        }
    }
}
