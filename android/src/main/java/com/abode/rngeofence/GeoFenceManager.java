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


import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.WritableMap;
import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.api.GoogleApiClient;
import com.google.android.gms.common.api.ResultCallbacks;
import com.google.android.gms.common.api.Status;
import com.google.android.gms.location.FusedLocationProviderApi;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.LocationListener;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.GeofencingRequest;
import com.google.android.gms.location.LocationServices;

import java.util.Collections;
import java.util.List;
import java.util.concurrent.CountDownLatch;

public class GeoFenceManager implements GoogleApiClient.ConnectionCallbacks, GoogleApiClient.OnConnectionFailedListener,LocationListener
{
    public static final String TAG = "RNABODE";
    public static final String TRANSITION_TASK_NAME = "region-monitor-transition";
    public static final String REGION_SYNC_TASK_NAME = "region-monitor-sync";

    private GeoFenceManagerInterface locationCallback;
    private GoogleApiClient googleApiClient;
    private PendingIntent geofencePendingIntent;
    private LocationRequest locationRequest;
    private FusedLocationProviderApi fusedLocationProviderApi;
    private CountDownLatch countDownLatch = new CountDownLatch(1);
    public ReactApplicationContext classContext;

    public GeoFenceManager(@NonNull ReactApplicationContext context)
    {
        locationRequest = LocationRequest.create();
        locationRequest.setPriority(LocationRequest.PRIORITY_HIGH_ACCURACY);
        locationRequest.setInterval(6000);
        locationRequest.setFastestInterval(6000);
        fusedLocationProviderApi = LocationServices.FusedLocationApi;


        googleApiClient = new GoogleApiClient.Builder(context)
                .addConnectionCallbacks(this)
                .addOnConnectionFailedListener(this)
                .addApi(LocationServices.API)

                .build();
        googleApiClient.connect();
        this.classContext = context;

        Intent intent = new Intent(context, RNGeoFenceTransitionService.class);
        // We use FLAG_UPDATE_CURRENT so that we get the same pending intent back when calling addGeofences() and removeGeofences().
        geofencePendingIntent = PendingIntent.getService(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT);
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

    public void addGeofences(@NonNull List<Geofence> geofences, @NonNull ResultCallbacks<Status> callback) throws InterruptedException
    {
        countDownLatch.await();
        GeofencingRequest request = new GeofencingRequest.Builder().addGeofences(geofences).setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER).build();
        if(ContextCompat.checkSelfPermission(this.classContext, Manifest.permission.ACCESS_FINE_LOCATION ) != PackageManager.PERMISSION_GRANTED){
            //request permissions
        }
        LocationServices.GeofencingApi.addGeofences(googleApiClient, request, geofencePendingIntent).setResultCallback(callback);
    }

    public void clearGeofences(@NonNull ResultCallbacks<Status> callback) throws InterruptedException
    {
        countDownLatch.await();
        LocationServices.GeofencingApi.removeGeofences(googleApiClient, geofencePendingIntent).setResultCallback(callback);
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
