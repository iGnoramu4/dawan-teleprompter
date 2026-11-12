package com.dawan.teleprompter

import android.content.Context
import android.graphics.Color
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Display
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 外接显示（E7-1）：DisplayManager 枚举副屏 + Presentation 输出纯稿件。
 *
 * 只做「枚举 / 显示 / 更新 / 关闭」四件事；行号与文本由 Dart 端给出，
 * 原生不参与排版计算，便于和阅读页保持同一行号坐标系。
 */
class ExternalDisplayController(
    private val context: Context,
    messenger: BinaryMessenger,
) : DisplayManager.DisplayListener {
    companion object {
        const val CHANNEL = "tps/display"

        /** 副屏上居中显示的窗口行数（当前行居中）。 */
        private const val VISIBLE_LINES = 5
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val displayManager =
        context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var presentation: PrompterPresentation? = null
    private var shownDisplayId = Display.DEFAULT_DISPLAY

    init {
        channel.setMethodCallHandler(::onMethodCall)
        displayManager.registerDisplayListener(this, mainHandler)
    }

    fun dispose() {
        displayManager.unregisterDisplayListener(this)
        channel.setMethodCallHandler(null)
        dismiss()
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "listDisplays" -> result.success(displays())
                "present" -> {
                    show(call)
                    result.success(true)
                }
                "update" -> {
                    update(call)
                    result.success(null)
                }
                "dismiss" -> {
                    dismiss()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("display_error", error.message, null)
        }
    }

    private fun displays(): List<Map<String, Any>> {
        return displayManager.displays
            .filter { it.displayId != Display.DEFAULT_DISPLAY && it.isValid }
            .map { display ->
                val metrics = context.resources.displayMetrics
                mapOf(
                    "id" to display.displayId,
                    "name" to (display.name ?: "Display ${display.displayId}"),
                    "width" to (display.mode?.physicalWidth ?: metrics.widthPixels),
                    "height" to (display.mode?.physicalHeight ?: metrics.heightPixels),
                    "presentation" to
                        (display.flags and Display.FLAG_PRESENTATION != 0),
                )
            }
    }

    private fun show(call: MethodCall) {
        val displayId = call.argument<Int>("displayId") ?: return
        val display = displayManager.getDisplay(displayId) ?: return
        dismiss()
        val next = PrompterPresentation(context, display)
        next.apply(
            lines = call.argument<List<String>>("lines") ?: emptyList(),
            anchor = call.argument<Int>("anchor") ?: 0,
            fontSizeSp = (call.argument<Double>("fontSize") ?: 48.0).toFloat(),
            mirrored = call.argument<Boolean>("mirrored") ?: false,
            bandRatio = (call.argument<Double>("bandRatio") ?: 0.5).toFloat(),
        )
        next.show()
        presentation = next
        shownDisplayId = displayId
    }

    private fun update(call: MethodCall) {
        val target = presentation ?: return
        target.apply(
            lines = call.argument<List<String>>("lines") ?: emptyList(),
            anchor = call.argument<Int>("anchor") ?: 0,
            fontSizeSp = (call.argument<Double>("fontSize") ?: 48.0).toFloat(),
            mirrored = call.argument<Boolean>("mirrored") ?: false,
            bandRatio = (call.argument<Double>("bandRatio") ?: 0.5).toFloat(),
        )
    }

    private fun dismiss() {
        presentation?.dismiss()
        presentation = null
        shownDisplayId = Display.DEFAULT_DISPLAY
    }

    // ------------------------------------------------------ DisplayManager

    override fun onDisplayAdded(displayId: Int) = Unit

    override fun onDisplayChanged(displayId: Int) = Unit

    override fun onDisplayRemoved(displayId: Int) {
        if (displayId != shownDisplayId) return
        dismiss()
        channel.invokeMethod("displayRemoved", displayId)
    }

    /** 副屏稿件：黑底白字、当前行高亮、整体可水平镜像。 */
    private class PrompterPresentation(
        context: Context,
        display: Display,
    ) : android.app.Presentation(context, display) {
        private val container = FrameLayout(context)
        private val column = LinearLayout(context)
        private var lines: List<String> = emptyList()
        private var anchor = 0
        private var fontSizeSp = 48f
        private var mirrored = false

        /** 当前行在副屏上的纵向位置（0–1），与主阅读带比例一致。 */
        private var bandRatio = 0.5f

        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)
            container.setBackgroundColor(Color.BLACK)
            column.orientation = LinearLayout.VERTICAL
            column.gravity = Gravity.CENTER_HORIZONTAL
            container.addView(
                column,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.CENTER,
                ),
            )
            setContentView(container)
            window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            render()
            // 首次布局完成后容器才有高度，再按 bandRatio 计算纵向偏移。
            container.post { render() }
        }

        fun apply(
            lines: List<String>,
            anchor: Int,
            fontSizeSp: Float,
            mirrored: Boolean,
            bandRatio: Float,
        ) {
            this.lines = lines
            this.anchor = anchor
            this.fontSizeSp = fontSizeSp
            this.mirrored = mirrored
            this.bandRatio = bandRatio.coerceIn(0.2f, 0.8f)
            if (isShowing) render()
        }

        private fun render() {
            column.removeAllViews()
            container.scaleX = if (mirrored) -1f else 1f
            column.translationY = (bandRatio - 0.5f) * container.height
            if (lines.isEmpty()) {
                column.addView(label("（无稿件）", false))
                return
            }
            val half = VISIBLE_LINES / 2
            val start = (anchor - half).coerceAtLeast(0)
            val end = (start + VISIBLE_LINES).coerceAtMost(lines.size)
            for (index in start until end) {
                column.addView(label(lines[index], index == anchor))
            }
        }

        private fun label(text: String, highlight: Boolean): TextView {
            return TextView(context).apply {
                this.text = text
                gravity = Gravity.CENTER
                setTextColor(if (highlight) Color.parseColor("#FFD24A") else Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSizeSp)
                setPadding(48, 18, 48, 18)
                setSingleLine(false)
                maxLines = 3
                if (highlight) {
                    setTypeface(typeface, android.graphics.Typeface.BOLD)
                }
            }
        }
    }
}
