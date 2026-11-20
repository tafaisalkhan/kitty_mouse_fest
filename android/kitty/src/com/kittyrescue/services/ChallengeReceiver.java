package com.kittyrescue.services;

import android.app.*;
import android.content.*;
import android.os.Build;
import java.util.Calendar;

public final class ChallengeReceiver extends BroadcastReceiver {
    static final String CHANNEL="daily_challenge";
    static PendingIntent alarm(Context context) { return PendingIntent.getBroadcast(context,1090,new Intent(context,ChallengeReceiver.class),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE); }
    public static void schedule(Context context) {
        android.content.SharedPreferences prefs=context.getSharedPreferences("kitty_notifications",0);
        AlarmManager manager=(AlarmManager)context.getSystemService(Context.ALARM_SERVICE);
        if (!prefs.getBoolean("enabled",false)) { manager.cancel(alarm(context)); return; }
        Calendar next=Calendar.getInstance(); next.set(Calendar.HOUR_OF_DAY,19); next.set(Calendar.MINUTE,0); next.set(Calendar.SECOND,0); next.set(Calendar.MILLISECOND,0);
        if (next.getTimeInMillis()<=System.currentTimeMillis()) next.add(Calendar.DAY_OF_YEAR,1);
        manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,next.getTimeInMillis(),alarm(context));
    }
    @Override public void onReceive(Context context,Intent ignored) {
        if (!context.getSharedPreferences("kitty_notifications",0).getBoolean("enabled",false)) return;
        NotificationManager manager=(NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT>=26) manager.createNotificationChannel(new NotificationChannel(CHANNEL,"Daily Challenge",NotificationManager.IMPORTANCE_DEFAULT));
        Intent launch=context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (launch!=null && (Build.VERSION.SDK_INT<33 || context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)==android.content.pm.PackageManager.PERMISSION_GRANTED)) {
            launch.putExtra("daily_challenge",true).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP|Intent.FLAG_ACTIVITY_SINGLE_TOP);
            PendingIntent open=PendingIntent.getActivity(context,1091,launch,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
            int small=context.getResources().getIdentifier("icon_monochrome","mipmap",context.getPackageName());
            Notification.Builder builder=Build.VERSION.SDK_INT>=26 ? new Notification.Builder(context,CHANNEL) : new Notification.Builder(context);
            Notification notice=builder.setSmallIcon(small==0?android.R.drawable.star_on:small).setContentTitle("Today's Daily Challenge is ready!").setContentText("A new mouse hunt and your daily coin reward are waiting.").setContentIntent(open).setAutoCancel(true).build();
            manager.notify(1090,notice);
        }
        schedule(context);
    }
}
