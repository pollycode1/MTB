package com.example.mtb

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import org.json.JSONObject

// รับข้อความที่แชร์มาจากแอพอื่น (เช่น LINE) → เข้ากล่องรับทันที ไม่ต้องเปิดแอพ
// บรรทัดแรกเป็นชื่องาน ข้อความเต็มเก็บเป็นหมายเหตุ (AI จัดหมวด/วันส่งให้ตอนเปิดแอพ)
class ShareToInboxActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim().orEmpty()
        val title = text.lineSequence().map { it.trim() }.firstOrNull { it.isNotEmpty() }.orEmpty().take(80)
        val ok = title.isNotEmpty() && MtbTasksWidget.addTask(this, JSONObject().apply {
            put("title", title)
            put("type", "inbox")
            if (text != title) put("meta", text)
        })
        Toast.makeText(this, if (ok) "เพิ่มเข้ากล่องรับแล้ว: $title" else "ไม่มีข้อความให้เพิ่ม", Toast.LENGTH_SHORT).show()
        finish()
    }
}
