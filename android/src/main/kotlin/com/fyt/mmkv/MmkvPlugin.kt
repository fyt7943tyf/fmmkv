package com.fyt.mmkv

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.PluginRegistry.Registrar

/** MmkvPlugin */
class MmkvPlugin: FlutterPlugin {

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {}

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}

  companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) {}
  }
}
