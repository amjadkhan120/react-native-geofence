package com.abode.rngeofence;

/**
 * Created by zigron on 04/10/2017.
 */

import android.app.IntentService;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.app.ActivityManager;
//import android.support.annotation.Nullable;
import android.support.v4.app.NotificationCompat;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;

import com.google.android.gms.location.GeofencingEvent;

import java.util.List;


public class RNGeoFenceTransitionService extends IntentService{

    private static final String TAG = RNGeoFenceTransitionService.class.getSimpleName();
    public static final int GEOFENCE_NOTIFICATION_ID = 0;

    private NotificationManager mNotificationManager;
    public static final int NOTIFICATION_ID = 1;
    public RNGeoFenceTransitionService() {
        super(TAG);
    }


    @Override
    protected void onHandleIntent(Intent intent)
    {
        if (intent.getExtras() == null)
        {
            return;
        }

        ActivityManager activityManager = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
        List<ActivityManager.RunningAppProcessInfo> services = activityManager.getRunningAppProcesses();
        boolean isActivityFound = false;

        if (services.get(0).processName
                .equalsIgnoreCase(getPackageName())) {
            isActivityFound = true;
        }



        GeofencingEvent geofencingEvent = GeofencingEvent.fromIntent(intent);

        if (geofencingEvent.hasError())
        {
            // Suppress geofencing event with error
            int error = geofencingEvent.getErrorCode();
            Integer integerError = new Integer(error);
            Log.d(GeoFenceManager.TAG, "Suppress geocoding event with error");
            Log.d(GeoFenceManager.TAG, integerError.toString());

        }

        if(isActivityFound) {
            Intent intent1 = new Intent("geofenceIntent");
            intent1.putExtra("geofence", intent);
            LocalBroadcastManager localBroadcastManager = LocalBroadcastManager.getInstance(this);
            localBroadcastManager.sendBroadcast(intent1);
            Log.d(GeoFenceManager.TAG, "addCircularRegion: foreground");
        }else {
            sendNotification("Geofence Hit");
            Log.d(GeoFenceManager.TAG, "addCircularRegion: background");
        }
        //return new HeadlessJsTaskConfig(RNGeofenceModule.EVENT_GEOFENCE, jsArgs, 0, true);

    }

    private void sendNotification(String msg) {
        mNotificationManager = (NotificationManager)
                this.getSystemService(Context.NOTIFICATION_SERVICE);

        //PendingIntent contentIntent = PendingIntent.getActivity(this, 0,
        //        new Intent(this, MainActivity.class), 0);

        NotificationCompat.Builder mBuilder =
                new NotificationCompat.Builder(this)
                        .setContentTitle("GCM Notification")
                        .setStyle(new NotificationCompat.BigTextStyle()
                                .bigText(msg))
                        .setContentText(msg);
        //mBuilder.setContentIntent(contentIntent);
        mNotificationManager.notify(NOTIFICATION_ID, mBuilder.build());
    }
}
