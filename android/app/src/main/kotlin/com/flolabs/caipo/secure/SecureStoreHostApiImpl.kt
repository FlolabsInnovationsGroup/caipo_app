package com.flolabs.caipo.secure

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.flolabs.caipo.SecureStoreHostApi
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * AES-GCM key in the Android Keystore. Ciphertext lives in an app-private
 * file, never in SharedPreferences.
 */
class SecureStoreHostApiImpl(filesDir: File) : SecureStoreHostApi {
    private val storeFile = File(filesDir, "caipo_tokens.bin")

    override suspend fun write(key: String, value: String) {
        val map = readMap().toMutableMap()
        map[key] = encrypt(value)
        writeMap(map)
    }

    override suspend fun read(key: String): String? {
        val stored = readMap()[key] ?: return null
        return decrypt(stored)
    }

    override suspend fun delete(key: String) {
        val map = readMap().toMutableMap()
        map.remove(key)
        writeMap(map)
    }

    override suspend fun deleteAll() {
        if (storeFile.exists()) storeFile.delete()
    }

    private fun secret(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val existing = keyStore.getKey(ALIAS, null) as? SecretKey
        if (existing != null) return existing
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    private fun encrypt(plain: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secret())
        val iv = cipher.iv
        val cipherText = cipher.doFinal(plain.toByteArray(Charsets.UTF_8))
        val packed = ByteArray(iv.size + cipherText.size)
        System.arraycopy(iv, 0, packed, 0, iv.size)
        System.arraycopy(cipherText, 0, packed, iv.size, cipherText.size)
        return Base64.encodeToString(packed, Base64.NO_WRAP)
    }

    private fun decrypt(packedBase64: String): String {
        val packed = Base64.decode(packedBase64, Base64.NO_WRAP)
        val iv = packed.copyOfRange(0, 12)
        val cipherText = packed.copyOfRange(12, packed.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, secret(), GCMParameterSpec(128, iv))
        return String(cipher.doFinal(cipherText), Charsets.UTF_8)
    }

    private fun readMap(): Map<String, String> {
        if (!storeFile.exists()) return emptyMap()
        return storeFile.readLines().mapNotNull { line ->
            val parts = line.split("=", limit = 2)
            if (parts.size == 2) parts[0] to parts[1] else null
        }.toMap()
    }

    private fun writeMap(map: Map<String, String>) {
        storeFile.parentFile?.mkdirs()
        storeFile.writeText(map.entries.joinToString("\n") { "${it.key}=${it.value}" })
    }

    companion object {
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val ALIAS = "caipo.token.kek"
    }
}
