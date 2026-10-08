package com.f2a.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.floatingactionbutton.FloatingActionButton
import com.google.android.material.textfield.TextInputEditText

class MainActivity : AppCompatActivity() {
    private val prefs by lazy { getSharedPreferences("f2a_store", Context.MODE_PRIVATE) }
    private val tokens = mutableListOf<TokenRecord>()
    private lateinit var adapter: TokenAdapter
    private lateinit var emptyView: View
    private val handler = Handler(Looper.getMainLooper())
    private val ticker = object : Runnable {
        override fun run() {
            adapter.notifyDataSetChanged()
            handler.postDelayed(this, 400)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        load()
        emptyView = findViewById(R.id.emptyView)
        adapter = TokenAdapter(
            tokens,
            onCopy = { code ->
                val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                cm.setPrimaryClip(ClipData.newPlainText("otp", code))
                Toast.makeText(this, "验证码已复制", Toast.LENGTH_SHORT).show()
            },
            onDelete = { token ->
                AlertDialog.Builder(this)
                    .setTitle("是否删除")
                    .setMessage("确定删除 ${token.displayName()} 吗？")
                    .setNegativeButton("否", null)
                    .setPositiveButton("是") { _, _ ->
                        tokens.removeAll { it.id == token.id }
                        save()
                        refreshEmpty()
                        adapter.notifyDataSetChanged()
                    }
                    .show()
            }
        )
        findViewById<RecyclerView>(R.id.list).apply {
            layoutManager = LinearLayoutManager(this@MainActivity)
            adapter = this@MainActivity.adapter
        }
        findViewById<FloatingActionButton>(R.id.fab).setOnClickListener {
            startActivity(Intent(this, AddTokenActivity::class.java))
        }
        findViewById<TextInputEditText>(R.id.search).addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                adapter.keyword = s?.toString().orEmpty()
                adapter.notifyDataSetChanged()
            }
        })
        refreshEmpty()
    }

    override fun onResume() {
        super.onResume()
        load()
        adapter.notifyDataSetChanged()
        refreshEmpty()
        handler.post(ticker)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(ticker)
    }

    private fun load() {
        tokens.clear()
        tokens.addAll(TokenStore.decode(prefs.getString("tokens", "[]") ?: "[]"))
    }

    private fun save() {
        prefs.edit().putString("tokens", TokenStore.encode(tokens)).apply()
    }

    private fun refreshEmpty() {
        emptyView.visibility = if (tokens.isEmpty()) View.VISIBLE else View.GONE
    }
}

class TokenAdapter(
    private val source: List<TokenRecord>,
    private val onCopy: (String) -> Unit,
    private val onDelete: (TokenRecord) -> Unit
) : RecyclerView.Adapter<TokenAdapter.Holder>() {
    var keyword: String = ""

    private fun filtered(): List<TokenRecord> {
        val key = keyword.trim().lowercase()
        if (key.isEmpty()) return source
        return source.filter {
            it.issuer.lowercase().contains(key) || it.account.lowercase().contains(key)
        }
    }

    class Holder(view: View) : RecyclerView.ViewHolder(view) {
        val issuer: TextView = view.findViewById(R.id.issuer)
        val account: TextView = view.findViewById(R.id.account)
        val code: TextView = view.findViewById(R.id.code)
        val remain: ProgressBar = view.findViewById(R.id.remain)
        val deleteBtn: TextView = view.findViewById(R.id.deleteBtn)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.item_token, parent, false)
        return Holder(view)
    }

    override fun getItemCount(): Int = filtered().size

    override fun onBindViewHolder(holder: Holder, position: Int) {
        val token = filtered()[position]
        holder.issuer.text = token.issuer.ifBlank { "令牌" }
        holder.account.text = token.account
        val code = try {
            OtpEngine.generate(token)
        } catch (_: Exception) {
            "------"
        }
        holder.code.text = OtpEngine.formatCode(code)
        holder.remain.max = token.period
        holder.remain.progress = OtpEngine.remaining(token.period)
        holder.itemView.setOnClickListener { onCopy(code) }
        holder.deleteBtn.setOnClickListener { onDelete(token) }
    }
}
