package com.f2a.app

import org.json.JSONArray
import org.json.JSONObject
import java.nio.charset.StandardCharsets
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import kotlin.math.pow

data class TokenRecord(
    val id: String,
    var issuer: String,
    var account: String,
    val secret: String,
    val type: String = "totp",
    val algorithm: String = "SHA1",
    val digits: Int = 6,
    val period: Int = 30,
    var counter: Long = 0
) {
    fun displayName(): String {
        return when {
            issuer.isNotBlank() && account.isNotBlank() -> "$issuer · $account"
            issuer.isNotBlank() -> issuer
            account.isNotBlank() -> account
            else -> "未命名令牌"
        }
    }

    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("issuer", issuer)
        put("account", account)
        put("secret", secret)
        put("type", type)
        put("algorithm", algorithm)
        put("digits", digits)
        put("period", period)
        put("counter", counter)
    }

    companion object {
        fun fromJson(obj: JSONObject): TokenRecord = TokenRecord(
            id = obj.optString("id"),
            issuer = obj.optString("issuer"),
            account = obj.optString("account"),
            secret = obj.optString("secret"),
            type = obj.optString("type", "totp"),
            algorithm = obj.optString("algorithm", "SHA1"),
            digits = obj.optInt("digits", 6).let { if (it == 8) 8 else 6 },
            period = obj.optInt("period", 30).let { if (it <= 0) 30 else it },
            counter = obj.optLong("counter", 0)
        )
    }
}

object Base32 {
    private const val ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    fun normalize(secret: String): String =
        secret.uppercase().replace(Regex("[\\s=-]"), "")

    fun isValid(secret: String): Boolean {
        val text = normalize(secret)
        if (text.length < 8) return false
        return text.all { ALPHABET.contains(it) }
    }

    fun decode(secret: String): ByteArray {
        val text = normalize(secret)
        var bits = 0
        var value = 0
        val out = ArrayList<Int>()
        for (ch in text) {
            val idx = ALPHABET.indexOf(ch)
            if (idx < 0) continue
            value = (value shl 5) or idx
            bits += 5
            if (bits >= 8) {
                out.add((value shr (bits - 8)) and 0xff)
                bits -= 8
            }
        }
        return ByteArray(out.size) { out[it].toByte() }
    }
}

object OtpEngine {
    fun remaining(period: Int, nowMs: Long = System.currentTimeMillis()): Int {
        val step = if (period > 0) period else 30
        val seconds = nowMs / 1000
        return (step - (seconds % step)).toInt()
    }

    fun formatCode(code: String): String = when (code.length) {
        6 -> "${code.substring(0, 3)} ${code.substring(3)}"
        8 -> "${code.substring(0, 4)} ${code.substring(4)}"
        else -> code
    }

    fun generate(token: TokenRecord, nowMs: Long = System.currentTimeMillis()): String {
        val key = Base32.decode(token.secret)
        if (key.isEmpty()) throw IllegalArgumentException("密钥解码失败")
        val moving = if (token.type == "hotp") token.counter else nowMs / 1000 / token.period
        val counter = ByteArray(8)
        var n = moving
        for (i in 7 downTo 0) {
            counter[i] = (n and 0xff).toByte()
            n = n ushr 8
        }
        val alg = when (token.algorithm.uppercase()) {
            "SHA256" -> "HmacSHA256"
            "SHA512" -> "HmacSHA512"
            else -> "HmacSHA1"
        }
        val mac = Mac.getInstance(alg)
        mac.init(SecretKeySpec(key, alg))
        val digest = mac.doFinal(counter)
        val offset = digest[digest.size - 1].toInt() and 0x0f
        val binary =
            ((digest[offset].toInt() and 0x7f) shl 24) or
                ((digest[offset + 1].toInt() and 0xff) shl 16) or
                ((digest[offset + 2].toInt() and 0xff) shl 8) or
                (digest[offset + 3].toInt() and 0xff)
        val mod = 10.0.pow(token.digits).toInt()
        return (binary % mod).toString().padStart(token.digits, '0')
    }
}

object OtpAuth {
    fun parse(uriText: String): TokenRecord {
        val trimmed = uriText.trim()
        if (!trimmed.lowercase().startsWith("otpauth://")) {
            throw IllegalArgumentException("不是有效的 otpauth 链接")
        }
        val without = trimmed.substring("otpauth://".length)
        val slash = without.indexOf('/')
        if (slash < 0) throw IllegalArgumentException("otpauth 缺少账户路径")
        val typeText = without.substring(0, slash).lowercase()
        val rest = without.substring(slash + 1)
        val q = rest.indexOf('?')
        val labelRaw = if (q >= 0) rest.substring(0, q) else rest
        val query = if (q >= 0) rest.substring(q + 1) else ""
        val params = parseQuery(query)
        val secret = params["secret"].orEmpty()
        if (!Base32.isValid(secret)) throw IllegalArgumentException("密钥无效，请检查 Base32 编码")
        val label = java.net.URLDecoder.decode(labelRaw.replace("+", " "), StandardCharsets.UTF_8.name())
        var issuer = params["issuer"].orEmpty()
        var account = label
        val colon = label.indexOf(':')
        if (colon >= 0) {
            if (issuer.isBlank()) issuer = label.substring(0, colon)
            account = label.substring(colon + 1)
        }
        val algo = params["algorithm"]?.uppercase() ?: "SHA1"
        return TokenRecord(
            id = "${System.currentTimeMillis()}_${(0..99999).random()}",
            issuer = issuer.trim(),
            account = account.trim(),
            secret = Base32.normalize(secret),
            type = if (typeText == "hotp") "hotp" else "totp",
            algorithm = if (algo == "SHA256" || algo == "SHA512") algo else "SHA1",
            digits = if (params["digits"] == "8") 8 else 6,
            period = params["period"]?.toIntOrNull()?.takeIf { it > 0 } ?: 30,
            counter = params["counter"]?.toLongOrNull() ?: 0
        )
    }

    private fun parseQuery(query: String): Map<String, String> {
        if (query.isEmpty()) return emptyMap()
        return query.split("&").mapNotNull { pair ->
            val eq = pair.indexOf('=')
            if (eq <= 0) null
            else java.net.URLDecoder.decode(pair.substring(0, eq), "UTF-8").lowercase() to
                java.net.URLDecoder.decode(pair.substring(eq + 1).replace("+", " "), "UTF-8")
        }.toMap()
    }
}

object TokenStore {
    fun encode(list: List<TokenRecord>): String {
        val arr = JSONArray()
        list.forEach { arr.put(it.toJson()) }
        return arr.toString()
    }

    fun decode(text: String): MutableList<TokenRecord> {
        val arr = JSONArray(text)
        return MutableList(arr.length()) { TokenRecord.fromJson(arr.getJSONObject(it)) }
    }
}
