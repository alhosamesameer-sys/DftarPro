package com.example.ledgerpro

import com.example.dftar.BuildConfig
import com.example.dftar.R

import android.app.Activity
import android.content.Intent
import android.provider.ContactsContract
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
    private val chooseContactRequest = 7203
    private var pendingContactResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dftar/contacts").setMethodCallHandler { call, result ->
            if (call.method != "pickContact") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingContactResult != null) {
                result.error("BUSY", "يوجد اختيار جهة اتصال جارٍ بالفعل", null)
                return@setMethodCallHandler
            }
            pendingContactResult = result
            try {
                val intent = Intent(Intent.ACTION_PICK).apply {
                    data = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivityForResult(intent, chooseContactRequest)
            } catch (e: Exception) {
                pendingContactResult = null
                result.error("CONTACT_PICKER_ERROR", "تعذر فتح جهات الاتصال: ${e.message}", null)
            }
        }

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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == chooseContactRequest) {
            val pending = pendingContactResult
            pendingContactResult = null
            if (pending == null) return
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                pending.success(null)
                return
            }
            try {
                val contactUri = data.data!!
                var displayName: String? = null
                var phoneNumber: String? = null
                contentResolver.query(
                    contactUri,
                    arrayOf(
                        ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                        ContactsContract.CommonDataKinds.Phone.NUMBER
                    ),
                    null, null, null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                        val phoneIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                        if (nameIndex >= 0) displayName = cursor.getString(nameIndex)
                        if (phoneIndex >= 0) phoneNumber = cursor.getString(phoneIndex)
                    }
                }
                pending.success(mapOf("name" to (displayName ?: ""), "phone" to (phoneNumber ?: "")))
            } catch (e: Exception) {
                pending.error("CONTACT_READ_ERROR", "تعذر قراءة جهة الاتصال: ${e.message}", null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
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
        val contentWidth = width - (margin * 2)
        val dark = Color.rgb(25, 25, 25)
        val border = Color.rgb(55, 55, 55)
        val light = Color.rgb(247, 247, 247)
        val headerGray = Color.rgb(235, 235, 235)
        val white = Color.WHITE

        var pageNumber = 0
        var page: PdfDocument.Page? = null
        var canvas: Canvas? = null
        var y = 0f

        fun strokeRect(left: Float, top: Float, right: Float, bottom: Float, color: Int = border, stroke: Float = 1f) {
            canvas!!.drawRect(left, top, right, bottom, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = color
                style = Paint.Style.STROKE
                strokeWidth = stroke
            })
        }

        fun fillRect(left: Float, top: Float, right: Float, bottom: Float, color: Int) {
            canvas!!.drawRect(left, top, right, bottom, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = color
                style = Paint.Style.FILL
            })
        }

        fun cellRtl(text: String, left: Float, top: Float, right: Float, heightCell: Float, size: Float = 9f, bold: Boolean = false, color: Int = dark) {
            drawRtl(canvas!!, text, right - 5f, top + 5f, (right - left - 10f).toInt().coerceAtLeast(1), size, color, bold)
        }

        fun startPage() {
            pageNumber += 1
            page = document.startPage(PdfDocument.PageInfo.Builder(width, height, pageNumber).create())
            canvas = page!!.canvas
            canvas!!.drawColor(white)

            val ownerAr = profile["user_name"]?.toString().orEmpty().ifBlank { "سمير الحسامي" }
            val ownerEn = profile["user_name_en"]?.toString().orEmpty().ifBlank { "Sameer Alhosami" }
            val addressAr = profile["address_ar"]?.toString().orEmpty()
            val addressEn = profile["address_en"]?.toString().orEmpty()
            val phone = profile["phone"]?.toString().orEmpty()

            // Word-style header: English left, logo centered, Arabic right.
            drawText(canvas!!, ownerEn, margin + 4f, margin + 17f, 12f, dark, true, Paint.Align.LEFT)
            if (addressEn.isNotBlank()) drawText(canvas!!, addressEn, margin + 4f, margin + 34f, 8f, dark, false, Paint.Align.LEFT)

            val logoPath = profile["logo_path"]?.toString().orEmpty()
            val logo = if (logoPath.isNotBlank()) BitmapFactory.decodeFile(logoPath)
            else BitmapFactory.decodeResource(resources, R.drawable.app_icon)
            if (logo != null && logo.width > 0 && logo.height > 0) {
                val maxW = 58f
                val maxH = 58f
                val scale = minOf(maxW / logo.width.toFloat(), maxH / logo.height.toFloat())
                val lw = logo.width * scale
                val lh = logo.height * scale
                canvas!!.drawBitmap(logo, null, RectF(width / 2f - lw / 2f, margin - 1f, width / 2f + lw / 2f, margin - 1f + lh), Paint(Paint.ANTI_ALIAS_FLAG))
            }

            drawText(canvas!!, ownerAr, width - margin - 4f, margin + 17f, 12f, dark, true, Paint.Align.RIGHT)
            val arSecond = if (phone.isBlank()) addressAr else if (addressAr.isBlank()) phone else "$addressAr • $phone"
            if (arSecond.isNotBlank()) drawText(canvas!!, arSecond, width - margin - 4f, margin + 34f, 8f, dark, false, Paint.Align.RIGHT)

            canvas!!.drawLine(margin, margin + 68f, width - margin, margin + 68f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = dark
                strokeWidth = 1.4f
            })
            drawText(canvas!!, "كشف حساب", width / 2f, margin + 94f, 19f, dark, true, Paint.Align.CENTER)
            y = margin + 108f
        }

        fun finishPage() {
            page?.let { document.finishPage(it) }
            page = null
            canvas = null
        }

        fun ensure(space: Float) {
            if (y + space > height - 38f) {
                finishPage()
                startPage()
            }
        }

        fun drawCustomerTable() {
            val row1 = 25f
            val row2 = 27f
            val row3 = 27f
            fillRect(margin, y, width - margin, y + row1, headerGray)
            strokeRect(margin, y, width - margin, y + row1, border, 1.2f)
            cellRtl("بيانات العميل", margin, y, width - margin, row1, 10f, true)
            y += row1

            val mid = margin + contentWidth / 2f
            strokeRect(margin, y, width - margin, y + row2, border)
            canvas!!.drawLine(mid, y, mid, y + row2, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = border })
            cellRtl("اسم العميل: " + account["name"].toString(), mid, y, width - margin, row2, 8.5f)
            cellRtl("العنوان: " + (account["address"]?.toString().orEmpty().ifBlank { "—" }), margin, y, mid, row2, 8.5f)
            y += row2

            strokeRect(margin, y, width - margin, y + row3, border)
            canvas!!.drawLine(mid, y, mid, y + row3, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = border })
            cellRtl("رقم الهاتف: " + (account["phone"]?.toString().orEmpty().ifBlank { "—" }), mid, y, width - margin, row3, 8.5f)
            cellRtl("رقم الحساب: " + (account["id"]?.toString().orEmpty().takeLast(12)), margin, y, mid, row3, 8.5f)
            y += row3 + 10f
        }

        fun drawBalanceTables(base: String, credit: Double, debit: Double, netLabel: String) {
            val currentH = 58f
            fillRect(margin, y, width - margin, y + currentH, white)
            strokeRect(margin, y, width - margin, y + currentH, border, 1.2f)
            drawText(canvas!!, "إجمالي الرصيد الحالي", width / 2f, y + 19f, 10.5f, dark, true, Paint.Align.CENTER)
            drawText(canvas!!, money(kotlin.math.abs(balance)) + " " + base + " — " + netLabel, width / 2f, y + 43f, 16f, dark, true, Paint.Align.CENTER)
            y += currentH + 8f

            val h = 42f
            val c1 = margin
            val c2 = margin + contentWidth / 3f
            val c3 = margin + contentWidth * 2f / 3f
            val c4 = width - margin
            fillRect(c1, y, c4, y + h, light)
            strokeRect(c1, y, c4, y + h, border)
            canvas!!.drawLine(c2, y, c2, y + h, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = border })
            canvas!!.drawLine(c3, y, c3, y + h, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = border })
            cellRtl("إجمالي له\n" + money(credit) + " " + base, c3, y, c4, h, 8.5f, true)
            cellRtl("إجمالي عليه\n" + money(debit) + " " + base, c2, y, c3, h, 8.5f, true)
            cellRtl("الصافي\n" + money(kotlin.math.abs(balance)) + " " + base + " — " + netLabel, c1, y, c2, h, 8.5f, true)
            y += h + 12f
        }

        fun drawTransactionHeader() {
            val h = 28f
            fillRect(margin, y, width - margin, y + h, headerGray)
            strokeRect(margin, y, width - margin, y + h, border)
            val x2 = margin + contentWidth * 0.23f
            val x3 = margin + contentWidth * 0.48f
            val x4 = margin + contentWidth * 0.68f
            val x5 = width - margin
            canvas!!.drawLine(x2, y, x2, y + h, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = border })
            canvas!!.drawLine(x3, y, x3, y + h, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = border })
            canvas!!.drawLine(x4, y, x4, y + h, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = border })
            cellRtl("التاريخ", x4, y, x5, h, 8f, true)
            cellRtl("التفاصيل", x3, y, x4, h, 8f, true)
            cellRtl("النوع", x2, y, x3, h, 8f, true)
            cellRtl("المبلغ / ما يعادله", margin, y, x2, h, 7.5f, true)
            y += h
        }

        startPage()

        val base = profile["base_currency"]?.toString().orEmpty().ifBlank {
            transactions.firstOrNull()?.get("baseCurrency")?.toString() ?: "YER"
        }
        val credit = transactions.filter { it["type"]?.toString() == "credit" }
            .sumOf { (it["baseAmount"] as? Number)?.toDouble() ?: 0.0 }
        val debit = transactions.filter { it["type"]?.toString() == "debit" }
            .sumOf { (it["baseAmount"] as? Number)?.toDouble() ?: 0.0 }
        val netLabel = if (kotlin.math.abs(balance) < 0.000001) "الحساب متعادل" else if (balance > 0) "له" else "عليه"

        ensure(105f)
        drawCustomerTable()
        ensure(120f)
        drawBalanceTables(base, credit, debit, netLabel)

        drawText(canvas!!, "تفاصيل العمليات", width - margin, y, 12f, dark, true, Paint.Align.RIGHT)
        y += 8f
        drawTransactionHeader()

        val rowHeight = 44f
        if (transactions.isEmpty()) {
            strokeRect(margin, y, width - margin, y + rowHeight, border)
            drawText(canvas!!, "لا توجد عمليات مسجلة في هذا الحساب.", width / 2f, y + 27f, 9f, dark, false, Paint.Align.CENTER)
            y += rowHeight
        } else {
            transactions.forEachIndexed { index, item ->
                ensure(rowHeight)
                val rowTop = y
                val rowBottom = y + rowHeight
                if (index % 2 == 0) fillRect(margin, rowTop, width - margin, rowBottom, light)
                strokeRect(margin, rowTop, width - margin, rowBottom, border)

                val x2 = margin + contentWidth * 0.23f
                val x3 = margin + contentWidth * 0.48f
                val x4 = margin + contentWidth * 0.68f
                val x5 = width - margin
                canvas!!.drawLine(x2, rowTop, x2, rowBottom, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = border })
                canvas!!.drawLine(x3, rowTop, x3, rowBottom, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = border })
                canvas!!.drawLine(x4, rowTop, x4, rowBottom, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = border })

                val date = item["date"]?.toString()?.take(10)?.replace("-", "/") ?: ""
                val note = item["note"]?.toString().orEmpty().ifBlank { item["category"]?.toString() ?: "عملية" }
                val type = if (item["type"]?.toString() == "credit") "له" else "عليه"
                val amount = (item["amount"] as? Number)?.toDouble() ?: 0.0
                val baseAmount = (item["baseAmount"] as? Number)?.toDouble() ?: 0.0
                val currency = item["currency"]?.toString() ?: base

                cellRtl(date, x4, rowTop, x5, rowHeight, 7.2f)
                cellRtl(note.take(28), x3, rowTop, x4, rowHeight, 7.2f)
                cellRtl(type, x2, rowTop, x3, rowHeight, 7.5f, true)
                cellRtl(if (currency == base) money(amount) + " " + currency else money(amount) + " " + currency + "\nما يعادل " + money(baseAmount) + " " + base, margin, rowTop, x2, rowHeight, 7.1f)
                y = rowBottom
            }
        }

        ensure(82f)
        y += 8f
        val totalH = 62f
        fillRect(margin, y, width - margin, y + totalH, light)
        strokeRect(margin, y, width - margin, y + totalH, border)
        drawRtl(canvas!!, "إجمالي له: " + money(credit) + " " + base, width - margin - 8f, y + 7f, (contentWidth * 0.42f).toInt(), 8.5f, dark, true)
        drawRtl(canvas!!, "إجمالي عليه: " + money(debit) + " " + base, width - margin - 8f, y + 28f, (contentWidth * 0.42f).toInt(), 8.5f, dark, true)
        drawRtl(canvas!!, "الصافي: " + money(kotlin.math.abs(balance)) + " " + base + " — " + netLabel, margin + contentWidth * 0.58f, y + 18f, (contentWidth * 0.38f).toInt(), 9f, dark, true)

        finishPage()
        val dir = File(cacheDir, "statements")
        dir.mkdirs()
        val file = File(dir, "statement_" + System.currentTimeMillis() + ".pdf")
        FileOutputStream(file).use { document.writeTo(it) }
        document.close()
        return file.absolutePath
    }


}
