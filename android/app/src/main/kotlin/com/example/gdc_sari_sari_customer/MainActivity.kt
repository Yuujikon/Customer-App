package com.example.gdc_sari_sari_customer

import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.google.android.gms.security.ProviderInstaller
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            ProviderInstaller.installIfNeededAsync(this, this)
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to invoke ProviderInstaller", e)
        }
    }

    override fun onProviderInstalled() {
        Log.i("MainActivity", "Google Play Services security provider installed successfully.")
    }

    override fun onProviderInstallFailed(errorCode: Int, recoveryIntent: Intent?) {
        Log.w("MainActivity", "Google Play Services provider installation failed (code: $errorCode).")
    }

    override fun getRenderMode(): RenderMode {
        return RenderMode.surface
    }
}

