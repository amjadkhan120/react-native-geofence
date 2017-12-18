package com.abode.rngeofence;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;

import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingEvent;

/**
 * Created by zigron on 17/10/2017.
 */

public class GeofenceReceiver extends BroadcastReceiver {
    public void onReceive(Context context, Intent intent) {
        if (intent.getExtras() == null)
        {
            return;
        }else{
            handleEnterExit(intent, context);
        }

    }

    private void handleError(Intent intent){

    }

    private void handleEnterExit(Intent intent, Context context) {
        GeofencingEvent geofencingEvent = GeofencingEvent.fromIntent(intent);

        int transition = geofencingEvent.getGeofenceTransition();
        if (transition == Geofence.GEOFENCE_TRANSITION_ENTER){
            Log.v("geofence","entered");
        }else if(transition == Geofence.GEOFENCE_TRANSITION_EXIT){
            Log.v("geofence","exited");
        }

        if(geofencingEvent.hasError()){
            Log.d("Geofence Hit With Error", intent.toString());
        }else{
            Log.d("Geofence Hit", intent.toString());
        }

        Intent intent1 = new Intent("geofenceIntent");
        intent1.putExtra("geofence", intent);

        LocalBroadcastManager localBroadcastManager = LocalBroadcastManager.getInstance(context);
        localBroadcastManager.sendBroadcast(intent1);
    }
}
