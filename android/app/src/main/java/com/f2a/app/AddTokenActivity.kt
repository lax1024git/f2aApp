package com.f2a.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputEditText
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions

class AddTokenActivity : AppCompatActivity() {
    private lateinit var uriInput: TextInputEditText
    private lateinit var issuerInput: TextInputEditText
    private lateinit var accountInput: TextInputEditText
    private lateinit var secretInput: TextInputEditText

    private val scanner = registerForActivityResult(ScanContract()) { result ->
        val text = result.contents ?: return@registerForActivityResult
        uriInput.setText(text)
        applyUri(text)
    }

    private val cameraPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            launchScanner()
        } else {
            Toast.makeText(this, "需要相机权限才能扫码", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_add)
        findViewById<MaterialToolbar>(R.id.toolbar).setNavigationOnClickListener { finish() }

        uriInput = findViewById(R.id.uri)
        issuerInput = findViewById(R.id.issuer)
        accountInput = findViewById(R.id.account)
        secretInput = findViewById(R.id.secret)

        findViewById<MaterialButton>(R.id.parse).setOnClickListener {
            applyUri(uriInput.text?.toString().orEmpty())
        }
        findViewById<MaterialButton>(R.id.scan).setOnClickListener {
            startScan()
        }
        findViewById<MaterialButton>(R.id.save).setOnClickListener {
            saveToken()
        }
    }

    private fun startScan() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED
        ) {
            launchScanner()
        } else {
            cameraPermission.launch(Manifest.permission.CAMERA)
        }
    }

    private fun launchScanner() {
        val options = ScanOptions().apply {
            setDesiredBarcodeFormats(ScanOptions.QR_CODE)
            setPrompt("将 otpauth 二维码放入框内")
            setBeepEnabled(false)
            setOrientationLocked(true)
            setCaptureActivity(CaptureActivityPortrait::class.java)
        }
        scanner.launch(options)
    }

    private fun applyUri(raw: String) {
        try {
            val token = OtpAuth.parse(raw)
            issuerInput.setText(token.issuer)
            accountInput.setText(token.account)
            secretInput.setText(token.secret)
            Toast.makeText(this, "已解析 otpauth 链接", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Toast.makeText(this, e.message ?: "解析失败", Toast.LENGTH_SHORT).show()
        }
    }

    private fun saveToken() {
        val secret = secretInput.text?.toString().orEmpty()
        if (!Base32.isValid(secret)) {
            Toast.makeText(this, "请输入有效的 Base32 密钥", Toast.LENGTH_SHORT).show()
            return
        }
        val token = TokenRecord(
            id = "${System.currentTimeMillis()}_${(0..99999).random()}",
            issuer = issuerInput.text?.toString()?.trim().orEmpty(),
            account = accountInput.text?.toString()?.trim().orEmpty(),
            secret = Base32.normalize(secret)
        )
        try {
            OtpEngine.generate(token)
        } catch (_: Exception) {
            Toast.makeText(this, "无法根据该密钥生成验证码", Toast.LENGTH_SHORT).show()
            return
        }
        val prefs = getSharedPreferences("f2a_store", Context.MODE_PRIVATE)
        val list = TokenStore.decode(prefs.getString("tokens", "[]") ?: "[]")
        list.add(0, token)
        prefs.edit().putString("tokens", TokenStore.encode(list)).apply()
        Toast.makeText(this, "令牌已保存", Toast.LENGTH_SHORT).show()
        finish()
    }
}
