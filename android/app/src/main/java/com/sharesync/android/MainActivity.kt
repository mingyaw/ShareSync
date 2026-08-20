package com.sharesync.android

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val density = resources.displayMetrics.density
        val padding = (24 * density).toInt()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(padding, padding, padding, padding)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }

        val title = TextView(this).apply {
            text = getString(R.string.app_name)
            textSize = 28f
            setTextColor(getColor(android.R.color.black))
        }

        val status = TextView(this).apply {
            text = getString(R.string.m0_status, M0SyncComponents.defaultPort())
            textSize = 16f
            setTextColor(getColor(android.R.color.darker_gray))
            setPadding(0, (12 * density).toInt(), 0, 0)
        }

        root.addView(title)
        root.addView(status)
        setContentView(root)
    }
}
