
package com.abode.rngeofence;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.support.annotation.NonNull;
import android.util.Log;
import android.content.IntentFilter;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;


import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.google.android.gms.common.api.ResultCallbacks;
import com.google.android.gms.common.api.Status;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingEvent;

import android.content.BroadcastReceiver;
import android.support.v4.content.LocalBroadcastManager;

import java.util.Arrays;
import java.util.List;

interface GeoFenceManagerInterface{
  void locationFetched(Object location);
}


public class RNGeofenceModule extends ReactContextBaseJavaModule implements GeoFenceManagerInterface{

  private final ReactApplicationContext reactContext;
  private boolean initialized = false;
  private boolean configured = false;
  private Intent launchIntent;
  private GeoFenceManager geofenceManager;

  public static final String EVENT_GEOFENCE = "geofence";
  public static final String EVENT_LOCATIONCHANGE = "location";

  @Override
  public void locationFetched(Object location){
    this.sendEvent(this.EVENT_LOCATIONCHANGE,location);
  }

  private BroadcastReceiver mLocalBroadcastReceiver = new BroadcastReceiver() {
    @Override
    public void onReceive(Context context, Intent intent) {
      // Get extra data included in the Intent
      if (intent.getExtras() == null)
      {
        return;
      }
      Intent fenceIntent = intent.getParcelableExtra("geofence");

      Log.d(GeoFenceManager.TAG, fenceIntent.toString());
      GeofencingEvent geofencingEvent = GeofencingEvent.fromIntent(fenceIntent);

      if (geofencingEvent.hasError())
      {
        // Suppress geofencing event with error
        int error = geofencingEvent.getErrorCode();
        Integer integerError = new Integer(error);
        Log.d(GeoFenceManager.TAG, "Suppress geocoding event with error");
        Log.d(GeoFenceManager.TAG, integerError.toString());

        return;
      }


      WritableMap coords = Arguments.createMap();
      coords.putDouble("latitude", geofencingEvent.getTriggeringLocation().getLatitude());
      coords.putDouble("longitude", geofencingEvent.getTriggeringLocation().getLongitude());
      coords.putDouble("accuracy", geofencingEvent.getTriggeringLocation().getAccuracy());
      coords.putDouble("timestamp",geofencingEvent.getTriggeringLocation().getTime());

      WritableMap location = Arguments.createMap();
      location.putMap("coords",coords);

      WritableMap region = Arguments.createMap();
      region.putString("identifier", geofencingEvent.getTriggeringGeofences().get(0).getRequestId());

      String action = "ENTER";
      if(geofencingEvent.getGeofenceTransition() == Geofence.GEOFENCE_TRANSITION_EXIT){
        action = "EXIT";
      }

      region.putMap("location", location);
      region.putString("action",action);

      Log.d(GeoFenceManager.TAG, "Report geofencing event to JS: " + region);

      reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
              .emit(RNGeofenceModule.EVENT_GEOFENCE, region);
    }
  };


  public RNGeofenceModule(ReactApplicationContext reactContext) {
    super(reactContext);

    LocalBroadcastManager localBroadcastManager = LocalBroadcastManager.getInstance(reactContext);
    localBroadcastManager.registerReceiver(mLocalBroadcastReceiver, new IntentFilter("geofenceIntent"));

    this.geofenceManager = new GeoFenceManager(reactContext);
    this.geofenceManager.locationInterfaceCallback(this);
    this.reactContext = reactContext;
  }



  @Override
  public String getName() {
    return "RNGeofence";
  }


  private void sendEvent(String eventName, Object params) {
    getReactApplicationContext()
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
            .emit(eventName, params);
  }

  @ReactMethod
  public void configure(ReadableMap option, final Callback success, final Callback failure){
    if(configured){ return; }

    configured = true;
  }

  @ReactMethod
  public void requestLocation(){
      this.geofenceManager.requestLocation();
  }

  @ReactMethod
  public void addGeofence(@NonNull ReadableMap geofence, @NonNull final Callback success, @NonNull final Callback failure){
    System.out.print("testing geofence");
    double latitude = geofence.getDouble("latitude");
    double longitude = geofence.getDouble("longitude");
    int     radius   = geofence.getInt("radius");
    String  identifier  = geofence.getString("identifier");

    // setLoiteringDelay, is the delay between Fence Enter Event & Dwell
    Geofence fence = new Geofence.Builder().setRequestId(identifier)
            .setCircularRegion(latitude, longitude, radius)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER | Geofence.GEOFENCE_TRANSITION_EXIT)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setLoiteringDelay(300000)
            .build();

    List<Geofence> fenceList = Arrays.asList(fence);
    try {
      geofenceManager.addGeofences(fenceList,new ResultCallbacks<Status>(){
        @Override
        public void onSuccess(@NonNull Status status)
        {
          Log.d(GeoFenceManager.TAG, "addCircularRegion: " + status);

          //data.addRegion(region);
          //data.save(getReactAppl  icationContext());
          success.invoke();
        }

        @Override
        public void onFailure(@NonNull Status status)
        {
          Log.d(GeoFenceManager.TAG, "addCircularRegion: " + status);
          failure.invoke();
          //promise.reject(Integer.toString(status.getStatusCode()), status.getStatusMessage());
        }
      });
    } catch (InterruptedException e) {
      e.printStackTrace();
    }

  }



  @ReactMethod
  public void removeGeofences(@NonNull final Callback success, @NonNull final Callback failure){

  }
}