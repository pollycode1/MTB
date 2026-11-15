package com.example.mtb

import android.app.Application
import android.content.Context
import java.io.File

/** Installs the crash log before anything else runs (content providers start before activities). */
class MtbApp : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, e ->
            val text = "--- ${java.util.Date()} native ${thread.name}\n${android.util.Log.getStackTraceString(e)}\n"
            for (dir in listOf(base.filesDir, File("/storage/emulated/0/Download/MTB"))) {
                try { dir.mkdirs(); File(dir, "mtb-crash.txt").appendText(text) } catch (_: Throwable) {}
            }
            previous?.uncaughtException(thread, e)
        }
    }
}
