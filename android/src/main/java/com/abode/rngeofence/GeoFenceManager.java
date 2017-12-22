package com.abode.rngeofence;

/**
 * Created by zigron on 03/10/2017.
 */

import android.Manifest;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.location.Location;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.util.Log;


import android.support.v4.content.ContextCompat;
import android.widget.Toast;


import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.WritableMap;
import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.api.GoogleApiClient;
import com.google.android.gms.common.api.ResultCallbacks;
import com.google.android.gms.common.api.Status;
import com.google.android.gms.location.FusedLocationProviderApi;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingClient;
import com.google.android.gms.location.LocationListener;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.GeofencingRequest;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;

import java.util.Collections;
import java.util.List;
import java.util.concurrent.CountDownLatch;

public class GeoFenceManager implements GoogleApiClient.ConnectionCallbacks, GoogleApiClient.OnConnectionFailedListener,LocationListener,OnCompleteListener<Void>
{
    public static final String TAG = "RNABODE";
    public static final String TRANSITION_TASK_NAME = "region-monitor-transition";
    public static final String REGION_SYNC_TASK_NAME = "region-monitor-sync";

    private GeoFenceManagerInterface locationCallback;
    private GoogleApiClient googleApiClient;
    /**
     * Provides access to the Geofencing API.
     */
    private GeofencingClient mGeofencingClient;

    private PendingIntent geofencePendingIntent;
    private LocationRequest locationRequest;
    private FusedLocationProviderApi fusedLocationProviderApi;
    private CountDownLatch countDownLatch = new CountDownLatch(1);
    public ReactApplicationContext classContext;
    ResultCallbacks callback;
    public GeoFenceManager(@NonNull ReactApplicationContext context)
    {
        locationRequest = LocationRequest.create();
        locationRequest.setPriority(LocationRequest.PRIORITY_HIGH_ACCURACY);
        locationRequest.setInterval(6000);
        locationRequest.setFastestInterval(6000);
        fusedLocationProviderApi = LocationServices.FusedLocationApi;

        mGeofencingClient = LocationServices.getGeofencingClient(context);

        googleApiClient = new GoogleApiClient.Builder(context)
                .addConnectionCallbacks(this)
                .addOnConnectionFailedListener(this)
                .addApi(LocationServices.API)

                .build();
        googleApiClient.connect();

        this.classContext = context;

        //Intent intent = new Intent(context, RNGeoFenceTransitionService.class);
        // We use FLAG_UPDATE_CURRENT so that we get the same pending intent back when calling addGeofences() and removeGeofences().
        //geofencePendingIntent = PendingIntent.getService(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT);
        //Intent intent = new Intent("com.abode.rngeofence.GeofenceReceiver.ACTION_RECEIVE_GEOFENCE");

        //geofencePendingIntent = PendingIntent.getBroadcast( context, 0,
        //        intent, PendingIntent.FLAG_UPDATE_CURRENT);

    }

    public void locationInterfaceCallback(GeoFenceManagerInterface location){
        this.locationCallback = location;
    }

    @Override
    public void onConnected(@Nullable Bundle bundle)
    {
        countDownLatch.countDown();
        Log.d(TAG, "RNRegionMonitor Google client connected");
    }

    @Override
    public void onConnectionSuspended(int i)
    {

        Log.d(TAG, "RNRegionMonitor Google client suspended: " + i);
    }

    @Override
    public void onConnectionFailed(@NonNull ConnectionResult connectionResult)
    {
        countDownLatch.countDown();
        Log.d(TAG, "RNRegionMonitor Google client failed: " + connectionResult.getErrorMessage());
    }


    private GeofencingRequest getGeofencingRequest(List<Geofence> fences) {
        GeofencingRequest.Builder builder = new GeofencingRequest.Builder();

        // The INITIAL_TRIGGER_ENTER flag indicates that geofencing service should trigger a
        // GEOFENCE_TRANSITION_ENTER notification when the geofence is added and if the device
        // is already inside that geofence.
        builder.setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER);

        // Add the geofences to be monitored by geofencing service.
        builder.addGeofences(fences);

