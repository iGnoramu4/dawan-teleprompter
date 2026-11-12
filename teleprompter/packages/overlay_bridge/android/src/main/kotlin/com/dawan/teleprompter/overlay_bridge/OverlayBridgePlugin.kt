package com.dawan.teleprompter.overlay_bridge

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.JSONMessageCodec

/**
 * 在主引擎与悬浮窗引擎之间双向转发 JSON 消息。
 *
 * 两个引擎各自注册同一个通道；任一引擎发送的消息会转给另一个引擎的
 * Dart 处理器，避免插件自带 messenger 在悬浮窗引擎内回环。
 */
class OverlayBridgePlugin : FlutterPlugin {
    private var channel: BasicMessageChannel<Any?>? = null
    private var isMainEngine = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val channel = BasicMessageChannel<Any?>(
            binding.binaryMessenger,
            CHANNEL,
            JSONMessageCodec.INSTANCE,
        )
        this.channel = channel
        // 主引擎先于悬浮窗引擎创建；第二个接入的引擎即悬浮窗引擎。
        if (mainChannel == null) {
            isMainEngine = true
            mainChannel = channel
        } else {
            overlayChannel = channel
        }
        channel.setMessageHandler { message, reply ->
            val target = if (isMainEngine) overlayChannel else mainChannel
            target?.send(message)
            reply.reply(null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMessageHandler(null)
        if (isMainEngine) {
            mainChannel = null
        } else if (overlayChannel === channel) {
            overlayChannel = null
        }
        channel = null
    }

    companion object {
        private const val CHANNEL = "com.tp.prompter.teleprompter/overlay_bridge"

        @Volatile
        private var mainChannel: BasicMessageChannel<Any?>? = null

        @Volatile
        private var overlayChannel: BasicMessageChannel<Any?>? = null
    }
}
