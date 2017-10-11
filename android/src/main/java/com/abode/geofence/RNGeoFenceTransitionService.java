package com.abode.geofence;

/**
 * Created by zigron on 04/10/2017.
 */

import android.app.IntentService;
import android.content.Intent;
//import android.support.annotation.Nullable;
import android.support.annotation.Nullable;
import android.util.Log;
import android.support.v4.content.LocalBroadcastManager;


import com.facebook.react.HeadlessJsTaskService;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.jstasks.HeadlessJsTaskConfig;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingEvent;
import com.facebook.react.bridge.ReactApplicationContext;

import org.json.JSONObject;


public class RNGeoFenceTransitionService extends IntentService{

    private static final String TAG = RNGeoFenceTransitionService.class.getSimpleName();
    public static final int GEOFENCE_NOTIFICATION_ID = 0;

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
        Intent intent1 = new Intent("geofenceIntent");
        intent1.putExtra("geofence", intent);
        LocalBroadcastManager localBroadcastManager = LocalBroadcastManager.getInstance(this);
        localBroadcastManager.sendBroadcast(intent1);

        //return new HeadlessJsTaskConfig(RNGeofenceModule.EVENT_GEOFENCE, jsArgs, 0, true);

    }

}
