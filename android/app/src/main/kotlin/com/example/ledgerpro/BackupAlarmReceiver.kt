package com.example.ledgerpro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BackupAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_BACKUP = "com.example.dftar.BACKUP_ALARM"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_BACKUP) return
        val launch = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("run_backup_alarm", true)
        }
        context.startActivity(launch)
    }
}