        // Return a GeofencingRequest.
        return builder.build();
    }

    /**
     * Gets a PendingIntent to send with the request to add or remove Geofences. Location Services
     * issues the Intent inside this PendingIntent whenever a geofence transition occurs for the
     * current list of geofences.
     *
     * @return A PendingIntent for the IntentService that handles geofence transitions.
     */
    private PendingIntent getGeofencePendingIntent() {
        // Reuse the PendingIntent if we already have it.
        if (geofencePendingIntent != null) {
            return geofencePendingIntent;
        }
        Intent intent = new Intent(this.classContext, RNGeoFenceTransitionService.class);
        // We use FLAG_UPDATE_CURRENT so that we get the same pending intent back when calling
        // addGeofences() and removeGeofences().
        geofencePendingIntent = PendingIntent.getService(this.classContext, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT);
        return geofencePendingIntent;
    }


    public void addGeofences(@NonNull List<Geofence> geofences, @NonNull ResultCallbacks<Status> callbac) throws InterruptedException
    {
        GeofencingRequest request = getGeofencingRequest(geofences);
        if(ContextCompat.checkSelfPermission(this.classContext, Manifest.permission.ACCESS_FINE_LOCATION ) != PackageManager.PERMISSION_GRANTED){
            //request permissions
        }
        this.callback = callbac;
        mGeofencingClient.addGeofences(request, getGeofencePendingIntent())
                .addOnCompleteListener(this);

        //LocationServices.GeofencingApi.addGeofences(googleApiClient, request, geofencePendingIntent).setResultCallback(callback);
    }

    @Override
    public void onComplete(@NonNull Task<Void> task) {
        //mPendingGeofenceTask = PendingGeofenceTask.NONE;
        if (task.isSuccessful()) {
            //updateGeofencesAdded(!getGeofencesAdded());
            //setButtonsEnabledState();
            Status st = new Status(0);
            this.callback.onSuccess(st);
            //int messageId = getGeofencesAdded() ? R.string.geofences_added :
            //        R.string.geofences_removed;
            //Toast.makeText(this, getString(messageId), Toast.LENGTH_SHORT).show();
        } else {
            // Get the status code for the error and log it using a user-friendly message.
            //String errorMessage = GeofenceErrorMessages.getErrorString(this, task.getException());
            //Log.w(TAG, errorMessage);
        }
    }

    public void clearGeofences(@NonNull ResultCallbacks<Status> callback) throws InterruptedException
    {
        mGeofencingClient.removeGeofences(getGeofencePendingIntent()).addOnCompleteListener(this);

        //LocationServices.GeofencingApi.removeGeofences(googleApiClient, getGeofencePendingIntent()).setResultCallback(callback);
    }

    public void removeGeofence(@NonNull String id, @NonNull ResultCallbacks<Status> callback) throws InterruptedException
    {
        countDownLatch.await();
        LocationServices.GeofencingApi.removeGeofences(googleApiClient, Collections.singletonList(id)).setResultCallback(callback);
    }

    public void requestLocation(){
        if(ContextCompat.checkSelfPermission(this.classContext, Manifest.permission.ACCESS_FINE_LOCATION ) == PackageManager.PERMISSION_GRANTED) {
            fusedLocationProviderApi.requestLocationUpdates(googleApiClient, locationRequest, this);
        }

    }


    @Override
    public void onLocationChanged(Location location) {
        Log.w("Location Fetched:" , location.toString());
        //Toast.makeText(mContext, "location :"+location.getLatitude()+" , "+location.getLongitude(), Toast.LENGTH_SHORT).show();
        WritableMap coords = Arguments.createMap();
        coords.putDouble("latitude", location.getLatitude());
        coords.putDouble("longitude", location.getLongitude());
        coords.putDouble("accuracy", location.getAccuracy());

        WritableMap locationHash = Arguments.createMap();
        locationHash.putMap("coords",coords);
        locationHash.putDouble("timestamp",location.getTime());

        this.locationCallback.locationFetched(locationHash);

    }
}
