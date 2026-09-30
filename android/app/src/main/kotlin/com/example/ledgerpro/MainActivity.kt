package com.example.ledgerpro

import com.example.dftar.BuildConfig
import com.example.dftar.R

import android.content.Intent
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.RectF
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.net.Uri
import androidx.core.content.FileProvider
import android.text.Layout
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.URLEncoder
import java.util.Locale

class MainActivity : FlutterFragmentActivity() {
    private val whatsappChannel = "dftar/whatsapp"
    private val pdfChannel = "dftar/native_pdf"
    private val backupAlarmChannel = "dftar/backup_alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupAlarmChannel).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "scheduleDailyBackup" -> {
                        val hour = (call.argument<Int>("hour") ?: 2).coerceIn(0, 23)
                        val minute = (call.argument<Int>("minute") ?: 0).coerceIn(0, 59)
                        scheduleDailyBackup(hour, minute)
                        result.success(true)
                    }
                    "cancelDailyBackup" -> {
                        cancelDailyBackup()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("BACKUP_ALARM_ERROR", e.message, null)
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, whatsappChannel).setMethodCallHandler { call, result ->
            if (call.method != "openWhatsApp") { result.notImplemented(); return@setMethodCallHandler }
            val phone = call.argument<String>("phone") ?: ""
            val text = call.argument<String>("text") ?: ""
            val business = call.argument<Boolean>("business") ?: false
            if (phone.isBlank()) { result.success(false); return@setMethodCallHandler }
            try {
                val pkg = if (business) "com.whatsapp.w4b" else "com.whatsapp"
                val encoded = URLEncoder.encode(text, "UTF-8")
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/" + phone + "?text=" + encoded)).apply { setPackage(pkg) }
                if (intent.resolveActivity(packageManager) != null) { startActivity(intent); result.success(true) } else result.success(false)
            } catch (_: Exception) { result.success(false) }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pdfChannel).setMethodCallHandler { call, result ->
            if (call.method != "createStatementPdf" && call.method != "openStatementPdf") { result.notImplemented(); return@setMethodCallHandler }
            try {
                val account = call.argument<Map<String, Any?>>("account") ?: emptyMap()
                val profile = call.argument<Map<String, Any?>>("profile") ?: emptyMap()
                val transactions = call.argument<List<Map<String, Any?>>>("transactions") ?: emptyList()
                val balance = (call.argument<Number>("balance") ?: 0).toDouble()
                val path = createStatementPdf(account, profile, transactions, balance)
                if (call.method == "openStatementPdf") {
                    val file = File(path)
                    val uri = FileProvider.getUriForFile(this, BuildConfig.APPLICATION_ID + ".fileprovider", file)
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/pdf")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    if (intent.resolveActivity(packageManager) == null) throw IllegalStateException("لا يوجد تطبيق لفتح ملفات PDF")
                    startActivity(intent)
                }
                result.success(path)
            } catch (e: Exception) {
                result.error("PDF_ERROR", e.message, null)
            }
        }
    }

    private fun scheduleDailyBackup(hour: Int, minute: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, BackupAlarmReceiver::class.java).setAction(BackupAlarmReceiver.ACTION_BACKUP)
        val pending = PendingIntent.getBroadcast(
            this, 7107, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val calendar = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, hour)
            set(java.util.Calendar.MINUTE, minute)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(java.util.Calendar.DAY_OF_YEAR, 1)
        }
        alarmManager.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            calendar.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pending
        )
    }

    private fun cancelDailyBackup() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, BackupAlarmReceiver::class.java).setAction(BackupAlarmReceiver.ACTION_BACKUP)
        val pending = PendingIntent.getBroadcast(
            this, 7107, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pending)
        pending.cancel()
    }

    private fun money(value: Double): String = String.format(Locale.US, "%.2f", value)

    private fun drawText(canvas: Canvas, text: String, x: Float, y: Float, size: Float, color: Int, bold: Boolean, align: Paint.Align) {
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.textSize = size
        p.color = color
        p.textAlign = align
        p.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
        canvas.drawText(text, x, y, p)
    }

    private fun drawRtl(canvas: Canvas, text: String, right: Float, top: Float, width: Int, size: Float, color: Int, bold: Boolean) {
        if (text.isBlank()) return
        val p = TextPaint(Paint.ANTI_ALIAS_FLAG)
        p.textSize = size
        p.color = color
        p.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
        val layout = StaticLayout.Builder.obtain(text, 0, text.length, p, width)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setIncludePad(false)
            .setTextDirection(TextDirectionHeuristics.RTL)
            .build()
        canvas.save()
        canvas.translate(right - width, top)
        layout.draw(canvas)
        canvas.restore()
    }

    private fun createStatementPdf(account: Map<String, Any?>, profile: Map<String, Any?>, transactions: List<Map<String, Any?>>, balance: Double): String {
        val document = PdfDocument()
        val width = 595
        val height = 842
        val margin = 34f
        val green = Color.rgb(8, 127, 91)
        val dark = Color.rgb(25, 40, 36)
        val light = Color.rgb(244, 248, 246)
        val border = Color.rgb(205, 216, 211)
        val white = Color.WHITE

        var pageNumber = 0
        var page: PdfDocument.Page? = null
        var canvas: Canvas? = null
        var y = 0f

        fun startPage() {
            pageNumber += 1
            page = document.startPage(PdfDocument.PageInfo.Builder(width, height, pageNumber).create())
            canvas = page!!.canvas
            canvas!!.drawColor(white)
            val owner = profile["user_name"]?.toString().orEmpty().ifBlank { "سمير الحسامي" }
            val address = profile["address_ar"]?.toString().orEmpty()
            drawText(canvas!!, owner, width - margin, margin + 20, 13f, dark, true, Paint.Align.RIGHT)
            drawText(canvas!!, address, width - margin, margin + 39, 9f, dark, false, Paint.Align.RIGHT)
            val logoPath = profile["logo_path"]?.toString().orEmpty()
            val logo = if (logoPath.isNotBlank()) BitmapFactory.decodeFile(logoPath) else BitmapFactory.decodeResource(resources, R.drawable.app_icon)
            if (logo != null && logo.width > 0 && logo.height > 0) {
                val max = 86f
                val scale = minOf(max / logo.width.toFloat(), max / logo.height.toFloat())
                val lw = logo.width * scale
                val lh = logo.height * scale
                canvas!!.drawBitmap(logo, null, RectF(width / 2f - lw / 2f, margin + 1f, width / 2f + lw / 2f, margin + 1f + lh), Paint(Paint.ANTI_ALIAS_FLAG))
            }
            drawText(canvas!!, "كشف حساب", width / 2f, margin + 104, 20f, dark, true, Paint.Align.CENTER)
            canvas!!.drawLine(margin, margin + 78, width - margin, margin + 78, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = dark; strokeWidth = 1.5f })
            y = margin + 98
        }

        fun finishPage() { page?.let { document.finishPage(it) }; page = null; canvas = null }
        fun ensure(space: Float) { if (y + space > height - 42) { finishPage(); startPage() } }

        startPage()

        val accountName = account["name"]?.toString().orEmpty()
        val accountPhone = account["phone"]?.toString().orEmpty()
        val accountAddress = account["address"]?.toString().orEmpty()
        val base = profile["base_currency"]?.toString().orEmpty().ifBlank {
            transactions.firstOrNull()?.get("baseCurrency")?.toString() ?: "YER"
        }

        drawRtl(canvas!!, "العميل: " + accountName, width - margin, y, width - (margin * 2).toInt(), 11f, dark, true)
        y += 25
        drawRtl(canvas!!, "الهاتف: " + if (accountPhone.isBlank()) "—" else accountPhone, width - margin, y, width - (margin * 2).toInt(), 10f, dark, false)
        y += 23
        drawRtl(canvas!!, "العنوان: " + if (accountAddress.isBlank()) "—" else accountAddress, width - margin, y, width - (margin * 2).toInt(), 10f, dark, false)
        y += 35

        val credit = transactions.filter { it["type"]?.toString() == "credit" }.sumOf { (it["baseAmount"] as? Number)?.toDouble() ?: 0.0 }
        val debit = transactions.filter { it["type"]?.toString() == "debit" }.sumOf { (it["baseAmount"] as? Number)?.toDouble() ?: 0.0 }
        val netLabel = if (balance >= 0) "له" else "عليه"

        canvas!!.drawRect(margin, y, width - margin, y + 62, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = light })
        canvas!!.drawRect(margin, y, width - margin, y + 62, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = border; style = Paint.Style.STROKE })
        drawText(canvas!!, "إجمالي الرصيد الحالي", width / 2f, y + 21, 11f, dark, true, Paint.Align.CENTER)
        drawText(canvas!!, money(kotlin.math.abs(balance)) + " " + base + " — " + netLabel, width / 2f, y + 48, 17f, green, true, Paint.Align.CENTER)
        y += 76

        drawText(canvas!!, "إجمالي له: " + money(credit) + " " + base, width - margin, y + 18, 9f, dark, true, Paint.Align.RIGHT)
        drawText(canvas!!, "إجمالي عليه: " + money(debit) + " " + base, width - margin, y + 38, 9f, dark, true, Paint.Align.RIGHT)
        y += 58

        drawText(canvas!!, "سجل العمليات", width - margin, y, 14f, green, true, Paint.Align.RIGHT)
        y += 10

        val rowHeight = 46f
        canvas!!.drawRect(margin, y, width - margin, y + 28, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = green })
        drawText(canvas!!, "التاريخ", 86f, y + 19, 8f, white, true, Paint.Align.CENTER)
        drawText(canvas!!, "العملية", 205f, y + 19, 8f, white, true, Paint.Align.CENTER)
        drawText(canvas!!, "المبلغ / المعادل", 380f, y + 19, 8f, white, true, Paint.Align.CENTER)
        drawText(canvas!!, "الرصيد", 515f, y + 19, 8f, white, true, Paint.Align.CENTER)
        y += 28

        var running = 0.0
        transactions.forEachIndexed { index, item ->
            ensure(rowHeight)
            if (index % 2 == 0) canvas!!.drawRect(margin, y, width - margin, y + rowHeight, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = light })
            canvas!!.drawRect(margin, y, width - margin, y + rowHeight, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = border; style = Paint.Style.STROKE })

            val amount = (item["amount"] as? Number)?.toDouble() ?: 0.0
            val baseAmount = (item["baseAmount"] as? Number)?.toDouble() ?: 0.0
            val type = item["type"]?.toString() ?: "credit"
            running += if (type == "credit") baseAmount else -baseAmount
            val date = item["date"]?.toString()?.take(10)?.replace("-", "/") ?: ""
            val note = item["note"]?.toString().orEmpty().ifBlank { item["category"]?.toString() ?: "عملية" }
            val currency = item["currency"]?.toString() ?: base

            drawText(canvas!!, date, 86f, y + 27, 7.5f, dark, false, Paint.Align.CENTER)
            drawText(canvas!!, note.take(20), 205f, y + 27, 7.5f, dark, false, Paint.Align.CENTER)
            drawText(canvas!!, money(amount) + " " + currency, 380f, y + 19, 7.5f, dark, false, Paint.Align.CENTER)
            drawText(canvas!!, money(baseAmount) + " " + base, 380f, y + 34, 6.5f, dark, false, Paint.Align.CENTER)
            drawText(canvas!!, money(running) + " " + base, 515f, y + 27, 7.5f, dark, false, Paint.Align.CENTER)
            y += rowHeight
        }

        if (transactions.isEmpty()) {
            drawText(canvas!!, "لا توجد عمليات مسجلة", width / 2f, y + 25, 10f, dark, false, Paint.Align.CENTER)
            y += 45
        }

        ensure(70f)
        y += 10
        canvas!!.drawRect(margin, y, width - margin, y + 58, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = light })
        canvas!!.drawRect(margin, y, width - margin, y + 58, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = border; style = Paint.Style.STROKE })
        drawText(canvas!!, "إجمالي له: " + money(credit) + " " + base, width - margin - 8, y + 19, 9f, dark, true, Paint.Align.RIGHT)
        drawText(canvas!!, "إجمالي عليه: " + money(debit) + " " + base, width - margin - 8, y + 38, 9f, dark, true, Paint.Align.RIGHT)
        drawText(canvas!!, "الصافي: " + money(kotlin.math.abs(balance)) + " " + base + " — " + netLabel, margin + 8, y + 31, 9f, green, true, Paint.Align.LEFT)

        finishPage()
        val dir = File(cacheDir, "statements")
        dir.mkdirs()
        val file = File(dir, "statement_" + System.currentTimeMillis() + ".pdf")
        FileOutputStream(file).use { document.writeTo(it) }
        document.close()
        return file.absolutePath
    }
}
