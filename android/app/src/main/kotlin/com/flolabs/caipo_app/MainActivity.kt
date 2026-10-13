package com.flolabs.caipo_app

import android.content.Intent
import com.flolabs.caipo.BleFlutterApi
import com.flolabs.caipo.BleHostApi
import com.flolabs.caipo.SecureStoreHostApi
import com.flolabs.caipo.ble.BleHostApiImpl
import com.flolabs.caipo.ble.CaipoBleManager
import com.flolabs.caipo.secure.SecureStoreHostApiImpl
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var bleHost: BleHostApiImpl? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val manager = CaipoBleManager.init(application)
        val flutterApi = BleFlutterApi(messenger)
        bleHost = BleHostApiImpl(manager, flutterApi, { this }, applicationContext)
        BleHostApi.setUp(messenger, bleHost)
        SecureStoreHostApi.setUp(messenger, SecureStoreHostApiImpl(filesDir))
    }

    @Deprecated("FlutterActivity still delivers the Bluetooth enable result here.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        bleHost?.onActivityResult(requestCode, resultCode)
    }
}
