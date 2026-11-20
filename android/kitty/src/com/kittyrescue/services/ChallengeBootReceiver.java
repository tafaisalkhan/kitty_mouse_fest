package com.kittyrescue.services;
import android.content.*;
public final class ChallengeBootReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context,Intent intent) {
        String action=intent.getAction();
        if (Intent.ACTION_BOOT_COMPLETED.equals(action)||Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)) ChallengeReceiver.schedule(context);
    }
}
